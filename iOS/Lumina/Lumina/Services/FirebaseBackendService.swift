import Foundation
import UIKit
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import GoogleSignIn

@MainActor
final class FirebaseBackendService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var lastError: String?

    private var authHandle: AuthStateDidChangeListenerHandle?
    private var db: Firestore {
        Firestore.firestore()
    }

    func startAuthListener(onChange: @escaping (User?) -> Void) {
        guard authHandle == nil else { return }
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
                onChange(user)
                if let user {
                    do {
                        try await self?.syncUserProfile(user: user, displayName: user.displayName)
                    } catch {
                        self?.lastError = error.localizedDescription
                    }
                }
            }
        }
    }

    @discardableResult
    func registerEmail(displayName: String, email: String, password: String) async throws -> User {
        let result = try await withTimeout(seconds: 16) {
            try await Auth.auth().createUser(withEmail: email, password: password)
        }
        let changeRequest = result.user.createProfileChangeRequest()
        changeRequest.displayName = displayName
        try await changeRequest.commitChanges()
        try await result.user.reload()
        let user = Auth.auth().currentUser ?? result.user
        currentUser = user
        syncUserProfileInBackground(user: user, displayName: displayName)
        return user
    }

    @discardableResult
    func signInEmail(email: String, password: String) async throws -> User {
        let result = try await withTimeout(seconds: 16) {
            try await Auth.auth().signIn(withEmail: email, password: password)
        }
        currentUser = result.user
        syncUserProfileInBackground(user: result.user, displayName: result.user.displayName)
        return result.user
    }

    @discardableResult
    func signInGoogle() async throws -> User {
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw LuminaAuthError.providerUnavailable("Google sign-in is missing the iOS client ID.")
        }
        guard let presenter = Self.topViewController() else {
            throw LuminaAuthError.providerUnavailable("Google sign-in could not find a screen to present from.")
        }

        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        let signInResult = try await withTimeout(seconds: 30) {
            try await Self.googleSignIn(presenting: presenter)
        }
        guard let idToken = signInResult.user.idToken?.tokenString else {
            throw LuminaAuthError.providerUnavailable("Google sign-in did not return an ID token.")
        }

        let credential = GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: signInResult.user.accessToken.tokenString
        )
        let result = try await withTimeout(seconds: 16) {
            try await Auth.auth().signIn(with: credential)
        }
        currentUser = result.user
        syncUserProfileInBackground(user: result.user, displayName: result.user.displayName)
        return result.user
    }

    func signOut() throws {
        try Auth.auth().signOut()
        currentUser = nil
    }

    func syncUserProfile(user: User, displayName: String?) async throws {
        let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let providerIDs = user.providerData.map(\.providerID)
        let payload: [String: Any] = [
            "displayName": (name?.isEmpty == false ? name : nil) ?? user.displayName ?? "User",
            "email": user.email ?? NSNull(),
            "phoneNumber": user.phoneNumber ?? NSNull(),
            "photoURL": user.photoURL?.absoluteString ?? NSNull(),
            "providerIds": providerIDs,
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("users").document(user.uid).setData(payload, merge: true)
    }

    func saveTherapySession(_ session: ChatSession) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let sessionPayload = try Self.firestoreDictionary(from: session)
        let payload: [String: Any] = [
            "session": sessionPayload,
            "therapistID": session.therapistID,
            "lastUpdated": session.lastUpdated,
            "messageCount": session.messageCount,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await db
            .collection("users")
            .document(user.uid)
            .collection("therapySessions")
            .document(session.id)
            .setData(payload, merge: true)
    }

    func fetchTherapySessions(limit: Int = 200) async throws -> [ChatSession] {
        guard let user = Auth.auth().currentUser else { return [] }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("therapySessions")
            .order(by: "lastUpdated", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            guard let payload = document.data()["session"] as? [String: Any] else { return nil }
            return try? Self.decode(ChatSession.self, from: payload)
        }
    }

    func deleteTherapySession(id: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await db
            .collection("users")
            .document(user.uid)
            .collection("therapySessions")
            .document(id)
            .delete()
    }

    func saveTherapyContext(_ snapshot: WellbeingContextSnapshot, therapistID: String?) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let contextPayload = try Self.firestoreDictionary(from: snapshot)
        let documentID = therapistID ?? "global"
        let payload: [String: Any] = [
            "context": contextPayload,
            "therapistID": therapistID ?? NSNull(),
            "generatedAt": snapshot.generatedAt,
            "headline": snapshot.headline,
            "summary": snapshot.summary,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await db
            .collection("users")
            .document(user.uid)
            .collection("therapyContexts")
            .document(documentID)
            .setData(payload, merge: true)
    }

    func fetchSubscriptionState() async throws -> SubscriptionState {
        guard let user = Auth.auth().currentUser else { return SubscriptionState() }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("entitlements")
            .document("subscription")
            .getDocument()
        guard let data = snapshot.data() else { return SubscriptionState() }
        return Self.subscriptionState(from: data)
    }

    func saveSubscriptionState(_ state: SubscriptionState) async throws {
        guard let user = Auth.auth().currentUser else { return }
        var payload = Self.subscriptionPayload(from: state)
        payload["updatedAt"] = FieldValue.serverTimestamp()
        try await db
            .collection("users")
            .document(user.uid)
            .collection("entitlements")
            .document("subscription")
            .setData(payload, merge: true)
    }

    private func syncUserProfileInBackground(user: User, displayName: String?) {
        Task { @MainActor [weak self] in
            do {
                try await self?.syncUserProfile(user: user, displayName: displayName)
            } catch {
                self?.lastError = error.localizedDescription
            }
        }
    }

    private static func firestoreDictionary<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LuminaAuthError.providerUnavailable("Could not encode data for cloud sync.")
        }
        return object
    }

    private static func decode<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func subscriptionState(from data: [String: Any]) -> SubscriptionState {
        let tier = SubscriptionTier(rawValue: data["tier"] as? String ?? "") ?? .free
        let status = SubscriptionStatus(rawValue: data["status"] as? String ?? "") ?? .unknown
        let provider = SubscriptionProvider(rawValue: data["provider"] as? String ?? "") ?? .none
        let periodEnd: TimeInterval?
        if let timestamp = data["currentPeriodEnd"] as? Timestamp {
            periodEnd = timestamp.dateValue().timeIntervalSince1970
        } else {
            periodEnd = data["currentPeriodEnd"] as? TimeInterval
        }
        let updatedAt: TimeInterval
        if let timestamp = data["updatedAt"] as? Timestamp {
            updatedAt = timestamp.dateValue().timeIntervalSince1970
        } else {
            updatedAt = data["updatedAt"] as? TimeInterval ?? Date().timeIntervalSince1970
        }
        return SubscriptionState(
            tier: tier,
            status: status,
            provider: provider,
            revenueCatAppUserID: data["revenueCatAppUserID"] as? String,
            productID: data["productID"] as? String,
            entitlementID: data["entitlementID"] as? String,
            currentPeriodEnd: periodEnd,
            willRenew: data["willRenew"] as? Bool ?? false,
            updatedAt: updatedAt
        )
    }

    private static func subscriptionPayload(from state: SubscriptionState) -> [String: Any] {
        [
            "tier": state.tier.rawValue,
            "status": state.status.rawValue,
            "provider": state.provider.rawValue,
            "revenueCatAppUserID": state.revenueCatAppUserID ?? NSNull(),
            "productID": state.productID ?? NSNull(),
            "entitlementID": state.entitlementID ?? NSNull(),
            "currentPeriodEnd": state.currentPeriodEnd.map { Timestamp(date: Date(timeIntervalSince1970: $0)) } ?? NSNull(),
            "willRenew": state.willRenew
        ]
    }

    private func withTimeout<T>(seconds: UInt64, operation: @escaping () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            group.addTask {
                try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
                throw LuminaAuthError.providerUnavailable("The sign-in request timed out. Check your connection and try again.")
            }
            guard let result = try await group.next() else {
                throw LuminaAuthError.providerUnavailable("The sign-in request could not complete.")
            }
            group.cancelAll()
            return result
        }
    }

    private static func googleSignIn(presenting viewController: UIViewController) async throws -> GIDSignInResult {
        try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(withPresenting: viewController) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let result else {
                    continuation.resume(throwing: LuminaAuthError.providerUnavailable("Google sign-in was cancelled."))
                    return
                }
                continuation.resume(returning: result)
            }
        }
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        let root = scene?.windows.first { $0.isKeyWindow }?.rootViewController
        return topViewController(from: root)
    }

    private static func topViewController(from viewController: UIViewController?) -> UIViewController? {
        if let navigation = viewController as? UINavigationController {
            return topViewController(from: navigation.visibleViewController)
        }
        if let tab = viewController as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = viewController?.presentedViewController {
            return topViewController(from: presented)
        }
        return viewController
    }
}

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

    @discardableResult
    func signInApple(idToken: String, rawNonce: String, fullName: PersonNameComponents?) async throws -> User {
        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: rawNonce,
            fullName: fullName
        )
        let result = try await withTimeout(seconds: 16) {
            try await Auth.auth().signIn(with: credential)
        }
        currentUser = result.user
        let displayName = result.user.displayName ?? Self.displayName(from: fullName)
        syncUserProfileInBackground(user: result.user, displayName: displayName)
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
            "schemaVersion": 1,
            "displayName": (name?.isEmpty == false ? name : nil) ?? user.displayName ?? "User",
            "email": user.email ?? NSNull(),
            "phoneNumber": user.phoneNumber ?? NSNull(),
            "photoURL": user.photoURL?.absoluteString ?? NSNull(),
            "providerIds": providerIDs,
            "lastPlatform": "ios",
            "updatedAt": FieldValue.serverTimestamp(),
            "createdAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("users").document(user.uid).setData(payload, merge: true)
    }

    func saveAppProfile(_ profile: PersistedProfileState, account: LuminaAccount?) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let displayName = account?.displayName ?? profile.userName
        let profilePayload: [String: Any] = [
            "schemaVersion": 1,
            "displayName": displayName,
            "bio": profile.userBio,
            "avatarID": profile.avatarID.rawValue,
            "gender": profile.gender.rawValue,
            "joinDate": Timestamp(date: profile.joinDate),
            "journalGoalPerWeek": profile.journalGoalPerWeek,
            "meditationGoalMinutes": profile.meditationGoalMinutes,
            "useJournalContextInTherapy": profile.useJournalContextInTherapy,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db
            .collection("users")
            .document(user.uid)
            .collection("profile")
            .document("main")
            .setData(profilePayload, merge: true)

        let rootPayload: [String: Any] = [
            "schemaVersion": 1,
            "displayName": displayName,
            "avatarID": profile.avatarID.rawValue,
            "gender": profile.gender.rawValue,
            "email": account?.email ?? user.email ?? NSNull(),
            "phoneNumber": account?.phone ?? user.phoneNumber ?? NSNull(),
            "lastPlatform": "ios",
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await db.collection("users").document(user.uid).setData(rootPayload, merge: true)
        try await saveDeviceProfile(profile)
    }

    func fetchAppProfile() async throws -> PersistedProfileState? {
        guard let user = Auth.auth().currentUser else { return nil }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("profile")
            .document("main")
            .getDocument()
        guard let data = snapshot.data() else { return nil }
        return Self.profileState(from: data)
    }

    func saveJournalSummary(_ entry: JournalEntry) async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await db
            .collection("users")
            .document(user.uid)
            .collection("journalSummaries")
            .document(entry.id)
            .setData(Self.journalSummaryPayload(from: entry), merge: true)
    }

    func saveJournalSummaries(_ entries: [JournalEntry]) async throws {
        guard let user = Auth.auth().currentUser else { return }
        guard !entries.isEmpty else { return }
        let batch = db.batch()
        let collection = db
            .collection("users")
            .document(user.uid)
            .collection("journalSummaries")
        entries.forEach { entry in
            batch.setData(Self.journalSummaryPayload(from: entry), forDocument: collection.document(entry.id), merge: true)
        }
        try await batch.commit()
    }

    func deleteJournalSummary(id: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await db
            .collection("users")
            .document(user.uid)
            .collection("journalSummaries")
            .document(id)
            .delete()
    }

    func saveJournalDeletion(_ tombstone: JournalDeletionTombstone) async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await db
            .collection("users")
            .document(user.uid)
            .collection("journalDeletes")
            .document(tombstone.id)
            .setData(Self.journalDeletionPayload(from: tombstone), merge: true)
    }

    func saveJournalDeletions(_ tombstones: [JournalDeletionTombstone]) async throws {
        guard let user = Auth.auth().currentUser else { return }
        guard !tombstones.isEmpty else { return }
        let batch = db.batch()
        let collection = db
            .collection("users")
            .document(user.uid)
            .collection("journalDeletes")
        tombstones.forEach { tombstone in
            batch.setData(Self.journalDeletionPayload(from: tombstone), forDocument: collection.document(tombstone.id), merge: true)
        }
        try await batch.commit()
    }

    func fetchJournalDeletions(limit: Int = 500) async throws -> [JournalDeletionTombstone] {
        guard let user = Auth.auth().currentUser else { return [] }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("journalDeletes")
            .order(by: "deletedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            Self.journalDeletion(from: document.data(), documentID: document.documentID)
        }
    }

    func fetchJournalSummaries(limit: Int = 300) async throws -> [JournalEntry] {
        guard let user = Auth.auth().currentUser else { return [] }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("journalSummaries")
            .order(by: "timestamp", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            Self.journalEntry(from: document.data(), documentID: document.documentID)
        }
    }

    func saveDailyJournalInsights(_ insights: DailyJournalInsights) async throws {
        guard let user = Auth.auth().currentUser else { return }
        var payload = try Self.firestoreDictionary(from: insights)
        payload["schemaVersion"] = 1
        payload["platform"] = "ios"
        payload["updatedAt"] = FieldValue.serverTimestamp()
        try await db
            .collection("users")
            .document(user.uid)
            .collection("journalInsights")
            .document(insights.dateKey)
            .setData(payload, merge: true)
    }

    func deleteDailyJournalInsights(dateKey: String) async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await db
            .collection("users")
            .document(user.uid)
            .collection("journalInsights")
            .document(dateKey)
            .delete()
    }

    func fetchLatestDailyJournalInsights() async throws -> DailyJournalInsights? {
        guard let user = Auth.auth().currentUser else { return nil }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("journalInsights")
            .order(by: "generatedAt", descending: true)
            .limit(to: 1)
            .getDocuments()
        guard let data = snapshot.documents.first?.data() else { return nil }
        return try? Self.decode(DailyJournalInsights.self, from: data)
    }

    func saveGardenState(_ state: PersistedGardenState) async throws {
        guard let user = Auth.auth().currentUser else { return }
        var payload = try Self.firestoreDictionary(from: state)
        payload["schemaVersion"] = 1
        payload["platform"] = "ios"
        payload["updatedAt"] = FieldValue.serverTimestamp()
        try await db
            .collection("users")
            .document(user.uid)
            .collection("garden")
            .document("state")
            .setData(payload, merge: true)
    }

    func fetchGardenState() async throws -> PersistedGardenState? {
        guard let user = Auth.auth().currentUser else { return nil }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("garden")
            .document("state")
            .getDocument()
        guard let data = snapshot.data() else { return nil }
        return try? Self.decode(PersistedGardenState.self, from: data)
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

    func saveTherapySessionDeletion(_ tombstone: TherapySessionDeletionTombstone) async throws {
        guard let user = Auth.auth().currentUser else { return }
        try await db
            .collection("users")
            .document(user.uid)
            .collection("therapySessionDeletes")
            .document(tombstone.id)
            .setData(Self.therapySessionDeletionPayload(from: tombstone), merge: true)
    }

    func saveTherapySessionDeletions(_ tombstones: [TherapySessionDeletionTombstone]) async throws {
        guard let user = Auth.auth().currentUser else { return }
        guard !tombstones.isEmpty else { return }
        let batch = db.batch()
        let collection = db
            .collection("users")
            .document(user.uid)
            .collection("therapySessionDeletes")
        tombstones.forEach { tombstone in
            batch.setData(Self.therapySessionDeletionPayload(from: tombstone), forDocument: collection.document(tombstone.id), merge: true)
        }
        try await batch.commit()
    }

    func fetchTherapySessionDeletions(limit: Int = 500) async throws -> [TherapySessionDeletionTombstone] {
        guard let user = Auth.auth().currentUser else { return [] }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("therapySessionDeletes")
            .order(by: "deletedAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { document in
            Self.therapySessionDeletion(from: document.data(), documentID: document.documentID)
        }
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

    func fetchTherapyContext(therapistID: String?) async throws -> WellbeingContextSnapshot? {
        guard let user = Auth.auth().currentUser else { return nil }
        let documentID = therapistID ?? "global"
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("therapyContexts")
            .document(documentID)
            .getDocument()
        guard let payload = snapshot.data()?["context"] as? [String: Any] else { return nil }
        return try? Self.decode(WellbeingContextSnapshot.self, from: payload)
    }

    func fetchSubscriptionState() async throws -> SubscriptionState {
        try await fetchSubscriptionSnapshot().subscription
    }

    func fetchSubscriptionSnapshot() async throws -> PersistedSubscriptionState {
        guard let user = Auth.auth().currentUser else { return PersistedSubscriptionState() }
        let snapshot = try await db
            .collection("users")
            .document(user.uid)
            .collection("entitlements")
            .document("subscription")
            .getDocument()
        guard let data = snapshot.data() else { return PersistedSubscriptionState() }
        return PersistedSubscriptionState(
            subscription: Self.subscriptionState(from: data),
            usage: Self.subscriptionUsage(from: data["usage"] as? [String: Any])
        )
    }

    func saveSubscriptionState(_ state: SubscriptionState) async throws {
        try await saveSubscriptionSnapshot(PersistedSubscriptionState(subscription: state))
    }

    func saveSubscriptionSnapshot(_ snapshot: PersistedSubscriptionState) async throws {
        guard let user = Auth.auth().currentUser else { return }
        var normalizedUsage = snapshot.usage
        normalizedUsage.normalize()
        var payload = Self.subscriptionPayload(from: snapshot.subscription)
        payload["schemaVersion"] = 1
        payload["platform"] = "ios"
        payload["usage"] = Self.subscriptionUsagePayload(from: normalizedUsage)
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

    private static func displayName(from components: PersonNameComponents?) -> String? {
        guard let components else { return nil }
        let name = PersonNameComponentsFormatter()
            .string(from: components)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? nil : name
    }

    private func saveDeviceProfile(_ profile: PersistedProfileState) async throws {
        guard let user = Auth.auth().currentUser else { return }
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let buildNumber = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let payload: [String: Any] = [
            "schemaVersion": 1,
            "platform": "ios",
            "deviceID": Self.deviceDocumentID,
            "deviceName": UIDevice.current.name,
            "deviceModel": UIDevice.current.model,
            "systemName": UIDevice.current.systemName,
            "systemVersion": UIDevice.current.systemVersion,
            "appVersion": appVersion ?? NSNull(),
            "buildNumber": buildNumber ?? NSNull(),
            "hapticFeedbackEnabled": profile.hapticFeedbackEnabled,
            "useLargeText": profile.useLargeText,
            "requireBiometrics": profile.requireBiometrics,
            "dailyReminderEnabled": profile.dailyReminderEnabled,
            "dailyReminderHour": profile.dailyReminderHour,
            "lastSeenAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]
        try await db
            .collection("users")
            .document(user.uid)
            .collection("devices")
            .document(Self.deviceDocumentID)
            .setData(payload, merge: true)
    }

    private static func firestoreDictionary<T: Encodable>(from value: T) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw LuminaAuthError.providerUnavailable("Could not encode data for cloud sync.")
        }
        return object
    }

    private static func decode<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: jsonCompatible(dictionary))
        return try JSONDecoder().decode(T.self, from: data)
    }

    private static func profileState(from data: [String: Any]) -> PersistedProfileState {
        let joinDate: Date
        if let timestamp = data["joinDate"] as? Timestamp {
            joinDate = timestamp.dateValue()
        } else if let interval = number(from: data["joinDate"]) {
            joinDate = Date(timeIntervalSince1970: interval)
        } else {
            joinDate = Date()
        }

        return PersistedProfileState(
            userName: string(from: data["displayName"]) ?? "User",
            userBio: string(from: data["bio"]) ?? "",
            avatarID: ProfileAvatarID.fromPersistedValue(string(from: data["avatarID"])),
            gender: ProfileGender(rawValue: string(from: data["gender"]) ?? "") ?? .notSpecified,
            joinDate: joinDate,
            dailyReminderEnabled: bool(from: data["dailyReminderEnabled"]) ?? false,
            dailyReminderHour: int(from: data["dailyReminderHour"]) ?? 9,
            hapticFeedbackEnabled: bool(from: data["hapticFeedbackEnabled"]) ?? true,
            useLargeText: bool(from: data["useLargeText"]) ?? false,
            requireBiometrics: bool(from: data["requireBiometrics"]) ?? false,
            useJournalContextInTherapy: bool(from: data["useJournalContextInTherapy"]) ?? true,
            journalGoalPerWeek: int(from: data["journalGoalPerWeek"]) ?? 3,
            meditationGoalMinutes: int(from: data["meditationGoalMinutes"]) ?? 10
        )
    }

    private static func journalEntry(from data: [String: Any], documentID: String) -> JournalEntry? {
        let id = string(from: data["entryID"]) ?? documentID
        guard let title = string(from: data["title"]),
              let moodRaw = string(from: data["mood"]),
              let mood = MoodType(rawValue: moodRaw) else {
            return nil
        }

        let timestamp: TimeInterval
        if let value = number(from: data["timestamp"]) {
            timestamp = value
        } else if let createdAt = data["createdAt"] as? Timestamp {
            timestamp = createdAt.dateValue().timeIntervalSince1970
        } else {
            timestamp = Date().timeIntervalSince1970
        }

        let policyRaw = string(from: data["therapyMemoryPolicy"])
            ?? JournalTherapyMemoryPolicy.automatic.rawValue
        return JournalEntry(
            id: id,
            date: string(from: data["dateLabel"]) ?? string(from: data["date"]) ?? Self.shortDateLabel(from: timestamp),
            timestamp: timestamp,
            title: title,
            content: string(from: data["content"]) ?? string(from: data["contentPreview"]) ?? "",
            mood: mood,
            tags: data["tags"] as? [String] ?? [],
            reflection: nullableString(from: data["reflection"]),
            actionItem: nullableString(from: data["actionItem"]),
            summary: nullableString(from: data["summary"]),
            sentimentScore: int(from: data["sentimentScore"]),
            energyLevel: int(from: data["energyLevel"]),
            anxietyLevel: int(from: data["anxietyLevel"]),
            therapyMemoryPolicy: JournalTherapyMemoryPolicy(rawValue: policyRaw),
            isPinned: bool(from: data["isPinned"]) ?? false
        )
    }

    private static func journalSummaryPayload(from entry: JournalEntry) -> [String: Any] {
        [
            "schemaVersion": 1,
            "platform": "ios",
            "entryID": entry.id,
            "dateLabel": entry.date,
            "timestamp": entry.timestamp,
            "createdAt": Timestamp(date: Date(timeIntervalSince1970: entry.timestamp)),
            "title": entry.title,
            "content": entry.content,
            "contentPreview": String(entry.displayContent.prefix(1_200)),
            "mood": entry.mood.rawValue,
            "tags": entry.tags,
            "summary": entry.summary ?? NSNull(),
            "reflection": entry.reflection ?? NSNull(),
            "actionItem": entry.actionItem ?? NSNull(),
            "sentimentScore": entry.sentimentScore ?? NSNull(),
            "energyLevel": entry.energyLevel ?? NSNull(),
            "anxietyLevel": entry.anxietyLevel ?? NSNull(),
            "therapyMemoryPolicy": entry.therapyMemoryPolicy?.rawValue ?? JournalTherapyMemoryPolicy.automatic.rawValue,
            "isPinned": entry.isPinned,
            "hasPrivateContent": !entry.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    private static func journalDeletion(from data: [String: Any], documentID: String) -> JournalDeletionTombstone? {
        let id = string(from: data["entryID"]) ?? documentID
        let deletedAt: TimeInterval
        if let value = number(from: data["deletedAt"]) {
            deletedAt = value
        } else if let timestamp = data["deletedAtTimestamp"] as? Timestamp {
            deletedAt = timestamp.dateValue().timeIntervalSince1970
        } else if let timestamp = data["updatedAt"] as? Timestamp {
            deletedAt = timestamp.dateValue().timeIntervalSince1970
        } else {
            return nil
        }
        return JournalDeletionTombstone(id: id, deletedAt: deletedAt)
    }

    private static func journalDeletionPayload(from tombstone: JournalDeletionTombstone) -> [String: Any] {
        [
            "schemaVersion": 1,
            "platform": "ios",
            "entryID": tombstone.id,
            "deletedAt": tombstone.deletedAt,
            "deletedAtTimestamp": Timestamp(date: Date(timeIntervalSince1970: tombstone.deletedAt)),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }

    private static func therapySessionDeletion(from data: [String: Any], documentID: String) -> TherapySessionDeletionTombstone? {
        let id = string(from: data["sessionID"]) ?? documentID
        let deletedAt: TimeInterval
        if let value = number(from: data["deletedAt"]) {
            deletedAt = value
        } else if let timestamp = data["deletedAtTimestamp"] as? Timestamp {
            deletedAt = timestamp.dateValue().timeIntervalSince1970
        } else if let timestamp = data["updatedAt"] as? Timestamp {
            deletedAt = timestamp.dateValue().timeIntervalSince1970
        } else {
            return nil
        }
        return TherapySessionDeletionTombstone(id: id, deletedAt: deletedAt)
    }

    private static func therapySessionDeletionPayload(from tombstone: TherapySessionDeletionTombstone) -> [String: Any] {
        [
            "schemaVersion": 1,
            "platform": "ios",
            "sessionID": tombstone.id,
            "deletedAt": tombstone.deletedAt,
            "deletedAtTimestamp": Timestamp(date: Date(timeIntervalSince1970: tombstone.deletedAt)),
            "updatedAt": FieldValue.serverTimestamp()
        ]
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

    private static func subscriptionUsage(from data: [String: Any]?) -> SubscriptionUsageState {
        guard let data else { return SubscriptionUsageState() }
        var usage = SubscriptionUsageState(
            dailyKey: data["dailyKey"] as? String ?? SubscriptionUsageState.dayKey(),
            monthlyKey: data["monthlyKey"] as? String ?? SubscriptionUsageState.monthKey(),
            aiChatRepliesToday: data["aiChatRepliesToday"] as? Int ?? 0,
            liveCallSecondsToday: data["liveCallSecondsToday"] as? Int ?? 0,
            liveCallSecondsThisMonth: data["liveCallSecondsThisMonth"] as? Int ?? 0
        )
        usage.normalize()
        return usage
    }

    private static func subscriptionUsagePayload(from usage: SubscriptionUsageState) -> [String: Any] {
        [
            "dailyKey": usage.dailyKey,
            "monthlyKey": usage.monthlyKey,
            "aiChatRepliesToday": usage.aiChatRepliesToday,
            "liveCallSecondsToday": usage.liveCallSecondsToday,
            "liveCallSecondsThisMonth": usage.liveCallSecondsThisMonth,
            "limits": [
                "freeAIChatDaily": SubscriptionUsageState.freeAIChatDailyLimit,
                "freeVoiceDailySeconds": SubscriptionUsageState.freeVoiceDailyLimitSeconds,
                "premiumVoiceMonthlySeconds": SubscriptionUsageState.premiumVoiceMonthlyLimitSeconds
            ]
        ]
    }

    private static func jsonCompatible(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp {
            return timestamp.dateValue().timeIntervalSince1970
        }
        if let dictionary = value as? [String: Any] {
            return dictionary.mapValues(jsonCompatible)
        }
        if let array = value as? [Any] {
            return array.map(jsonCompatible)
        }
        if value is NSNull {
            return NSNull()
        }
        return value
    }

    private static func string(from value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return value as? String
    }

    private static func nullableString(from value: Any?) -> String? {
        guard let string = string(from: value) else { return nil }
        return string.isEmpty ? nil : string
    }

    private static func bool(from value: Any?) -> Bool? {
        guard let value, !(value is NSNull) else { return nil }
        if let bool = value as? Bool { return bool }
        if let number = value as? NSNumber { return number.boolValue }
        return nil
    }

    private static func int(from value: Any?) -> Int? {
        guard let value, !(value is NSNull) else { return nil }
        if let int = value as? Int { return int }
        if let number = value as? NSNumber { return number.intValue }
        if let double = value as? Double { return Int(double) }
        return nil
    }

    private static func number(from value: Any?) -> TimeInterval? {
        guard let value, !(value is NSNull) else { return nil }
        if let double = value as? Double { return double }
        if let int = value as? Int { return TimeInterval(int) }
        if let number = value as? NSNumber { return number.doubleValue }
        return nil
    }

    private static func shortDateLabel(from timestamp: TimeInterval) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter.string(from: Date(timeIntervalSince1970: timestamp)).uppercased()
    }

    private static var deviceDocumentID: String {
        let raw = UIDevice.current.identifierForVendor?.uuidString ?? UIDevice.current.name
        return raw
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
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

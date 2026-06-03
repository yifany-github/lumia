import Foundation
import RevenueCat

struct RevenueCatPlan: Identifiable, Equatable {
    let id: String
    let packageIdentifier: String
    let productIdentifier: String
    let title: String
    let price: String
    let detail: String
    let isRecommended: Bool
}

@MainActor
final class RevenueCatSubscriptionService: ObservableObject {
    static let publicAPIKey = "appl_pwmMKaUkLjtbMQnctcHRVwWgBJn"
    static let entitlementID = "premium"

    @Published private(set) var plans: [RevenueCatPlan] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var packagesByIdentifier: [String: Package] = [:]
    private var configuredUserID: String?
    private var hasConfiguredPurchases = false

    func refresh(appUserID: String?) async -> SubscriptionState {
        do {
            isLoading = true
            lastError = nil
            try await configure(appUserID: appUserID)

            let offerings = try await Purchases.shared.offerings()
            Self.logOfferings(offerings)
            updatePlans(from: offerings)

            let customerInfo = try await Purchases.shared.customerInfo()
            isLoading = false
            return subscriptionState(from: customerInfo)
        } catch {
            Self.logRevenueCatError(error)
            isLoading = false
            lastError = Self.readableErrorMessage(from: error)
            return SubscriptionState(
                tier: .free,
                status: .unknown,
                provider: .revenuecat,
                revenueCatAppUserID: appUserID,
                entitlementID: Self.entitlementID,
                updatedAt: Date().timeIntervalSince1970
            )
        }
    }

    func purchase(planID: String, appUserID: String?) async throws -> SubscriptionState {
        try await configure(appUserID: appUserID)
        guard let package = packagesByIdentifier[planID] else {
            throw RevenueCatSubscriptionError.planUnavailable
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await Purchases.shared.purchase(package: package)
            lastError = nil
            return subscriptionState(from: result.customerInfo)
        } catch {
            lastError = Self.readableErrorMessage(from: error)
            throw error
        }
    }

    func restorePurchases(appUserID: String?) async throws -> SubscriptionState {
        try await configure(appUserID: appUserID)
        isLoading = true
        defer { isLoading = false }
        do {
            let customerInfo = try await Purchases.shared.restorePurchases()
            lastError = nil
            return subscriptionState(from: customerInfo)
        } catch {
            lastError = Self.readableErrorMessage(from: error)
            throw error
        }
    }

    private func configure(appUserID: String?) async throws {
        let normalizedUserID = appUserID?.trimmingCharacters(in: .whitespacesAndNewlines)
        let userID = normalizedUserID?.isEmpty == false ? normalizedUserID : nil

        if !hasConfiguredPurchases {
            #if DEBUG
            Purchases.logLevel = .debug
            print("Lumia RevenueCat configure bundle=\(Bundle.main.bundleIdentifier ?? "unknown") user=\(userID ?? "anonymous") keyPrefix=\(Self.publicAPIKey.prefix(8))")
            #else
            Purchases.logLevel = .warn
            #endif
            Purchases.configure(withAPIKey: Self.publicAPIKey, appUserID: userID)
            configuredUserID = userID
            hasConfiguredPurchases = true
            return
        }

        guard configuredUserID != userID, let userID else { return }
        _ = try await Purchases.shared.logIn(userID)
        configuredUserID = userID
    }

    private func updatePlans(from offerings: Offerings) {
        let packages = offerings.current?.availablePackages ?? []
        packagesByIdentifier = Dictionary(uniqueKeysWithValues: packages.map { ($0.identifier, $0) })
        plans = packages.map { package in
            let product = package.storeProduct
            let productID = product.productIdentifier
            let isYearly = productID.localizedCaseInsensitiveContains("year")
                || package.identifier.localizedCaseInsensitiveContains("annual")
                || package.identifier.localizedCaseInsensitiveContains("year")
            return RevenueCatPlan(
                id: package.identifier,
                packageIdentifier: package.identifier,
                productIdentifier: productID,
                title: isYearly ? "Yearly" : "Monthly",
                price: product.localizedPriceString,
                detail: isYearly ? "Best value for steady support" : "Flexible access, cancel anytime",
                isRecommended: isYearly
            )
        }
    }

    private func subscriptionState(from customerInfo: CustomerInfo) -> SubscriptionState {
        guard let entitlement = customerInfo.entitlements[Self.entitlementID] else {
            return SubscriptionState(
                tier: .free,
                status: .unknown,
                provider: .revenuecat,
                revenueCatAppUserID: configuredUserID,
                entitlementID: Self.entitlementID,
                updatedAt: Date().timeIntervalSince1970
            )
        }

        return SubscriptionState(
            tier: entitlement.isActive ? .premium : .free,
            status: status(from: entitlement),
            provider: .revenuecat,
            revenueCatAppUserID: configuredUserID,
            productID: entitlement.productIdentifier,
            entitlementID: Self.entitlementID,
            currentPeriodEnd: entitlement.expirationDate?.timeIntervalSince1970,
            willRenew: entitlement.willRenew,
            updatedAt: Date().timeIntervalSince1970
        )
    }

    private func status(from entitlement: EntitlementInfo) -> SubscriptionStatus {
        guard entitlement.isActive else { return .expired }
        if entitlement.periodType == .trial {
            return .trialing
        }
        return .active
    }

    private static func readableErrorMessage(from error: Error) -> String {
        let message = error.localizedDescription
        if message.localizedCaseInsensitiveContains("offerings-empty")
            || message.localizedCaseInsensitiveContains("could be fetched from App Store Connect")
            || message.localizedCaseInsensitiveContains("no App Store products registered") {
            return "Plans are temporarily unavailable. Please try again later."
        }
        if message.localizedCaseInsensitiveContains("network") {
            return "Plans could not load because the network is unavailable. Try again in a moment."
        }
        return message
    }

    private static func logRevenueCatError(_ error: Error) {
        #if DEBUG
        print("Lumia RevenueCat raw error: \(error)")
        let nsError = error as NSError
        print("Lumia RevenueCat nsError domain=\(nsError.domain) code=\(nsError.code) userInfo=\(nsError.userInfo)")
        #endif
    }

    private static func logOfferings(_ offerings: Offerings) {
        #if DEBUG
        let current = offerings.current
        let packageSummary = current?.availablePackages.map {
            "\($0.identifier):\($0.storeProduct.productIdentifier):\($0.storeProduct.localizedPriceString)"
        }.joined(separator: ", ") ?? "none"
        print("Lumia RevenueCat offerings current=\(current?.identifier ?? "nil") packages=[\(packageSummary)]")
        #endif
    }
}

enum RevenueCatSubscriptionError: LocalizedError {
    case planUnavailable

    var errorDescription: String? {
        switch self {
        case .planUnavailable:
            return "This plan is not available yet. Check RevenueCat offerings and try again."
        }
    }
}

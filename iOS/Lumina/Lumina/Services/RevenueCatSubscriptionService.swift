import Foundation
import RevenueCat
import StoreKit

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
    static let storeKitProductIDs = ["lumia_plus_monthly_v2", "lumia_plus_yearly_v2"]
    static let fallbackPlans = [
        RevenueCatPlan(
            id: "lumia_plus_yearly_v2",
            packageIdentifier: "lumia_plus_yearly_v2",
            productIdentifier: "lumia_plus_yearly_v2",
            title: "Lumia Plus Yearly",
            price: "$64.99/year",
            detail: "1 year auto-renewing subscription. Cancel anytime in App Store settings.",
            isRecommended: true
        ),
        RevenueCatPlan(
            id: "lumia_plus_monthly_v2",
            packageIdentifier: "lumia_plus_monthly_v2",
            productIdentifier: "lumia_plus_monthly_v2",
            title: "Lumia Plus Monthly",
            price: "$4.99/month",
            detail: "1 month auto-renewing subscription. Cancel anytime in App Store settings.",
            isRecommended: false
        )
    ]

    @Published private(set) var plans: [RevenueCatPlan] = []
    @Published private(set) var isLoading = false
    @Published private(set) var lastError: String?

    private var packagesByIdentifier: [String: Package] = [:]
    private var revenueCatProductsByIdentifier: [String: StoreProduct] = [:]
    private var storeKitProductsByIdentifier: [String: Product] = [:]
    private var configuredUserID: String?
    private var hasConfiguredPurchases = false

    func refresh(appUserID: String?) async -> SubscriptionState {
        isLoading = true
        lastError = nil
        defer { isLoading = false }

        let freeState = SubscriptionState(
            tier: .free,
            status: .unknown,
            provider: .revenuecat,
            revenueCatAppUserID: appUserID,
            entitlementID: Self.entitlementID,
            updatedAt: Date().timeIntervalSince1970
        )

        do {
            try await configure(appUserID: appUserID)

            let offerings = try await Purchases.shared.offerings()
            Self.logOfferings(offerings)
            updatePlans(from: offerings)

            if plans.isEmpty {
                await updateRevenueCatDirectProductPlans()
            }

            if plans.isEmpty {
                try await updateStoreKitFallbackPlans()
            }

            if plans.isEmpty {
                updateStaticFallbackPlans()
            }

            let customerInfo = try await Purchases.shared.customerInfo()
            let revenueCatState = subscriptionState(from: customerInfo)
            if revenueCatState.hasPremiumAccess {
                return revenueCatState
            }
            return await currentStoreKitSubscriptionState(defaultState: revenueCatState, appUserID: appUserID)
        } catch {
            Self.logRevenueCatError(error)
            do {
                await updateRevenueCatDirectProductPlans()
                if plans.isEmpty {
                    try await updateStoreKitFallbackPlans()
                }
                if plans.isEmpty {
                    updateStaticFallbackPlans()
                }
                lastError = plans.isEmpty ? Self.readableErrorMessage(from: error) : nil
            } catch {
                updateStaticFallbackPlans()
                lastError = Self.readableErrorMessage(from: error)
            }
            return await currentStoreKitSubscriptionState(defaultState: freeState, appUserID: appUserID)
        }
    }

    func purchase(planID: String, appUserID: String?) async throws -> SubscriptionState {
        try await configure(appUserID: appUserID)
        isLoading = true
        defer { isLoading = false }

        if let package = packagesByIdentifier[planID] {
            do {
                let result = try await Purchases.shared.purchase(package: package)
                lastError = nil
                return subscriptionState(from: result.customerInfo)
            } catch {
                lastError = Self.readableErrorMessage(from: error)
                throw error
            }
        }

        if revenueCatProductsByIdentifier.isEmpty {
            await updateRevenueCatDirectProductPlans()
        }

        if let product = revenueCatProductsByIdentifier[planID] {
            do {
                let (_, customerInfo, userCancelled) = try await Purchases.shared.purchase(product: product)
                guard !userCancelled else {
                    throw RevenueCatSubscriptionError.purchaseCancelled
                }
                lastError = nil
                return subscriptionState(from: customerInfo)
            } catch {
                lastError = Self.readableErrorMessage(from: error)
                throw error
            }
        }

        if storeKitProductsByIdentifier.isEmpty {
            try await updateStoreKitFallbackPlans()
        }

        guard let product = storeKitProductsByIdentifier[planID] else {
            throw RevenueCatSubscriptionError.planUnavailable
        }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try Self.verified(verification)
                await transaction.finish()
                lastError = nil
                return subscriptionState(from: transaction, appUserID: appUserID)
            case .userCancelled:
                throw RevenueCatSubscriptionError.purchaseCancelled
            case .pending:
                throw RevenueCatSubscriptionError.purchasePending
            @unknown default:
                throw RevenueCatSubscriptionError.purchaseUnknown
            }
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
            let revenueCatState = subscriptionState(from: customerInfo)
            if revenueCatState.hasPremiumAccess {
                lastError = nil
                return revenueCatState
            }
            let storeKitState = await currentStoreKitSubscriptionState(defaultState: revenueCatState, appUserID: appUserID)
            lastError = nil
            return storeKitState
        } catch {
            await updateRevenueCatDirectProductPlans()
            if plans.isEmpty {
                try await updateStoreKitFallbackPlans()
            }
            if plans.isEmpty {
                updateStaticFallbackPlans()
            }
            let storeKitState = await currentStoreKitSubscriptionState(
                defaultState: SubscriptionState(
                    tier: .free,
                    status: .unknown,
                    provider: .storekit,
                    revenueCatAppUserID: appUserID,
                    entitlementID: Self.entitlementID,
                    updatedAt: Date().timeIntervalSince1970
                ),
                appUserID: appUserID
            )
            lastError = nil
            return storeKitState
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
        revenueCatProductsByIdentifier = [:]
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
                title: isYearly ? "Lumia Plus Yearly" : "Lumia Plus Monthly",
                price: product.localizedPriceString,
                detail: isYearly
                    ? "Yearly auto-renewing subscription. Cancel anytime in App Store settings."
                    : "Monthly auto-renewing subscription. Cancel anytime in App Store settings.",
                isRecommended: isYearly
            )
        }
    }

    private func updateRevenueCatDirectProductPlans() async {
        let products = await Purchases.shared.products(Self.storeKitProductIDs)
        let sortedProducts = products.sorted {
            Self.productSortRank($0.productIdentifier) < Self.productSortRank($1.productIdentifier)
        }
        Self.logRevenueCatDirectProducts(sortedProducts)
        revenueCatProductsByIdentifier = Dictionary(uniqueKeysWithValues: sortedProducts.map {
            ($0.productIdentifier, $0)
        })
        guard plans.isEmpty else { return }
        plans = sortedProducts.map { product in
            let productID = product.productIdentifier
            let isYearly = productID.localizedCaseInsensitiveContains("year")
                || productID.localizedCaseInsensitiveContains("annual")
            return RevenueCatPlan(
                id: productID,
                packageIdentifier: productID,
                productIdentifier: productID,
                title: isYearly ? "Lumia Plus Yearly" : "Lumia Plus Monthly",
                price: product.localizedPriceString,
                detail: isYearly
                    ? "Yearly auto-renewing subscription. Cancel anytime in App Store settings."
                    : "Monthly auto-renewing subscription. Cancel anytime in App Store settings.",
                isRecommended: isYearly
            )
        }
    }

    private func updateStoreKitFallbackPlans() async throws {
        let products = try await Product.products(for: Self.storeKitProductIDs)
        let sortedProducts = products.sorted { Self.productSortRank($0.id) < Self.productSortRank($1.id) }
        Self.logStoreKitProducts(sortedProducts)
        storeKitProductsByIdentifier = Dictionary(uniqueKeysWithValues: sortedProducts.map { ($0.id, $0) })
        guard plans.isEmpty else { return }
        plans = sortedProducts.map { product in
            let isYearly = product.id.localizedCaseInsensitiveContains("year")
                || product.id.localizedCaseInsensitiveContains("annual")
            return RevenueCatPlan(
                id: product.id,
                packageIdentifier: product.id,
                productIdentifier: product.id,
                title: isYearly ? "Lumia Plus Yearly" : "Lumia Plus Monthly",
                price: product.displayPrice,
                detail: isYearly
                    ? "Yearly auto-renewing subscription. Cancel anytime in App Store settings."
                    : "Monthly auto-renewing subscription. Cancel anytime in App Store settings.",
                isRecommended: isYearly
            )
        }
    }

    private func updateStaticFallbackPlans() {
        plans = Self.fallbackPlans
        #if DEBUG
        print("Lumia static fallback plans shown because App Store products were not returned.")
        #endif
    }

    private func currentStoreKitSubscriptionState(defaultState: SubscriptionState, appUserID: String?) async -> SubscriptionState {
        for await result in StoreKit.Transaction.currentEntitlements {
            guard let transaction = try? Self.verified(result),
                  Self.storeKitProductIDs.contains(transaction.productID) else { continue }
            return subscriptionState(from: transaction, appUserID: appUserID)
        }
        return defaultState
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

    private func subscriptionState(from transaction: StoreKit.Transaction, appUserID: String?) -> SubscriptionState {
        let now = Date().timeIntervalSince1970
        let expiration = transaction.expirationDate?.timeIntervalSince1970
        let isActive = expiration.map { $0 > now } ?? true
        return SubscriptionState(
            tier: isActive ? .premium : .free,
            status: isActive ? .active : .expired,
            provider: .storekit,
            revenueCatAppUserID: appUserID,
            productID: transaction.productID,
            entitlementID: Self.entitlementID,
            currentPeriodEnd: expiration,
            willRenew: isActive,
            updatedAt: now
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

    private static func verified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let value):
            return value
        case .unverified:
            throw RevenueCatSubscriptionError.unverifiedTransaction
        }
    }

    private static func productSortRank(_ productID: String) -> Int {
        if productID.localizedCaseInsensitiveContains("year")
            || productID.localizedCaseInsensitiveContains("annual") {
            return 0
        }
        return 1
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

    private static func logRevenueCatDirectProducts(_ products: [StoreProduct]) {
        #if DEBUG
        let requested = Self.storeKitProductIDs.joined(separator: ", ")
        let summary = products.map { "\($0.productIdentifier):\($0.localizedPriceString)" }.joined(separator: ", ")
        print("Lumia RevenueCat direct products requested=[\(requested)] products count=\(products.count) products=[\(summary)]")
        #endif
    }

    private static func logStoreKitProducts(_ products: [Product]) {
        #if DEBUG
        let requested = Self.storeKitProductIDs.joined(separator: ", ")
        let summary = products.map { "\($0.id):\($0.displayPrice)" }.joined(separator: ", ")
        let bundledConfigURL = Bundle.main.url(forResource: "LumiaSubscriptions", withExtension: "storekit")
        let bundledProductIDs = Self.bundledStoreKitSubscriptionIDs().joined(separator: ", ")
        let storeEnvironmentKeys = ProcessInfo.processInfo.environment.keys
            .filter {
                $0.localizedCaseInsensitiveContains("store")
                    || $0.localizedCaseInsensitiveContains("kit")
                    || $0.localizedCaseInsensitiveContains("iap")
            }
            .sorted()
            .joined(separator: ", ")

        print("Lumia StoreKit fallback requested=[\(requested)] products count=\(products.count) products=[\(summary)]")
        print("Lumia StoreKit bundled config path=\(bundledConfigURL?.path ?? "nil") subscriptionIDs=[\(bundledProductIDs)]")
        print("Lumia StoreKit environment keys=[\(storeEnvironmentKeys)]")
        #endif
    }

    private static func bundledStoreKitSubscriptionIDs() -> [String] {
        guard let url = Bundle.main.url(forResource: "LumiaSubscriptions", withExtension: "storekit"),
              let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let groups = json["subscriptionGroups"] as? [[String: Any]] else {
            return []
        }

        return groups.flatMap { group in
            let subscriptions = group["subscriptions"] as? [[String: Any]] ?? []
            return subscriptions.compactMap { $0["productID"] as? String }
        }
    }
}

enum RevenueCatSubscriptionError: LocalizedError {
    case planUnavailable
    case purchaseCancelled
    case purchasePending
    case purchaseUnknown
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .planUnavailable:
            return "The App Store is still making this plan available. Please try again shortly."
        case .purchaseCancelled:
            return "Purchase was cancelled."
        case .purchasePending:
            return "Purchase is pending approval."
        case .purchaseUnknown:
            return "Purchase could not be completed. Try again in a moment."
        case .unverifiedTransaction:
            return "The App Store transaction could not be verified."
        }
    }
}

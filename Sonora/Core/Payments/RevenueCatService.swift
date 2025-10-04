import Combine
import Foundation
import RevenueCat

/// RevenueCat-backed implementation that conforms to the existing StoreKitServiceProtocol.
/// This allows us to use RevenueCat purchasing without touching UI or gating.
public final class RevenueCatService: NSObject, StoreKitServiceProtocol, @unchecked Sendable {
    // MARK: - Types
    private enum CacheKey {
        static let proFlag = "storekit.isPro.cached"
        static let proTs = "storekit.isPro.cached.ts"
    }

    // MARK: - Configuration
    private let apiKey: String
    private let entitlementId: String
    private let productIdToRcPackageId: [String: String] = [
        "sonora.pro.monthly": "$rc_monthly",
        "sonora.pro.annual": "$rc_annual"
    ]

    // MARK: - State
    private let userDefaults: UserDefaults
    private let cacheTTL: TimeInterval = 3_600 // 1 hour
    private let subject: CurrentValueSubject<Bool, Never>

    public var isProPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    public var isPro: Bool { subject.value }

    public init(
        apiKey: String? = nil,
        entitlementId: String = "pro",
        userDefaults: UserDefaults = .standard
    ) {
        // Resolve configuration
        let envApi = ProcessInfo.processInfo.environment["RC_API_KEY"]
        let resolvedKey = apiKey ?? envApi ?? "appl_NuJfLSURCFnBBqcYSlHIwfYreue"
        self.apiKey = resolvedKey
        self.entitlementId = ProcessInfo.processInfo.environment["RC_ENTITLEMENT_ID"] ?? entitlementId
        self.userDefaults = userDefaults

        // Initialize cached state
        let cached = userDefaults.object(forKey: CacheKey.proFlag) as? Bool
        let ts = userDefaults.object(forKey: CacheKey.proTs) as? TimeInterval
        let now = Date().timeIntervalSince1970
        let valid = (cached ?? false) && (ts ?? 0) > 0 && (now - (ts ?? 0) < cacheTTL)
        self.subject = CurrentValueSubject<Bool, Never>(valid ? (cached ?? false) : false)

        super.init()

        // Configure RevenueCat
        let builder = Configuration.Builder(withAPIKey: resolvedKey)
            .with(storeKitVersion: .storeKit2)
        Purchases.logLevel = .info
        Purchases.configure(with: builder.build())
        Purchases.shared.delegate = self

        // Initial entitlement refresh
        Task { await refreshEntitlements() }
    }

    // MARK: - StoreKitServiceProtocol
    public func purchase(productId: String) async throws -> Bool {
        // Resolve package from offerings using either mapped RC package id or product id.
        let offerings = try await Purchases.shared.offerings()
        guard let package = findPackage(in: offerings, forProductId: productId) else {
            print("🛒 [RevenueCatService] Package not found for productId=\(productId)")
            return false
        }

        print("🛒 [RevenueCatService] Purchasing package: id=\(package.identifier), storeProductId=\(package.storeProduct.productIdentifier)")
        let result = try await Purchases.shared.purchase(package: package)
        let info = result.customerInfo
        let active = isEntitled(info)
        await MainActor.run { setIsPro(active) }
        print("🛒 [RevenueCatService] purchase completed, isPro=\(active)")
        return active
    }

    public func restorePurchases() async throws -> Bool {
        print("🛒 [RevenueCatService] restorePurchases() start")
        let info = try await Purchases.shared.restorePurchases()
        let active = isEntitled(info)
        await MainActor.run { setIsPro(active) }
        print("🛒 [RevenueCatService] restorePurchases() done, isPro=\(active)")
        return active
    }

    public func refreshEntitlements(force: Bool = false) async {
        if !force, let cached = getCachedIsProValid(), cached {
            await MainActor.run { self.subject.send(cached) }
            print("🛒 [RevenueCatService] refreshEntitlements() using cached isPro=true")
            return
        }
        do {
            let info = try await Purchases.shared.customerInfo()
            let active = isEntitled(info)
            await MainActor.run { setIsPro(active) }
            print("🛒 [RevenueCatService] refreshEntitlements() computed isPro=\(active)")
        } catch {
            print("🛒 [RevenueCatService] refreshEntitlements() error: \(error.localizedDescription)")
        }
    }

    // MARK: - Helpers
    private func getCachedIsProValid() -> Bool? {
        let cached = userDefaults.object(forKey: CacheKey.proFlag) as? Bool
        let ts = userDefaults.object(forKey: CacheKey.proTs) as? TimeInterval
        guard let flag = cached, let t = ts else { return nil }
        return (Date().timeIntervalSince1970 - t) < cacheTTL ? flag : nil
    }

    @MainActor
    private func setIsPro(_ value: Bool) {
        subject.send(value)
        userDefaults.set(value, forKey: CacheKey.proFlag)
        userDefaults.set(Date().timeIntervalSince1970, forKey: CacheKey.proTs)
    }

    private func isEntitled(_ info: CustomerInfo) -> Bool {
        // Prefer checking explicit entitlement id
        if let ent = info.entitlements[entitlementId], ent.isActive { return true }
        // Fallback: any active entitlement
        return info.entitlements.active.first != nil
    }

    private func findPackage(in offerings: Offerings, forProductId productId: String) -> Package? {
        let mappedId = productIdToRcPackageId[productId]

        // Prefer current offering
        if let current = offerings.current {
            if let pkg = current.availablePackages.first(where: { pkg in
                pkg.storeProduct.productIdentifier == productId || (mappedId != nil && pkg.identifier == mappedId)
            }) {
                return pkg
            }
        }

        // Search all offerings if not found in current
        for offering in offerings.all.values {
            if let pkg = offering.availablePackages.first(where: { pkg in
                pkg.storeProduct.productIdentifier == productId || (mappedId != nil && pkg.identifier == mappedId)
            }) {
                return pkg
            }
        }
        return nil
    }
}

extension RevenueCatService: PurchasesDelegate {
    public func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        let active = isEntitled(customerInfo)
        Task { @MainActor in self.setIsPro(active) }
        print("🛒 [RevenueCatService] receivedUpdated customerInfo, isPro=\(active)")
    }
}

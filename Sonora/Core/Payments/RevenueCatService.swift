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
    private let cacheTTL: TimeInterval = 900 // 15 minutes
    private let subject: CurrentValueSubject<Bool, Never>
    private var initializationContinuation: CheckedContinuation<Void, Never>?
    private var _isInitialized: Bool = false

    public var isProPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    public var isPro: Bool { subject.value }

    /// Returns true once the initial entitlement refresh has completed.
    /// Use this to ensure entitlements are loaded before making subscription-dependent decisions.
    /// Waits up to 10 seconds (or 20 seconds in TestFlight) for initialization, then proceeds anyway.
    public func waitForInitialization() async -> Bool {
        // If already initialized, return immediately
        if _isInitialized { return true }

        // Determine timeout based on environment
        let isTestFlight = Bundle.main.appStoreReceiptURL?.path.contains("sandboxReceipt") == true
        let timeoutSeconds: UInt64 = isTestFlight ? 20 : 10

        print("🛒 [RevenueCatService] Waiting for initialization (timeout: \(timeoutSeconds)s, isTestFlight: \(isTestFlight))...")

        // Wait for initialization with timeout
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                // Task 1: Wait for initialization
                group.addTask {
                    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                        if self._isInitialized {
                            continuation.resume()
                        } else {
                            self.initializationContinuation = continuation
                        }
                    }
                }

                // Task 2: Timeout based on environment
                group.addTask {
                    try await Task.sleep(nanoseconds: timeoutSeconds * 1_000_000_000)
                    throw TimeoutError()
                }

                // Wait for first task to complete
                try await group.next()
                group.cancelAll()
            }
            print("🛒 [RevenueCatService] ✓ Initialization wait completed successfully")
            return true
        } catch {
            print("🛒 [RevenueCatService] ⚠️ Initialization timeout after \(timeoutSeconds)s, proceeding anyway")
            if isTestFlight {
                print("   💡 TestFlight tip: Check sandbox tester configuration and RevenueCat entitlements")
            }
            return false
        }
    }

    private struct TimeoutError: Error {}

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

        // Log initialization configuration
        let maskedKey = String(resolvedKey.prefix(8)) + "..." + String(resolvedKey.suffix(4))
        print("🛒 [RevenueCatService] Initializing with:")
        print("   - API Key: \(maskedKey)")
        print("   - Entitlement ID: '\(self.entitlementId)'")
        print("   - StoreKit Version: 2")
        print("   - Initial cached isPro: \(valid ? (cached ?? false) : false)")
        if let ts = ts, valid {
            let age = now - ts
            print("   - Cache age: \(Int(age))s (valid for \(Int(cacheTTL - age))s more)")
        }

        // Configure RevenueCat
        let builder = Configuration.Builder(withAPIKey: resolvedKey)
            .with(storeKitVersion: .storeKit2)
        Purchases.logLevel = .info
        Purchases.configure(with: builder.build())
        Purchases.shared.delegate = self

        // Initial entitlement refresh
        print("🛒 [RevenueCatService] Starting async entitlement refresh...")
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
        print("🛒 [RevenueCatService] refreshEntitlements(force: \(force)) called")

        if !force, let cached = getCachedIsProValid(), cached {
            await MainActor.run { self.subject.send(cached) }
            print("🛒 [RevenueCatService] ✓ Using valid cached isPro=true (skipping API call)")
            return
        }

        print("🛒 [RevenueCatService] Fetching customer info from RevenueCat API...")
        do {
            let info = try await Purchases.shared.customerInfo()

            // Log all entitlements for debugging
            print("🛒 [RevenueCatService] Received customer info:")
            print("   - User ID: \(info.originalAppUserId)")
            print("   - All entitlements: \(info.entitlements.all.keys.sorted())")
            print("   - Active entitlements: \(info.entitlements.active.keys.sorted())")

            // Check entitlement and log reasoning
            let active = isEntitled(info, verbose: true)
            await MainActor.run { setIsPro(active) }

            print("🛒 [RevenueCatService] ✓ refreshEntitlements() completed, isPro=\(active)")

            // Mark initialization as complete
            markInitializationComplete()
        } catch {
            print("🛒 [RevenueCatService] ❌ refreshEntitlements() error: \(error.localizedDescription)")
            print("   - Error type: \(type(of: error))")
            print("   - Full error: \(error)")

            // Still mark as initialized even on error (to avoid hanging)
            markInitializationComplete()
        }
    }

    private func markInitializationComplete() {
        guard !_isInitialized else { return }
        _isInitialized = true
        print("🛒 [RevenueCatService] ✓ Initialization completed")

        // Resume any waiting continuation
        if let continuation = initializationContinuation {
            continuation.resume()
            initializationContinuation = nil
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
        let oldValue = subject.value
        if oldValue != value {
            print("🛒 [RevenueCatService] ⚡️ isPro changed: \(oldValue) → \(value)")
        }
        subject.send(value)
        userDefaults.set(value, forKey: CacheKey.proFlag)
        userDefaults.set(Date().timeIntervalSince1970, forKey: CacheKey.proTs)
    }

    private func isEntitled(_ info: CustomerInfo, verbose: Bool = false) -> Bool {
        if verbose {
            print("🛒 [RevenueCatService] Checking entitlement logic:")
            print("   - Looking for entitlement: '\(entitlementId)' (case-insensitive)")
        }

        // Step 1: Try exact match first
        if let ent = info.entitlements[entitlementId] {
            if verbose {
                print("   - Found exact match '\(entitlementId)' entitlement")
                print("     • isActive: \(ent.isActive)")
                print("     • productIdentifier: \(ent.productIdentifier)")
                if let expiry = ent.expirationDate {
                    print("     • expirationDate: \(expiry)")
                }
            }
            if ent.isActive {
                if verbose { print("   ✓ Result: Pro (exact entitlement match is active)") }
                return true
            }
        } else if verbose {
            print("   - Exact match '\(entitlementId)' NOT found")
        }

        // Step 2: Try case-insensitive match (e.g., "Pro" vs "pro")
        let entitlementIdLower = entitlementId.lowercased()
        for (key, ent) in info.entitlements.all {
            if key.lowercased() == entitlementIdLower && ent.isActive {
                if verbose {
                    print("   - Found case-insensitive match '\(key)' (looking for '\(entitlementId)')")
                    print("     • isActive: \(ent.isActive)")
                    print("     • productIdentifier: \(ent.productIdentifier)")
                }
                if verbose { print("   ✓ Result: Pro (case-insensitive entitlement match is active)") }
                return true
            }
        }

        if verbose {
            print("   - No case-insensitive match found for '\(entitlementId)'")
        }

        // Step 3: Fallback - check for any active entitlement
        let hasAnyActive = info.entitlements.active.first != nil
        if verbose {
            print("   - Checking fallback: any active entitlement")
            print("     • hasAnyActive: \(hasAnyActive)")
            if hasAnyActive {
                print("     • Active entitlements: \(info.entitlements.active.keys.sorted())")
            }
            print("   \(hasAnyActive ? "✓" : "✗") Result: \(hasAnyActive ? "Pro (fallback - any active entitlement)" : "Free (no active entitlements)")")
        }
        return hasAnyActive
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
        print("🛒 [RevenueCatService] 🔄 Received updated customerInfo from delegate")
        let active = isEntitled(customerInfo, verbose: true)
        Task { @MainActor in self.setIsPro(active) }
    }
}

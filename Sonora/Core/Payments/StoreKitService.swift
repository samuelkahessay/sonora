import Foundation
import Combine
#if canImport(StoreKit)
import StoreKit
#endif

public protocol StoreKitServiceProtocol: Sendable {
    func purchase(productId: String) async throws -> Bool
    func restorePurchases() async throws -> Bool
    var isProPublisher: AnyPublisher<Bool, Never> { get }
    var isPro: Bool { get }
    func refreshEntitlements(force: Bool) async
}

public extension StoreKitServiceProtocol {
    func refreshEntitlements() async {
        await refreshEntitlements(force: false)
    }
}

public final class StoreKitService: StoreKitServiceProtocol, @unchecked Sendable {
    // MARK: - Constants
    private let productIds: Set<String> = ["sonora.pro.monthly", "sonora.pro.annual"]
    private enum CacheKey {
        static let proFlag = "storekit.isPro.cached"
        static let proTs = "storekit.isPro.cached.ts"
    }
    private let cacheTTL: TimeInterval = 3600 // 1 hour

    // MARK: - State
    private let userDefaults: UserDefaults
    private let subject: CurrentValueSubject<Bool, Never>
    private let queue = DispatchQueue(label: "StoreKitService.queue")

    public var isProPublisher: AnyPublisher<Bool, Never> { subject.eraseToAnyPublisher() }
    public var isPro: Bool { subject.value }

    public init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        // Load cached value
        let (cached, ts) = (
            userDefaults.object(forKey: CacheKey.proFlag) as? Bool,
            userDefaults.object(forKey: CacheKey.proTs) as? TimeInterval
        )
        let now = Date().timeIntervalSince1970
        let valid = (cached ?? false) && (ts ?? 0) > 0 && (now - (ts ?? 0) < cacheTTL)
        self.subject = CurrentValueSubject<Bool, Never>(valid ? (cached ?? false) : false)

        // Refresh entitlements on init (non-blocking)
        Task { await refreshEntitlements() }

        // Observe app foreground to refresh
        #if canImport(UIKit)
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.refreshEntitlements() }
        }
        #endif
    }

    public func purchase(productId: String) async throws -> Bool {
        #if canImport(StoreKit)
        print("🛒 [StoreKitService] purchase() start, productId=\(productId)")
        let ids = Array(productIds)
        let products = try await Product.products(for: ids)
        print("🛒 [StoreKitService] products fetched: \(products.map { $0.id }) for ids=\(ids)")
        guard let product = products.first(where: { $0.id == productId }) else {
            print("🛒 [StoreKitService] requested product not found in fetched list")
            return false
        }
        print("🛒 [StoreKitService] initiating purchase for \(product.id)")
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                print("🛒 [StoreKitService] purchase verified; finishing transaction and refreshing entitlements")
                await MainActor.run { setIsPro(true) }
                await refreshEntitlements(force: true)
                return true
            case .unverified:
                print("🛒 [StoreKitService] purchase unverified")
                return false
            }
        case .userCancelled:
            print("🛒 [StoreKitService] purchase cancelled by user")
            return false
        case .pending:
            // Treat pending as not upgraded yet
            print("🛒 [StoreKitService] purchase pending")
            return false
        @unknown default:
            print("🛒 [StoreKitService] unknown purchase result")
            return false
        }
        #else
        print("🛒 [StoreKitService] StoreKit not available in this build")
        return false
        #endif
    }

    public func restorePurchases() async throws -> Bool {
        #if canImport(StoreKit)
        print("🛒 [StoreKitService] restorePurchases() start")
        try await AppStore.sync()
        // Sync triggers entitlement updates; refresh view of current state
        let before = subject.value
        await refreshEntitlements(force: true)
        let after = subject.value
        print("🛒 [StoreKitService] restorePurchases() done, before=\(before), after=\(after)")
        return after != before || after
        #else
        print("🛒 [StoreKitService] StoreKit not available in this build")
        return false
        #endif
    }

    // MARK: - Private
    @MainActor
    private func setIsPro(_ value: Bool) {
        subject.send(value)
        userDefaults.set(value, forKey: CacheKey.proFlag)
        userDefaults.set(Date().timeIntervalSince1970, forKey: CacheKey.proTs)
    }

    private func getCachedIsProValid() -> Bool? {
        let cached = userDefaults.object(forKey: CacheKey.proFlag) as? Bool
        let ts = userDefaults.object(forKey: CacheKey.proTs) as? TimeInterval
        guard let flag = cached, let t = ts else { return nil }
        return (Date().timeIntervalSince1970 - t) < cacheTTL ? flag : nil
    }

    private func computeIsPro() async -> Bool {
        #if canImport(StoreKit)
        // Check latest verified transactions for known products
        print("🛒 [StoreKitService] computeIsPro() scanning latest transactions for ids=\(productIds)")
        for id in productIds {
            if let result = await Transaction.latest(for: id) {
                switch result {
                case .verified(let transaction):
                    print("🛒 [StoreKitService] latest transaction verified for id=\(id), revoked=\(transaction.revocationDate != nil)")
                    if transaction.revocationDate == nil {
                        return true
                    }
                case .unverified:
                    print("🛒 [StoreKitService] latest transaction unverified for id=\(id)")
                    continue
                }
            }
        }
        // Alternatively, iterate currentEntitlements quickly
        // (kept simple to avoid long-lived streams here)
        return false
        #else
        print("🛒 [StoreKitService] computeIsPro() StoreKit not available")
        return false
        #endif
    }

    public func refreshEntitlements(force: Bool = false) async {
        if !force, let cached = getCachedIsProValid(), cached {
            // Only short-circuit on positive cache hits. A cached `false` should still recompute so
            // upgrade flows reflect immediately.
            await MainActor.run { self.subject.send(cached) }
            print("🛒 [StoreKitService] refreshEntitlements() using cached isPro=true")
            return
        }

        let value = await computeIsPro()
        await MainActor.run { setIsPro(value) }
        print("🛒 [StoreKitService] refreshEntitlements() computed isPro=\(value)")
    }
}

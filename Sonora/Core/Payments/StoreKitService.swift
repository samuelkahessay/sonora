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
}

public final class StoreKitService: StoreKitServiceProtocol, @unchecked Sendable {
    // MARK: - Constants
    private let productIds: Set<String> = ["pro.monthly", "pro.annual"]
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
        let products = try await Product.products(for: Array(productIds))
        guard let product = products.first(where: { $0.id == productId }) else { return false }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                await transaction.finish()
                await refreshEntitlements()
                return true
            case .unverified:
                return false
            }
        case .userCancelled:
            return false
        case .pending:
            // Treat pending as not upgraded yet
            return false
        @unknown default:
            return false
        }
        #else
        return false
        #endif
    }

    public func restorePurchases() async throws -> Bool {
        #if canImport(StoreKit)
        try await AppStore.sync()
        // Sync triggers entitlement updates; refresh view of current state
        let before = subject.value
        await refreshEntitlements()
        return subject.value != before || subject.value
        #else
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
        for id in productIds {
            if let result = await Transaction.latest(for: id) {
                switch result {
                case .verified(let transaction):
                    if transaction.revocationDate == nil {
                        return true
                    }
                case .unverified:
                    continue
                }
            }
        }
        // Alternatively, iterate currentEntitlements quickly
        // (kept simple to avoid long-lived streams here)
        return false
        #else
        return false
        #endif
    }

    public func refreshEntitlements() async {
        if let cached = getCachedIsProValid() {
            // Cache still valid; keep current subject (already set on init)
            await MainActor.run { self.subject.send(cached) }
            return
        }
        let value = await computeIsPro()
        await MainActor.run { setIsPro(value) }
    }
}


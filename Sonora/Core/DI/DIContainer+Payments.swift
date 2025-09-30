import Foundation

extension DIContainer {
    @MainActor
    func storeKitService() -> any StoreKitServiceProtocol {
        ensureConfigured()
        if let svc = _storeKitService { return svc }
        guard let svc = resolve((any StoreKitServiceProtocol).self) else {
            fatalError("DIContainer not configured: storeKitService")
        }
        _storeKitService = svc
        return svc
    }
}

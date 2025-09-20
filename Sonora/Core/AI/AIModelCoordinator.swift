import Foundation

/// Coordinates access to heavy on-device AI workloads so only one runs at a time.
actor AIModelCoordinator {
    private enum State: Equatable {
        case idle
        case analyzing
    }

    static let shared = AIModelCoordinator()

    private var state: State = .idle

    func acquireAnalyzing<T: Sendable>(_ operation: @MainActor @Sendable () async throws -> T) async throws -> T {
        try await transitionToAnalyzing()
        do {
            let result = try await withTaskCancellationHandler(operation: {
                try await operation()
            }, onCancel: { [weak self] in
                Task { await self?.releaseToIdle() }
            })
            releaseToIdle()
            return result
        } catch {
            releaseToIdle()
            throw error
        }
    }

    private func transitionToAnalyzing() async throws {
        if state == .analyzing { return }
        state = .analyzing
    }

    private func releaseToIdle() {
        state = .idle
    }
}

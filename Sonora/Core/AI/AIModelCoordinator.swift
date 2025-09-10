import Foundation

// Central authority to guarantee mutual exclusion between large local models (Whisper vs Phi‑4).
// Keeps a simple state machine and offers acquire() wrappers to serialize transitions.
actor AIModelCoordinator {
    enum State: Equatable {
        case idle
        case transcribing
        case analyzing
    }

    static let shared = AIModelCoordinator()

    private var state: State = .idle

    // Optional unload hooks injected by clients (services)
    private var unloadWhisperHook: (@MainActor @Sendable () -> Void)?
    private var unloadPhiHook: (@MainActor @Sendable () -> Void)?

    // Register unload hooks; safe to call multiple times, latest wins.
    func registerUnloadHandlers(unloadWhisper: (@MainActor @Sendable () -> Void)? = nil,
                                unloadPhi: (@MainActor @Sendable () -> Void)? = nil) {
        if let uw = unloadWhisper { self.unloadWhisperHook = uw }
        if let up = unloadPhi { self.unloadPhiHook = up }
    }

    // Public helpers
    func acquireTranscribing<T: Sendable>(_ operation: @MainActor @Sendable () async throws -> T) async throws -> T {
        try await transition(to: .transcribing)
        do {
            let result = try await withTaskCancellationHandler(operation: {
                try await operation()
            }, onCancel: { [weak self] in
                Task { await self?.releaseToIdleIfNeeded() }
            })
            await releaseToIdleIfNeeded()
            return result
        } catch {
            await releaseToIdleIfNeeded()
            throw error
        }
    }

    func acquireAnalyzing<T: Sendable>(_ operation: @MainActor @Sendable () async throws -> T) async throws -> T {
        try await transition(to: .analyzing)
        do {
            let result = try await withTaskCancellationHandler(operation: {
                try await operation()
            }, onCancel: { [weak self] in
                Task { await self?.releaseToIdleIfNeeded() }
            })
            await releaseToIdleIfNeeded()
            return result
        } catch {
            await releaseToIdleIfNeeded()
            throw error
        }
    }

    // Internal state transitions
    private func transition(to target: State) async throws {
        if state == target { return }
        switch (state, target) {
        case (.idle, _):
            // No-op
            break
        case (.transcribing, .analyzing):
            // Must unload Whisper first
            if let hook = unloadWhisperHook { await hook() }
        case (.analyzing, .transcribing):
            // Must unload Phi‑4 first
            if let hook = unloadPhiHook { await hook() }
        default:
            break
        }
        state = target
    }

    private func releaseToIdleIfNeeded() {
        state = .idle
    }
}

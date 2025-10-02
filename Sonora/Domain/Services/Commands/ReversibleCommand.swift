import Foundation

/// Represents an action that can be executed and undone.
public protocol ReversibleCommand: Sendable {
    @MainActor func execute() async throws
    @MainActor func undo() async throws
}


import Foundation

/// Generic protocol for all Use Cases in the application
/// Provides consistent interface with associated types for Input/Output
public protocol UseCase: Sendable {
    associatedtype Input: Sendable
    associatedtype Output: Sendable

    /// Execute the use case with the given input
    func execute(_ input: Input) async throws -> Output
}

/// Specialized Use Case protocol for operations that don't require input
public protocol NoInputUseCase: Sendable {
    associatedtype Output: Sendable

    /// Execute the use case without input
    func execute() async throws -> Output
}

/// Specialized Use Case protocol for operations that don't return output  
public protocol NoOutputUseCase: Sendable {
    associatedtype Input: Sendable

    /// Execute the use case with input but no return value
    func execute(_ input: Input) async throws
}

/// Specialized Use Case protocol for simple operations with no input or output
public protocol SimpleUseCase: Sendable {

    /// Execute the use case without input or output
    func execute() async throws
}

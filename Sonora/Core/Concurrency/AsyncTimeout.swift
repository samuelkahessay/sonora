import Foundation

/// Error thrown when an asynchronous operation exceeds the allotted timeout interval.
public struct AsyncTimeoutError: LocalizedError {
    public let message: String

    public init(_ message: String) {
        self.message = message
    }

    public var errorDescription: String? { message }
}

/// Execute an asynchronous operation with a timeout. If the timeout elapses before the
/// operation completes, `AsyncTimeoutError` is thrown and the task is cancelled.
@discardableResult
public func withTimeout<T>(seconds: TimeInterval,
                           operationDescription: String,
                           operation: @escaping @Sendable () async throws -> T) async throws -> T {
    let deadline = UInt64(max(0, seconds) * 1_000_000_000)
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try Task.checkCancellation()
            return try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: deadline)
            throw AsyncTimeoutError("Operation timed out: \(operationDescription)")
        }

        guard let result = try await group.next() else {
            group.cancelAll()
            throw AsyncTimeoutError("Operation timed out: \(operationDescription)")
        }

        group.cancelAll()
        return result
    }
}

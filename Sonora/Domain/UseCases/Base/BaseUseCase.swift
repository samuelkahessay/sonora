import Foundation

/// Abstract base class providing common functionality for all Use Cases
/// Centralizes logging, correlation ID generation, and standard error handling
open class BaseUseCase: @unchecked Sendable {

    // MARK: - Dependencies
    internal let logger: any LoggerProtocol
    internal let correlationIdGenerator: @Sendable () -> String

    // MARK: - Initialization
    public init(
        logger: any LoggerProtocol = Logger.shared,
        correlationIdGenerator: @escaping @Sendable () -> String = { UUID().uuidString }
    ) {
        self.logger = logger
        self.correlationIdGenerator = correlationIdGenerator
    }

    // MARK: - Common Functionality

    /// Generate a new correlation ID for tracking operations
    internal func generateCorrelationId() -> String {
        correlationIdGenerator()
    }

    /// Create standardized log context with correlation ID
    internal func createLogContext(
        correlationId: String,
        additionalInfo: [String: Any] = [:]
    ) -> LogContext {
        LogContext(correlationId: correlationId, additionalInfo: additionalInfo)
    }

    /// Standard input validation with logging
    internal func validateNonEmptyString(
        _ value: String,
        fieldName: String,
        context: LogContext
    ) throws {
        guard !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("\(fieldName) validation failed: empty string", category: .useCase, context: context, error: nil)
            throw ValidationError.emptyField(fieldName)
        }
    }

    /// Standard UUID validation with logging
    internal func validateUUID(
        _ uuid: UUID?,
        fieldName: String,
        context: LogContext
    ) throws {
        guard uuid != nil else {
            logger.error("\(fieldName) validation failed: nil UUID", category: .useCase, context: context, error: nil)
            throw ValidationError.invalidUUID(fieldName)
        }
    }

    /// Standard minimum length validation
    internal func validateMinimumLength(
        _ value: String,
        fieldName: String,
        minimumLength: Int,
        context: LogContext
    ) throws {
        guard value.count >= minimumLength else {
            logger.error("\(fieldName) validation failed: too short (\(value.count) chars, minimum \(minimumLength))",
                        category: .useCase, context: context, error: nil)
            throw ValidationError.fieldTooShort(fieldName, minimum: minimumLength, actual: value.count)
        }
    }

    /// Log the start of a use case execution
    internal func logExecutionStart(
        operation: String,
        context: LogContext
    ) {
        logger.info("Starting \(operation)", category: .useCase, context: context)
    }

    /// Log successful completion of a use case
    internal func logExecutionSuccess(
        operation: String,
        context: LogContext,
        additionalInfo: [String: Any] = [:]
    ) {
        let mergedInfo = (context.additionalInfo ?? [:]).merging(additionalInfo) { _, new in new }
        let logContext = LogContext(correlationId: context.correlationId, additionalInfo: mergedInfo)
        logger.info("\(operation) completed successfully", category: .useCase, context: logContext)
    }

    /// Log and wrap execution errors
    internal func logAndWrapError(
        operation: String,
        context: LogContext,
        error: Error
    ) -> Error {
        logger.error("\(operation) failed", category: .useCase, context: context, error: error)

        // Return specialized error based on type
        if error is ValidationError {
            return error
        } else {
            return UseCaseError.executionFailed(operation: operation, underlyingError: error)
        }
    }
}

// MARK: - Error Types

/// Validation errors for input parameters
public enum ValidationError: LocalizedError, Sendable {
    case emptyField(String)
    case invalidUUID(String)
    case fieldTooShort(String, minimum: Int, actual: Int)

    public var errorDescription: String? {
        switch self {
        case .emptyField(let field):
            return "Field '\(field)' cannot be empty"
        case .invalidUUID(let field):
            return "Field '\(field)' must be a valid UUID"
        case .fieldTooShort(let field, let minimum, let actual):
            return "Field '\(field)' is too short (minimum: \(minimum), actual: \(actual))"
        }
    }
}

/// General use case execution errors
public enum UseCaseError: LocalizedError, Sendable {
    case executionFailed(operation: String, underlyingError: Error)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let operation, let underlyingError):
            return "Operation '\(operation)' failed: \(underlyingError.localizedDescription)"
        }
    }
}

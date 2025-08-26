import Foundation

/// Specific error types for repository operations in the data layer
public enum RepositoryError: LocalizedError, Equatable {
    
    // MARK: - File System Errors
    case fileNotFound(String)
    case fileCreationFailed(String)
    case fileReadFailed(String)
    case fileWriteFailed(String)
    case fileDeletionFailed(String)
    case fileCorrupted(String)
    case atomicWriteFailed(String)
    case directoryCreationFailed(String)
    case pathInvalid(String)
    case permissionDenied(String)
    
    // MARK: - Data Integrity Errors
    case indexCorrupted(String)
    case metadataInvalid(String)
    case dataIntegrityViolation(String)
    case versionMismatch(expected: String, found: String)
    case checksumMismatch(String)
    case duplicateEntry(String)
    case referentialIntegrityViolation(String)
    
    // MARK: - Encoding/Decoding Errors
    case encodingFailed(String)
    case decodingFailed(String)
    case jsonSerializationFailed(String)
    case jsonDeserializationFailed(String)
    case unsupportedDataFormat(String)
    case schemaValidationFailed(String)
    
    // MARK: - Repository State Errors
    case repositoryNotInitialized(String)
    case repositoryCorrupted(String)
    case repositoryLocked(String)
    case repositoryMigrationRequired(String)
    case repositoryVersionUnsupported(String)
    case repositoryConfigurationInvalid(String)
    
    // MARK: - Resource Management Errors
    case resourceNotFound(String)
    case resourceAlreadyExists(String)
    case resourceLocked(String)
    case resourceUnavailable(String)
    case resourceQuotaExceeded(String)
    case resourceSizeLimitExceeded(String)
    
    // MARK: - Transaction Errors
    case transactionFailed(String)
    case transactionRolledBack(String)
    case transactionTimeout(String)
    case transactionDeadlock(String)
    case concurrentModification(String)
    
    // MARK: - Cache Errors
    case cacheNotFound(String)
    case cacheExpired(String)
    case cacheCorrupted(String)
    case cacheEvictionFailed(String)
    case cacheSizeLimitExceeded(String)
    
    // MARK: - Validation Errors
    case validationFailed(String)
    case constraintViolation(String)
    case uniquenessViolation(String)
    case requiredFieldMissing(String)
    case fieldValueInvalid(field: String, value: String)
    case relationshipInvalid(String)
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        // File System Errors
        case .fileNotFound(let path):
            return "File not found: \(path)"
        case .fileCreationFailed(let reason):
            return "Failed to create file: \(reason)"
        case .fileReadFailed(let reason):
            return "Failed to read file: \(reason)"
        case .fileWriteFailed(let reason):
            return "Failed to write file: \(reason)"
        case .fileDeletionFailed(let reason):
            return "Failed to delete file: \(reason)"
        case .fileCorrupted(let path):
            return "File is corrupted: \(path)"
        case .atomicWriteFailed(let reason):
            return "Atomic write operation failed: \(reason)"
        case .directoryCreationFailed(let path):
            return "Failed to create directory: \(path)"
        case .pathInvalid(let path):
            return "Invalid file path: \(path)"
        case .permissionDenied(let operation):
            return "Permission denied for operation: \(operation)"
            
        // Data Integrity Errors
        case .indexCorrupted(let details):
            return "Index file is corrupted: \(details)"
        case .metadataInvalid(let details):
            return "Metadata is invalid: \(details)"
        case .dataIntegrityViolation(let details):
            return "Data integrity violation: \(details)"
        case .versionMismatch(let expected, let found):
            return "Version mismatch: expected \(expected), found \(found)"
        case .checksumMismatch(let details):
            return "Checksum mismatch: \(details)"
        case .duplicateEntry(let identifier):
            return "Duplicate entry found: \(identifier)"
        case .referentialIntegrityViolation(let details):
            return "Referential integrity violation: \(details)"
            
        // Encoding/Decoding Errors
        case .encodingFailed(let reason):
            return "Data encoding failed: \(reason)"
        case .decodingFailed(let reason):
            return "Data decoding failed: \(reason)"
        case .jsonSerializationFailed(let reason):
            return "JSON serialization failed: \(reason)"
        case .jsonDeserializationFailed(let reason):
            return "JSON deserialization failed: \(reason)"
        case .unsupportedDataFormat(let format):
            return "Unsupported data format: \(format)"
        case .schemaValidationFailed(let reason):
            return "Schema validation failed: \(reason)"
            
        // Repository State Errors
        case .repositoryNotInitialized(let name):
            return "Repository not initialized: \(name)"
        case .repositoryCorrupted(let name):
            return "Repository is corrupted: \(name)"
        case .repositoryLocked(let name):
            return "Repository is locked: \(name)"
        case .repositoryMigrationRequired(let details):
            return "Repository migration required: \(details)"
        case .repositoryVersionUnsupported(let version):
            return "Repository version unsupported: \(version)"
        case .repositoryConfigurationInvalid(let reason):
            return "Repository configuration is invalid: \(reason)"
            
        // Resource Management Errors
        case .resourceNotFound(let identifier):
            return "Resource not found: \(identifier)"
        case .resourceAlreadyExists(let identifier):
            return "Resource already exists: \(identifier)"
        case .resourceLocked(let identifier):
            return "Resource is locked: \(identifier)"
        case .resourceUnavailable(let identifier):
            return "Resource is unavailable: \(identifier)"
        case .resourceQuotaExceeded(let details):
            return "Resource quota exceeded: \(details)"
        case .resourceSizeLimitExceeded(let details):
            return "Resource size limit exceeded: \(details)"
            
        // Transaction Errors
        case .transactionFailed(let reason):
            return "Transaction failed: \(reason)"
        case .transactionRolledBack(let reason):
            return "Transaction was rolled back: \(reason)"
        case .transactionTimeout(let details):
            return "Transaction timed out: \(details)"
        case .transactionDeadlock(let details):
            return "Transaction deadlock detected: \(details)"
        case .concurrentModification(let resource):
            return "Concurrent modification detected: \(resource)"
            
        // Cache Errors
        case .cacheNotFound(let key):
            return "Cache entry not found: \(key)"
        case .cacheExpired(let key):
            return "Cache entry expired: \(key)"
        case .cacheCorrupted(let details):
            return "Cache is corrupted: \(details)"
        case .cacheEvictionFailed(let reason):
            return "Cache eviction failed: \(reason)"
        case .cacheSizeLimitExceeded(let details):
            return "Cache size limit exceeded: \(details)"
            
        // Validation Errors
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .constraintViolation(let constraint):
            return "Constraint violation: \(constraint)"
        case .uniquenessViolation(let field):
            return "Uniqueness violation: \(field)"
        case .requiredFieldMissing(let field):
            return "Required field missing: \(field)"
        case .fieldValueInvalid(let field, let value):
            return "Invalid value for field \(field): \(value)"
        case .relationshipInvalid(let details):
            return "Invalid relationship: \(details)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .permissionDenied:
            return "The app doesn't have the necessary permissions to perform this operation."
        case .repositoryCorrupted, .indexCorrupted, .fileCorrupted:
            return "Data corruption has been detected in the repository."
        case .atomicWriteFailed:
            return "The atomic write operation could not ensure data consistency."
        case .transactionTimeout:
            return "The operation took longer than expected and was cancelled."
        case .concurrentModification:
            return "Another process modified the data while this operation was in progress."
        case .resourceQuotaExceeded, .resourceSizeLimitExceeded:
            return "The operation exceeded system resource limits."
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Grant the necessary permissions in system settings and try again."
        case .repositoryCorrupted, .indexCorrupted, .fileCorrupted:
            return "The app may need to rebuild its data. Consider restarting the app or clearing app data."
        case .atomicWriteFailed:
            return "Try the operation again. If it continues to fail, restart the app."
        case .transactionTimeout:
            return "Try the operation again with fewer concurrent operations."
        case .concurrentModification:
            return "Refresh the data and try the operation again."
        case .resourceQuotaExceeded:
            return "Free up system resources or try again later."
        case .resourceSizeLimitExceeded:
            return "Reduce the size of the data being processed."
        case .repositoryMigrationRequired:
            return "The app needs to update its data format. This will happen automatically."
        case .versionMismatch:
            return "Update the app to the latest version."
        default:
            return "Try the operation again. If the problem persists, restart the app."
        }
    }
    
    // MARK: - Error Classification
    
    /// Whether this error is recoverable by retrying the operation
    public var isRetryable: Bool {
        switch self {
        case .transactionTimeout, .transactionDeadlock, .concurrentModification, .resourceUnavailable:
            return true
        case .permissionDenied, .repositoryCorrupted, .fileCorrupted, .versionMismatch:
            return false
        case .atomicWriteFailed, .fileWriteFailed, .fileReadFailed:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error indicates data corruption
    public var indicatesCorruption: Bool {
        switch self {
        case .repositoryCorrupted, .indexCorrupted, .fileCorrupted, .dataIntegrityViolation, .checksumMismatch, .cacheCorrupted:
            return true
        default:
            return false
        }
    }
    
    /// Whether this error requires immediate attention
    public var isCritical: Bool {
        switch self {
        case .repositoryCorrupted, .dataIntegrityViolation, .checksumMismatch, .referentialIntegrityViolation:
            return true
        default:
            return false
        }
    }
    
    /// The category of repository operation that failed
    public var operationType: RepositoryOperationType {
        switch self {
        case .fileReadFailed, .fileNotFound, .decodingFailed, .jsonDeserializationFailed, .cacheNotFound:
            return .read
        case .fileWriteFailed, .fileCreationFailed, .atomicWriteFailed, .encodingFailed, .jsonSerializationFailed:
            return .write
        case .fileDeletionFailed:
            return .delete
        case .validationFailed, .constraintViolation, .uniquenessViolation, .schemaValidationFailed:
            return .validation
        case .transactionFailed, .transactionRolledBack, .transactionTimeout, .transactionDeadlock:
            return .transaction
        case .cacheExpired, .cacheCorrupted, .cacheEvictionFailed, .cacheSizeLimitExceeded:
            return .cache
        default:
            return .other
        }
    }
}

// MARK: - Supporting Types

/// Types of repository operations
public enum RepositoryOperationType: String, CaseIterable {
    case read
    case write
    case delete
    case validation
    case transaction
    case cache
    case other
    
    public var displayName: String {
        switch self {
        case .read: return "Read"
        case .write: return "Write"
        case .delete: return "Delete"
        case .validation: return "Validation"
        case .transaction: return "Transaction"
        case .cache: return "Cache"
        case .other: return "Other"
        }
    }
    
    public var iconName: String {
        switch self {
        case .read: return "doc.text"
        case .write: return "square.and.pencil"
        case .delete: return "trash"
        case .validation: return "checkmark.shield"
        case .transaction: return "arrow.triangle.2.circlepath"
        case .cache: return "memorychip"
        case .other: return "gear"
        }
    }
}

// MARK: - Error Recovery Strategies

/// Strategies for recovering from repository errors
public enum RepositoryRecoveryStrategy: String, CaseIterable {
    case retry
    case refresh
    case migrate
    case rebuild
    case clearCache
    case requestPermission
    case userIntervention
    case none
    
    public var displayName: String {
        switch self {
        case .retry: return "Retry Operation"
        case .refresh: return "Refresh Data"
        case .migrate: return "Migrate Data"
        case .rebuild: return "Rebuild Repository"
        case .clearCache: return "Clear Cache"
        case .requestPermission: return "Request Permission"
        case .userIntervention: return "User Action Required"
        case .none: return "No Recovery Available"
        }
    }
}

// MARK: - Error Extensions

public extension RepositoryError {
    
    /// Recommended recovery strategy for this error
    var recommendedRecoveryStrategy: RepositoryRecoveryStrategy {
        switch self {
        case .transactionTimeout, .transactionDeadlock, .concurrentModification:
            return .retry
        case .cacheExpired, .cacheCorrupted:
            return .clearCache
        case .repositoryMigrationRequired, .versionMismatch:
            return .migrate
        case .repositoryCorrupted, .indexCorrupted:
            return .rebuild
        case .permissionDenied:
            return .requestPermission
        case .dataIntegrityViolation, .checksumMismatch:
            return .userIntervention
        default:
            return .retry
        }
    }
    
    /// Convert to a SonoraError for unified error handling
    var asSonoraError: SonoraError {
        switch self {
        case .fileNotFound(let path):
            return .storageFileNotFound(path)
        case .fileWriteFailed(let reason):
            return .storageWriteFailed(reason)
        case .fileReadFailed(let reason):
            return .storageReadFailed(reason)
        case .fileDeletionFailed(let reason):
            return .storageDeleteFailed(reason)
        case .permissionDenied:
            return .storagePermissionDenied
        case .encodingFailed(let reason):
            return .dataEncodingFailed(reason)
        case .decodingFailed(let reason):
            return .dataDecodingFailed(reason)
        case .fileCorrupted(let path):
            return .dataCorrupted("Repository corruption detected at \(path)")
        case .repositoryCorrupted(let details), .indexCorrupted(let details):
            return .dataCorrupted("Repository corruption detected: \(details)")
        default:
            return .unknown("Repository error: \(self.localizedDescription)")
        }
    }
}

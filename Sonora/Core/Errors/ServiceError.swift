import Foundation
import AVFoundation

/// Specific error types for service layer operations
public enum ServiceError: LocalizedError, Equatable {
    
    // MARK: - Audio Service Errors
    case audioSessionConfigurationFailed(String)
    case audioRecordingPermissionDenied
    case audioRecordingDeviceUnavailable
    case audioRecordingFailed(String)
    case audioPlaybackFailed(String)
    case audioFormatConversionFailed(String)
    case audioFileProcessingFailed(String)
    case audioSessionInterrupted(String)
    case audioHardwareError(String)
    
    // MARK: - Transcription Service Errors
    case transcriptionServiceOffline
    case transcriptionAPIKeyInvalid
    case transcriptionAPIQuotaExceeded
    case transcriptionFileTooLarge(Int64)
    case transcriptionFormatUnsupported(String)
    case transcriptionLanguageUnsupported(String)
    case transcriptionProcessingFailed(String)
    case transcriptionResultInvalid(String)
    case transcriptionServiceTimeout
    case transcriptionServiceRateLimited
    
    // MARK: - Analysis Service Errors
    case analysisServiceOffline
    case analysisAPIKeyInvalid
    case analysisAPIQuotaExceeded
    case analysisInputTooShort(Int)
    case analysisInputTooLong(Int)
    case analysisModelUnavailable(String)
    case analysisProcessingFailed(String)
    case analysisResultInvalid(String)
    case analysisServiceTimeout
    case analysisServiceRateLimited
    case analysisLanguageUnsupported(String)
    
    // MARK: - Network Service Errors
    case networkServiceUnavailable
    case networkConnectionLost
    case networkRequestTimeout(TimeInterval)
    case networkInvalidURL(String)
    case networkSSLError(String)
    case networkProxyError(String)
    case networkDNSError(String)
    case networkCertificateError(String)
    
    // MARK: - File Service Errors
    case fileServicePermissionDenied(String)
    case fileServiceDiskFull
    case fileServicePathInvalid(String)
    case fileServiceFileInUse(String)
    case fileServiceBackupFailed(String)
    case fileServiceSyncFailed(String)
    case fileServiceQuotaExceeded(String)
    case fileServiceCorruptionDetected(String)
    
    // MARK: - Configuration Service Errors
    case configurationServiceNotInitialized
    case configurationKeyMissing(String)
    case configurationValueInvalid(String)
    case configurationFileCorrupted(String)
    case configurationSchemaMismatch(String)
    case configurationMigrationFailed(String)
    
    // MARK: - Authentication Service Errors
    case authenticationRequired
    case authenticationFailed(String)
    case authenticationTokenExpired
    case authenticationTokenInvalid
    case authenticationServiceUnavailable
    case authenticationRateLimited
    
    // MARK: - Metadata Service Errors
    case metadataExtractionFailed(String)
    case metadataValidationFailed(String)
    case metadataStorageFailed(String)
    case metadataRetrievalFailed(String)
    case metadataFormatUnsupported(String)
    
    // MARK: - Synchronization Service Errors
    case syncServiceConflict(String)
    case syncServiceConnectionLost
    case syncServiceVersionMismatch(String)
    case syncServiceDataCorrupted(String)
    case syncServicePermissionDenied
    case syncServiceQuotaExceeded
    
    // MARK: - Cache Service Errors
    case cacheServiceFull
    case cacheServiceCorrupted(String)
    case cacheServiceEvictionFailed(String)
    case cacheServiceValidationFailed(String)
    case cacheServiceSizeLimitExceeded(String)
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        // Audio Service Errors
        case .audioSessionConfigurationFailed(let reason):
            return "Audio session configuration failed: \(reason)"
        case .audioRecordingPermissionDenied:
            return "Microphone permission is required for recording"
        case .audioRecordingDeviceUnavailable:
            return "Audio recording device is unavailable"
        case .audioRecordingFailed(let reason):
            return "Audio recording failed: \(reason)"
        case .audioPlaybackFailed(let reason):
            return "Audio playback failed: \(reason)"
        case .audioFormatConversionFailed(let format):
            return "Audio format conversion failed: \(format)"
        case .audioFileProcessingFailed(let reason):
            return "Audio file processing failed: \(reason)"
        case .audioSessionInterrupted(let reason):
            return "Audio session was interrupted: \(reason)"
        case .audioHardwareError(let details):
            return "Audio hardware error: \(details)"
            
        // Transcription Service Errors
        case .transcriptionServiceOffline:
            return "Transcription service is currently offline"
        case .transcriptionAPIKeyInvalid:
            return "Invalid API key for transcription service"
        case .transcriptionAPIQuotaExceeded:
            return "Transcription API quota has been exceeded"
        case .transcriptionFileTooLarge(let size):
            return "File too large for transcription: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))"
        case .transcriptionFormatUnsupported(let format):
            return "Unsupported file format for transcription: \(format)"
        case .transcriptionLanguageUnsupported(let language):
            return "Unsupported language for transcription: \(language)"
        case .transcriptionProcessingFailed(let reason):
            return "Transcription processing failed: \(reason)"
        case .transcriptionResultInvalid(let details):
            return "Invalid transcription result: \(details)"
        case .transcriptionServiceTimeout:
            return "Transcription service request timed out"
        case .transcriptionServiceRateLimited:
            return "Transcription service rate limit exceeded"
            
        // Analysis Service Errors
        case .analysisServiceOffline:
            return "Analysis service is currently offline"
        case .analysisAPIKeyInvalid:
            return "Invalid API key for analysis service"
        case .analysisAPIQuotaExceeded:
            return "Analysis API quota has been exceeded"
        case .analysisInputTooShort(let length):
            return "Input too short for analysis: \(length) characters"
        case .analysisInputTooLong(let length):
            return "Input too long for analysis: \(length) characters"
        case .analysisModelUnavailable(let model):
            return "Analysis model unavailable: \(model)"
        case .analysisProcessingFailed(let reason):
            return "Analysis processing failed: \(reason)"
        case .analysisResultInvalid(let details):
            return "Invalid analysis result: \(details)"
        case .analysisServiceTimeout:
            return "Analysis service request timed out"
        case .analysisServiceRateLimited:
            return "Analysis service rate limit exceeded"
        case .analysisLanguageUnsupported(let language):
            return "Unsupported language for analysis: \(language)"
            
        // Network Service Errors
        case .networkServiceUnavailable:
            return "Network service is unavailable"
        case .networkConnectionLost:
            return "Network connection was lost"
        case .networkRequestTimeout(let timeout):
            return "Network request timed out after \(timeout) seconds"
        case .networkInvalidURL(let url):
            return "Invalid network URL: \(url)"
        case .networkSSLError(let details):
            return "SSL/TLS error: \(details)"
        case .networkProxyError(let details):
            return "Proxy error: \(details)"
        case .networkDNSError(let details):
            return "DNS resolution error: \(details)"
        case .networkCertificateError(let details):
            return "Certificate error: \(details)"
            
        // File Service Errors
        case .fileServicePermissionDenied(let operation):
            return "Permission denied for file operation: \(operation)"
        case .fileServiceDiskFull:
            return "Insufficient disk space for file operation"
        case .fileServicePathInvalid(let path):
            return "Invalid file path: \(path)"
        case .fileServiceFileInUse(let filename):
            return "File is currently in use: \(filename)"
        case .fileServiceBackupFailed(let reason):
            return "File backup failed: \(reason)"
        case .fileServiceSyncFailed(let reason):
            return "File synchronization failed: \(reason)"
        case .fileServiceQuotaExceeded(let details):
            return "File service quota exceeded: \(details)"
        case .fileServiceCorruptionDetected(let details):
            return "File corruption detected: \(details)"
            
        // Configuration Service Errors
        case .configurationServiceNotInitialized:
            return "Configuration service is not initialized"
        case .configurationKeyMissing(let key):
            return "Missing configuration key: \(key)"
        case .configurationValueInvalid(let key):
            return "Invalid configuration value for key: \(key)"
        case .configurationFileCorrupted(let filename):
            return "Configuration file is corrupted: \(filename)"
        case .configurationSchemaMismatch(let details):
            return "Configuration schema mismatch: \(details)"
        case .configurationMigrationFailed(let reason):
            return "Configuration migration failed: \(reason)"
            
        // Authentication Service Errors
        case .authenticationRequired:
            return "Authentication is required"
        case .authenticationFailed(let reason):
            return "Authentication failed: \(reason)"
        case .authenticationTokenExpired:
            return "Authentication token has expired"
        case .authenticationTokenInvalid:
            return "Authentication token is invalid"
        case .authenticationServiceUnavailable:
            return "Authentication service is unavailable"
        case .authenticationRateLimited:
            return "Authentication rate limit exceeded"
            
        // Metadata Service Errors
        case .metadataExtractionFailed(let reason):
            return "Metadata extraction failed: \(reason)"
        case .metadataValidationFailed(let reason):
            return "Metadata validation failed: \(reason)"
        case .metadataStorageFailed(let reason):
            return "Metadata storage failed: \(reason)"
        case .metadataRetrievalFailed(let reason):
            return "Metadata retrieval failed: \(reason)"
        case .metadataFormatUnsupported(let format):
            return "Unsupported metadata format: \(format)"
            
        // Synchronization Service Errors
        case .syncServiceConflict(let details):
            return "Sync conflict detected: \(details)"
        case .syncServiceConnectionLost:
            return "Sync service connection was lost"
        case .syncServiceVersionMismatch(let details):
            return "Sync version mismatch: \(details)"
        case .syncServiceDataCorrupted(let details):
            return "Sync data corruption detected: \(details)"
        case .syncServicePermissionDenied:
            return "Permission denied for sync operation"
        case .syncServiceQuotaExceeded:
            return "Sync service quota exceeded"
            
        // Cache Service Errors
        case .cacheServiceFull:
            return "Cache service is full"
        case .cacheServiceCorrupted(let details):
            return "Cache service corruption detected: \(details)"
        case .cacheServiceEvictionFailed(let reason):
            return "Cache eviction failed: \(reason)"
        case .cacheServiceValidationFailed(let reason):
            return "Cache validation failed: \(reason)"
        case .cacheServiceSizeLimitExceeded(let details):
            return "Cache size limit exceeded: \(details)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .audioRecordingPermissionDenied:
            return "The app requires microphone access to record audio."
        case .networkConnectionLost, .networkServiceUnavailable:
            return "The device is not connected to the internet or the service is temporarily unavailable."
        case .transcriptionAPIQuotaExceeded, .analysisAPIQuotaExceeded:
            return "You have exceeded your API usage quota for this billing period."
        case .fileServiceDiskFull:
            return "The device storage is full and cannot accommodate new files."
        case .authenticationTokenExpired:
            return "Your authentication session has expired and needs to be renewed."
        case .configurationServiceNotInitialized:
            return "The app's configuration system has not been properly set up."
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .audioRecordingPermissionDenied:
            return "Go to Settings > Privacy & Security > Microphone and enable access for this app."
        case .networkConnectionLost, .networkServiceUnavailable:
            return "Check your internet connection and try again."
        case .transcriptionAPIQuotaExceeded, .analysisAPIQuotaExceeded:
            return "Wait for your quota to reset or upgrade your service plan."
        case .fileServiceDiskFull:
            return "Free up storage space by deleting unused files or apps."
        case .authenticationTokenExpired:
            return "Please sign in again to renew your authentication."
        case .transcriptionFileTooLarge:
            return "Try using a shorter audio file or compress the file before uploading."
        case .configurationServiceNotInitialized:
            return "Restart the app to reinitialize the configuration system."
        case .transcriptionServiceTimeout, .analysisServiceTimeout:
            return "Try again with a smaller file or check your internet connection."
        default:
            return "Please try again. If the problem persists, contact support."
        }
    }
    
    // MARK: - Error Classification
    
    /// The type of service that generated this error
    public var serviceType: ServiceType {
        switch self {
        case .audioSessionConfigurationFailed, .audioRecordingPermissionDenied, .audioRecordingDeviceUnavailable, .audioRecordingFailed, .audioPlaybackFailed, .audioFormatConversionFailed, .audioFileProcessingFailed, .audioSessionInterrupted, .audioHardwareError:
            return .audio
        case .transcriptionServiceOffline, .transcriptionAPIKeyInvalid, .transcriptionAPIQuotaExceeded, .transcriptionFileTooLarge, .transcriptionFormatUnsupported, .transcriptionLanguageUnsupported, .transcriptionProcessingFailed, .transcriptionResultInvalid, .transcriptionServiceTimeout, .transcriptionServiceRateLimited:
            return .transcription
        case .analysisServiceOffline, .analysisAPIKeyInvalid, .analysisAPIQuotaExceeded, .analysisInputTooShort, .analysisInputTooLong, .analysisModelUnavailable, .analysisProcessingFailed, .analysisResultInvalid, .analysisServiceTimeout, .analysisServiceRateLimited, .analysisLanguageUnsupported:
            return .analysis
        case .networkServiceUnavailable, .networkConnectionLost, .networkRequestTimeout, .networkInvalidURL, .networkSSLError, .networkProxyError, .networkDNSError, .networkCertificateError:
            return .network
        case .fileServicePermissionDenied, .fileServiceDiskFull, .fileServicePathInvalid, .fileServiceFileInUse, .fileServiceBackupFailed, .fileServiceSyncFailed, .fileServiceQuotaExceeded, .fileServiceCorruptionDetected:
            return .file
        case .configurationServiceNotInitialized, .configurationKeyMissing, .configurationValueInvalid, .configurationFileCorrupted, .configurationSchemaMismatch, .configurationMigrationFailed:
            return .configuration
        case .authenticationRequired, .authenticationFailed, .authenticationTokenExpired, .authenticationTokenInvalid, .authenticationServiceUnavailable, .authenticationRateLimited:
            return .authentication
        case .metadataExtractionFailed, .metadataValidationFailed, .metadataStorageFailed, .metadataRetrievalFailed, .metadataFormatUnsupported:
            return .metadata
        case .syncServiceConflict, .syncServiceConnectionLost, .syncServiceVersionMismatch, .syncServiceDataCorrupted, .syncServicePermissionDenied, .syncServiceQuotaExceeded:
            return .synchronization
        case .cacheServiceFull, .cacheServiceCorrupted, .cacheServiceEvictionFailed, .cacheServiceValidationFailed, .cacheServiceSizeLimitExceeded:
            return .cache
        }
    }
    
    /// Whether this error is recoverable by retrying
    public var isRetryable: Bool {
        switch self {
        case .transcriptionServiceTimeout, .analysisServiceTimeout, .networkRequestTimeout, .networkConnectionLost:
            return true
        case .transcriptionServiceOffline, .analysisServiceOffline, .networkServiceUnavailable:
            return true
        case .syncServiceConnectionLost, .syncServiceConflict:
            return true
        case .audioRecordingPermissionDenied, .authenticationTokenExpired, .fileServiceDiskFull:
            return false // Requires user action
        case .transcriptionAPIKeyInvalid, .analysisAPIKeyInvalid, .authenticationTokenInvalid:
            return false // Requires configuration
        default:
            return false
        }
    }
    
    /// Whether this error requires user intervention
    public var requiresUserIntervention: Bool {
        switch self {
        case .audioRecordingPermissionDenied, .authenticationRequired, .authenticationTokenExpired:
            return true
        case .fileServiceDiskFull, .fileServicePermissionDenied:
            return true
        case .transcriptionAPIQuotaExceeded, .analysisAPIQuotaExceeded:
            return true
        case .configurationKeyMissing, .configurationValueInvalid:
            return true
        default:
            return false
        }
    }
    
    /// Severity level of this error
    public var severity: ServiceErrorSeverity {
        switch self {
        case .networkRequestTimeout, .transcriptionServiceTimeout, .analysisServiceTimeout:
            return .warning
        case .audioRecordingPermissionDenied, .authenticationRequired, .fileServiceDiskFull:
            return .error
        case .fileServiceCorruptionDetected, .configurationFileCorrupted, .syncServiceDataCorrupted:
            return .critical
        case .audioHardwareError, .configurationServiceNotInitialized:
            return .critical
        default:
            return .error
        }
    }
    
    /// Convert to a SonoraError for unified error handling
    public var asSonoraError: SonoraError {
        switch self {
        case .audioRecordingPermissionDenied:
            return .audioPermissionDenied
        case .audioRecordingFailed(let reason):
            return .audioRecordingFailed(reason)
        case .audioSessionConfigurationFailed(let reason):
            return .audioSessionSetupFailed(reason)
        case .transcriptionServiceOffline:
            return .transcriptionServiceUnavailable
        case .transcriptionProcessingFailed(let reason):
            return .transcriptionFailed(reason)
        case .transcriptionServiceTimeout:
            return .transcriptionTimeout
        case .transcriptionAPIQuotaExceeded:
            return .transcriptionQuotaExceeded
        case .analysisServiceOffline:
            return .analysisServiceUnavailable
        case .analysisProcessingFailed(let reason):
            return .analysisProcessingFailed(reason)
        case .analysisServiceTimeout:
            return .analysisTimeout
        case .analysisAPIQuotaExceeded:
            return .analysisQuotaExceeded
        case .networkServiceUnavailable, .networkConnectionLost:
            return .networkUnavailable
        case .networkRequestTimeout:
            return .networkTimeout
        case .fileServicePermissionDenied:
            return .storagePermissionDenied
        case .fileServiceDiskFull:
            return .storageSpaceInsufficient
        case .configurationKeyMissing(let key):
            return .configurationMissing(key)
        case .configurationValueInvalid(let key):
            return .configurationInvalid(key)
        default:
            return .unknown("Service error: \(self.localizedDescription)")
        }
    }
}

// MARK: - Supporting Types

/// Types of services that can generate errors
public enum ServiceType: String, CaseIterable {
    case audio
    case transcription
    case analysis
    case network
    case file
    case configuration
    case authentication
    case metadata
    case synchronization
    case cache
    
    public var displayName: String {
        switch self {
        case .audio: return "Audio"
        case .transcription: return "Transcription"
        case .analysis: return "Analysis"
        case .network: return "Network"
        case .file: return "File"
        case .configuration: return "Configuration"
        case .authentication: return "Authentication"
        case .metadata: return "Metadata"
        case .synchronization: return "Synchronization"
        case .cache: return "Cache"
        }
    }
    
    public var iconName: String {
        switch self {
        case .audio: return "waveform"
        case .transcription: return "text.quote"
        case .analysis: return "magnifyingglass"
        case .network: return "network"
        case .file: return "folder"
        case .configuration: return "gear"
        case .authentication: return "person.badge.key"
        case .metadata: return "info.circle"
        case .synchronization: return "arrow.triangle.2.circlepath"
        case .cache: return "memorychip"
        }
    }
}

/// Severity levels for service errors
public enum ServiceErrorSeverity: String, CaseIterable, Comparable {
    case info
    case warning
    case error
    case critical
    
    public var displayName: String {
        rawValue.capitalized
    }
    
    public var iconName: String {
        switch self {
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }
    
    public var color: String {
        switch self {
        case .info: return "blue"
        case .warning: return "orange"
        case .error: return "red"
        case .critical: return "purple"
        }
    }
    
    public static func < (lhs: ServiceErrorSeverity, rhs: ServiceErrorSeverity) -> Bool {
        let order: [ServiceErrorSeverity] = [.info, .warning, .error, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}

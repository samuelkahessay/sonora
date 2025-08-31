import Foundation

/// Comprehensive error types for the Sonora application
public enum SonoraError: LocalizedError, Equatable {
    
    // MARK: - Audio Recording Errors
    case audioPermissionDenied
    case audioSessionSetupFailed(String)
    case audioRecordingFailed(String)
    case audioRecordingInterrupted
    case audioFileNotFound(String)
    case audioFileCorrupted(String)
    case audioFormatUnsupported(String)
    case audioFileProcessingFailed(String)
    
    // MARK: - Transcription Errors
    case transcriptionServiceUnavailable
    case transcriptionFailed(String)
    case transcriptionTimeout
    case transcriptionInvalidResponse
    case transcriptionQuotaExceeded
    case transcriptionFileTooBig(Int64)
    case transcriptionUnsupportedFormat(String)
    
    // MARK: - Analysis Errors
    case analysisServiceUnavailable
    case analysisInvalidInput(String)
    case analysisProcessingFailed(String)
    case analysisTimeout
    case analysisModelUnavailable(String)
    case analysisInsufficientContent
    case analysisQuotaExceeded
    
    // MARK: - Storage Errors
    case storagePermissionDenied
    case storageSpaceInsufficient
    case storageFileNotFound(String)
    case storageCorruptedData(String)
    case storageWriteFailed(String)
    case storageReadFailed(String)
    case storageDeleteFailed(String)
    
    // MARK: - Network Errors
    case networkUnavailable
    case networkTimeout
    case networkServerError(Int, String?)
    case networkInvalidResponse
    case networkBadRequest(String)
    case networkUnauthorized
    case networkForbidden
    case networkRateLimited
    
    // MARK: - Configuration Errors
    case configurationMissing(String)
    case configurationInvalid(String)
    case apiKeyMissing
    case apiKeyInvalid
    case endpointUnavailable(String)
    
    // MARK: - Data Errors
    case dataCorrupted(String)
    case dataFormatInvalid(String)
    case dataDecodingFailed(String)
    case dataEncodingFailed(String)
    case dataMigrationFailed(String)
    
    // MARK: - User Interface Errors
    case uiStateInconsistent(String)
    case uiOperationCancelled
    case uiFeatureUnavailable(String)
    
    // MARK: - System Errors
    case systemMemoryLow
    case systemDiskFull
    case systemResourceUnavailable(String)
    case systemVersionUnsupported(String)
    
    // MARK: - Unknown Errors
    case unknown(String)
    
    // MARK: - LocalizedError Implementation
    
    public var errorDescription: String? {
        switch self {
        // Audio Recording Errors
        case .audioPermissionDenied:
            return "Microphone permission is required to record audio."
        case .audioSessionSetupFailed(let reason):
            return "Failed to set up audio session: \(reason)"
        case .audioRecordingFailed(let reason):
            return "Audio recording failed: \(reason)"
        case .audioRecordingInterrupted:
            return "Audio recording was interrupted."
        case .audioFileNotFound(let filename):
            return "Audio file not found: \(filename)"
        case .audioFileCorrupted(let filename):
            return "Audio file is corrupted: \(filename)"
        case .audioFormatUnsupported(let format):
            return "Unsupported audio format: \(format)"
        case .audioFileProcessingFailed(let reason):
            return "Audio file processing failed: \(reason)"
            
        // Transcription Errors
        case .transcriptionServiceUnavailable:
            return "Transcription service is currently unavailable."
        case .transcriptionFailed(let reason):
            return "Transcription failed: \(reason)"
        case .transcriptionTimeout:
            return "Transcription timed out. Please try again."
        case .transcriptionInvalidResponse:
            return "Received invalid response from transcription service."
        case .transcriptionQuotaExceeded:
            return "Transcription quota exceeded. Please try again later."
        case .transcriptionFileTooBig(let size):
            return "File too large for transcription (\(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))). Maximum size is 25MB."
        case .transcriptionUnsupportedFormat(let format):
            return "Unsupported file format for transcription: \(format)"
            
        // Analysis Errors
        case .analysisServiceUnavailable:
            return "Analysis service is currently unavailable."
        case .analysisInvalidInput(let reason):
            return "Invalid input for analysis: \(reason)"
        case .analysisProcessingFailed(let reason):
            return "Analysis processing failed: \(reason)"
        case .analysisTimeout:
            return "Analysis timed out. Please try again."
        case .analysisModelUnavailable(let model):
            return "Analysis model unavailable: \(model)"
        case .analysisInsufficientContent:
            return "Insufficient content for meaningful analysis."
        case .analysisQuotaExceeded:
            return "Analysis quota exceeded. Please try again later."
            
        // Storage Errors
        case .storagePermissionDenied:
            return "Storage permission is required to save recordings."
        case .storageSpaceInsufficient:
            return "Insufficient storage space available."
        case .storageFileNotFound(let filename):
            return "File not found: \(filename)"
        case .storageCorruptedData(let details):
            return "Corrupted data detected: \(details)"
        case .storageWriteFailed(let reason):
            return "Failed to save file: \(reason)"
        case .storageReadFailed(let reason):
            return "Failed to read file: \(reason)"
        case .storageDeleteFailed(let reason):
            return "Failed to delete file: \(reason)"
            
        // Network Errors
        case .networkUnavailable:
            return "Network connection unavailable. Please check your internet connection."
        case .networkTimeout:
            return "Network request timed out. Please try again."
        case .networkServerError(let code, let message):
            return "Server error (\(code))" + (message != nil ? ": \(message!)" : "")
        case .networkInvalidResponse:
            return "Received invalid response from server."
        case .networkBadRequest(let reason):
            return "Bad request: \(reason)"
        case .networkUnauthorized:
            return "Unauthorized access. Please check your credentials."
        case .networkForbidden:
            return "Access forbidden. You don't have permission to perform this action."
        case .networkRateLimited:
            return "Too many requests. Please wait and try again."
            
        // Configuration Errors
        case .configurationMissing(let key):
            return "Missing configuration: \(key)"
        case .configurationInvalid(let key):
            return "Invalid configuration: \(key)"
        case .apiKeyMissing:
            return "API key is missing. Please configure your API key in settings."
        case .apiKeyInvalid:
            return "Invalid API key. Please check your API key in settings."
        case .endpointUnavailable(let endpoint):
            return "Service endpoint unavailable: \(endpoint)"
            
        // Data Errors
        case .dataCorrupted(let details):
            return "Data corruption detected: \(details)"
        case .dataFormatInvalid(let format):
            return "Invalid data format: \(format)"
        case .dataDecodingFailed(let reason):
            return "Failed to decode data: \(reason)"
        case .dataEncodingFailed(let reason):
            return "Failed to encode data: \(reason)"
        case .dataMigrationFailed(let reason):
            return "Data migration failed: \(reason)"
            
        // User Interface Errors
        case .uiStateInconsistent(let details):
            return "Inconsistent UI state: \(details)"
        case .uiOperationCancelled:
            return "Operation was cancelled by user."
        case .uiFeatureUnavailable(let feature):
            return "Feature unavailable: \(feature)"
            
        // System Errors
        case .systemMemoryLow:
            return "System memory is low. Please close other apps and try again."
        case .systemDiskFull:
            return "Device storage is full. Please free up space and try again."
        case .systemResourceUnavailable(let resource):
            return "System resource unavailable: \(resource)"
        case .systemVersionUnsupported(let version):
            return "Unsupported system version: \(version)"
            
        // Unknown Errors
        case .unknown(let reason):
            return "An unknown error occurred: \(reason)"
        }
    }
    
    public var failureReason: String? {
        switch self {
        case .audioPermissionDenied:
            return "Microphone access has been denied."
        case .transcriptionServiceUnavailable:
            return "The transcription service is temporarily offline."
        case .networkUnavailable:
            return "No internet connection is available."
        case .storageSpaceInsufficient:
            return "Device storage is full."
        case .systemMemoryLow:
            return "Available memory is insufficient."
        default:
            return nil
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .audioPermissionDenied:
            return "Go to Settings > Privacy & Security > Microphone and enable access for Sonora."
        case .transcriptionServiceUnavailable, .analysisServiceUnavailable:
            return "Please try again in a few minutes. If the problem persists, contact support."
        case .networkUnavailable, .networkTimeout:
            return "Check your internet connection and try again."
        case .storageSpaceInsufficient, .systemDiskFull:
            return "Free up storage space by deleting unused files or apps."
        case .systemMemoryLow:
            return "Close other running apps to free up memory."
        case .transcriptionFileTooBig:
            return "Try recording shorter audio segments or compress the file."
        case .apiKeyMissing, .apiKeyInvalid:
            return "Configure a valid API key in the app settings."
        case .transcriptionQuotaExceeded, .analysisQuotaExceeded:
            return "Wait for your quota to reset or upgrade your plan."
        default:
            return "Please try again. If the problem persists, contact support."
        }
    }
    
    // MARK: - Error Categories
    
    /// Category of the error for grouping and handling
    public var category: SonoraErrorCategory {
        switch self {
        case .audioPermissionDenied, .audioSessionSetupFailed, .audioRecordingFailed, .audioRecordingInterrupted, .audioFileNotFound, .audioFileCorrupted, .audioFormatUnsupported, .audioFileProcessingFailed:
            return .audio
        case .transcriptionServiceUnavailable, .transcriptionFailed, .transcriptionTimeout, .transcriptionInvalidResponse, .transcriptionQuotaExceeded, .transcriptionFileTooBig, .transcriptionUnsupportedFormat:
            return .transcription
        case .analysisServiceUnavailable, .analysisInvalidInput, .analysisProcessingFailed, .analysisTimeout, .analysisModelUnavailable, .analysisInsufficientContent, .analysisQuotaExceeded:
            return .analysis
        case .storagePermissionDenied, .storageSpaceInsufficient, .storageFileNotFound, .storageCorruptedData, .storageWriteFailed, .storageReadFailed, .storageDeleteFailed:
            return .storage
        case .networkUnavailable, .networkTimeout, .networkServerError, .networkInvalidResponse, .networkBadRequest, .networkUnauthorized, .networkForbidden, .networkRateLimited:
            return .network
        case .configurationMissing, .configurationInvalid, .apiKeyMissing, .apiKeyInvalid, .endpointUnavailable:
            return .configuration
        case .dataCorrupted, .dataFormatInvalid, .dataDecodingFailed, .dataEncodingFailed, .dataMigrationFailed:
            return .data
        case .uiStateInconsistent, .uiOperationCancelled, .uiFeatureUnavailable:
            return .userInterface
        case .systemMemoryLow, .systemDiskFull, .systemResourceUnavailable, .systemVersionUnsupported:
            return .system
        case .unknown:
            return .unknown
        }
    }
    
    /// Whether this error is recoverable by retrying
    public var isRetryable: Bool {
        switch self {
        case .networkTimeout, .networkServerError, .transcriptionTimeout, .analysisTimeout, .transcriptionServiceUnavailable, .analysisServiceUnavailable:
            return true
        case .networkUnavailable, .storageSpaceInsufficient, .systemMemoryLow, .systemDiskFull:
            return false // Require user action
        case .audioPermissionDenied, .storagePermissionDenied, .apiKeyMissing, .apiKeyInvalid:
            return false // Require user configuration
        default:
            return false
        }
    }
    
    /// Severity level of the error
    public var severity: SonoraErrorSeverity {
        switch self {
        case .uiOperationCancelled:
            return .info
        case .transcriptionTimeout, .analysisTimeout, .networkTimeout:
            return .warning
        case .audioPermissionDenied, .storagePermissionDenied, .apiKeyMissing, .networkUnavailable:
            return .error
        case .systemMemoryLow, .systemDiskFull, .dataCorrupted:
            return .critical
        default:
            return .error
        }
    }
}

// MARK: - Supporting Types

/// Categories for grouping errors
public enum SonoraErrorCategory: String, CaseIterable {
    case audio
    case transcription
    case analysis
    case storage
    case network
    case configuration
    case data
    case userInterface
    case system
    case unknown
    
    public var displayName: String {
        switch self {
        case .audio: return "Audio"
        case .transcription: return "Transcription"
        case .analysis: return "Analysis"
        case .storage: return "Storage"
        case .network: return "Network"
        case .configuration: return "Configuration"
        case .data: return "Data"
        case .userInterface: return "User Interface"
        case .system: return "System"
        case .unknown: return "Unknown"
        }
    }
    
    public var iconName: String {
        switch self {
        case .audio: return "waveform"
        case .transcription: return "text.quote"
        case .analysis: return "magnifyingglass"
        case .storage: return "folder"
        case .network: return "network"
        case .configuration: return "gear"
        case .data: return "doc.text"
        case .userInterface: return "rectangle.on.rectangle"
        case .system: return "desktopcomputer"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Severity levels for errors
public enum SonoraErrorSeverity: String, CaseIterable, Comparable {
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
    
    public static func < (lhs: SonoraErrorSeverity, rhs: SonoraErrorSeverity) -> Bool {
        let order: [SonoraErrorSeverity] = [.info, .warning, .error, .critical]
        guard let lhsIndex = order.firstIndex(of: lhs),
              let rhsIndex = order.firstIndex(of: rhs) else {
            return false
        }
        return lhsIndex < rhsIndex
    }
}
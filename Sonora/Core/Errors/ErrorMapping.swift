import Foundation
import AVFoundation
import Network

/// Utilities for mapping common iOS system errors to Sonora error types
public final class ErrorMapping {
    
    // MARK: - Main Error Mapping Function
    
    /// Maps any error to the appropriate Sonora error type
    public static func mapError(_ error: Error) -> SonoraError {
        // Handle already mapped errors
        if let sonoraError = error as? SonoraError {
            return sonoraError
        }
        
        if let repositoryError = error as? RepositoryError {
            return repositoryError.asSonoraError
        }
        
        if let serviceError = error as? ServiceError {
            return serviceError.asSonoraError
        }
        
        // Handle NSError cases
        if let nsError = error as NSError? {
            return mapNSError(nsError)
        }
        
        // Handle known Swift error types
        if let urlError = error as? URLError {
            return mapURLError(urlError)
        }
        
        if let decodingError = error as? DecodingError {
            return mapDecodingError(decodingError)
        }
        
        if let encodingError = error as? EncodingError {
            return mapEncodingError(encodingError)
        }
        
        // Handle TranscriptionError specifically
        if let transcriptionError = error as? TranscriptionError {
            return mapTranscriptionError(transcriptionError)
        }

        // WhisperKit integration errors
        if let wkError = error as? WhisperKitTranscriptionError {
            return mapWhisperKitError(wkError)
        }
        if let dlError = error as? ModelDownloadError {
            return mapModelDownloadError(dlError)
        }
        
        // Fallback for unknown errors (apply simple heuristics)
        let message = error.localizedDescription
        if message.lowercased().contains("no speech detected") {
            return .transcriptionFailed("No speech detected")
        }
        if message.contains("Analysis service error") && message.contains("timed out") {
            return .analysisTimeout
        }
        return .unknown(message)
    }
    
    // MARK: - NSError Mapping
    
    private static func mapNSError(_ nsError: NSError) -> SonoraError {
        switch nsError.domain {
        case NSCocoaErrorDomain:
            return mapCocoaError(nsError)
        case NSURLErrorDomain:
            return mapURLError(nsError)
        case "com.apple.avfaudio":
            return mapAudioSessionError(nsError)
        case NSOSStatusErrorDomain:
            return mapOSStatusError(nsError)
        case NSPOSIXErrorDomain:
            return mapPOSIXError(nsError)
        case "kCFErrorDomainCFNetwork":
            return mapCFNetworkError(nsError)
        default:
            // Heuristic: common ASR engines report "No speech detected" in various domains
            let message = nsError.localizedDescription
            if message.lowercased().contains("no speech detected") {
                return .transcriptionFailed("No speech detected")
            }
            if message.contains("Analysis service error") && message.contains("timed out") {
                return .analysisTimeout
            }
            return .unknown("System error: \(message)")
        }
    }
    
    // MARK: - Specific Error Domain Mappings
    
    private static func mapCocoaError(_ error: NSError) -> SonoraError {
        switch error.code {
        case NSFileReadNoSuchFileError:
            return .storageFileNotFound(error.userInfo[NSFilePathErrorKey] as? String ?? "Unknown file")
        case NSFileReadNoPermissionError:
            return .storagePermissionDenied
        case NSFileWriteNoPermissionError:
            return .storagePermissionDenied
        case NSFileWriteFileExistsError:
            return .storageWriteFailed("File already exists")
        case NSFileWriteVolumeReadOnlyError:
            return .storageWriteFailed("Volume is read-only")
        case NSFileWriteOutOfSpaceError:
            return .storageSpaceInsufficient
        case NSFileReadCorruptFileError:
            return .storageCorruptedData("File is corrupted")
        case NSPropertyListReadCorruptError:
            return .dataCorrupted("Property list is corrupted")
        case NSPropertyListWriteInvalidError:
            return .dataEncodingFailed("Invalid property list data")
        case NSExecutableNotLoadableError:
            return .systemResourceUnavailable("Executable not loadable")
        case NSUserCancelledError:
            return .uiOperationCancelled
        default:
            return .unknown("Cocoa error: \(error.localizedDescription)")
        }
    }
    
    private static func mapURLError(_ error: Error) -> SonoraError {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return .networkUnavailable
            case .timedOut:
                return .networkTimeout
            case .cannotFindHost, .dnsLookupFailed:
                return .networkServerError(0, "DNS lookup failed")
            case .serverCertificateUntrusted, .clientCertificateRejected:
                return .networkServerError(0, "Certificate error")
            case .badURL:
                return .networkBadRequest("Invalid URL")
            case .httpTooManyRedirects:
                return .networkServerError(0, "Too many redirects")
            case .userCancelledAuthentication:
                return .networkUnauthorized
            case .noPermissionsToReadFile:
                return .storagePermissionDenied
            case .cannotCreateFile:
                return .storageWriteFailed("Cannot create file")
            case .cannotWriteToFile:
                return .storageWriteFailed("Cannot write to file")
            case .fileDoesNotExist:
                return .storageFileNotFound("File does not exist")
            case .dataNotAllowed:
                return .networkBadRequest("Data not allowed")
            default:
                return .networkServerError(0, urlError.localizedDescription)
            }
        } else if let nsError = error as NSError? {
            return mapURLError(nsError)
        }
        
        return .networkServerError(0, error.localizedDescription)
    }
    
    private static func mapURLError(_ nsError: NSError) -> SonoraError {
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet, NSURLErrorNetworkConnectionLost:
            return .networkUnavailable
        case NSURLErrorTimedOut:
            return .networkTimeout
        case NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed:
            return .networkServerError(0, "DNS lookup failed")
        case NSURLErrorServerCertificateUntrusted, NSURLErrorClientCertificateRejected:
            return .networkServerError(0, "Certificate error")
        case NSURLErrorBadURL:
            return .networkBadRequest("Invalid URL")
        case NSURLErrorHTTPTooManyRedirects:
            return .networkServerError(0, "Too many redirects")
        case NSURLErrorUserCancelledAuthentication:
            return .networkUnauthorized
        default:
            return .networkServerError(0, nsError.localizedDescription)
        }
    }
    
    private static func mapAudioSessionError(_ error: NSError) -> SonoraError {
        switch error.code {
        case 560030004: // cannotInterruptOthers
            return .audioSessionSetupFailed("Cannot interrupt other audio")
        case 560557106: // cannotStartPlaying
            return .audioSessionSetupFailed("Cannot start playing")
        case 560557109: // cannotStartRecording
            return .audioRecordingFailed("Cannot start recording")
        case 560030737: // sessionNotActive
            return .audioSessionSetupFailed("Session not active")
        case 560557105: // incompatibleCategory
            return .audioSessionSetupFailed("Incompatible category")
        case 560030966: // mediaServicesFailed
            return .audioSessionSetupFailed("Media services failed")
        case 560030963: // mediaServicesWereReset
            return .audioSessionSetupFailed("Media services were reset")
        case 560030305: // isBusy
            return .audioSessionSetupFailed("Audio session is busy")
        case 560030001: // insufficientPriority
            return .audioSessionSetupFailed("Insufficient priority")
        default:
            return .audioSessionSetupFailed("Audio session error: \(error.localizedDescription)")
        }
    }
    
    private static func mapOSStatusError(_ error: NSError) -> SonoraError {
        switch Int32(error.code) {
        case -66681: // kAudioServicesUnsupportedPropertyError
            return .audioFormatUnsupported("Unsupported audio property")
        case -66682: // kAudioServicesBadPropertySizeError
            return .audioRecordingFailed("Bad audio property size")
        case -66683: // kAudioServicesSystemSoundUnspecifiedError
            return .audioRecordingFailed("Unspecified audio system error")
        case -66684: // kAudioServicesSystemSoundClientTimedOutError
            return .audioRecordingFailed("Audio system timed out")
        case -25293: // errSecAuthFailed
            return .networkUnauthorized
        case -128: // errSecUserCanceled
            return .uiOperationCancelled
        case -25291: // errSecNotAvailable
            return .systemResourceUnavailable("Security service not available")
        default:
            return .unknown("OS Status error: \(error.code)")
        }
    }
    
    private static func mapPOSIXError(_ error: NSError) -> SonoraError {
        switch Int32(error.code) {
        case Int32(ENOENT): // No such file or directory
            return .storageFileNotFound("File not found")
        case Int32(EACCES): // Permission denied
            return .storagePermissionDenied
        case Int32(ENOSPC): // No space left on device
            return .storageSpaceInsufficient
        case Int32(EROFS): // Read-only file system
            return .storageWriteFailed("Read-only file system")
        case Int32(EEXIST): // File exists
            return .storageWriteFailed("File already exists")
        case Int32(EISDIR): // Is a directory
            return .storageWriteFailed("Target is a directory")
        case Int32(ENOTDIR): // Not a directory
            return .storageReadFailed("Path is not a directory")
        case Int32(ENOMEM): // Cannot allocate memory
            return .systemMemoryLow
        case Int32(EINVAL): // Invalid argument
            return .dataFormatInvalid("Invalid argument")
        case Int32(EIO): // Input/output error
            return .storageCorruptedData("I/O error")
        case Int32(EBUSY): // Device or resource busy
            return .systemResourceUnavailable("Resource busy")
        case Int32(ETIMEDOUT): // Operation timed out
            return .networkTimeout
        case Int32(ECONNREFUSED): // Connection refused
            return .networkServerError(0, "Connection refused")
        case Int32(EHOSTUNREACH): // No route to host
            return .networkUnavailable
        case Int32(ENETUNREACH): // Network is unreachable
            return .networkUnavailable
        default:
            return .unknown("POSIX error: \(error.code)")
        }
    }
    
    private static func mapCFNetworkError(_ error: NSError) -> SonoraError {
        switch error.code {
        case 1: // Host not found
            return .networkServerError(0, "Host not found")
        case 2: // DNS service failure
            return .networkServerError(0, "DNS service failure")
        case 3: // Timeout
            return .networkTimeout
        case 100: // SOCKS error
            return .networkServerError(0, "SOCKS error")
        case 301: // HTTP parse failure
            return .networkInvalidResponse
        case 302: // HTTP redirection loop
            return .networkServerError(0, "Redirection loop")
        case 303: // Bad URL
            return .networkBadRequest("Bad URL")
        default:
            return .networkServerError(0, "CFNetwork error: \(error.code)")
        }
    }
    
    private static func mapDecodingError(_ error: DecodingError) -> SonoraError {
        switch error {
        case .typeMismatch(let type, let context):
            return .dataDecodingFailed("Type mismatch for \(type) at \(context.codingPath)")
        case .valueNotFound(let type, let context):
            return .dataDecodingFailed("Value not found for \(type) at \(context.codingPath)")
        case .keyNotFound(let key, let context):
            return .dataDecodingFailed("Key '\(key.stringValue)' not found at \(context.codingPath)")
        case .dataCorrupted(let context):
            return .dataCorrupted("Data corrupted at \(context.codingPath): \(context.debugDescription)")
        @unknown default:
            return .dataDecodingFailed("Unknown decoding error")
        }
    }
    
    private static func mapEncodingError(_ error: EncodingError) -> SonoraError {
        switch error {
        case .invalidValue(let value, let context):
            return .dataEncodingFailed("Invalid value '\(value)' at \(context.codingPath)")
        @unknown default:
            return .dataEncodingFailed("Unknown encoding error")
        }
    }
    
    // MARK: - HTTP Status Code Mapping
    
    /// Maps HTTP status codes to appropriate SonoraError cases
    public static func mapHTTPStatusCode(_ statusCode: Int, data: Data? = nil) -> SonoraError {
        let message = data.flatMap { String(data: $0, encoding: .utf8) }
        
        switch statusCode {
        case 200...299:
            return .networkInvalidResponse // Success codes shouldn't be mapped to errors
        case 400:
            return .networkBadRequest(message ?? "Bad request")
        case 401:
            return .networkUnauthorized
        case 403:
            return .networkForbidden
        case 404:
            return .networkServerError(statusCode, "Resource not found")
        case 408:
            return .networkTimeout
        case 409:
            return .networkServerError(statusCode, "Conflict")
        case 413:
            return .transcriptionFileTooBig(0) // Size unknown
        case 429:
            return .networkRateLimited
        case 500...599:
            return .networkServerError(statusCode, message ?? "Server error")
        default:
            return .networkServerError(statusCode, message ?? "HTTP error")
        }
    }
    
    // MARK: - AVFoundation Error Mapping
    
    /// Maps AVFoundation specific errors
    public static func mapAVFoundationError(_ error: Error) -> SonoraError {
        if let nsError = error as NSError? {
            switch nsError.domain {
            case "AVFoundationErrorDomain":
                return mapAVFoundationDomainError(nsError)
            case "com.apple.avfaudio":
                return mapAudioSessionError(nsError)
            default:
                return mapError(error)
            }
        }
        return mapError(error)
    }
    
    private static func mapAVFoundationDomainError(_ error: NSError) -> SonoraError {
        switch error.code {
        case AVError.fileFailedToParse.rawValue:
            return .audioFileCorrupted("Failed to parse audio file")
        case AVError.fileFormatNotRecognized.rawValue:
            return .audioFormatUnsupported("Format not recognized")
        case AVError.invalidSourceMedia.rawValue:
            return .audioFileCorrupted("Invalid source media")
        case AVError.mediaServicesWereReset.rawValue:
            return .audioSessionSetupFailed("Media services were reset")
        case AVError.mediaChanged.rawValue:
            return .audioRecordingInterrupted
        case AVError.noDataCaptured.rawValue:
            return .audioRecordingFailed("No data captured")
        case AVError.sessionNotRunning.rawValue:
            return .audioSessionSetupFailed("Session not running")
        // Deprecated in iOS 9.0: AVError.deviceIsNotAvailableInBackground no longer produced
        case AVError.sessionConfigurationChanged.rawValue:
            return .audioSessionSetupFailed("Session configuration changed")
        case AVError.diskFull.rawValue:
            return .storageSpaceInsufficient
        case AVError.deviceWasDisconnected.rawValue:
            return .audioRecordingFailed("Audio device disconnected")
        case AVError.recordingAlreadyInProgress.rawValue:
            return .audioRecordingFailed("Recording already in progress")
        default:
            return .audioRecordingFailed("AVFoundation error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Network Framework Error Mapping
    
    /// Maps Network framework errors (iOS 12+)
    @available(iOS 12.0, *)
    public static func mapNetworkError(_ error: Error) -> SonoraError {
        // Simple fallback to avoid complex NWError handling
        return ErrorMapping.mapError(error)
    }
    
    // MARK: - Core Data Error Mapping (if needed in future)
    
    /// Maps Core Data errors (for future use)
    public static func mapCoreDataError(_ error: Error) -> SonoraError {
        // Simplified Core Data error mapping to avoid missing constants
        if let nsError = error as NSError? {
            switch nsError.domain {
            case "NSCocoaErrorDomain":
                if nsError.code >= 1550 && nsError.code <= 1690 { // Core Data validation errors
                    return .dataFormatInvalid("Core Data validation failed: \(nsError.localizedDescription)")
                } else if nsError.code >= 130000 && nsError.code <= 135000 { // Core Data migration errors
                    return .dataMigrationFailed("Core Data migration failed: \(nsError.localizedDescription)")
                } else {
                    return .dataCorrupted("Core Data error: \(nsError.localizedDescription)")
                }
            default:
                return .unknown("Core Data error: \(nsError.localizedDescription)")
            }
        }
        return .unknown("Core Data error: \(error.localizedDescription)")
    }
    
    // MARK: - TranscriptionError Mapping
    
    /// Maps TranscriptionError to appropriate SonoraError cases
    private static func mapTranscriptionError(_ error: TranscriptionError) -> SonoraError {
        switch error {
        case .alreadyInProgress:
            return .transcriptionFailed("Transcription is already in progress")
        case .alreadyCompleted:
            return .transcriptionFailed("Transcription has already been completed")
        case .invalidState:
            return .transcriptionFailed("Invalid transcription state")
        case .fileNotFound:
            return .audioFileNotFound("Audio file could not be found")
        case .invalidAudioFormat:
            return .audioFormatUnsupported("Audio format is not supported for transcription")
        case .networkError(let message):
            return .networkServerError(0, message)
        case .serviceUnavailable:
            return .transcriptionServiceUnavailable
        case .conflictingOperation:
            return .transcriptionFailed("Cannot transcribe while recording")
        case .systemBusy:
            return .transcriptionServiceUnavailable
        case .noSpeechDetected:
            return .transcriptionFailed("No speech detected")
        case .transcriptionFailed(let reason):
            return .transcriptionFailed(reason)
        }
    }

    // MARK: - WhisperKit Error Mapping
    private static func mapWhisperKitError(_ error: WhisperKitTranscriptionError) -> SonoraError {
        switch error {
        case .notInitialized:
            return .transcriptionServiceUnavailable
        case .initializationFailed:
            return .transcriptionServiceUnavailable
        case .modelNotAvailable(let message):
            return .configurationInvalid(message)
        case .transcriptionFailed(let message):
            return .transcriptionFailed(message)
        case .audioProcessingFailed(let message):
            return .audioFileProcessingFailed(message)
        }
    }

    private static func mapModelDownloadError(_ error: ModelDownloadError) -> SonoraError {
        switch error {
        case .networkError(let message):
            return .networkServerError(0, message)
        case .storageError(let message):
            return .storageWriteFailed(message)
        case .modelNotFound(let model):
            return .configurationInvalid("Model not found: \(model)")
        case .cancelled:
            return .uiOperationCancelled
        }
    }
}

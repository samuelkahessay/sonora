import Foundation

/// Enumeration of available transcription services
enum TranscriptionServiceType: String, CaseIterable {
    case cloudAPI = "cloud_api"
    case localWhisperKit = "local_whisperkit"
    
    var displayName: String {
        switch self {
        case .cloudAPI: return "Cloud API"
        case .localWhisperKit: return "Local WhisperKit"
        }
    }
    
    var description: String {
        switch self {
        case .cloudAPI: return "Fast, accurate transcription using cloud services"
        case .localWhisperKit: return "Private, offline transcription using local AI models"
        }
    }
    
    var icon: String {
        switch self {
        case .cloudAPI: return "cloud.fill"
        case .localWhisperKit: return "brain.head.profile"
        }
    }
    
    /// Default service type
    static let `default`: TranscriptionServiceType = .cloudAPI
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    private static let transcriptionServiceKey = "selectedTranscriptionService"
    
    /// Currently selected transcription service
    var selectedTranscriptionService: TranscriptionServiceType {
        get {
            guard let rawValue = string(forKey: Self.transcriptionServiceKey),
                  let service = TranscriptionServiceType(rawValue: rawValue) else {
                return TranscriptionServiceType.default
            }
            return service
        }
        set {
            set(newValue.rawValue, forKey: Self.transcriptionServiceKey)
        }
    }
    
    /// Checks if the currently selected service is available for use
    @MainActor
    func isSelectedTranscriptionServiceAvailable(downloadManager: ModelDownloadManager) -> Bool {
        let selectedService = selectedTranscriptionService
        
        switch selectedService {
        case .cloudAPI:
            // Cloud API is always available (assuming network connectivity)
            return true
        case .localWhisperKit:
            // Local WhisperKit requires a downloaded model
            let selectedModel = selectedWhisperModelInfo
            return downloadManager.isModelAvailable(selectedModel.id)
        }
    }
    
    /// Gets the effective transcription service (falls back to cloud if local is unavailable)
    @MainActor
    func getEffectiveTranscriptionService(downloadManager: ModelDownloadManager) -> TranscriptionServiceType {
        let selected = selectedTranscriptionService
        
        if isSelectedTranscriptionServiceAvailable(downloadManager: downloadManager) {
            return selected
        } else {
            // Fall back to cloud API if local service is selected but not available
            return .cloudAPI
        }
    }
}
import Foundation

/// Enumeration of available transcription services.
public enum TranscriptionServiceType: String, CaseIterable, Codable, Sendable {
    case cloudAPI = "cloud_api"
    
    var displayName: String {
        "Cloud API"
    }
    
    var description: String {
        "Fast, accurate transcription using cloud services"
    }
    
    var icon: String {
        "cloud.fill"
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
    
    /// Checks if the currently selected service is available for use.
    @MainActor
    func isSelectedTranscriptionServiceAvailable() -> Bool {
        true
    }
    
    /// Gets the effective transcription service (falls back to cloud if others were previously persisted).
    @MainActor
    func getEffectiveTranscriptionService() -> TranscriptionServiceType {
        .cloudAPI
    }
}

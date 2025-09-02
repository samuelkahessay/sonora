import Foundation

/// Where transcription work runs
enum TranscriptionProcessingType {
    case unknown
    case networkBased
    case localProcessing
}

/// Rough speed estimate for UI
enum TranscriptionSpeed {
    case veryFast
    case fast
    case medium
    case slow
}

/// Aggregated status for the active transcription service
struct TranscriptionServiceStatus {
    let serviceInfo: TranscriptionServiceInfo
    let modelDownloadState: ModelDownloadState
    let isReady: Bool
    let fallbackAvailable: Bool
}


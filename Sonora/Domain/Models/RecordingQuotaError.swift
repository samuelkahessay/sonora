import Foundation

/// Domain error for recording quota policy violations
public enum RecordingQuotaError: LocalizedError, Equatable, Sendable {
    /// Quota limit reached (remaining <= 0)
    case limitReached(remaining: TimeInterval)

    public var errorDescription: String? {
        switch self {
        case .limitReached:
            return "You’ve reached your monthly recording limit for cloud transcription."
        }
    }
}

import Foundation

/// Policy defining daily and per-session limits based on transcription service type
public struct RecordingQuotaPolicy: Sendable {
    public init() {}

    /// Daily limit in seconds for the given service type. `nil` means unlimited.
    public func dailyLimit(for service: TranscriptionServiceType) -> TimeInterval? {
        switch service {
        case .cloudAPI: return 600 // 10 minutes total per day
        }
    }

    /// Max session duration in seconds for the given service type. `nil` means unlimited.
    public func maxSessionDuration(for service: TranscriptionServiceType) -> TimeInterval? {
        // No per-session limit; enforcement is based on remaining daily quota
        return nil
    }
}

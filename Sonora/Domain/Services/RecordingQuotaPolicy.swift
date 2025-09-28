import Foundation

/// Policy defining daily and per-session limits based on transcription service type
public struct RecordingQuotaPolicy: Sendable {
    public init() {}

    /// Daily limit in seconds for the given service type. `nil` means unlimited.
    public func dailyLimit(for service: TranscriptionServiceType) -> TimeInterval? {
        // Daily limit removed; monthly quota enforcement is handled separately.
        return nil
    }

    /// Max session duration in seconds for the given service type. `nil` means unlimited.
    public func maxSessionDuration(for service: TranscriptionServiceType) -> TimeInterval? {
        // No per-session limit; enforcement is based on remaining daily quota
        return nil
    }
}

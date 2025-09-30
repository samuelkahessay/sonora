import Foundation

/// Defines monthly recording limits per transcription service.
/// Return `nil` to indicate no limit (e.g., Pro entitlement).
public protocol RecordingQuotaPolicyProtocol: Sendable {
    func monthlyLimit(for service: TranscriptionServiceType) -> TimeInterval?
}

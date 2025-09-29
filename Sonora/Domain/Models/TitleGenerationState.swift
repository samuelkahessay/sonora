import Foundation

public enum TitleGenerationFailureReason: String, CaseIterable, Codable, Hashable, Sendable {
    case network
    case timeout
    case server
    case validation
    case transcriptUnavailable
    case configuration
    case unknown

    init(jobReason: AutoTitleJob.FailureReason?) {
        guard let jobReason else {
            self = .unknown
            return
        }
        switch jobReason {
        case .network: self = .network
        case .timeout: self = .timeout
        case .server: self = .server
        case .validation: self = .validation
        case .transcriptUnavailable: self = .transcriptUnavailable
        case .configuration: self = .configuration
        case .unknown: self = .unknown
        }
    }

    public var displayName: String {
        switch self {
        case .network: return "Network error"
        case .timeout: return "Timed out"
        case .server: return "Server issue"
        case .validation: return "Validation issue"
        case .transcriptUnavailable: return "Transcript missing"
        case .configuration: return "Configuration issue"
        case .unknown: return "Unknown issue"
        }
    }
}

public enum TitleGenerationState: Equatable, Hashable, Sendable {
    case idle
    case inProgress
    case streaming(String)
    case success(String)
    case failed(reason: TitleGenerationFailureReason, message: String?)

    public var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }

    public var failureReason: TitleGenerationFailureReason? {
        if case .failed(let reason, _) = self { return reason }
        return nil
    }

    public var failureMessage: String? {
        if case .failed(_, let message) = self { return message }
        return nil
    }
}

extension TitleGenerationState {
    init(job: AutoTitleJob) {
        switch job.status {
        case .queued, .processing:
            self = .inProgress
        case .failed:
            self = .failed(
                reason: TitleGenerationFailureReason(jobReason: job.failureReason),
                message: job.lastError
            )
        }
    }
}

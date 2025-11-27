import Foundation

public enum DistillationFailureReason: String, CaseIterable, Codable, Hashable, Sendable {
    case network
    case timeout
    case server
    case validation
    case transcriptUnavailable
    case quotaExceeded
    case configuration
    case unknown

    init(jobReason: AutoDistillJob.FailureReason?) {
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
        case .quotaExceeded: self = .quotaExceeded
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
        case .quotaExceeded: return "Quota exceeded"
        case .configuration: return "Configuration issue"
        case .unknown: return "Unknown issue"
        }
    }
}

public enum DistillationState: Equatable, Sendable {
    case idle
    case inProgress
    case streaming(DistillProgressUpdate?)
    case success(AnalysisMode)
    case failed(reason: DistillationFailureReason, message: String?)

    public var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    public var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

extension DistillationState {
    init(job: AutoDistillJob) {
        switch job.status {
        case .queued, .processing:
            self = .inProgress
        case .failed:
            self = .failed(
                reason: DistillationFailureReason(jobReason: job.failureReason),
                message: job.lastError
            )
        }
    }
}

import Foundation

/// Aggregated view of the auto-title pipeline for cross-surface indicators.
public struct TitlePipelineMetrics: Equatable, Hashable, Sendable {
    public let inProgressCount: Int
    public let failedCount: Int
    public let lastFailureReason: TitleGenerationFailureReason?
    public let lastFailureMessage: String?
    public let lastUpdated: Date

    public init(
        inProgressCount: Int = 0,
        failedCount: Int = 0,
        lastFailureReason: TitleGenerationFailureReason? = nil,
        lastFailureMessage: String? = nil,
        lastUpdated: Date = Date()
    ) {
        self.inProgressCount = inProgressCount
        self.failedCount = failedCount
        self.lastFailureReason = lastFailureReason
        self.lastFailureMessage = lastFailureMessage
        self.lastUpdated = lastUpdated
    }

    public var hasInFlight: Bool { inProgressCount > 0 }
    public var hasFailures: Bool { failedCount > 0 }
}

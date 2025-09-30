import Foundation

public struct AutoTitleJob: Identifiable, Equatable, Sendable {
    public enum Status: String, Codable, CaseIterable, Sendable {
        case queued
        case processing
        case failed
    }

    public enum FailureReason: String, Codable, CaseIterable, Sendable {
        case network
        case timeout
        case server
        case validation
        case transcriptUnavailable
        case configuration
        case unknown
    }

    public let memoId: UUID
    public let status: Status
    public let createdAt: Date
    public let updatedAt: Date
    public let retryCount: Int
    public let lastError: String?
    public let nextRetryAt: Date?
    public let failureReason: FailureReason?

    public init(
        memoId: UUID,
        status: Status,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil,
        nextRetryAt: Date? = nil,
        failureReason: FailureReason? = nil
    ) {
        self.memoId = memoId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.retryCount = retryCount
        self.lastError = lastError
        self.nextRetryAt = nextRetryAt
        self.failureReason = failureReason
    }

    public var id: UUID { memoId }

    public func updating(
        status: Status? = nil,
        updatedAt: Date = Date(),
        retryCount: Int? = nil,
        lastError: String? = nil,
        nextRetryAt: Date?? = nil,
        failureReason: FailureReason?? = nil
    ) -> Self {
        Self(
            memoId: memoId,
            status: status ?? self.status,
            createdAt: createdAt,
            updatedAt: updatedAt,
            retryCount: retryCount ?? self.retryCount,
            lastError: lastError,
            nextRetryAt: nextRetryAt ?? self.nextRetryAt,
            failureReason: failureReason ?? self.failureReason
        )
    }
}

import Foundation

@MainActor
public protocol GetRemainingMonthlyQuotaUseCaseProtocol {
    /// Returns remaining monthly quota in seconds for the current month.
    /// Returns TimeInterval.infinity for Pro users (no limit).
    func execute() async throws -> TimeInterval
}

@MainActor
public final class GetRemainingMonthlyQuotaUseCase: GetRemainingMonthlyQuotaUseCaseProtocol {
    private let quotaPolicy: any RecordingQuotaPolicyProtocol
    private let usageRepository: any RecordingUsageRepository
    private let calendar: Calendar

    public init(
        quotaPolicy: any RecordingQuotaPolicyProtocol,
        usageRepository: any RecordingUsageRepository,
        calendar: Calendar = .current
    ) {
        self.quotaPolicy = quotaPolicy
        self.usageRepository = usageRepository
        self.calendar = calendar
    }

    public func execute() async throws -> TimeInterval {
        // Determine monthly limit for the active service (cloud API for free tier)
        let monthlyLimit = quotaPolicy.monthlyLimit(for: .cloudAPI)
        guard let limit = monthlyLimit else {
            // Pro user: unlimited
            return .infinity
        }

        let now = Date()
        guard let interval = calendar.dateInterval(of: .month, for: now) else {
            // Fallback: if calendar fails, treat as no remaining to be safe
            return 0
        }
        let monthStart = interval.start
        let monthUsage = await usageRepository.monthToDateUsage(for: monthStart)
        return max(0, limit - monthUsage)
    }
}

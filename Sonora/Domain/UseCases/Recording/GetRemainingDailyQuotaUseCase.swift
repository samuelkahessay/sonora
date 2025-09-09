import Foundation

@MainActor
public protocol GetRemainingDailyQuotaUseCaseProtocol {
    /// Returns remaining daily quota in seconds for the given service; nil if unlimited.
    func execute(service: TranscriptionServiceType) async -> TimeInterval?
}

@MainActor
public final class GetRemainingDailyQuotaUseCase: GetRemainingDailyQuotaUseCaseProtocol {
    private let usageRepository: any RecordingUsageRepository
    private let policy: RecordingQuotaPolicy
    private let calendar: Calendar

    public init(
        usageRepository: any RecordingUsageRepository,
        policy: RecordingQuotaPolicy = RecordingQuotaPolicy(),
        calendar: Calendar = .current
    ) {
        self.usageRepository = usageRepository
        self.policy = policy
        self.calendar = calendar
    }

    public func execute(service: TranscriptionServiceType) async -> TimeInterval? {
        guard let limit = policy.dailyLimit(for: service) else { return nil }
        let today = calendar.startOfDay(for: Date())
        let used = await usageRepository.usage(for: today)
        let remaining = max(0, limit - used)
        return remaining
    }
}


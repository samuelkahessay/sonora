import Foundation

@MainActor
public protocol ResetDailyUsageIfNeededUseCaseProtocol {
    /// Ensures today’s usage publisher reflects the current day (resets in-memory day if needed).
    func execute(now: Date) async
}

@MainActor
public final class ResetDailyUsageIfNeededUseCase: ResetDailyUsageIfNeededUseCaseProtocol {
    private let usageRepository: any RecordingUsageRepository

    public init(usageRepository: any RecordingUsageRepository) {
        self.usageRepository = usageRepository
    }

    public func execute(now: Date) async {
        await usageRepository.resetIfDayChanged(now: now)
    }
}

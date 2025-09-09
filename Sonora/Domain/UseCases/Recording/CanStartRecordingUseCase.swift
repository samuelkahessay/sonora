import Foundation

@MainActor
public protocol CanStartRecordingUseCaseProtocol {
    /// Returns allowed session duration (seconds) for the next recording if permitted.
    /// For unlimited services, returns nil. Throws RecordingQuotaError if not allowed.
    func execute(service: TranscriptionServiceType) async throws -> TimeInterval?
}

@MainActor
public final class CanStartRecordingUseCase: CanStartRecordingUseCaseProtocol {
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

    public func execute(service: TranscriptionServiceType) async throws -> TimeInterval? {
        // Unlimited for local
        guard let dailyLimit = policy.dailyLimit(for: service) else { return nil }

        let today = calendar.startOfDay(for: Date())
        let used = await usageRepository.usage(for: today)
        let remaining = max(0, dailyLimit - used)

        guard remaining > 0 else { throw RecordingQuotaError.limitReached(remaining: 0) }

        // No per-session cap; allow up to remaining daily time
        return remaining
    }
}

import Foundation

@MainActor
public protocol ConsumeRecordingUsageUseCaseProtocol {
    /// Consumes elapsed seconds of recording for today for the given service (no-op for unlimited services).
    func execute(elapsed: TimeInterval, service: TranscriptionServiceType) async
}

@MainActor
public final class ConsumeRecordingUsageUseCase: ConsumeRecordingUsageUseCaseProtocol {
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

    public func execute(elapsed: TimeInterval, service: TranscriptionServiceType) async {
        // Only cloud usage is tracked
        guard policy.dailyLimit(for: service) != nil else { return }
        let today = calendar.startOfDay(for: Date())
        let clamped = max(0, elapsed)
        await usageRepository.addUsage(clamped, for: today)
    }
}


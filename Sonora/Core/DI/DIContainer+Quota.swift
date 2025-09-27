import Foundation

// MARK: - Quota Use Case Factories

extension DIContainer {
    @MainActor
    func getRemainingDailyQuotaUseCase() -> any GetRemainingDailyQuotaUseCaseProtocol {
        let repo = recordingUsageRepository()
        return GetRemainingDailyQuotaUseCase(usageRepository: repo)
    }

    @MainActor
    func canStartRecordingUseCase() -> any CanStartRecordingUseCaseProtocol {
        let monthlyUC = getRemainingMonthlyQuotaUseCase()
        return CanStartRecordingUseCase(getRemainingMonthlyQuotaUseCase: monthlyUC)
    }

    @MainActor
    func consumeRecordingUsageUseCase() -> any ConsumeRecordingUsageUseCaseProtocol {
        let repo = recordingUsageRepository()
        return ConsumeRecordingUsageUseCase(usageRepository: repo)
    }

    @MainActor
    func resetDailyUsageIfNeededUseCase() -> any ResetDailyUsageIfNeededUseCaseProtocol {
        let repo = recordingUsageRepository()
        return ResetDailyUsageIfNeededUseCase(usageRepository: repo)
    }
}

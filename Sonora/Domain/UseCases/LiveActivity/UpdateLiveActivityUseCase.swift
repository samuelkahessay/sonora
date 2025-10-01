import Foundation

protocol UpdateLiveActivityUseCaseProtocol: Sendable {
    func execute(duration: TimeInterval,
                 isCountdown: Bool,
                 remainingTime: TimeInterval?,
                 level: Double?,
                 peakLevel: Double?,
                 voiceActivity: Double?,
                 frequencyLow: Double?,
                 frequencyMid: Double?,
                 frequencyHigh: Double?) async throws
}

@MainActor
final class UpdateLiveActivityUseCase: UpdateLiveActivityUseCaseProtocol, @unchecked Sendable {
    private let liveActivityService: any LiveActivityServiceProtocol

    init(liveActivityService: any LiveActivityServiceProtocol) {
        self.liveActivityService = liveActivityService
    }

    func execute(duration: TimeInterval,
                 isCountdown: Bool,
                 remainingTime: TimeInterval?,
                 level: Double?,
                 peakLevel: Double? = nil,
                 voiceActivity: Double? = nil,
                 frequencyLow: Double? = nil,
                 frequencyMid: Double? = nil,
                 frequencyHigh: Double? = nil) async throws {
        try await liveActivityService.updateActivity(
            duration: duration,
            isCountdown: isCountdown,
            remainingTime: remainingTime,
            level: level,
            peakLevel: peakLevel,
            voiceActivity: voiceActivity,
            frequencyLow: frequencyLow,
            frequencyMid: frequencyMid,
            frequencyHigh: frequencyHigh
        )
    }
}

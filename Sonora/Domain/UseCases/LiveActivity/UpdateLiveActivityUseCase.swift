import Foundation

protocol UpdateLiveActivityUseCaseProtocol {
    func execute(duration: TimeInterval, isCountdown: Bool, remainingTime: TimeInterval?) async throws
}

final class UpdateLiveActivityUseCase: UpdateLiveActivityUseCaseProtocol {
    private let liveActivityService: any LiveActivityServiceProtocol
    
    init(liveActivityService: any LiveActivityServiceProtocol) {
        self.liveActivityService = liveActivityService
    }
    
    func execute(duration: TimeInterval, isCountdown: Bool, remainingTime: TimeInterval?) async throws {
        try await liveActivityService.updateActivity(duration: duration, isCountdown: isCountdown, remainingTime: remainingTime)
    }
}


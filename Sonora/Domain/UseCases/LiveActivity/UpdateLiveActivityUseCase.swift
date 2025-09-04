import Foundation

protocol UpdateLiveActivityUseCaseProtocol: Sendable {
    func execute(duration: TimeInterval, isCountdown: Bool, remainingTime: TimeInterval?) async throws
}

@MainActor
final class UpdateLiveActivityUseCase: UpdateLiveActivityUseCaseProtocol, @unchecked Sendable {
    private let liveActivityService: any LiveActivityServiceProtocol
    
    init(liveActivityService: any LiveActivityServiceProtocol) {
        self.liveActivityService = liveActivityService
    }
    
    func execute(duration: TimeInterval, isCountdown: Bool, remainingTime: TimeInterval?) async throws {
        try await liveActivityService.updateActivity(duration: duration, isCountdown: isCountdown, remainingTime: remainingTime)
    }
}


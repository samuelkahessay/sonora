import Foundation

protocol EndLiveActivityUseCaseProtocol {
    func execute(dismissalPolicy: ActivityDismissalPolicy) async throws
}

final class EndLiveActivityUseCase: EndLiveActivityUseCaseProtocol {
    private let liveActivityService: any LiveActivityServiceProtocol
    
    init(liveActivityService: any LiveActivityServiceProtocol) {
        self.liveActivityService = liveActivityService
    }
    
    func execute(dismissalPolicy: ActivityDismissalPolicy = .afterDelay(4.0)) async throws {
        try await liveActivityService.endCurrentActivity(dismissalPolicy: dismissalPolicy)
    }
}


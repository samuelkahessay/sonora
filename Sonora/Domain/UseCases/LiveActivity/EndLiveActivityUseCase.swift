import Foundation

protocol EndLiveActivityUseCaseProtocol: Sendable {
    func execute(dismissalPolicy: ActivityDismissalPolicy) async throws
}

@MainActor
final class EndLiveActivityUseCase: EndLiveActivityUseCaseProtocol, @unchecked Sendable {
    private let liveActivityService: any LiveActivityServiceProtocol

    init(liveActivityService: any LiveActivityServiceProtocol) {
        self.liveActivityService = liveActivityService
    }

    func execute(dismissalPolicy: ActivityDismissalPolicy = .afterDelay(4.0)) async throws {
        try await liveActivityService.endCurrentActivity(dismissalPolicy: dismissalPolicy)
    }
}

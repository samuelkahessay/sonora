import Foundation

protocol StartLiveActivityUseCaseProtocol: Sendable {
    func execute(memoTitle: String, startTime: Date) async throws
}

final class StartLiveActivityUseCase: StartLiveActivityUseCaseProtocol, @unchecked Sendable {
    private let liveActivityService: any LiveActivityServiceProtocol

    init(liveActivityService: any LiveActivityServiceProtocol) {
        self.liveActivityService = liveActivityService
    }

    func execute(memoTitle: String, startTime: Date) async throws {
        try await liveActivityService.startRecordingActivity(memoTitle: memoTitle, startTime: startTime)
    }
}

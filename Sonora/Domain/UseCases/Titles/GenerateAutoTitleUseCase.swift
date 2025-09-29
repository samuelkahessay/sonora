import Foundation

@MainActor
protocol GenerateAutoTitleUseCaseProtocol: Sendable {
    func execute(memoId: UUID, transcript: String) async
}

@MainActor
final class GenerateAutoTitleUseCase: GenerateAutoTitleUseCaseProtocol, @unchecked Sendable {
    private let memoRepository: any MemoRepository
    private let coordinator: TitleGenerationCoordinator
    private let logger: any LoggerProtocol

    init(
        memoRepository: any MemoRepository,
        coordinator: TitleGenerationCoordinator,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.memoRepository = memoRepository
        self.coordinator = coordinator
        self.logger = logger
    }

    func execute(memoId: UUID, transcript: String) async {
        guard let memo = memoRepository.getMemo(by: memoId) else { return }
        if let title = memo.customTitle, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return
        }

        logger.debug(
            "Queueing auto-title generation",
            category: .system,
            context: LogContext(additionalInfo: [
                "memoId": memoId.uuidString,
                "transcriptLength": "\(transcript.count)"
            ])
        )
        coordinator.enqueue(memoId: memoId)
    }
}

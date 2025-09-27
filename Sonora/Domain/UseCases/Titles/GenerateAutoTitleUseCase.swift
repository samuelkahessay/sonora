import Foundation

@MainActor
protocol GenerateAutoTitleUseCaseProtocol: Sendable {
    func execute(memoId: UUID, transcript: String) async
}

@MainActor
final class GenerateAutoTitleUseCase: GenerateAutoTitleUseCaseProtocol, @unchecked Sendable {
    private let titleService: any TitleServiceProtocol
    private let memoRepository: any MemoRepository
    private let transcriptionRepository: any TranscriptionRepository
    private let logger: any LoggerProtocol

    init(
        titleService: any TitleServiceProtocol,
        memoRepository: any MemoRepository,
        transcriptionRepository: any TranscriptionRepository,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.titleService = titleService
        self.memoRepository = memoRepository
        self.transcriptionRepository = transcriptionRepository
        self.logger = logger
    }

    func execute(memoId: UUID, transcript: String) async {
        // Check existing memo and title
        guard let memo = memoRepository.getMemo(by: memoId) else { return }
        if let t = memo.customTitle, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }

        // Build input slice: first ~1500 chars + last ~400 if long
        let slice = Self.slice(transcript: transcript)
        let languageHint = transcriptionRepository.getTranscriptionMetadata(for: memoId)?.detectedLanguage

        do {
            if let title = try await titleService.generateTitle(transcript: slice, languageHint: languageHint) {
                memoRepository.renameMemo(memo, newTitle: title)
                logger.info("Auto title set for memo: \(memoId)", category: .system, context: LogContext(additionalInfo: ["title": title]))
            }
        } catch {
            logger.debug("Auto title generation failed: \(error.localizedDescription)", category: .system, context: LogContext(additionalInfo: ["memoId": memoId.uuidString]))
        }
    }

    private static func slice(transcript: String) -> String {
        let maxFirst = 1500
        let maxLast = 400
        if transcript.count <= maxFirst { return transcript }
        let firstPart = String(transcript.prefix(maxFirst))
        let lastPart = String(transcript.suffix(maxLast))
        return firstPart + "\n\n" + lastPart
    }
}

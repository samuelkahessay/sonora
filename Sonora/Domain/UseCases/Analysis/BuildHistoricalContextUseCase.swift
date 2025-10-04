import Foundation

/// Use case for building lightweight historical context for pattern detection
/// Extracts recent memos with cached analysis results to enable cross-memo pattern analysis
protocol BuildHistoricalContextUseCaseProtocol: Sendable {
    func execute(currentMemoId: UUID) async -> [HistoricalMemoContext]
}

final class BuildHistoricalContextUseCase: BuildHistoricalContextUseCaseProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let memoRepository: any MemoRepository
    private let analysisRepository: any AnalysisRepository
    private let logger: any LoggerProtocol

    // MARK: - Configuration
    private let maxHistoricalMemos = 10
    private let maxDaysBack = 30

    // MARK: - Initialization
    init(
        memoRepository: any MemoRepository,
        analysisRepository: any AnalysisRepository,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.memoRepository = memoRepository
        self.analysisRepository = analysisRepository
        self.logger = logger
    }

    // MARK: - Use Case Execution
    @MainActor
    func execute(currentMemoId: UUID) async -> [HistoricalMemoContext] {
        let context = LogContext(additionalInfo: ["currentMemoId": currentMemoId.uuidString])

        logger.debug("Building historical context for pattern detection", category: .analysis, context: context)

        // Get all memos from repository
        let allMemos = memoRepository.memos

        // Filter to recent memos (last 30 days, exclude current)
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -maxDaysBack, to: Date()) ?? Date()
        let recentMemos = allMemos
            .filter { $0.id != currentMemoId } // Exclude current memo
            .filter { $0.creationDate >= cutoffDate } // Last 30 days
            .sorted { $0.creationDate > $1.creationDate } // Most recent first
            .prefix(maxHistoricalMemos) // Limit to 10

        logger.debug("Found \(recentMemos.count) recent memos for historical context", category: .analysis, context: context)

        // Build historical context for each memo
        var historicalContext: [HistoricalMemoContext] = []
        for memo in recentMemos {
            // Calculate days ago
            let daysAgo = Calendar.current.dateComponents([.day], from: memo.creationDate, to: Date()).day ?? 0

            // Try to get cached distill summary
            var summary: String?
            if let cachedDistill = analysisRepository.getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self) {
                summary = cachedDistill.data.summary
            } else if let cachedSummary = analysisRepository.getAnalysisResult(for: memo.id, mode: .distillSummary, responseType: DistillSummaryData.self) {
                summary = cachedSummary.data.summary
            }

            // Try to get cached themes
            var themes: [String]?
            if let cachedDistillThemes = analysisRepository.getAnalysisResult(for: memo.id, mode: .distillThemes, responseType: DistillThemesData.self) {
                themes = cachedDistillThemes.data.key_themes
            }

            // Only include memos with at least a summary or themes
            if summary != nil || themes != nil {
                let histContext = HistoricalMemoContext(
                    memoId: memo.id.uuidString,
                    title: memo.displayName,
                    daysAgo: daysAgo,
                    summary: summary,
                    themes: themes
                )
                historicalContext.append(histContext)
            }
        }

        logger.debug("Built historical context with \(historicalContext.count) memos (filtered from \(recentMemos.count) candidates)",
                    category: .analysis,
                    context: LogContext(additionalInfo: [
                        "currentMemoId": currentMemoId.uuidString,
                        "contextSize": historicalContext.count,
                        "totalCandidates": recentMemos.count
                    ]))

        return historicalContext
    }
}

import Foundation

/// Protocol for Lite Distill analysis (free tier)
/// Provides focused clarity with ONE personal insight via single API call
protocol AnalyzeLiteDistillUseCaseProtocol: Sendable {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<LiteDistillData>
}

/// Free-tier Lite Distill analysis use case
/// Single API call optimized for cost efficiency while delivering meaningful insights
/// Use case runs off main thread; repository operations automatically hop to main actor.
final class AnalyzeLiteDistillUseCase: AnalyzeLiteDistillUseCaseProtocol, Sendable {

    // MARK: - Dependencies
    private let analysisService: any AnalysisServiceProtocol
    private let analysisRepository: any AnalysisRepository
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol
    private let operationCoordinator: any OperationCoordinatorProtocol

    // MARK: - Initialization
    init(
        analysisService: any AnalysisServiceProtocol,
        analysisRepository: any AnalysisRepository,
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol,
        operationCoordinator: any OperationCoordinatorProtocol
    ) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
        self.logger = logger
        self.eventBus = eventBus
        self.operationCoordinator = operationCoordinator
    }

    // MARK: - Use Case Execution
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<LiteDistillData> {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: ["memoId": memoId.uuidString])

        logger.analysis("Starting Lite Distill analysis (free tier)", context: context)

        // Validate inputs early
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }

        // CACHE FIRST: Skip coordinator for cache hit
        if let cachedResult = await analysisRepository.getAnalysisResult(for: memoId, mode: .liteDistill, responseType: LiteDistillData.self) {
            logger.analysis("LiteDistill.CacheHit", level: .info, context: context)
            return cachedResult
        }

        // Register analysis operation
        guard let operationId = await operationCoordinator.registerOperation(.analysis(memoId: memoId, analysisType: .liteDistill)) else {
            logger.warning("Lite Distill analysis rejected by operation coordinator", category: .analysis, context: context, error: nil)
            throw AnalysisError.systemBusy
        }

        do {
            // Execute single API call for Lite Distill
            let requestContext = AnalysisRequestContext(correlationId: correlationId, memoId: memoId)
            let result = try await analysisService.analyzeLiteDistill(transcript: transcript, context: requestContext)

            // Save result to cache
            await analysisRepository.saveAnalysisResult(result, for: memoId, mode: .liteDistill)

            // Publish completion event
            await MainActor.run {
                eventBus.publish(.analysisCompleted(memoId: memoId, type: .liteDistill, result: result.data.summary))
            }

            await operationCoordinator.completeOperation(operationId)

            logger.analysis("Lite Distill analysis completed successfully", context: context)
            return result

        } catch {
            logger.error("Lite Distill analysis failed", category: .analysis, context: context, error: error)
            await operationCoordinator.failOperation(operationId, errorDescription: error.localizedDescription)
            throw error
        }
    }
}

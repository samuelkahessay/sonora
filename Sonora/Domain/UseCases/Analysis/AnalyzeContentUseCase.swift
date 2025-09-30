import Foundation

/// Use case for performing general content analysis on transcript with repository caching
/// Encapsulates the business logic for detailed content analysis with persistence
protocol AnalyzeContentUseCaseProtocol: Sendable {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<AnalysisData>
}

final class AnalyzeContentUseCase: AnalyzeContentUseCaseProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let analysisService: any AnalysisServiceProtocol
    private let analysisRepository: any AnalysisRepository
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol

    // MARK: - Initialization
    init(
        analysisService: any AnalysisServiceProtocol,
        analysisRepository: any AnalysisRepository,
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol
    ) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
        self.logger = logger
        self.eventBus = eventBus
    }

    // MARK: - Use Case Execution
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<AnalysisData> {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: ["memoId": memoId.uuidString])

        logger.analysis("Starting content analysis", context: context)

        // Validate inputs
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("Content analysis failed: empty transcript", category: .analysis, context: context, error: AnalysisError.emptyTranscript)
            throw AnalysisError.emptyTranscript
        }

        guard transcript.count >= 10 else {
            logger.error("Content analysis failed: transcript too short (\(transcript.count) chars)", category: .analysis, context: context, error: AnalysisError.transcriptTooShort)
            throw AnalysisError.transcriptTooShort
        }

        logger.debug("Transcript validated (\(transcript.count) characters)", category: .analysis, context: context)

        // CACHE FIRST: Check if analysis already exists
        let cacheTimer = PerformanceTimer(operation: "Content Analysis Cache Check", category: .performance)
        if let cachedResult = await MainActor.run(body: {
            analysisRepository.getAnalysisResult(for: memoId, mode: .analysis, responseType: AnalysisData.self)
        }) {
            _ = cacheTimer.finish(additionalInfo: "Cache HIT - returning immediately")
            logger.analysis("Found cached content analysis (cache hit)",
                          level: .info,
                          context: LogContext(correlationId: correlationId, additionalInfo: [
                              "memoId": memoId.uuidString,
                              "cacheHit": true,
                              "latencyMs": cachedResult.latency_ms
                          ]))
            return cachedResult
        }
        _ = cacheTimer.finish(additionalInfo: "Cache MISS - proceeding to API call")

        logger.analysis("No cached content analysis found, calling analysis service",
                      level: .warning,
                      context: LogContext(correlationId: correlationId, additionalInfo: ["cacheHit": false]))

        do {
            // Perform analysis (execute is not @MainActor)
            let analysisTimer = PerformanceTimer(operation: "Content Analysis API Call", category: .analysis)
            let result = try await analysisService.analyzeAnalysis(transcript: transcript)

            // Guardrails: validate structure before persisting
            guard AnalysisGuardrails.validate(analysis: result.data) else {
                logger.error("Content analysis validation failed — not persisting result", category: .analysis, context: context, error: nil)
                throw AnalysisError.invalidResponse
            }
            _ = analysisTimer.finish(additionalInfo: "Service call completed successfully")

            logger.analysis("Content analysis completed successfully",
                          context: LogContext(correlationId: correlationId, additionalInfo: [
                              "apiLatencyMs": result.latency_ms,
                              "summaryLength": result.data.summary.count,
                              "keyPointsCount": result.data.key_points.count,
                              "model": result.model
                          ]))

            // SAVE TO CACHE: Store result for future use
            let saveTimer = PerformanceTimer(operation: "Content Analysis Cache Save", category: .performance)
            await MainActor.run { analysisRepository.saveAnalysisResult(result, for: memoId, mode: .analysis) }
            _ = saveTimer.finish(additionalInfo: "Analysis cached successfully")

            logger.analysis("Content analysis cached successfully",
                          context: LogContext(correlationId: correlationId, additionalInfo: ["cached": true]))

            // Publish analysisCompleted event on main actor
            print("📡 AnalyzeContentUseCase: Publishing analysisCompleted event for memo \(memoId)")
            await MainActor.run { EventBus.shared.publish(.analysisCompleted(memoId: memoId, type: .analysis, result: result.data.summary)) }

            return result

        } catch {
            logger.error("Content analysis service call failed",
                       category: .analysis,
                       context: LogContext(correlationId: correlationId, additionalInfo: ["serviceError": error.localizedDescription]),
                       error: error)
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}

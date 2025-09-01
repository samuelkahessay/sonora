import Foundation

/// Use case for performing comprehensive Distill analysis on transcript with repository caching
/// Provides mentor-like insights including summary, action items, themes, and reflection questions
protocol AnalyzeDistillUseCaseProtocol {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<DistillData>
}

final class AnalyzeDistillUseCase: AnalyzeDistillUseCaseProtocol {
    
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
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<DistillData> {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: ["memoId": memoId.uuidString])
        
        logger.analysis("Starting Distill analysis (comprehensive mentor-like insights)", context: context)
        
        // Register analysis operation (analysis can run concurrently - no conflicts)
        guard let operationId = await operationCoordinator.registerOperation(.analysis(memoId: memoId, analysisType: .distill)) else {
            logger.warning("Distill analysis rejected by operation coordinator (system at capacity)", category: .analysis, context: context, error: nil)
            throw AnalysisError.systemBusy
        }
        
        logger.debug("Distill analysis operation registered with ID: \(operationId)", category: .analysis, context: context)
        
        do {
            // Validate inputs
            guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                await operationCoordinator.failOperation(operationId, error: AnalysisError.emptyTranscript)
                throw AnalysisError.emptyTranscript
            }
            
            guard transcript.count >= 10 else {
                await operationCoordinator.failOperation(operationId, error: AnalysisError.transcriptTooShort)
                throw AnalysisError.transcriptTooShort
            }
            
            logger.debug("Transcript validated (\(transcript.count) characters)", category: .analysis, context: context)
        
            // CACHE FIRST: Check if analysis already exists
            let cacheTimer = PerformanceTimer(operation: "Distill Cache Check", category: .performance)
            if let cachedResult = await MainActor.run(body: {
                analysisRepository.getAnalysisResult(for: memoId, mode: .distill, responseType: DistillData.self)
            }) {
                _ = cacheTimer.finish(additionalInfo: "Cache HIT - returning immediately")
                logger.analysis("Found cached Distill analysis (cache hit)", 
                              level: .info, 
                              context: LogContext(correlationId: correlationId, additionalInfo: [
                                  "memoId": memoId.uuidString,
                                  "cacheHit": true,
                                  "latencyMs": cachedResult.latency_ms
                              ]))
                
                // Complete operation immediately for cache hit
                await operationCoordinator.completeOperation(operationId)
                return cachedResult
            }
            _ = cacheTimer.finish(additionalInfo: "Cache MISS - proceeding to API call")
            
            logger.analysis("No cached result found, calling analysis service", 
                          level: .warning, 
                          context: LogContext(correlationId: correlationId, additionalInfo: ["cacheHit": false]))
        
            // Call service to perform analysis
            let analysisTimer = PerformanceTimer(operation: "Distill Analysis API Call", category: .analysis)
            let result = try await analysisService.analyzeDistill(transcript: transcript)

            // Guardrails: validate structure before persisting
            guard AnalysisGuardrails.validate(distill: result.data) else {
                logger.error("Distill validation failed — not persisting result", category: .analysis, context: context, error: nil)
                await operationCoordinator.failOperation(operationId, error: AnalysisError.invalidResponse)
                throw AnalysisError.invalidResponse
            }
            _ = analysisTimer.finish(additionalInfo: "Service call completed successfully")
            
            logger.analysis("Distill analysis completed successfully", 
                          context: LogContext(correlationId: correlationId, additionalInfo: [
                              "apiLatencyMs": result.latency_ms,
                              "summaryLength": result.data.summary.count,
                              "actionItemsCount": result.data.action_items?.count ?? 0,
                              "themesCount": result.data.key_themes.count,
                              "questionsCount": result.data.reflection_questions.count,
                              "model": result.model
                          ]))
            
            // SAVE TO CACHE: Store result for future use
            let saveTimer = PerformanceTimer(operation: "Distill Cache Save", category: .performance)
            await MainActor.run {
                analysisRepository.saveAnalysisResult(result, for: memoId, mode: .distill)
            }
            _ = saveTimer.finish(additionalInfo: "Analysis cached successfully")
            
            logger.analysis("Distill analysis cached successfully", 
                          context: LogContext(correlationId: correlationId, additionalInfo: ["cached": true]))
            
            // Publish analysisCompleted event on main actor
            logger.debug("Publishing analysisCompleted event for Distill analysis", category: .analysis, context: context)
            await MainActor.run { [eventBus] in
                eventBus.publish(.analysisCompleted(memoId: memoId, type: .distill, result: result.data.summary))
            }
            
            // Complete the analysis operation
            await operationCoordinator.completeOperation(operationId)
            logger.debug("Distill analysis operation completed: \(operationId)", category: .analysis, context: context)
            
            return result
            
        } catch {
            logger.error("Distill analysis service call failed", 
                       category: .analysis, 
                       context: LogContext(correlationId: correlationId, additionalInfo: ["serviceError": error.localizedDescription]), 
                       error: error)
            
            // Fail the analysis operation
            await operationCoordinator.failOperation(operationId, error: error)
            
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}
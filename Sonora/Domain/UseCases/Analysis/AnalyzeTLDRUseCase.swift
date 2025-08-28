import Foundation

/// Use case for performing TLDR analysis on transcript with repository caching
/// Encapsulates the business logic for generating TLDR summaries with persistence
protocol AnalyzeTLDRUseCaseProtocol {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<TLDRData>
}

final class AnalyzeTLDRUseCase: AnalyzeTLDRUseCaseProtocol {
    
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
        eventBus: any EventBusProtocol = EventBus.shared,
        operationCoordinator: any OperationCoordinatorProtocol
    ) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
        self.logger = logger
        self.eventBus = eventBus
        self.operationCoordinator = operationCoordinator
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<TLDRData> {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: ["memoId": memoId.uuidString])
        
        logger.analysis("Starting TLDR analysis", context: context)
        
        // Register analysis operation (analysis can run concurrently - no conflicts)
        guard let operationId = await operationCoordinator.registerOperation(.analysis(memoId: memoId, analysisType: .tldr)) else {
            logger.warning("TLDR analysis rejected by operation coordinator (system at capacity)", category: .analysis, context: context, error: nil)
            throw AnalysisError.systemBusy
        }
        
        logger.debug("TLDR analysis operation registered with ID: \(operationId)", category: .analysis, context: context)
        
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
            let cacheTimer = PerformanceTimer(operation: "TLDR Cache Check", category: .performance)
            if let cachedResult = await MainActor.run(body: {
                analysisRepository.getAnalysisResult(for: memoId, mode: .tldr, responseType: TLDRData.self)
            }) {
                cacheTimer.finish(additionalInfo: "Cache HIT - returning immediately")
                logger.analysis("Found cached TLDR analysis (cache hit)", 
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
            cacheTimer.finish(additionalInfo: "Cache MISS - proceeding to API call")
            
            logger.analysis("No cached result found, calling analysis service", 
                          level: .warning, 
                          context: LogContext(correlationId: correlationId, additionalInfo: ["cacheHit": false]))
        
            // Call service to perform analysis
            let analysisTimer = PerformanceTimer(operation: "TLDR Analysis API Call", category: .analysis)
            let result = try await analysisService.analyzeTLDR(transcript: transcript)
            analysisTimer.finish(additionalInfo: "Service call completed successfully")
            
            logger.analysis("TLDR analysis completed successfully", 
                          context: LogContext(correlationId: correlationId, additionalInfo: [
                              "apiLatencyMs": result.latency_ms,
                              "summaryLength": result.data.summary.count,
                              "keyPointsCount": result.data.key_points.count,
                              "model": result.model
                          ]))
            
            // SAVE TO CACHE: Store result for future use
            let saveTimer = PerformanceTimer(operation: "TLDR Cache Save", category: .performance)
            await MainActor.run {
                analysisRepository.saveAnalysisResult(result, for: memoId, mode: .tldr)
            }
            saveTimer.finish(additionalInfo: "Analysis cached successfully")
            
            logger.analysis("TLDR analysis cached successfully", 
                          context: LogContext(correlationId: correlationId, additionalInfo: ["cached": true]))
            
            // Publish analysisCompleted event on main actor
            logger.debug("Publishing analysisCompleted event for TLDR analysis", category: .analysis, context: context)
            await MainActor.run { [eventBus] in
                eventBus.publish(.analysisCompleted(memoId: memoId, type: .tldr, result: result.data.summary))
            }
            
            // Complete the analysis operation
            await operationCoordinator.completeOperation(operationId)
            logger.debug("TLDR analysis operation completed: \(operationId)", category: .analysis, context: context)
            
            return result
            
        } catch {
            logger.error("TLDR analysis service call failed", 
                       category: .analysis, 
                       context: LogContext(correlationId: correlationId, additionalInfo: ["serviceError": error.localizedDescription]), 
                       error: error)
            
            // Fail the analysis operation
            await operationCoordinator.failOperation(operationId, error: error)
            
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
    }

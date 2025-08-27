import Foundation

/// Use case for performing TLDR analysis on transcript with repository caching
/// Encapsulates the business logic for generating TLDR summaries with persistence
protocol AnalyzeTLDRUseCaseProtocol {
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<TLDRData>
}

final class AnalyzeTLDRUseCase: AnalyzeTLDRUseCaseProtocol {
    
    // MARK: - Dependencies
    private let analysisService: AnalysisServiceProtocol
    private let analysisRepository: AnalysisRepository
    private let logger: LoggerProtocol
    
    // MARK: - Initialization
    init(
        analysisService: AnalysisServiceProtocol, 
        analysisRepository: AnalysisRepository,
        logger: LoggerProtocol = Logger.shared
    ) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
        self.logger = logger
    }
    
    // MARK: - Use Case Execution
    func execute(transcript: String, memoId: UUID) async throws -> AnalyzeEnvelope<TLDRData> {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: ["memoId": memoId.uuidString])
        
        logger.analysis("Starting TLDR analysis", context: context)
        
        // Validate inputs
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logger.error("TLDR analysis failed: empty transcript", category: .analysis, context: context, error: AnalysisError.emptyTranscript)
            throw AnalysisError.emptyTranscript
        }
        
        guard transcript.count >= 10 else {
            logger.error("TLDR analysis failed: transcript too short (\(transcript.count) chars)", category: .analysis, context: context, error: AnalysisError.transcriptTooShort)
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
            return cachedResult
        }
        cacheTimer.finish(additionalInfo: "Cache MISS - proceeding to API call")
        
        logger.analysis("No cached result found, calling analysis service", 
                      level: .warning, 
                      context: LogContext(correlationId: correlationId, additionalInfo: ["cacheHit": false]))
        
        do {
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
            return result
            
        } catch {
            logger.error("TLDR analysis service call failed", 
                       category: .analysis, 
                       context: LogContext(correlationId: correlationId, additionalInfo: ["serviceError": error.localizedDescription]), 
                       error: error)
            throw AnalysisError.analysisServiceError(error.localizedDescription)
        }
    }
}


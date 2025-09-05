import Foundation

/// Parallel implementation of Distill analysis for improved performance
/// Executes 4 component analyses concurrently and combines results
/// Provides progressive UI updates as components complete
protocol AnalyzeDistillParallelUseCaseProtocol: Sendable {
    func execute(transcript: String, memoId: UUID, progressHandler: @MainActor @escaping (DistillProgressUpdate) -> Void) async throws -> AnalyzeEnvelope<DistillData>
}

/// Progress update for parallel distill processing
public struct DistillProgressUpdate: Sendable, Equatable {
    public let completedComponents: Int
    public let totalComponents: Int
    public let completedResults: PartialDistillData
    public let latestComponent: AnalysisMode?
    
    public var progress: Double {
        return Double(completedComponents) / Double(totalComponents)
    }
}

/// Partial distill data that gets built up progressively
public struct PartialDistillData: Sendable, Equatable {
    public var summary: String?
    public var actionItems: [DistillData.ActionItem]?
    public var keyThemes: [String]?
    public var reflectionQuestions: [String]?
    
    /// Convert to complete DistillData if all components are present
    public func toDistillData() -> DistillData? {
        guard let summary = summary,
              let keyThemes = keyThemes,
              let reflectionQuestions = reflectionQuestions else {
            return nil
        }
        
        return DistillData(
            summary: summary,
            action_items: actionItems,
            key_themes: keyThemes,
            reflection_questions: reflectionQuestions
        )
    }
}

enum DistillComponentData: Sendable {
    case summary(DistillSummaryData)
    case actions(DistillActionsData)
    case themes(DistillThemesData)
    case reflection(DistillReflectionData)
}

final class AnalyzeDistillParallelUseCase: AnalyzeDistillParallelUseCaseProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    private let analysisService: any AnalysisServiceProtocol
    private let analysisRepository: any AnalysisRepository
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol
    private let operationCoordinator: any OperationCoordinatorProtocol
    
    // MARK: - Constants
    private let componentModes: [AnalysisMode] = [.distillSummary, .distillActions, .distillThemes, .distillReflection]
    
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
    @MainActor
    func execute(transcript: String, memoId: UUID, progressHandler: @MainActor @escaping (DistillProgressUpdate) -> Void) async throws -> AnalyzeEnvelope<DistillData> {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: ["memoId": memoId.uuidString])
        
        logger.analysis("Starting parallel Distill analysis", context: context)

        // Validate inputs early; avoid registering an op for invalid requests
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }

        // CACHE FIRST: Skip coordinator entirely for cache hit
        if let cachedResult = await MainActor.run(body: {
            analysisRepository.getAnalysisResult(for: memoId, mode: .distill, responseType: DistillData.self)
        }) {
            logger.analysis("Found complete cached Distill analysis (no coordinator op)", level: .info, context: context)
            return cachedResult
        }

        // Register analysis operation for the actual parallel run
        guard let operationId = await operationCoordinator.registerOperation(.analysis(memoId: memoId, analysisType: .distill)) else {
            logger.warning("Parallel Distill analysis rejected by operation coordinator", category: .analysis, context: context, error: nil)
            throw AnalysisError.systemBusy
        }

        do {
            
            // Execute parallel component analysis
            let result = try await executeParallelComponents(
                transcript: transcript,
                memoId: memoId,
                progressHandler: progressHandler,
                context: context
            )
            
            // Save complete result to cache
            await MainActor.run {
                analysisRepository.saveAnalysisResult(result, for: memoId, mode: .distill)
            }
            
            // Publish completion event
            await MainActor.run {
                EventBus.shared.publish(.analysisCompleted(memoId: memoId, type: .distill, result: result.data.summary))
            }
            
            await operationCoordinator.completeOperation(operationId)
            
            logger.analysis("Parallel Distill analysis completed successfully", context: context)
            return result
            
        } catch {
            await operationCoordinator.failOperation(operationId, errorDescription: error.localizedDescription)
            throw error
        }
    }
    
    // MARK: - Private Implementation
    
    private func executeParallelComponents(
        transcript: String,
        memoId: UUID,
        progressHandler: @MainActor @escaping (DistillProgressUpdate) -> Void,
        context: LogContext
    ) async throws -> AnalyzeEnvelope<DistillData> {
        
        var partialData = PartialDistillData()
        var completedCount = 0
        var combinedLatency = 0
        let model = "gpt-5-nano"
        var combinedTokens = TokenUsage(input: 0, output: 0)
        
        // Send initial progress
        let initialPartial = partialData
        await MainActor.run {
            progressHandler(DistillProgressUpdate(
                completedComponents: 0,
                totalComponents: componentModes.count,
                completedResults: initialPartial,
                latestComponent: nil
            ))
        }
        
        logger.analysis("Starting parallel execution of \(componentModes.count) components", context: context)
        
        // Execute all components in parallel using TaskGroup
        try await withThrowingTaskGroup(of: (AnalysisMode, DistillComponentData, Int, TokenUsage).self) { group in
            
            // Add tasks for each component
            for mode in componentModes {
                group.addTask { [self] in
                    // Check cache first
                    if let cached = await checkComponentCache(mode: mode, memoId: memoId) {
                        logger.debug("Cache hit for component \(mode.rawValue)", category: .analysis, context: context)
                        return (mode, cached.data, cached.latency_ms, cached.tokens)
                    }
                    
                    // Execute API call for component
                    logger.debug("Executing API call for component \(mode.rawValue)", category: .analysis, context: context)
                    let result = try await executeComponentAnalysis(mode: mode, transcript: transcript, memoId: memoId)
                    
                    // Save component to cache
                    await saveComponentCache(data: result.data, latency: result.latency_ms, tokens: result.tokens, mode: mode, memoId: memoId)
                    
                    return (mode, result.data, result.latency_ms, result.tokens)
                }
            }
            
            // Collect results as they complete
            for try await (mode, data, latency, tokens) in group {
                combinedLatency = max(combinedLatency, latency) // Use max since parallel
                combinedTokens = TokenUsage(
                    input: combinedTokens.input + tokens.input,
                    output: combinedTokens.output + tokens.output
                )
                
                // Update partial data based on component type
                updatePartialData(&partialData, mode: mode, data: data)
                
                completedCount += 1
                let currentCompleted = completedCount
                let currentPartial = partialData
                
                // Send progress update on main actor
                await MainActor.run {
                    progressHandler(DistillProgressUpdate(
                        completedComponents: currentCompleted,
                        totalComponents: componentModes.count,
                        completedResults: currentPartial,
                        latestComponent: mode
                    ))
                }
                
                logger.debug("Component \(mode.rawValue) completed (\(completedCount)/\(componentModes.count))", 
                           category: .analysis, context: context)
            }
        }
        
        // Combine results into final DistillData
        guard let finalData = partialData.toDistillData() else {
            logger.error("Failed to combine parallel component results", category: .analysis, context: context, error: nil)
            throw AnalysisError.invalidResponse
        }
        
        logger.analysis("Parallel component execution completed", 
                       context: LogContext(correlationId: context.correlationId, additionalInfo: [
                           "combinedLatency": combinedLatency,
                           "totalInputTokens": combinedTokens.input,
                           "totalOutputTokens": combinedTokens.output
                       ]))
        
        // Create final envelope
        return AnalyzeEnvelope(
            mode: .distill,
            data: finalData,
            model: model,
            tokens: combinedTokens,
            latency_ms: combinedLatency,
            moderation: nil
        )
    }
    
    private func checkComponentCache(mode: AnalysisMode, memoId: UUID) async -> (data: DistillComponentData, latency_ms: Int, tokens: TokenUsage)? {
        return await MainActor.run {
            switch mode {
            case .distillSummary:
                if let result = analysisRepository.getAnalysisResult(for: memoId, mode: mode, responseType: DistillSummaryData.self) {
                    return (.summary(result.data), result.latency_ms, result.tokens)
                }
            case .distillActions:
                if let result = analysisRepository.getAnalysisResult(for: memoId, mode: mode, responseType: DistillActionsData.self) {
                    return (.actions(result.data), result.latency_ms, result.tokens)
                }
            case .distillThemes:
                if let result = analysisRepository.getAnalysisResult(for: memoId, mode: mode, responseType: DistillThemesData.self) {
                    return (.themes(result.data), result.latency_ms, result.tokens)
                }
            case .distillReflection:
                if let result = analysisRepository.getAnalysisResult(for: memoId, mode: mode, responseType: DistillReflectionData.self) {
                    return (.reflection(result.data), result.latency_ms, result.tokens)
                }
            default:
                break
            }
            return nil
        }
    }
    
    private func executeComponentAnalysis(mode: AnalysisMode, transcript: String, memoId: UUID) async throws -> (data: DistillComponentData, latency_ms: Int, tokens: TokenUsage) {
        switch mode {
        case .distillSummary:
            let envelope = try await analysisService.analyzeDistillSummary(transcript: transcript)
            return (.summary(envelope.data), envelope.latency_ms, envelope.tokens)
        case .distillActions:
            let envelope = try await analysisService.analyzeDistillActions(transcript: transcript)
            return (.actions(envelope.data), envelope.latency_ms, envelope.tokens)
        case .distillThemes:
            let envelope = try await analysisService.analyzeDistillThemes(transcript: transcript)
            return (.themes(envelope.data), envelope.latency_ms, envelope.tokens)
        case .distillReflection:
            let envelope = try await analysisService.analyzeDistillReflection(transcript: transcript)
            return (.reflection(envelope.data), envelope.latency_ms, envelope.tokens)
        default:
            throw AnalysisError.invalidResponse
        }
    }
    
    private func saveComponentCache(data: DistillComponentData, latency: Int, tokens: TokenUsage, mode: AnalysisMode, memoId: UUID) async {
        await MainActor.run {
            switch data {
            case .summary(let summaryData):
                let envelope = AnalyzeEnvelope(mode: mode, data: summaryData, model: "gpt-5-nano", tokens: tokens, latency_ms: latency, moderation: nil)
                analysisRepository.saveAnalysisResult(envelope, for: memoId, mode: mode)
            case .actions(let actionsData):
                let envelope = AnalyzeEnvelope(mode: mode, data: actionsData, model: "gpt-5-nano", tokens: tokens, latency_ms: latency, moderation: nil)
                analysisRepository.saveAnalysisResult(envelope, for: memoId, mode: mode)
            case .themes(let themesData):
                let envelope = AnalyzeEnvelope(mode: mode, data: themesData, model: "gpt-5-nano", tokens: tokens, latency_ms: latency, moderation: nil)
                analysisRepository.saveAnalysisResult(envelope, for: memoId, mode: mode)
            case .reflection(let reflectionData):
                let envelope = AnalyzeEnvelope(mode: mode, data: reflectionData, model: "gpt-5-nano", tokens: tokens, latency_ms: latency, moderation: nil)
                analysisRepository.saveAnalysisResult(envelope, for: memoId, mode: mode)
            }
        }
    }
    
    private func updatePartialData(_ partialData: inout PartialDistillData, mode: AnalysisMode, data: DistillComponentData) {
        switch data {
        case .summary(let summaryData):
            partialData.summary = summaryData.summary
        case .actions(let actionsData):
            partialData.actionItems = actionsData.action_items
        case .themes(let themesData):
            partialData.keyThemes = themesData.key_themes
        case .reflection(let reflectionData):
            partialData.reflectionQuestions = reflectionData.reflection_questions
        }
    }
}

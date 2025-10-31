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
        Double(completedComponents) / Double(totalComponents)
    }
}

/// Partial distill data that gets built up progressively
public struct PartialDistillData: Sendable, Equatable {
    public var summary: String?
    public var actionItems: [DistillData.ActionItem]?
    public var reflectionQuestions: [String]?
    public var patterns: [DistillData.Pattern]?
    public var events: [EventsData.DetectedEvent]?
    public var reminders: [RemindersData.DetectedReminder]?

    // Pro-tier fields
    public var cognitivePatterns: [CognitivePattern]?
    public var philosophicalEchoes: [PhilosophicalEcho]?
    public var valuesInsights: ValuesInsight?

    /// Convert to complete DistillData if all required components are present
    public func toDistillData() -> DistillData? {
        guard let summary = summary,
              let reflectionQuestions = reflectionQuestions else {
            return nil
        }

        return DistillData(
            summary: summary,
            action_items: actionItems,
            reflection_questions: reflectionQuestions,
            patterns: patterns,
            events: events,
            reminders: reminders,
            cognitivePatterns: cognitivePatterns,
            philosophicalEchoes: philosophicalEchoes,
            valuesInsights: valuesInsights
        )
    }
}

extension PartialDistillData {
    public static func == (lhs: PartialDistillData, rhs: PartialDistillData) -> Bool {
        // Compare simple fields directly
        guard lhs.summary == rhs.summary,
              lhs.actionItems == rhs.actionItems,
              lhs.reflectionQuestions == rhs.reflectionQuestions,
              lhs.patterns == rhs.patterns,
              lhs.cognitivePatterns == rhs.cognitivePatterns,
              lhs.philosophicalEchoes == rhs.philosophicalEchoes,
              lhs.valuesInsights == rhs.valuesInsights else {
            return false
        }
        // Compare events/reminders by IDs (domain types are not Equatable)
        let lEventIds = lhs.events?.map { $0.id } ?? []
        let rEventIds = rhs.events?.map { $0.id } ?? []
        let lReminderIds = lhs.reminders?.map { $0.id } ?? []
        let rReminderIds = rhs.reminders?.map { $0.id } ?? []
        return lEventIds == rEventIds && lReminderIds == rReminderIds
    }
}

enum DistillComponentData: Sendable {
    case summary(DistillSummaryData)
    case actions(DistillActionsData)
    case reflection(DistillReflectionData)
    case detections(EventsData?, RemindersData?)
    case patterns([DistillData.Pattern]?)
    // Pro-tier components
    case cognitiveClarity([CognitivePattern]?)
    case philosophicalEchoes([PhilosophicalEcho]?)
    case valuesRecognition(ValuesInsight?)
}

final class AnalyzeDistillParallelUseCase: AnalyzeDistillParallelUseCaseProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let analysisService: any AnalysisServiceProtocol
    private let analysisRepository: any AnalysisRepository
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol
    private let operationCoordinator: any OperationCoordinatorProtocol
    private let detectUseCase: any DetectEventsAndRemindersUseCaseProtocol
    private let buildHistoricalContextUseCase: any BuildHistoricalContextUseCaseProtocol

    // MARK: - Constants
    private let componentModes: [AnalysisMode] = [.distillSummary, .distillActions, .distillReflection]

    // MARK: - Initialization
    init(
        analysisService: any AnalysisServiceProtocol,
        analysisRepository: any AnalysisRepository,
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol,
        operationCoordinator: any OperationCoordinatorProtocol,
        detectUseCase: any DetectEventsAndRemindersUseCaseProtocol,
        buildHistoricalContextUseCase: any BuildHistoricalContextUseCaseProtocol
    ) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
        self.logger = logger
        self.eventBus = eventBus
        self.operationCoordinator = operationCoordinator
        self.detectUseCase = detectUseCase
        self.buildHistoricalContextUseCase = buildHistoricalContextUseCase
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

        // Build historical context for pattern detection
        let historicalContext = await buildHistoricalContextUseCase.execute(currentMemoId: memoId)
        let enablePatterns = !historicalContext.isEmpty

        logger.debug("Historical context: \(historicalContext.count) memos, patterns \(enablePatterns ? "enabled" : "disabled")",
                    category: .analysis, context: context)

        // Send initial progress
        // Total: summary + actions + reflection + detections + (optional: patterns) + 3 Pro modes
        let totalComponents = componentModes.count + 1 + (enablePatterns ? 1 : 0) + 3
        let initialPartial = partialData
        await MainActor.run {
            progressHandler(DistillProgressUpdate(
                completedComponents: 0,
                totalComponents: totalComponents,
                completedResults: initialPartial,
                latestComponent: nil
            ))
        }

        logger.analysis("Starting parallel execution of \(componentModes.count) components + patterns=\(enablePatterns) + 3 Pro modes", context: context)

        // Execute all components in parallel using TaskGroup
        try await withThrowingTaskGroup(of: (AnalysisMode?, DistillComponentData, Int, TokenUsage).self) { group in

            // Add tasks for each component with streaming support
            for mode in componentModes {
                group.addTask { [self] in
                    // Check cache first
                    if let cached = await checkComponentCache(mode: mode, memoId: memoId) {
                        logger.debug("Cache hit for component \(mode.rawValue)", category: .analysis, context: context)
                        return (mode, cached.data, cached.latency_ms, cached.tokens)
                    }

                    // Execute API call for component with streaming
                    logger.debug("Executing API call for component \(mode.rawValue) with streaming", category: .analysis, context: context)
                    let result = try await executeComponentAnalysis(
                        mode: mode,
                        transcript: transcript,
                        memoId: memoId,
                        streamingProgress: { update in
                            // Log streaming updates for debugging
                            logger.debug("\(mode.displayName) streaming: \(update.partialText.prefix(50))...", category: .analysis, context: context)
                        }
                    )

                    // Save component to cache
                    await saveComponentCache(data: result.data, latency: result.latency_ms, tokens: result.tokens, mode: mode, memoId: memoId)

                    return (mode, result.data, result.latency_ms, result.tokens)
                }
            }

            // Add detection task
            group.addTask { [self] in
                do {
                    let det = try await detectUseCase.execute(transcript: transcript, memoId: memoId)
                    let latencyMs = Int(det.detectionMetadata.processingTime * 1_000)
                    return (nil, .detections(det.events, det.reminders), latencyMs, TokenUsage(input: 0, output: 0))
                } catch {
                    logger.warning("Detection error; continuing without detections", category: .analysis, context: context, error: error)
                    return (nil, .detections(nil, nil), 0, TokenUsage(input: 0, output: 0))
                }
            }

            // Add patterns task if historical context is available
            if enablePatterns {
                group.addTask { [self] in
                    do {
                        logger.debug("Calling full distill mode with historical context for patterns", category: .analysis, context: context)
                        let envelope = try await analysisService.analyzeDistill(
                            transcript: transcript,
                            historicalContext: historicalContext
                        )
                        // Extract only patterns from the full distill response
                        let patterns = envelope.data.patterns
                        logger.debug("Patterns detected: \(patterns?.count ?? 0)", category: .analysis, context: context)
                        return (nil, .patterns(patterns), envelope.latency_ms, envelope.tokens)
                    } catch {
                        logger.warning("Pattern detection error; continuing without patterns", category: .analysis, context: context, error: error)
                        return (nil, .patterns(nil), 0, TokenUsage(input: 0, output: 0))
                    }
                }
            }

            // Add Pro-tier analysis tasks (Beck/Ellis CBT, wisdom, values) with streaming support
            group.addTask { [self] in
                do {
                    logger.debug("Executing cognitive-clarity analysis (Beck/Ellis CBT) with streaming", category: .analysis, context: context)
                    let envelope = try await analysisService.analyzeCognitiveClarityCBTStreaming(
                        transcript: transcript,
                        progress: { update in
                            // Streaming updates for CBT patterns
                            logger.debug("CBT streaming: \(update.partialText.prefix(50))...", category: .analysis, context: context)
                        }
                    )
                    let patterns = envelope.data.cognitivePatterns
                    logger.debug("Cognitive patterns detected: \(patterns.count)", category: .analysis, context: context)
                    return (.cognitiveClarityCBT, .cognitiveClarity(patterns.isEmpty ? nil : patterns), envelope.latency_ms, envelope.tokens)
                } catch {
                    logger.warning("Cognitive clarity error; continuing without CBT analysis", category: .analysis, context: context, error: error)
                    return (.cognitiveClarityCBT, .cognitiveClarity(nil), 0, TokenUsage(input: 0, output: 0))
                }
            }

            group.addTask { [self] in
                do {
                    logger.debug("Executing philosophical-echoes analysis (wisdom connections) with streaming", category: .analysis, context: context)
                    let envelope = try await analysisService.analyzePhilosophicalEchoesStreaming(
                        transcript: transcript,
                        progress: { update in
                            // Streaming updates for philosophical echoes
                            logger.debug("Wisdom streaming: \(update.partialText.prefix(50))...", category: .analysis, context: context)
                        }
                    )
                    let echoes = envelope.data.philosophicalEchoes
                    logger.debug("Philosophical echoes detected: \(echoes.count)", category: .analysis, context: context)
                    return (.philosophicalEchoes, .philosophicalEchoes(echoes.isEmpty ? nil : echoes), envelope.latency_ms, envelope.tokens)
                } catch {
                    logger.warning("Philosophical echoes error; continuing without wisdom analysis", category: .analysis, context: context, error: error)
                    return (.philosophicalEchoes, .philosophicalEchoes(nil), 0, TokenUsage(input: 0, output: 0))
                }
            }

            group.addTask { [self] in
                do {
                    logger.debug("Executing values-recognition analysis with streaming", category: .analysis, context: context)
                    let envelope = try await analysisService.analyzeValuesRecognitionStreaming(
                        transcript: transcript,
                        progress: { update in
                            // Streaming updates for values
                            logger.debug("Values streaming: \(update.partialText.prefix(50))...", category: .analysis, context: context)
                        }
                    )
                    let coreValues = envelope.data.coreValues
                    let tensions = envelope.data.tensions
                    let valuesInsight = ValuesInsight(coreValues: coreValues, tensions: tensions)
                    logger.debug("Values detected: \(coreValues.count), tensions: \(tensions?.count ?? 0)", category: .analysis, context: context)
                    return (.valuesRecognition, .valuesRecognition(valuesInsight), envelope.latency_ms, envelope.tokens)
                } catch {
                    logger.warning("Values recognition error; continuing without values analysis", category: .analysis, context: context, error: error)
                    return (.valuesRecognition, .valuesRecognition(nil), 0, TokenUsage(input: 0, output: 0))
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
                        totalComponents: totalComponents,
                        completedResults: currentPartial,
                        latestComponent: mode
                    ))
                }

                logger.debug("Component \(mode?.rawValue ?? "detections") completed (\(completedCount)/\(totalComponents))",
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
        await MainActor.run {
            switch mode {
            case .distillSummary:
                if let result = analysisRepository.getAnalysisResult(for: memoId, mode: mode, responseType: DistillSummaryData.self) {
                    return (.summary(result.data), result.latency_ms, result.tokens)
                }
            case .distillActions:
                if let result = analysisRepository.getAnalysisResult(for: memoId, mode: mode, responseType: DistillActionsData.self) {
                    return (.actions(result.data), result.latency_ms, result.tokens)
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

    private func executeComponentAnalysis(
        mode: AnalysisMode,
        transcript: String,
        memoId: UUID,
        streamingProgress: AnalysisStreamingHandler? = nil
    ) async throws -> (data: DistillComponentData, latency_ms: Int, tokens: TokenUsage) {
        switch mode {
        case .distillSummary:
            let envelope = try await analysisService.analyzeDistillSummaryStreaming(
                transcript: transcript,
                progress: streamingProgress
            )
            return (.summary(envelope.data), envelope.latency_ms, envelope.tokens)
        case .distillActions:
            let envelope = try await analysisService.analyzeDistillActionsStreaming(
                transcript: transcript,
                progress: streamingProgress
            )
            return (.actions(envelope.data), envelope.latency_ms, envelope.tokens)
        case .distillReflection:
            let envelope = try await analysisService.analyzeDistillReflectionStreaming(
                transcript: transcript,
                progress: streamingProgress
            )
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
            case .reflection(let reflectionData):
                let envelope = AnalyzeEnvelope(mode: mode, data: reflectionData, model: "gpt-5-nano", tokens: tokens, latency_ms: latency, moderation: nil)
                analysisRepository.saveAnalysisResult(envelope, for: memoId, mode: mode)
            case .detections:
                // No cache persistence for detection bundle in this use case.
                break
            case .patterns:
                // No separate cache for patterns - they're part of the full distill result
                break
            case .cognitiveClarity, .philosophicalEchoes, .valuesRecognition:
                // No separate cache for Pro components - they're part of the full distill result
                break
            }
        }
    }

    private func updatePartialData(_ partialData: inout PartialDistillData, mode: AnalysisMode?, data: DistillComponentData) {
        switch data {
        case .summary(let summaryData):
            partialData.summary = summaryData.summary
        case .actions(let actionsData):
            partialData.actionItems = actionsData.action_items
        case .reflection(let reflectionData):
            partialData.reflectionQuestions = reflectionData.reflection_questions
        case .detections(let ev, let rem):
            partialData.events = ev?.events
            partialData.reminders = rem?.reminders
            Logger.shared.debug(
                "Distill.Partial.Detections",
                category: .analysis,
                context: LogContext(additionalInfo: [
                    "events": ev?.events.count ?? 0,
                    "reminders": rem?.reminders.count ?? 0
                ])
            )
        case .patterns(let patterns):
            partialData.patterns = patterns
            Logger.shared.debug(
                "Distill.Partial.Patterns",
                category: .analysis,
                context: LogContext(additionalInfo: [
                    "patterns": patterns?.count ?? 0
                ])
            )
        case .cognitiveClarity(let patterns):
            partialData.cognitivePatterns = patterns
            Logger.shared.debug(
                "Distill.Partial.CognitivePatterns",
                category: .analysis,
                context: LogContext(additionalInfo: [
                    "cognitivePatterns": patterns?.count ?? 0
                ])
            )
        case .philosophicalEchoes(let echoes):
            partialData.philosophicalEchoes = echoes
            Logger.shared.debug(
                "Distill.Partial.PhilosophicalEchoes",
                category: .analysis,
                context: LogContext(additionalInfo: [
                    "philosophicalEchoes": echoes?.count ?? 0
                ])
            )
        case .valuesRecognition(let insight):
            partialData.valuesInsights = insight
            Logger.shared.debug(
                "Distill.Partial.ValuesInsights",
                category: .analysis,
                context: LogContext(additionalInfo: [
                    "coreValues": insight?.coreValues.count ?? 0,
                    "tensions": insight?.tensions?.count ?? 0
                ])
            )
        }
    }
}

import Foundation

/// Use case for detecting events and reminders from transcription text using AI analysis
protocol DetectEventsAndRemindersUseCaseProtocol: Sendable {
    func execute(transcript: String, memoId: UUID) async throws -> DetectionResult
}

struct DetectionResult: Sendable {
    let events: EventsData?
    let reminders: RemindersData?
    let detectionMetadata: DetectionMetadata
}

struct DetectionMetadata: Sendable {
    let totalDetections: Int
    let averageConfidence: Float
    let highConfidenceCount: Int
    let processingTime: TimeInterval
    let analysisMode: String // "cloud" or "cached"
    
    var detectionQuality: DetectionQuality {
        switch averageConfidence {
        case 0.8...1.0: return .excellent
        case 0.6..<0.8: return .good
        case 0.4..<0.6: return .fair
        default: return .poor
        }
    }
    
    enum DetectionQuality: String, CaseIterable {
        case excellent = "Excellent"
        case good = "Good"
        case fair = "Fair"
        case poor = "Poor"
        
        var color: String {
            switch self {
            case .excellent: return "green"
            case .good: return "blue"
            case .fair: return "orange"
            case .poor: return "red"
            }
        }
    }
}

final class DetectEventsAndRemindersUseCase: DetectEventsAndRemindersUseCaseProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    private let analysisService: any AnalysisServiceProtocol
    private let analysisRepository: any AnalysisRepository
    private let logger: LoggerProtocol
    private let eventBus: EventBusProtocol
    private let operationCoordinator: OperationCoordinatorProtocol
    private let thresholdPolicy: any AdaptiveThresholdPolicy
    
    // MARK: - Configuration
    // Legacy static thresholds remain as a safety floor; adaptive policy refines per-context
    private var legacyEventThreshold: Float { Float(UserDefaults.standard.object(forKey: "eventConfidenceThreshold") as? Double ?? 0.7) }
    private var legacyReminderThreshold: Float { Float(UserDefaults.standard.object(forKey: "reminderConfidenceThreshold") as? Double ?? 0.7) }
    
    // MARK: - Initialization
    init(
        analysisService: any AnalysisServiceProtocol,
        analysisRepository: any AnalysisRepository,
        logger: LoggerProtocol = Logger.shared,
        eventBus: EventBusProtocol = EventBus.shared,
        operationCoordinator: OperationCoordinatorProtocol,
        thresholdPolicy: any AdaptiveThresholdPolicy = DefaultAdaptiveThresholdPolicy()
    ) {
        self.analysisService = analysisService
        self.analysisRepository = analysisRepository
        self.logger = logger
        self.eventBus = eventBus
        self.operationCoordinator = operationCoordinator
        self.thresholdPolicy = thresholdPolicy
    }
    
    // MARK: - Use Case Execution
    
    @MainActor
    func execute(transcript: String, memoId: UUID) async throws -> DetectionResult {
        let startTime = Date()
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "memoId": memoId.uuidString,
            "transcriptLength": transcript.count
        ])
        
        logger.info("Starting event and reminder detection",
                   category: .analysis,
                   context: context)
        
        // Validate inputs
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.emptyTranscript
        }
        
        guard transcript.count >= 10 else {
            throw AnalysisError.transcriptTooShort
        }
        
        // Check cache first
        if let cachedEvents = await getCachedAnalysis(for: memoId, mode: .events) as EventsData?,
           let cachedReminders = await getCachedAnalysis(for: memoId, mode: .reminders) as RemindersData? {
            logger.info("Using cached event/reminder detection results",
                       category: .analysis,
                       context: context)
            
            return DetectionResult(
                events: cachedEvents,
                reminders: cachedReminders,
                detectionMetadata: createMetadata(
                    events: cachedEvents,
                    reminders: cachedReminders,
                    processingTime: Date().timeIntervalSince(startTime),
                    analysisMode: "cached"
                )
            )
        }
        
        // Register operation (use generic analysis category)
        guard let operationId = await operationCoordinator.registerOperation(
            .analysis(memoId: memoId, analysisType: .analysis)
        ) else {
            logger.warning("Event/reminder detection rejected by operation coordinator",
                          category: .analysis,
                          context: context,
                          error: nil)
            throw AnalysisError.systemBusy
        }
        
        do {
            // Build feature context and adaptive thresholds
            let detectionContext = DetectionContextBuilder.build(memoId: memoId, transcript: transcript)
            let adaptive = thresholdPolicy.thresholds(for: detectionContext)
            let eventThreshold = max(adaptive.event, legacyEventThreshold)
            let reminderThreshold = max(adaptive.reminder, legacyReminderThreshold)
            
            logger.debug("Adaptive thresholds computed",
                        category: .analysis,
                        context: LogContext(correlationId: correlationId, additionalInfo: [
                            "memoId": memoId.uuidString,
                            "eventThreshold": eventThreshold,
                            "reminderThreshold": reminderThreshold,
                            "transcriptLength": detectionContext.transcriptLength,
                            "sentenceCount": detectionContext.sentenceCount,
                            "hasDatesOrTimes": detectionContext.hasDatesOrTimes,
                            "hasCalendarPhrases": detectionContext.hasCalendarPhrases,
                            "imperativeVerbDensity": detectionContext.imperativeVerbDensity
                        ]))
            let result = try await performDetection(
                transcript: transcript,
                memoId: memoId,
                context: context,
                startTime: startTime,
                eventThreshold: eventThreshold,
                reminderThreshold: reminderThreshold
            )
            
            // Cache results
            if let events = result.events {
                await cacheAnalysisResult(events, for: memoId, mode: .events)
            }
            
            if let reminders = result.reminders {
                await cacheAnalysisResult(reminders, for: memoId, mode: .reminders)
            }
            
            await operationCoordinator.completeOperation(operationId)
            
            logger.info("Event and reminder detection completed successfully",
                       category: .analysis,
                       context: LogContext(correlationId: correlationId, additionalInfo: [
                           "eventCount": result.events?.events.count ?? 0,
                           "reminderCount": result.reminders?.reminders.count ?? 0,
                           "processingTime": result.detectionMetadata.processingTime,
                           "averageConfidence": result.detectionMetadata.averageConfidence
                       ]))
            
            return result
            
        } catch {
            await operationCoordinator.failOperation(operationId, errorDescription: error.localizedDescription)
            logger.error("Event and reminder detection failed",
                        category: .analysis,
                        context: context,
                        error: error)
            throw error
        }
    }
    
    // MARK: - Private Implementation
    
    private func performDetection(
        transcript: String,
        memoId: UUID,
        context: LogContext,
        startTime: Date,
        eventThreshold: Float,
        reminderThreshold: Float
    ) async throws -> DetectionResult {
        return try await performCloudDetection(
            transcript: transcript,
            memoId: memoId,
            context: context,
            startTime: startTime,
            eventThreshold: eventThreshold,
            reminderThreshold: reminderThreshold
        )
    }
    
    private func performCloudDetection(
        transcript: String,
        memoId: UUID,
        context: LogContext,
        startTime: Date,
        eventThreshold: Float,
        reminderThreshold: Float
    ) async throws -> DetectionResult {
        logger.debug("Performing cloud event/reminder detection",
                    category: .analysis,
                    context: context)

        // Use cloud analysis for events/reminders when available
        async let eventsResult: AnalyzeEnvelope<EventsData> = analysisService.analyze(
            mode: .events,
            transcript: transcript,
            responseType: EventsData.self
        )
        async let remindersResult: AnalyzeEnvelope<RemindersData> = analysisService.analyze(
            mode: .reminders,
            transcript: transcript,
            responseType: RemindersData.self
        )
        
        // Process results and filter by confidence
        let eventsEnvelope = try await eventsResult
        let remindersEnvelope = try await remindersResult
        let filteredEvents = filterEventsByConfidence(eventsEnvelope.data, threshold: eventThreshold)
        let filteredReminders = filterRemindersByConfidence(remindersEnvelope.data, threshold: reminderThreshold)
        
        return DetectionResult(
            events: filteredEvents,
            reminders: filteredReminders,
            detectionMetadata: createMetadata(
                events: filteredEvents,
                reminders: filteredReminders,
                processingTime: Date().timeIntervalSince(startTime),
                analysisMode: "cloud"
            )
        )
    }
    
    // MARK: - Result Processing
    
    private func filterEventsByConfidence(_ eventsData: EventsData?, threshold: Float) -> EventsData? {
        guard let eventsData = eventsData else { return nil }
        let filteredEvents = eventsData.events.filter { event in
            event.confidence >= threshold
        }
        
        logger.debug(
            "Filtered events by confidence: \(eventsData.events.count) → \(filteredEvents.count) (threshold: \(threshold))",
            category: .analysis,
            context: nil
        )
        
        return filteredEvents.isEmpty ? nil : EventsData(events: filteredEvents)
    }
    
    private func filterRemindersByConfidence(_ remindersData: RemindersData?, threshold: Float) -> RemindersData? {
        guard let remindersData = remindersData else { return nil }
        let filteredReminders = remindersData.reminders.filter { reminder in
            reminder.confidence >= threshold
        }
        
        logger.debug(
            "Filtered reminders by confidence: \(remindersData.reminders.count) → \(filteredReminders.count) (threshold: \(threshold))",
            category: .analysis,
            context: nil
        )
        
        return filteredReminders.isEmpty ? nil : RemindersData(reminders: filteredReminders)
    }
    
    private func createMetadata(
        events: EventsData?,
        reminders: RemindersData?,
        processingTime: TimeInterval,
        analysisMode: String
    ) -> DetectionMetadata {
        let eventCount = events?.events.count ?? 0
        let reminderCount = reminders?.reminders.count ?? 0
        let totalDetections = eventCount + reminderCount
        
        // Calculate average confidence
        var allConfidences: [Float] = []
        if let events = events {
            allConfidences.append(contentsOf: events.events.map { $0.confidence })
        }
        if let reminders = reminders {
            allConfidences.append(contentsOf: reminders.reminders.map { $0.confidence })
        }
        
        let averageConfidence = allConfidences.isEmpty ? 0.0 : 
            allConfidences.reduce(0, +) / Float(allConfidences.count)
        
        // Count high confidence detections (>= 0.8)
        let highConfidenceCount = allConfidences.filter { $0 >= 0.8 }.count
        
        return DetectionMetadata(
            totalDetections: totalDetections,
            averageConfidence: averageConfidence,
            highConfidenceCount: highConfidenceCount,
            processingTime: processingTime,
            analysisMode: analysisMode
        )
    }
    
    // MARK: - Cache Management
    
    private func getCachedAnalysis<T: Codable & Sendable>(
        for memoId: UUID, 
        mode: AnalysisMode
    ) async -> T? {
        return await MainActor.run {
            return analysisRepository.getAnalysisResult(
                for: memoId,
                mode: mode,
                responseType: T.self
            )?.data
        }
    }
    
    private func cacheAnalysisResult<T: Codable & Sendable>(
        _ data: T,
        for memoId: UUID,
        mode: AnalysisMode
    ) async {
        await MainActor.run {
            let envelope = AnalyzeEnvelope(
                mode: mode,
                data: data,
                model: "gpt-5-nano",
                tokens: TokenUsage(input: 0, output: 0), // Simplified for now
                latency_ms: 0, // Simplified for now
                moderation: nil
            )
            
            analysisRepository.saveAnalysisResult(envelope, for: memoId, mode: mode)
        }
    }
}

// MARK: - Operation Type Extension

// Removed custom OperationType extension. We use `.analysis(memoId:analysisType:)` with `.analysis`.

enum EventReminderAnalysisType: String, CaseIterable {
    case eventReminder = "event_reminder"
    case eventOnly = "event_only"
    case reminderOnly = "reminder_only"
}

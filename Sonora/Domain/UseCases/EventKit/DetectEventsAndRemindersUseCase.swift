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
    private let nearMissMargin: Float = 0.10
    private var legacyEventThreshold: Float { Float(UserDefaults.standard.object(forKey: "eventConfidenceThreshold") as? Double ?? 0.45) }
    private var legacyReminderThreshold: Float { Float(UserDefaults.standard.object(forKey: "reminderConfidenceThreshold") as? Double ?? 0.40) }

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

        // Register operation (use distill as generic analysis category)
        guard let operationId = await operationCoordinator.registerOperation(
            .analysis(memoId: memoId, analysisType: .distill)
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
            print("🗓️ [Detect] thresholds event=\(eventThreshold) reminder=\(reminderThreshold) context hasDates=\(detectionContext.hasDatesOrTimes) hasCalendarPhrases=\(detectionContext.hasCalendarPhrases)")
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
        try await performCloudDetection(
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
        let requestContext = AnalysisRequestContext(correlationId: correlationId, memoId: memoId)
        async let eventsResult: AnalyzeEnvelope<EventsData> = analysisService.analyze(
            mode: .events,
            transcript: transcript,
            responseType: EventsData.self,
            historicalContext: nil,
            context: requestContext
        )
        async let remindersResult: AnalyzeEnvelope<RemindersData> = analysisService.analyze(
            mode: .reminders,
            transcript: transcript,
            responseType: RemindersData.self,
            historicalContext: nil,
            context: requestContext
        )

        // Process results and filter by confidence
        let eventsEnvelope = try await eventsResult
        let remindersEnvelope = try await remindersResult

        // Validate server output before thresholding
        let validatedEvents = DetectionValidator.validateEvents(eventsEnvelope.data)
        let validatedReminders = DetectionValidator.validateReminders(remindersEnvelope.data)
        print("🗓️ [Detect] raw counts events=\(eventsEnvelope.data.events.count) reminders=\(remindersEnvelope.data.reminders.count)")
        print("🗓️ [Detect] validated counts events=\(validatedEvents?.events.count ?? 0) reminders=\(validatedReminders?.reminders.count ?? 0)")

        let eventFilterOutcome = filterEventsByConfidence(
            validatedEvents,
            threshold: eventThreshold,
            nearMissMargin: nearMissMargin
        )
        var filteredEvents = eventFilterOutcome.accepted
        logNearMisses(
            kind: "events",
            nearMisses: eventFilterOutcome.nearMisses,
            threshold: eventThreshold,
            memoId: memoId,
            correlationId: context.correlationId,
            transcript: transcript
        )

        let reminderFilterOutcome = filterRemindersByConfidence(
            validatedReminders,
            threshold: reminderThreshold,
            nearMissMargin: nearMissMargin
        )
        var filteredReminders = reminderFilterOutcome.accepted
        logNearMisses(
            kind: "reminders",
            nearMisses: reminderFilterOutcome.nearMisses,
            threshold: reminderThreshold,
            memoId: memoId,
            correlationId: context.correlationId,
            transcript: transcript
        )

        // Smart fallback: if nothing passes thresholds but raw contains items,
        // include the strongest candidates at a relaxed bound to aid recall.
        if filteredEvents == nil, !eventsEnvelope.data.events.isEmpty {
            let fallback = eventsEnvelope.data.events
                .sorted { $0.confidence > $1.confidence }
                .prefix(2)
                .filter { $0.confidence >= max(0.40, eventThreshold - 0.25) }
            if !fallback.isEmpty { filteredEvents = EventsData(events: Array(fallback)) }
        }
        if filteredReminders == nil, !remindersEnvelope.data.reminders.isEmpty {
            let fallback = remindersEnvelope.data.reminders
                .sorted { $0.confidence > $1.confidence }
                .prefix(3)
                .filter { $0.confidence >= max(0.40, reminderThreshold - 0.25) }
            if !fallback.isEmpty { filteredReminders = RemindersData(reminders: Array(fallback)) }
        }
        print("🗓️ [Detect] filtered counts events=\(filteredEvents?.events.count ?? 0) reminders=\(filteredReminders?.reminders.count ?? 0)")

        logConfidenceStats(
            kind: "events",
            threshold: eventThreshold,
            rawScores: validatedEvents?.events.map { $0.confidence } ?? [],
            acceptedCount: eventFilterOutcome.accepted?.events.count ?? 0,
            finalCount: filteredEvents?.events.count ?? 0,
            context: context
        )

        logConfidenceStats(
            kind: "reminders",
            threshold: reminderThreshold,
            rawScores: validatedReminders?.reminders.map { $0.confidence } ?? [],
            acceptedCount: reminderFilterOutcome.accepted?.reminders.count ?? 0,
            finalCount: filteredReminders?.reminders.count ?? 0,
            context: context
        )

        // Temporal refinement: adjust times when explicit phrases like "6 p.m." are present
        filteredEvents = TemporalRefiner.refine(eventsData: filteredEvents, transcript: transcript) ?? filteredEvents
        filteredReminders = TemporalRefiner.refine(remindersData: filteredReminders, transcript: transcript) ?? filteredReminders

        // Domain-level deduplication to prevent overlap across events/reminders
        let preDedupEventCount = filteredEvents?.events.count ?? 0
        let preDedupReminderCount = filteredReminders?.reminders.count ?? 0
        let deduped = DeduplicationService.dedupe(events: filteredEvents, reminders: filteredReminders)
        filteredEvents = deduped.events
        filteredReminders = deduped.reminders

        // Log post-dedup deltas and small samples for diagnostics
        let postDedupEventCount = filteredEvents?.events.count ?? 0
        let postDedupReminderCount = filteredReminders?.reminders.count ?? 0
        let removedEvents = max(0, preDedupEventCount - postDedupEventCount)
        let removedReminders = max(0, preDedupReminderCount - postDedupReminderCount)

        func eventSamples(_ data: EventsData?) -> [[String: Any]] {
            guard let data else { return [] }
            return Array(data.events.prefix(3)).map { e in
                [
                    "id": e.id,
                    "title": e.title,
                    "confidence": Double(e.confidence),
                    "start": e.startDate?.ISO8601Format() ?? "",
                    "hasLocation": (e.location?.isEmpty == false),
                    "hasParticipants": !(e.participants?.isEmpty ?? true)
                ]
            }
        }
        func reminderSamples(_ data: RemindersData?) -> [[String: Any]] {
            guard let data else { return [] }
            return Array(data.reminders.prefix(3)).map { r in
                [
                    "id": r.id,
                    "title": r.title,
                    "confidence": Double(r.confidence),
                    "due": r.dueDate?.ISO8601Format() ?? "",
                    "priority": r.priority.rawValue
                ]
            }
        }

        logger.info(
            "Detection.PostDedup",
            category: .detection,
            context: LogContext(
                correlationId: context.correlationId,
                additionalInfo: [
                    "preEvents": preDedupEventCount,
                    "preReminders": preDedupReminderCount,
                    "postEvents": postDedupEventCount,
                    "postReminders": postDedupReminderCount,
                    "removedEvents": removedEvents,
                    "removedReminders": removedReminders,
                    "eventSamples": eventSamples(filteredEvents),
                    "reminderSamples": reminderSamples(filteredReminders)
                ].merging(context.additionalInfo ?? [:]) { current, _ in current }
            )
        )

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

    private func filterEventsByConfidence(
        _ eventsData: EventsData?,
        threshold: Float,
        nearMissMargin: Float
    ) -> (accepted: EventsData?, nearMisses: [NearMissInfo]) {
        guard let eventsData = eventsData else { return (nil, []) }

        var accepted: [EventsData.DetectedEvent] = []
        var nearMisses: [NearMissInfo] = []
        let lowerBound = max(0, threshold - nearMissMargin)

        for event in eventsData.events {
            if event.confidence >= threshold {
                accepted.append(event)
            } else if event.confidence >= lowerBound {
                nearMisses.append(
                    NearMissInfo(
                        id: event.id,
                        title: event.title,
                        confidence: event.confidence,
                        sourceText: event.sourceText,
                        startDate: event.startDate,
                        endDate: event.endDate,
                        dueDate: nil,
                        memoId: event.memoId
                    )
                )
            }
        }

        logger.debug(
            "Filtered events by confidence: \(eventsData.events.count) → \(accepted.count) (threshold: \(threshold))",
            category: .analysis,
            context: nil
        )

        let acceptedData = accepted.isEmpty ? nil : EventsData(events: accepted)
        return (acceptedData, nearMisses)
    }

    private func filterRemindersByConfidence(
        _ remindersData: RemindersData?,
        threshold: Float,
        nearMissMargin: Float
    ) -> (accepted: RemindersData?, nearMisses: [NearMissInfo]) {
        guard let remindersData = remindersData else { return (nil, []) }

        var accepted: [RemindersData.DetectedReminder] = []
        var nearMisses: [NearMissInfo] = []
        let lowerBound = max(0, threshold - nearMissMargin)

        for reminder in remindersData.reminders {
            if reminder.confidence >= threshold {
                accepted.append(reminder)
            } else if reminder.confidence >= lowerBound {
                nearMisses.append(
                    NearMissInfo(
                        id: reminder.id,
                        title: reminder.title,
                        confidence: reminder.confidence,
                        sourceText: reminder.sourceText,
                        startDate: nil,
                        endDate: nil,
                        dueDate: reminder.dueDate,
                        memoId: reminder.memoId
                    )
                )
            }
        }

        logger.debug(
            "Filtered reminders by confidence: \(remindersData.reminders.count) → \(accepted.count) (threshold: \(threshold))",
            category: .analysis,
            context: nil
        )

        let acceptedData = accepted.isEmpty ? nil : RemindersData(reminders: accepted)
        return (acceptedData, nearMisses)
    }

    private func logNearMisses(
        kind: String,
        nearMisses: [NearMissInfo],
        threshold: Float,
        memoId: UUID,
        correlationId: String?,
        transcript: String
    ) {
        guard !nearMisses.isEmpty else { return }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        isoFormatter.timeZone = TimeZone(secondsFromGMT: 0)

        let lowerBound = max(0, threshold - nearMissMargin)
        let candidates: [[String: Any]] = nearMisses.map { info in
            var payload: [String: Any] = [
                "id": info.id,
                "title": info.title,
                "confidence": Double(info.confidence),
                "delta": Double(max(0, threshold - info.confidence)),
                "sourceText": info.sourceText.isEmpty ? String(transcript.prefix(160)) : info.sourceText
            ]
            if let start = info.startDate {
                payload["startDate"] = isoFormatter.string(from: start)
            }
            if let end = info.endDate {
                payload["endDate"] = isoFormatter.string(from: end)
            }
            if let due = info.dueDate {
                payload["dueDate"] = isoFormatter.string(from: due)
            }
            if let memo = info.memoId {
                payload["candidateMemoId"] = memo.uuidString
            }
            return payload
        }

        let info: [String: Any] = [
            "memoId": memoId.uuidString,
            "mode": kind,
            "threshold": Double(threshold),
            "nearMissLowerBound": Double(lowerBound),
            "candidateCount": nearMisses.count,
            "candidates": candidates
        ]

        logger.info(
            "Detection.NearMiss",
            category: .detection,
            context: LogContext(
                correlationId: correlationId,
                additionalInfo: info
            )
        )
    }

    private func logConfidenceStats(
        kind: String,
        threshold: Float,
        rawScores: [Float],
        acceptedCount: Int,
        finalCount: Int,
        context: LogContext
    ) {
        var info: [String: Any] = [
            "mode": kind,
            "threshold": Double(threshold),
            "rawCount": rawScores.count,
            "acceptedCount": acceptedCount,
            "finalCount": finalCount,
            "fallbackCount": max(0, finalCount - acceptedCount),
            "histogram": confidenceHistogram(for: rawScores)
        ]

        if let min = rawScores.min() {
            info["minScore"] = Double(min)
        }

        if let max = rawScores.max() {
            info["maxScore"] = Double(max)
        }

        if !rawScores.isEmpty {
            let sum = rawScores.reduce(0, +)
            info["averageScore"] = Double(sum / Float(rawScores.count))
        }

        logger.info(
            "Detection.ConfidenceStats",
            category: .analysis,
            context: LogContext(
                correlationId: context.correlationId,
                additionalInfo: info.merging(context.additionalInfo ?? [:]) { current, _ in current }
            )
        )
    }

    private func confidenceHistogram(for scores: [Float]) -> [String: Int] {
        let buckets: [(lower: Float, upper: Float, label: String)] = [
            (0.0, 0.2, "0.0-0.2"),
            (0.2, 0.3, "0.2-0.3"),
            (0.3, 0.4, "0.3-0.4"),
            (0.4, 0.5, "0.4-0.5"),
            (0.5, 0.6, "0.5-0.6"),
            (0.6, 0.7, "0.6-0.7"),
            (0.7, 0.8, "0.7-0.8"),
            (0.8, 0.9, "0.8-0.9"),
            (0.9, 1.01, "0.9-1.0")
        ]

        var histogram = Dictionary(uniqueKeysWithValues: buckets.map { ($0.label, 0) })

        for score in scores {
            guard score >= 0 else { continue }
            if let bucket = buckets.first(where: { score >= $0.lower && score < $0.upper }) {
                histogram[bucket.label, default: 0] += 1
            } else if score >= 1.0 { // Handle potential rounding to exactly 1.0
                histogram["0.9-1.0", default: 0] += 1
            }
        }

        return histogram
    }

    private struct NearMissInfo: Sendable {
        let id: String
        let title: String
        let confidence: Float
        let sourceText: String
        let startDate: Date?
        let endDate: Date?
        let dueDate: Date?
        let memoId: UUID?
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
        await analysisRepository.getAnalysisResult(
            for: memoId,
            mode: mode,
            responseType: T.self
        )?.data
    }

    private func cacheAnalysisResult<T: Codable & Sendable>(
        _ data: T,
        for memoId: UUID,
        mode: AnalysisMode
    ) async {
        let envelope = AnalyzeEnvelope(
            mode: mode,
            data: data,
            model: "gpt-5-mini",
            tokens: TokenUsage(input: 0, output: 0), // Simplified for now
            latency_ms: 0, // Simplified for now
            moderation: nil
        )

        await analysisRepository.saveAnalysisResult(envelope, for: memoId, mode: mode)
    }
}

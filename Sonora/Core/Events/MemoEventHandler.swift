import Foundation

/// Primary event handler for memo-related events
/// Handles cross-cutting concerns like logging, analytics, and audit trail
@MainActor
public final class MemoEventHandler {
    
    // MARK: - Dependencies
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol
    private let transcriptionRepository: any TranscriptionRepository
    private let subscriptionManager: EventSubscriptionManager
    
    // MARK: - Analytics Tracking
    private var memoCount: Int = 0
    private var transcriptionStartTime: [UUID: Date] = [:]
    private var analysisStartTime: [UUID: Date] = [:]
    private var eventAuditTrail: [(Date, AppEvent)] = []
    
    // MARK: - Configuration
    private let maxAuditTrailEvents = 100
    
    // MARK: - Initialization
    init(
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol = EventBus.shared,
        transcriptionRepository: any TranscriptionRepository
    ) {
        self.logger = logger
        self.eventBus = eventBus
        self.transcriptionRepository = transcriptionRepository
        self.subscriptionManager = EventSubscriptionManager(eventBus: eventBus)
        
        // Subscribe to all memo-related events
        setupEventSubscriptions()
        
        logger.info("MemoEventHandler initialized and subscribed to events", 
                   category: .system, 
                   context: LogContext())
    }
    
    // MARK: - Event Subscriptions
    private func setupEventSubscriptions() {
        // Subscribe to all AppEvent types
        subscriptionManager.subscribe(to: AppEvent.self) { [weak self] event in
            Task { @MainActor in
                await self?.handleEvent(event)
            }
        }
        
        logger.debug("MemoEventHandler subscribed to all app events", 
                    category: .system, 
                    context: LogContext())
    }
    
    // MARK: - Event Handling
    private func handleEvent(_ event: AppEvent) async {
        let correlationId = UUID().uuidString
        let context = LogContext(
            correlationId: correlationId,
            additionalInfo: [
                "eventCategory": event.category.rawValue,
                "memoId": event.memoId?.uuidString ?? "unknown"
            ]
        )
        
        // Add to audit trail
        addToAuditTrail(event)
        
        // Log the event
        logger.info("Processing event: \(event.description)", 
                   category: .useCase, 
                   context: context)
        
        // Handle specific event types
        switch event {
        case .memoCreated(let domainMemo):
            await handleMemoCreated(domainMemo, correlationId: correlationId)
            
        case .recordingStarted(let memoId):
            await handleRecordingStarted(memoId, correlationId: correlationId)
            
        case .recordingCompleted(let memoId):
            await handleRecordingCompleted(memoId, correlationId: correlationId)
            
        case .transcriptionCompleted(let memoId, let text):
            await handleTranscriptionCompleted(memoId: memoId, text: text, correlationId: correlationId)
            
        case .analysisCompleted(let memoId, let type, let result):
            await handleAnalysisCompleted(memoId: memoId, type: type, result: result, correlationId: correlationId)
        case .transcriptionRouteDecided:
            // Audit only; UI reacts elsewhere
            break
        case .transcriptionProgress:
            // Progress is handled by UI; keep audit only
            break
        case .navigatePopToRootMemos:
            break
        case .navigateOpenMemoByID(memoId: _):
            break
        case .whisperModelNormalized(previous: _, normalized: _):
            break
        case .microphonePermissionStatusChanged(status: _):
            break
        case .calendarEventCreated(_, _),
             .eventCreationFailed(_, _),
             .batchEventCreationCompleted(_, _, _),
             .eventConflictDetected(_, _),
             .reminderCreated(_, _),
             .reminderCreationFailed(_, _),
             .batchReminderCreationCompleted(_, _, _):
            // EventKit-specific events are handled by their respective handlers
            break
        }
        
        // Update analytics
        updateAnalytics(for: event)
    }
    
    // MARK: - Specific Event Handlers
    
    private func handleMemoCreated(_ domainMemo: Memo, correlationId: String) async {
        let context = LogContext(
            correlationId: correlationId,
            additionalInfo: [
                "memoId": domainMemo.id.uuidString,
                "filename": domainMemo.filename,
                "fileSize": domainMemo.formattedFileSize
            ]
        )
        
        logger.info("New memo created: \(domainMemo.filename)", 
                   category: .useCase, 
                   context: context)
        
        // Track memo creation metrics
        memoCount += 1
        
        // Log file metadata for debugging
        logger.debug("Memo metadata - Size: \(domainMemo.formattedFileSize), Extension: \(domainMemo.fileExtension)", 
                    category: .useCase, 
                    context: context)

        // Start transcription (idempotent) – single orchestrator to avoid duplicates
        Task { @MainActor in
            // Defensive: ensure file exists before triggering work (protects imported/test memos)
            guard FileManager.default.fileExists(atPath: domainMemo.fileURL.path) else {
                logger.warning("Skipping transcription: audio file missing", category: .transcription, context: context, error: nil)
                return
            }
            let state = transcriptionRepository.getTranscriptionState(for: domainMemo.id)
            // Only start if nothing has begun yet
            guard state.isNotStarted else { return }
            do {
                try await DIContainer.shared.startTranscriptionUseCase().execute(memo: domainMemo)
            } catch {
                // Non-fatal: log and continue. Already-completed/in-progress errors are expected in races.
                Logger.shared.debug("StartTranscriptionUseCase skipped/failed for memoCreated: \(error.localizedDescription)",
                                    category: .transcription,
                                    context: context)
            }
        }
    }
    
    private func handleRecordingStarted(_ memoId: UUID, correlationId: String) async {
        let context = LogContext(
            correlationId: correlationId,
            additionalInfo: ["memoId": memoId.uuidString, "phase": "recording_started"]
        )
        
        logger.info("Recording started for memo: \(memoId)", 
                   category: .audio, 
                   context: context)
    }
    
    private func handleRecordingCompleted(_ memoId: UUID, correlationId: String) async {
        let context = LogContext(
            correlationId: correlationId,
            additionalInfo: ["memoId": memoId.uuidString, "phase": "recording_completed"]
        )
        
        logger.info("Recording completed for memo: \(memoId)", 
                   category: .audio, 
                   context: context)
        
        // Start tracking transcription time
        transcriptionStartTime[memoId] = Date()
    }
    
    private func handleTranscriptionCompleted(memoId: UUID, text: String, correlationId: String) async {
        // Calculate transcription duration
        let duration = transcriptionStartTime[memoId].map { Date().timeIntervalSince($0) }
        transcriptionStartTime.removeValue(forKey: memoId)
        
        // Pre-calculate metrics to avoid complex expression
        let wordsCount = text.split(separator: " ").count
        let wordsPerMinute: Double
        if let duration = duration, duration > 0 {
            wordsPerMinute = Double(wordsCount) / max(duration / 60, 0.1)
        } else {
            wordsPerMinute = 0
        }
        
        // Fetch transcription metadata to report the service used (local WhisperKit vs Cloud API)
        let serviceMeta: (serviceKey: String, serviceLabel: String, whisperModel: String?) = {
            let meta = transcriptionRepository.getTranscriptionMetadata(for: memoId)
            let key = meta?.transcriptionService?.rawValue ?? "unknown"
            let label: String
            switch meta?.transcriptionService {
            case .some(.localWhisperKit): label = "WhisperKit (local)"
            case .some(.cloudAPI): label = "Cloud API"
            default: label = "unknown"
            }
            let model = meta?.whisperModel
            return (key, label, model)
        }()

        var info: [String: Any] = [
            "memoId": memoId.uuidString,
            "textLength": text.count,
            "transcriptionDurationSeconds": duration?.rounded() ?? 0,
            "wordsPerMinute": wordsPerMinute,
            "service": serviceMeta.serviceLabel,
            "serviceKey": serviceMeta.serviceKey
        ]
        if let model = serviceMeta.whisperModel { info["whisperModel"] = model }

        let context = LogContext(
            correlationId: correlationId,
            additionalInfo: info
        )

        logger.info("Transcription completed via \(serviceMeta.serviceLabel) for memo: \(memoId)",
                   category: .transcription,
                   context: context)
        
        // Log transcription performance metrics
        if let duration = duration {
            logger.info("Transcription metrics - Duration: \(String(format: "%.1f", duration))s, Words: \(wordsCount), WPM: \(String(format: "%.1f", wordsPerMinute))", 
                       category: .transcription, 
                       context: context)
        }
        
        // Start tracking analysis time
        analysisStartTime[memoId] = Date()

        // Auto-detect events/reminders if integration is enabled and transcript suggests scheduling language
        guard FeatureFlags.useEventKitIntegration else { return }
        let defaults = UserDefaults.standard
        let autoEvents = defaults.object(forKey: "autoDetectEvents") as? Bool ?? true
        let autoReminders = defaults.object(forKey: "autoDetectReminders") as? Bool ?? true
        if (autoEvents || autoReminders) && shouldRunEventDetection(transcript: text) {
            logger.info("Auto-detection trigger conditions met; starting detection", category: .analysis, context: context)
            Task { @MainActor in
                do {
                    let result = try await DIContainer.shared.detectEventsAndRemindersUseCase().execute(transcript: text, memoId: memoId)
                    let eventsCount = autoEvents ? (result.events?.events.count ?? 0) : 0
                    let remindersCount = autoReminders ? (result.reminders?.reminders.count ?? 0) : 0
                    logger.info("Auto-detection completed: events=\(eventsCount), reminders=\(remindersCount)", category: .analysis, context: context)
                } catch {
                    logger.warning("Auto-detection failed: \(error.localizedDescription)", category: .analysis, context: context, error: error)
                }
            }
        }
    }

    // Simple heuristic to decide if we should run detection
    private func shouldRunEventDetection(transcript: String) -> Bool {
        let lower = transcript.lowercased()
        let eventKeywords = ["meet", "meeting", "appointment", "tomorrow", "next", "pm", "am", "call", "schedule", "at "]
        let reminderKeywords = ["remember", "remind", "don't forget", "dont forget", "todo", "follow up", "buy", "send", "pick up"]
        let hasEventLanguage = eventKeywords.contains { lower.contains($0) }
        let hasReminderLanguage = reminderKeywords.contains { lower.contains($0) }

        // Quick date/time detection using NSDataDetector
        var hasDateTime = false
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) {
            let range = NSRange(lower.startIndex..<lower.endIndex, in: lower)
            let matches = detector.matches(in: lower, options: [], range: range)
            hasDateTime = !matches.isEmpty
        }

        let hasEnoughWords = transcript.split(separator: " ").count > 5
        return hasEnoughWords && (hasDateTime || hasEventLanguage || hasReminderLanguage)
    }
    
    private func handleAnalysisCompleted(memoId: UUID, type: AnalysisMode, result: String, correlationId: String) async {
        // Calculate analysis duration
        let duration = analysisStartTime[memoId].map { Date().timeIntervalSince($0) }
        
        let context = LogContext(
            correlationId: correlationId,
            additionalInfo: [
                "memoId": memoId.uuidString,
                "analysisType": type.rawValue,
                "resultLength": result.count,
                "analysisDurationSeconds": duration?.rounded() ?? 0
            ]
        )
        
        logger.info("Analysis completed for memo: \(memoId) - Type: \(type.displayName)", 
                   category: .analysis, 
                   context: context)
        
        // Log analysis performance metrics
        if let duration = duration {
            logger.info("Analysis metrics - Type: \(type.displayName), Duration: \(String(format: "%.1f", duration))s, Result: \(result.prefix(50))...", 
                       category: .analysis, 
                       context: context)
        }
        
        // Clean up analysis start time when all analyses might be done
        // (In a real implementation, you'd track multiple analysis types per memo)
        analysisStartTime.removeValue(forKey: memoId)
    }
    
    // MARK: - Analytics & Metrics
    
    private func updateAnalytics(for event: AppEvent) {
        // Update internal metrics based on event type
        switch event.category {
        case .memo:
            // Memo-related analytics already handled in specific handlers
            break
        case .recording:
            // Recording metrics tracking
            break
        case .transcription:
            // Transcription success rate tracking
            break
        case .analysis:
            // Analysis completion tracking
            break
        }
    }
    
    private func addToAuditTrail(_ event: AppEvent) {
        eventAuditTrail.append((Date(), event))
        
        // Maintain maximum audit trail size
        if eventAuditTrail.count > maxAuditTrailEvents {
            eventAuditTrail.removeFirst()
        }
    }
    
    // MARK: - Public Analytics Access
    
    /// Get current memo count tracked by this handler
    public var currentMemoCount: Int {
        return memoCount
    }
    
    /// Get recent events from audit trail
    public func getRecentEvents(limit: Int = 10) -> [(Date, AppEvent)] {
        return Array(eventAuditTrail.suffix(limit))
    }
    
    /// Get handler statistics for debugging
    public var handlerStatistics: String {
        return """
        MemoEventHandler Statistics:
        - Total memos tracked: \(memoCount)
        - Pending transcriptions: \(transcriptionStartTime.count)
        - Pending analyses: \(analysisStartTime.count)
        - Audit trail events: \(eventAuditTrail.count)
        """
    }
    
    // MARK: - Cleanup
    deinit {
        subscriptionManager.cleanup()
        // Avoid actor-hopping or logging from deinit to prevent isolation issues.
    }
}

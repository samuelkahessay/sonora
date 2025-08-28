import Foundation

/// Primary event handler for memo-related events
/// Handles cross-cutting concerns like logging, analytics, and audit trail
@MainActor
public final class MemoEventHandler {
    
    // MARK: - Dependencies
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol
    private let subscriptionManager: EventSubscriptionManager
    
    // MARK: - Analytics Tracking
    private var memoCount: Int = 0
    private var transcriptionStartTime: [UUID: Date] = [:]
    private var analysisStartTime: [UUID: Date] = [:]
    private var eventAuditTrail: [(Date, AppEvent)] = []
    
    // MARK: - Configuration
    private let maxAuditTrailEvents = 100
    
    // MARK: - Initialization
    public init(
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol = EventBus.shared
    ) {
        self.logger = logger
        self.eventBus = eventBus
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
        }
        
        // Update analytics
        updateAnalytics(for: event)
    }
    
    // MARK: - Specific Event Handlers
    
    private func handleMemoCreated(_ domainMemo: DomainMemo, correlationId: String) async {
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
        
        let context = LogContext(
            correlationId: correlationId,
            additionalInfo: [
                "memoId": memoId.uuidString,
                "textLength": text.count,
                "transcriptionDurationSeconds": duration?.rounded() ?? 0,
                "wordsPerMinute": wordsPerMinute
            ]
        )
        
        logger.info("Transcription completed for memo: \(memoId)", 
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
        logger.debug("MemoEventHandler cleaned up subscriptions", 
                    category: .system, 
                    context: LogContext())
    }
}

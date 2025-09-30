import Foundation
import AVFoundation
import UIKit
import UserNotifications

/// Primary event handler for memo-related events
/// Handles cross-cutting concerns like logging, analytics, and audit trail
@MainActor
public final class MemoEventHandler {
    
    // MARK: - Dependencies
    private let logger: any LoggerProtocol
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
        case .promptShown(_, _, _, _, _),
             .promptUsed(_, _, _, _, _),
             .promptFavoritedToggled(_, _):
            // Prompt analytics handled separately; audit only
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
                // Gate against monthly quota (Pro: unlimited)
                let remaining = try await DIContainer.shared.getRemainingMonthlyQuotaUseCase().execute()
                if remaining.isFinite {
                    // Determine required seconds for this memo
                    let required: TimeInterval
                    if let secs = domainMemo.durationSeconds {
                        required = max(0, secs)
                    } else {
                        let asset = AVURLAsset(url: domainMemo.fileURL)
                        if let dur = try? await asset.load(.duration) {
                            required = max(0, CMTimeGetSeconds(dur))
                        } else {
                            required = 0
                        }
                    }

                    if required > remaining {
                        // Fail immediately and do not start API work
                        let message = "Monthly quota reached"
                        self.transcriptionRepository.saveTranscriptionState(.failed(message), for: domainMemo.id)
                        self.logger.info("Transcription blocked by monthly quota (required=\(Int(required))s, remaining=\(Int(remaining))s)",
                                         category: .transcription,
                                         context: context)
                        return
                    }
                }

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
        
        // Fetch transcription metadata to report the service used
        let serviceMeta: (serviceKey: String, serviceLabel: String) = {
            let meta = transcriptionRepository.getTranscriptionMetadata(for: memoId)
            let key = meta?.transcriptionService?.rawValue ?? "unknown"
            let label = (meta?.transcriptionService == .cloudAPI) ? "Cloud API" : "unknown"
            return (key, label)
        }()

        let info: [String: Any] = [
            "memoId": memoId.uuidString,
            "textLength": text.count,
            "transcriptionDurationSeconds": duration?.rounded() ?? 0,
            "wordsPerMinute": wordsPerMinute,
            "service": serviceMeta.serviceLabel,
            "serviceKey": serviceMeta.serviceKey
        ]

        let context = LogContext(
            correlationId: correlationId,
            additionalInfo: info
        )

        logger.info("Transcription completed via \(serviceMeta.serviceLabel) for memo: \(memoId)",
                   category: .transcription,
                   context: context)
        await scheduleTranscriptionCompletionNotificationIfNeeded(memoId: memoId, wordsCount: wordsCount)
        
        // Log transcription performance metrics
        if let duration = duration {
            logger.info("Transcription metrics - Duration: \(String(format: "%.1f", duration))s, Words: \(wordsCount), WPM: \(String(format: "%.1f", wordsPerMinute))", 
                       category: .transcription, 
                       context: context)
        }
        
        // Start tracking analysis time
        analysisStartTime[memoId] = Date()

        // Record monthly usage (counts audio seconds transcribed via cloud)
        Task { @MainActor in
            let usageRepo = DIContainer.shared.recordingUsageRepository()
            let memo = DIContainer.shared.memoRepository().getMemo(by: memoId)
            let seconds = memo?.durationSeconds ?? 0
            if seconds > 0 {
                await usageRepo.addMonthlyUsage(seconds, for: Date())
                self.logger.debug("Recorded monthly usage: \(Int(seconds))s for memo \(memoId)",
                                   category: .transcription,
                                   context: context)
            }
        }

        // Kick off Auto Title generation (non-blocking)
        // Use original text (with filler words) for better context
        Task { @MainActor in
            let originalText = transcriptionRepository.getTranscriptionMetadata(for: memoId)?.originalText ?? text
            await DIContainer.shared.generateAutoTitleUseCase().execute(memoId: memoId, transcript: originalText)
        }

        // Auto-detection disabled: Events/Reminders run when Distill is invoked
        // If needed in the future, gate via explicit setting keys below (default false)
        // let autoEvents = UserDefaults.standard.object(forKey: "autoDetectEvents") as? Bool ?? false
        // let autoReminders = UserDefaults.standard.object(forKey: "autoDetectReminders") as? Bool ?? false
        // Intentionally no-op here per product direction
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

private extension MemoEventHandler {
    func scheduleTranscriptionCompletionNotificationIfNeeded(memoId: UUID, wordsCount: Int) async {
        let appState = await MainActor.run { UIApplication.shared.applicationState }
        guard appState != .active else { return }

        let center = UNUserNotificationCenter.current()
        guard await ensureNotificationAuthorization(center: center) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Transcription Complete"
        if wordsCount > 0 {
            content.body = "Your memo is ready to review (\(wordsCount) words)."
        } else {
            content.body = "Your memo transcription is ready to review."
        }
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "transcription.\(memoId.uuidString)",
            content: content,
            trigger: nil
        )

        do {
            try await addNotificationRequest(request, center: center)
        } catch {
            logger.warning("Failed to schedule transcription completion notification", category: .transcription, context: nil, error: error)
        }
    }

    func ensureNotificationAuthorization(center: UNUserNotificationCenter) async -> Bool {
        let status = await fetchNotificationAuthorizationStatus(center: center)
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            do {
                return try await requestNotificationAuthorization(center: center)
            } catch {
                logger.warning("Notification authorization request failed", category: .transcription, context: nil, error: error)
                return false
            }
        @unknown default:
            return false
        }
    }

    func fetchNotificationAuthorizationStatus(center: UNUserNotificationCenter) async -> UNAuthorizationStatus {
        await withCheckedContinuation { (continuation: CheckedContinuation<UNAuthorizationStatus, Never>) in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestNotificationAuthorization(center: UNUserNotificationCenter) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: granted)
                }
            }
        }
    }

    func addNotificationRequest(_ request: UNNotificationRequest, center: UNUserNotificationCenter) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            center.add(request) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: ())
                }
            }
        }
    }
}

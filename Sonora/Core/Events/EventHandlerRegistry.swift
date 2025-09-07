import Foundation

/// Centralized registry for managing all event handlers
/// Provides lifecycle management, registration, and debugging capabilities
@MainActor
public final class EventHandlerRegistry {
    
    // MARK: - Singleton
    private static let _shared = EventHandlerRegistry()
    nonisolated(unsafe) public static var shared: EventHandlerRegistry { MainActor.assumeIsolated { _shared } }
    
    // MARK: - Dependencies
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol
    
    // MARK: - Handler Management
    private var registeredHandlers: [String: Any] = [:]
    private var handlerStatus: [String: Bool] = [:]
    private var didRegisterAll: Bool = false
    
    // MARK: - Handler Instances
    private var memoEventHandler: MemoEventHandler?
    private var calendarEventHandler: CalendarEventHandler?
    private var remindersEventHandler: RemindersEventHandler?
    private var liveActivityEventHandler: LiveActivityEventHandler?
    private var spotlightEventHandler: SpotlightEventHandler?
    private var whisperKitEventHandler: WhisperKitEventHandler?
    
    // MARK: - Configuration
    private let enabledHandlers: Set<String> = [
        "MemoEventHandler",         // Always enabled for cross-cutting concerns
        "CalendarEventHandler",     // Calendar integration (auto-detect gated by settings)
        "RemindersEventHandler",     // Reminders integration (auto-detect gated by settings)
        "LiveActivityEventHandler",  // Live Activities for recording
        "WhisperKitEventHandler"     // Whisper model lifecycle optimization
    ]
    
    // MARK: - Initialization
    private init(
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol = EventBus.shared
    ) {
        self.logger = logger
        self.eventBus = eventBus
        
        logger.info("EventHandlerRegistry initialized", 
                   category: .system, 
                   context: LogContext())
    }
    
    // MARK: - Handler Registration
    
    /// Register all standard event handlers
    public func registerAllHandlers() {
        guard !didRegisterAll else {
            logger.debug("EventHandlerRegistry: registerAllHandlers called more than once – ignoring", category: .system, context: LogContext())
            return
        }
        didRegisterAll = true
        logger.info("Registering all event handlers", 
                   category: .system, 
                   context: LogContext())
        
        // Register memo event handler (core functionality)
        registerMemoEventHandler()
        
        // Register placeholder handlers for future features
        registerCalendarEventHandler()
        registerRemindersEventHandler()
        registerLiveActivityEventHandler()
        registerSpotlightEventHandler()
        registerWhisperKitEventHandler()
        
        // Log registration summary
        let activeCount = handlerStatus.values.filter { $0 }.count
        let totalCount = handlerStatus.count
        
        logger.info("Event handler registration complete - \(activeCount)/\(totalCount) handlers active", 
                   category: .system, 
                   context: LogContext(additionalInfo: [
                       "activeHandlers": activeCount,
                       "totalHandlers": totalCount,
                       "handlers": Array(registeredHandlers.keys)
                   ]))
    }
    
    /// Register the core memo event handler
    private func registerMemoEventHandler() {
        let handlerName = "MemoEventHandler"
        let isEnabled = enabledHandlers.contains(handlerName)
        
        if isEnabled {
            let trRepo = DIContainer.shared.transcriptionRepository()
            memoEventHandler = MemoEventHandler(logger: logger, eventBus: eventBus, transcriptionRepository: trRepo)
            registeredHandlers[handlerName] = memoEventHandler
            handlerStatus[handlerName] = true
            
            logger.info("Registered and activated MemoEventHandler", 
                       category: .system, 
                       context: LogContext())
        } else {
            handlerStatus[handlerName] = false
            logger.debug("MemoEventHandler disabled in configuration", 
                        category: .system, 
                        context: LogContext())
        }
    }
    
    /// Register the calendar event handler
    private func registerCalendarEventHandler() {
        let handlerName = "CalendarEventHandler"
        let isEnabled = enabledHandlers.contains(handlerName) && FeatureFlags.useEventKitIntegration

        calendarEventHandler = CalendarEventHandler(logger: logger, eventBus: eventBus)
        registeredHandlers[handlerName] = calendarEventHandler
        handlerStatus[handlerName] = isEnabled
        if isEnabled { calendarEventHandler?.enable() }

        logger.info("Registered CalendarEventHandler — active=\(isEnabled)",
                    category: .system,
                    context: LogContext())
    }
    
    /// Register the reminders event handler
    private func registerRemindersEventHandler() {
        let handlerName = "RemindersEventHandler"
        let isEnabled = enabledHandlers.contains(handlerName) && FeatureFlags.useEventKitIntegration

        remindersEventHandler = RemindersEventHandler(logger: logger, eventBus: eventBus)
        registeredHandlers[handlerName] = remindersEventHandler
        handlerStatus[handlerName] = isEnabled
        if isEnabled { remindersEventHandler?.enable() }

        logger.info("Registered RemindersEventHandler — active=\(isEnabled)",
                    category: .system,
                    context: LogContext())
    }
    
    /// Register the Live Activity event handler
    private func registerLiveActivityEventHandler() {
        let handlerName = "LiveActivityEventHandler"
        let isEnabled = enabledHandlers.contains(handlerName)
        
        if isEnabled {
            liveActivityEventHandler = LiveActivityEventHandler(logger: logger, eventBus: eventBus)
            registeredHandlers[handlerName] = liveActivityEventHandler
            handlerStatus[handlerName] = true
            logger.info("Registered and activated LiveActivityEventHandler",
                        category: .system,
                        context: LogContext())
        } else {
            handlerStatus[handlerName] = false
            logger.debug("LiveActivityEventHandler disabled in configuration",
                        category: .system,
                        context: LogContext())
        }
    }

    /// Register the Spotlight event handler
    private func registerSpotlightEventHandler() {
        let handlerName = "SpotlightEventHandler"
        // Always register Spotlight; it internally respects the feature flag
        spotlightEventHandler = SpotlightEventHandler(logger: logger, eventBus: eventBus, indexer: DIContainer.shared.spotlightIndexer())
        registeredHandlers[handlerName] = spotlightEventHandler
        handlerStatus[handlerName] = true
        logger.info("Registered SpotlightEventHandler", category: .system, context: LogContext())
    }

    /// Register the WhisperKit lifecycle optimization handler
    private func registerWhisperKitEventHandler() {
        let handlerName = "WhisperKitEventHandler"
        let isEnabled = enabledHandlers.contains(handlerName)
        if isEnabled {
            whisperKitEventHandler = WhisperKitEventHandler(logger: logger, eventBus: eventBus)
            registeredHandlers[handlerName] = whisperKitEventHandler
            handlerStatus[handlerName] = true
            logger.info("Registered and activated WhisperKitEventHandler", category: .system, context: LogContext())
        } else {
            handlerStatus[handlerName] = false
            logger.debug("WhisperKitEventHandler disabled in configuration", category: .system, context: LogContext())
        }
    }
    
    // MARK: - Handler Management
    
    /// Enable a specific handler by name
    func enableHandler(_ handlerName: String) -> Bool {
        guard registeredHandlers[handlerName] != nil else {
            logger.warning("Attempted to enable unregistered handler: \(handlerName)", 
                          category: .system, 
                          context: LogContext(),
                          error: nil)
            return false
        }

        switch handlerName {
        case "CalendarEventHandler":
            calendarEventHandler?.enable()
            handlerStatus[handlerName] = true
            return true
        case "RemindersEventHandler":
            remindersEventHandler?.enable()
            handlerStatus[handlerName] = true
            return true
        default:
            logger.info("No-op enable for handler \(handlerName)", category: .system, context: LogContext())
            return false
        }
    }
    
    /// Disable a specific handler by name
    func disableHandler(_ handlerName: String) -> Bool {
        guard registeredHandlers[handlerName] != nil else {
            logger.warning("Attempted to disable unregistered handler: \(handlerName)", 
                          category: .system, 
                          context: LogContext(),
                          error: nil)
            return false
        }
        switch handlerName {
        case "CalendarEventHandler":
            calendarEventHandler?.disable()
            handlerStatus[handlerName] = false
            return true
        case "RemindersEventHandler":
            remindersEventHandler?.disable()
            handlerStatus[handlerName] = false
            return true
        default:
            logger.info("No-op disable for handler \(handlerName)", category: .system, context: LogContext())
            return false
        }
    }
    
    /// Unregister all handlers (cleanup)
    public func unregisterAllHandlers() {
        logger.info("Unregistering all event handlers", 
                   category: .system, 
                   context: LogContext())
        
        let handlerCount = registeredHandlers.count
        
        // Clean up handlers (they should handle their own cleanup in deinit)
        memoEventHandler = nil
        calendarEventHandler = nil
        remindersEventHandler = nil
        
        registeredHandlers.removeAll()
        handlerStatus.removeAll()
        
        logger.info("Unregistered \(handlerCount) event handlers", 
                   category: .system, 
                   context: LogContext())
    }
    
    // MARK: - Status and Debugging
    
    /// Get list of registered handler names
    public var registeredHandlerNames: [String] {
        return Array(registeredHandlers.keys).sorted()
    }
    
    /// Get list of active handler names
    public var activeHandlerNames: [String] {
        return handlerStatus.compactMap { key, value in
            value ? key : nil
        }.sorted()
    }
    
    /// Get detailed status information
    public var detailedStatus: String {
        let totalHandlers = registeredHandlers.count
        let activeHandlers = handlerStatus.values.filter { $0 }.count
        
        var status = """
        EventHandlerRegistry Status:
        - Total registered: \(totalHandlers)
        - Currently active: \(activeHandlers)
        
        Handler Details:
        """
        
        for (name, isActive) in handlerStatus.sorted(by: { $0.key < $1.key }) {
            let statusIcon = isActive ? "✅" : "⚪"
            let statusText = isActive ? "Active" : "Inactive"
            status += "\n  \(statusIcon) \(name): \(statusText)"
            
            // Add handler-specific details
            switch name {
            case "MemoEventHandler":
                if let handler = memoEventHandler {
                    status += " - Tracking \(handler.currentMemoCount) memos"
                }
            case "CalendarEventHandler":
                status += " - Placeholder implementation"
            case "RemindersEventHandler":
                status += " - Placeholder implementation"
            default:
                break
            }
        }
        
        return status
    }
    
    /// Get specific handler instance (for debugging)
    public func getHandler<T>(_ handlerName: String, as type: T.Type) -> T? {
        return registeredHandlers[handlerName] as? T
    }
    
    /// Test event flow by publishing a test event
    public func testEventFlow() {
        logger.info("Testing event flow with synthetic event", 
                   category: .system, 
                   context: LogContext())
        
        // Create a test memo for event flow testing
        let testMemo = Memo(
            filename: "Test Memo for Event Flow",
            fileURL: URL(fileURLWithPath: "/tmp/test.m4a"),
            creationDate: Date()
        )
        
        // Publish test event
        eventBus.publish(.memoCreated(testMemo))
        
        logger.info("Test event published - check handler logs for processing confirmation", 
                   category: .system, 
                   context: LogContext())
    }
    
    /// Get handler statistics for specific handler
    public func getHandlerStatistics(_ handlerName: String) -> String? {
        switch handlerName {
        case "MemoEventHandler":
            return memoEventHandler?.handlerStatistics
        case "CalendarEventHandler":
            return calendarEventHandler?.integrationStatus
        case "RemindersEventHandler":
            return remindersEventHandler?.integrationStatus
        default:
            return "Handler '\(handlerName)' not found or doesn't support statistics"
        }
    }
    
    /// Get registry performance metrics
    public var performanceMetrics: String {
        return """
        EventHandlerRegistry Performance:
        - Registration overhead: Minimal (one-time setup)
        - Memory usage: \(registeredHandlers.count) handler references
        - Event handling: Delegated to individual handlers
        - Cleanup: Automatic via ARC and handler deinit
        """
    }
    
    // MARK: - Cleanup
    deinit {
        // Handler cleanup is automatic via ARC since handlers clean up their own subscriptions
        // unregisterAllHandlers() is @MainActor isolated and cannot be called from deinit
    }
}

// MARK: - Protocol for DI

@MainActor
public protocol EventHandlerRegistryProtocol {
    func registerAllHandlers()
    func testEventFlow()
    var detailedStatus: String { get }
    func getHandler<T>(_ handlerName: String, as type: T.Type) -> T?
}

extension EventHandlerRegistry: EventHandlerRegistryProtocol {}

import Foundation
// No direct EventKit dependency here; repository returns DTOs

/// Event handler for calendar integration using EventKit and analysis results
@MainActor
final class CalendarEventHandler {
    // MARK: - Dependencies
    private let logger: any LoggerProtocol
    private let subscriptionManager: EventSubscriptionManager
    private let eventKitRepository: any EventKitRepository
    private let permissionService: any EventKitPermissionServiceProtocol
    private let createEventUseCase: any CreateCalendarEventUseCaseProtocol
    private let detectUseCase: any DetectEventsAndRemindersUseCaseProtocol

    // MARK: - State
    private var isEnabled: Bool = true

    // MARK: - Initialization
    init(
        logger: any LoggerProtocol,
        eventBus: any EventBusProtocol,
        eventKitRepository: any EventKitRepository,
        permissionService: any EventKitPermissionServiceProtocol,
        createEventUseCase: any CreateCalendarEventUseCaseProtocol,
        detectUseCase: any DetectEventsAndRemindersUseCaseProtocol
    ) {
        self.logger = logger
        self.subscriptionManager = EventSubscriptionManager(eventBus: eventBus)
        self.eventKitRepository = eventKitRepository
        self.permissionService = permissionService
        self.createEventUseCase = createEventUseCase
        self.detectUseCase = detectUseCase

        if isEnabled { setupEventSubscriptions() }
        logger.info("CalendarEventHandler initialized", category: .system, context: LogContext())
    }

    convenience init(logger: any LoggerProtocol = Logger.shared,
                     eventBus: any EventBusProtocol = EventBus.shared) {
        self.init(
            logger: logger,
            eventBus: eventBus,
            eventKitRepository: DIContainer.shared.eventKitRepository(),
            permissionService: DIContainer.shared.eventKitPermissionService(),
            createEventUseCase: DIContainer.shared.createCalendarEventUseCase(),
            detectUseCase: DIContainer.shared.detectEventsAndRemindersUseCase()
        )
    }

    // MARK: - Subscriptions
    private func setupEventSubscriptions() {
        subscriptionManager.subscribe(to: AppEvent.self) { [weak self] event in
            Task { @MainActor in
                await self?.handleEvent(event)
            }
        }
    }

    // MARK: - Event Handling
    private func handleEvent(_ event: AppEvent) async {
        guard isEnabled else { return }
        switch event {
        case .transcriptionCompleted(let memoId, let text):
            await handleTranscriptionCompleted(memoId: memoId, text: text)
        default:
            break
        }
    }

    private func handleTranscriptionCompleted(memoId: UUID, text: String) async {
        let defaults = UserDefaults.standard
        let autoEvents = defaults.object(forKey: "autoDetectEvents") as? Bool ?? false
        guard autoEvents else { return }

        await permissionService.checkCalendarPermission(ignoreCache: false)
        guard permissionService.calendarPermissionState.isAuthorized else { return }

        do {
            let detection = try await detectUseCase.execute(transcript: text, memoId: memoId)
            guard let events = detection.events?.events, !events.isEmpty else { return }

            for event in events {
                let suggested = try await eventKitRepository.suggestCalendar(for: event)
                var calendar = suggested
                if calendar == nil {
                    calendar = try await eventKitRepository.getDefaultCalendar()
                }
                guard let calendar else { continue }
                _ = try await createEventUseCase.execute(event: event, calendar: calendar)
            }
        } catch {
            logger.warning("CalendarEventHandler event flow failed: \(error.localizedDescription)",
                          category: .eventkit,
                          context: LogContext(additionalInfo: ["memoId": memoId.uuidString]),
                          error: error)
        }
    }

    // MARK: - Enable/Disable
    func enable() {
        guard !isEnabled else { return }
        isEnabled = true
        setupEventSubscriptions()
    }

    // MARK: - Debug
    var integrationStatus: String {
        return """
        Calendar Integration Status:
        - Enabled: \(isEnabled)
        - Calendar Permission: \(permissionService.calendarPermissionState.displayText)
        """
    }

    deinit { subscriptionManager.cleanup() }
}

import Foundation
// No direct EventKit dependency here; repository returns DTOs

/// Event handler for Reminders integration using EventKit and analysis results
@MainActor
final class RemindersEventHandler {
    // MARK: - Dependencies
    private let logger: any LoggerProtocol
    private let subscriptionManager: EventSubscriptionManager
    private let eventKitRepository: any EventKitRepository
    private let permissionService: any EventKitPermissionServiceProtocol
    private let createReminderUseCase: any CreateReminderUseCaseProtocol
    private let detectUseCase: any DetectEventsAndRemindersUseCaseProtocol

    // MARK: - State
    private var isEnabled: Bool = true

    // MARK: - Initialization
    init(
        logger: any LoggerProtocol,
        eventBus: any EventBusProtocol,
        eventKitRepository: any EventKitRepository,
        permissionService: any EventKitPermissionServiceProtocol,
        createReminderUseCase: any CreateReminderUseCaseProtocol,
        detectUseCase: any DetectEventsAndRemindersUseCaseProtocol
    ) {
        self.logger = logger
        self.subscriptionManager = EventSubscriptionManager(eventBus: eventBus)
        self.eventKitRepository = eventKitRepository
        self.permissionService = permissionService
        self.createReminderUseCase = createReminderUseCase
        self.detectUseCase = detectUseCase

        if isEnabled { setupEventSubscriptions() }
        logger.info("RemindersEventHandler initialized", category: .system, context: LogContext())
    }

    convenience init(logger: any LoggerProtocol = Logger.shared,
                     eventBus: any EventBusProtocol = EventBus.shared) {
        self.init(
            logger: logger,
            eventBus: eventBus,
            eventKitRepository: DIContainer.shared.eventKitRepository(),
            permissionService: DIContainer.shared.eventKitPermissionService(),
            createReminderUseCase: DIContainer.shared.createReminderUseCase(),
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
        let autoReminders = defaults.object(forKey: "autoDetectReminders") as? Bool ?? true
        guard autoReminders else { return }

        await permissionService.checkReminderPermission(ignoreCache: false)
        guard permissionService.reminderPermissionState.isAuthorized else { return }

        do {
            let detection = try await detectUseCase.execute(transcript: text, memoId: memoId)
            guard let reminders = detection.reminders?.reminders, !reminders.isEmpty else { return }

            for reminder in reminders {
                let suggested = try await eventKitRepository.suggestReminderList(for: reminder)
                var list = suggested
                if list == nil {
                    list = try await eventKitRepository.getDefaultReminderList()
                }
                guard let list else { continue }
                _ = try await createReminderUseCase.execute(reminder: reminder, list: list)
            }
        } catch {
            logger.warning("RemindersEventHandler flow failed: \(error.localizedDescription)",
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
        Reminders Integration Status:
        - Enabled: \(isEnabled)
        - Reminder Permission: \(permissionService.reminderPermissionState.displayText)
        """
    }

    deinit { subscriptionManager.cleanup() }
}

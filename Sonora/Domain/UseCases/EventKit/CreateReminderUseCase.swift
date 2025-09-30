import Foundation
// Domain stays pure; use CalendarDTO bridging model

/// Use case for creating reminders with validation and error handling
protocol CreateReminderUseCaseProtocol: Sendable {
    @MainActor
    func execute(reminder: RemindersData.DetectedReminder, list: CalendarDTO) async throws -> String
    @MainActor
    func execute(reminders: [RemindersData.DetectedReminder], listMapping: [String: CalendarDTO]) async throws -> [String: Result<String, Error>]
}

final class CreateReminderUseCase: CreateReminderUseCaseProtocol, @unchecked Sendable {

    // MARK: - Dependencies
    private let eventKitRepository: any EventKitRepository
    private let permissionService: any EventKitPermissionServiceProtocol
    private let logger: any LoggerProtocol
    private let eventBus: any EventBusProtocol

    // MARK: - Initialization
    init(
        eventKitRepository: any EventKitRepository,
        permissionService: any EventKitPermissionServiceProtocol,
        logger: any LoggerProtocol = Logger.shared,
        eventBus: any EventBusProtocol = EventBus.shared
    ) {
        self.eventKitRepository = eventKitRepository
        self.permissionService = permissionService
        self.logger = logger
        self.eventBus = eventBus
    }

    // MARK: - Use Case Execution

    @MainActor
    func execute(reminder: RemindersData.DetectedReminder, list: CalendarDTO) async throws -> String {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "reminderTitle": reminder.title,
            "listTitle": list.title,
            "priority": reminder.priority.rawValue,
            "confidence": reminder.confidence,
            "hasDueDate": reminder.dueDate != nil
        ])

        logger.info("Starting reminder creation",
                   category: .eventkit,
                   context: context)

        // Validate inputs
        try validateReminderInput(reminder)
        try validateReminderListInput(list)

        // Check permissions
        await permissionService.checkReminderPermission(ignoreCache: false)
        guard permissionService.reminderPermissionState.isAuthorized else {
            logger.warning("Reminder permission not granted",
                          category: .eventkit,
                          context: context,
                          error: nil)
            throw EventKitError.permissionDenied(type: .reminder)
        }

        do {
            // Create the reminder
            let reminderId = try await eventKitRepository.createReminder(reminder, in: list, maxRetries: 3)

            // Publish success event
            await MainActor.run {
                eventBus.publish(.reminderCreated(
                    memoId: reminder.memoId ?? UUID(),
                    reminderId: reminderId
                ))
            }

            logger.info("Reminder created successfully",
                       category: .eventkit,
                       context: LogContext(correlationId: correlationId, additionalInfo: [
                           "reminderId": reminderId
                       ]))

            return reminderId

        } catch {
            logger.error("Failed to create reminder",
                        category: .eventkit,
                        context: context,
                        error: error)

            // Publish failure event
            await MainActor.run {
                eventBus.publish(.reminderCreationFailed(
                    reminderTitle: reminder.title,
                    message: error.localizedDescription
                ))
            }

            throw error
        }
    }

    @MainActor
    func execute(reminders: [RemindersData.DetectedReminder],
                listMapping: [String: CalendarDTO]) async throws -> [String: Result<String, Error>] {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "reminderCount": reminders.count,
            "listCount": Set(listMapping.values).count
        ])

        logger.info("Starting batch reminder creation",
                   category: .eventkit,
                   context: context)

        // Validate inputs
        guard !reminders.isEmpty else {
            throw EventKitError.invalidEventData(field: "reminders - array is empty")
        }

        for reminder in reminders {
            try validateReminderInput(reminder)
            guard listMapping[reminder.id] != nil else {
                throw EventKitError.reminderListNotFound(identifier: reminder.id)
            }
        }

        // Check permissions
        await permissionService.checkReminderPermission(ignoreCache: false)
        guard permissionService.reminderPermissionState.isAuthorized else {
            throw EventKitError.permissionDenied(type: .reminder)
        }

        // Create reminders in batch
        let results = try await eventKitRepository.createReminders(reminders, listMapping: listMapping, maxRetries: 3)

        // Analyze results and publish events
        let successCount = results.values.compactMap { try? $0.get() }.count
        let failureCount = reminders.count - successCount

        await MainActor.run {
            // Publish individual success/failure events
            for (reminderId, result) in results {
                guard let reminder = reminders.first(where: { $0.id == reminderId }) else { continue }

                switch result {
                case .success(let createdReminderId):
                    eventBus.publish(.reminderCreated(
                        memoId: reminder.memoId ?? UUID(),
                        reminderId: createdReminderId
                    ))
                case .failure(let error):
                    eventBus.publish(.reminderCreationFailed(
                        reminderTitle: reminder.title,
                        message: error.localizedDescription
                    ))
                }
            }

            // Publish batch completion event
            eventBus.publish(.batchReminderCreationCompleted(
                totalReminders: reminders.count,
                successCount: successCount,
                failureCount: failureCount
            ))
        }

        logger.info("Batch reminder creation completed",
                   category: .eventkit,
                   context: LogContext(correlationId: correlationId, additionalInfo: [
                       "successCount": successCount,
                       "failureCount": failureCount,
                       "successRate": Float(successCount) / Float(reminders.count)
                   ]))

        return results
    }

    // MARK: - Private Validation

    private func validateReminderInput(_ reminder: RemindersData.DetectedReminder) throws {
        // Validate title
        guard !reminder.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventKitError.invalidEventData(field: "reminder title is empty")
        }

        // Validate title length
        guard reminder.title.count <= 255 else {
            throw EventKitError.invalidEventData(field: "reminder title exceeds maximum length (255)")
        }

        // Validate confidence level
        guard reminder.confidence >= 0.0 && reminder.confidence <= 1.0 else {
            throw EventKitError.invalidEventData(field: "confidence must be between 0.0 and 1.0")
        }

        // Validate due date if provided
        if let dueDate = reminder.dueDate {
            // Check if due date is too far in the past
            let oneWeekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
            guard dueDate >= oneWeekAgo else {
                throw EventKitError.invalidEventData(field: "due date is too far in the past")
            }

            // Check if due date is too far in the future
            let fiveYearsFromNow = Calendar.current.date(byAdding: .year, value: 5, to: Date())!
            guard dueDate <= fiveYearsFromNow else {
                throw EventKitError.invalidEventData(field: "due date is too far in the future")
            }
        }

        // Validate source text
        guard !reminder.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventKitError.invalidEventData(field: "source text is empty")
        }

        // Validate source text length (for notes field)
        guard reminder.sourceText.count <= 1_000 else {
            throw EventKitError.invalidEventData(field: "source text exceeds maximum length (1000)")
        }
    }

    private func validateReminderListInput(_ list: CalendarDTO) throws {
        guard list.allowsModifications else {
            throw EventKitError.reminderListNotFound(identifier: "List does not allow modifications: \(list.title)")
        }
        guard list.entityType == .reminder else {
            throw EventKitError.reminderListNotFound(identifier: "Invalid calendar for reminders: \(list.title)")
        }
    }
}

// Note: publishes direct AppEvent enum cases defined in AppEvent

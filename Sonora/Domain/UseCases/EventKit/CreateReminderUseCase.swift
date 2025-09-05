import Foundation
@preconcurrency import EventKit

/// Use case for creating reminders with validation and error handling
protocol CreateReminderUseCaseProtocol: Sendable {
    func execute(reminder: RemindersData.DetectedReminder, list: EKCalendar) async throws -> String
    func execute(reminders: [RemindersData.DetectedReminder], listMapping: [String: EKCalendar]) async throws -> [String: Result<String, Error>]
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
    func execute(reminder: RemindersData.DetectedReminder, list: EKCalendar) async throws -> String {
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
            let reminderId = try await eventKitRepository.createReminder(
                reminder,
                in: list,
                maxRetries: 3
            )
            
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
                    error: error
                ))
            }
            
            throw error
        }
    }
    
    @MainActor
    func execute(reminders: [RemindersData.DetectedReminder], 
                listMapping: [String: EKCalendar]) async throws -> [String: Result<String, Error>] {
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
        let results = try await eventKitRepository.createReminders(
            reminders,
            listMapping: listMapping,
            maxRetries: 3
        )
        
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
                        error: error
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
        guard reminder.sourceText.count <= 1000 else {
            throw EventKitError.invalidEventData(field: "source text exceeds maximum length (1000)")
        }
    }
    
    private func validateReminderListInput(_ list: EKCalendar) throws {
        // Check if calendar allows modifications
        guard list.allowsContentModifications else {
            throw EventKitError.reminderListNotFound(identifier: "List does not allow modifications: \(list.title)")
        }
        
        // Check if it's a reminder calendar (not an event calendar)
        guard list.type == .local || list.type == .calDAV || 
              list.type == .exchange else {
            throw EventKitError.reminderListNotFound(identifier: "Invalid calendar type for reminders: \(list.title)")
        }
        
        // Additional check to ensure it's configured for reminders
        guard list.allowedEntityTypes.contains(.reminder) else {
            throw EventKitError.reminderListNotFound(identifier: "Calendar not configured for reminders: \(list.title)")
        }
    }
}

// MARK: - EventBus Extensions for Reminder Events

extension AppEvent {
    static func reminderCreated(memoId: UUID, reminderId: String) -> AppEvent {
        return .analysisCompleted(memoId: memoId, type: .reminders, result: "Reminder created: \(reminderId)")
    }
    
    static func reminderCreationFailed(reminderTitle: String, error: Error) -> AppEvent {
        return .analysisCompleted(memoId: UUID(), type: .reminders, result: "Failed: \(reminderTitle) - \(error.localizedDescription)")
    }
    
    static func batchReminderCreationCompleted(totalReminders: Int, successCount: Int, failureCount: Int) -> AppEvent {
        return .analysisCompleted(memoId: UUID(), type: .reminders, result: "Batch complete: \(successCount)/\(totalReminders) succeeded")
    }
}

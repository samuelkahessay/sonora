import Foundation
@preconcurrency import EventKit

/// Use case for creating calendar events with validation and error handling
protocol CreateCalendarEventUseCaseProtocol: Sendable {
    func execute(event: EventsData.DetectedEvent, calendar: EKCalendar) async throws -> String
    func execute(events: [EventsData.DetectedEvent], calendarMapping: [String: EKCalendar]) async throws -> [String: Result<String, Error>]
}

final class CreateCalendarEventUseCase: CreateCalendarEventUseCaseProtocol, @unchecked Sendable {
    
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
    func execute(event: EventsData.DetectedEvent, calendar: EKCalendar) async throws -> String {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "eventTitle": event.title,
            "calendarTitle": calendar.title,
            "confidence": event.confidence,
            "hasDate": event.startDate != nil
        ])
        
        logger.info("Starting calendar event creation",
                   category: .eventkit,
                   context: context)
        
        // Validate inputs
        try validateEventInput(event)
        try validateCalendarInput(calendar)
        
        // Check permissions
        await permissionService.checkCalendarPermission(ignoreCache: false)
        guard permissionService.calendarPermissionState.isAuthorized else {
            logger.warning("Calendar permission not granted",
                          category: .eventkit,
                          context: context,
                          error: nil)
            throw EventKitError.permissionDenied(type: .calendar)
        }
        
        // Check for conflicts if event has a specific time
        if let startDate = event.startDate {
            do {
                let conflicts = try await eventKitRepository.detectConflicts(for: event)
                if !conflicts.isEmpty {
                    logger.info("Conflicts detected for event creation",
                               category: .eventkit,
                               context: LogContext(correlationId: correlationId, additionalInfo: [
                                   "conflictCount": conflicts.count,
                                   "conflictTitles": conflicts.map { $0.title ?? "Untitled" }
                               ]))
                    
                    // Don't throw error, but publish event for UI to handle
                    await MainActor.run {
                        eventBus.publish(.eventConflictDetected(
                            eventId: event.id,
                            conflicts: conflicts.map { $0.title ?? "Untitled Event" }
                        ))
                    }
                }
            } catch {
                logger.warning("Failed to check for conflicts, proceeding anyway",
                              category: .eventkit,
                              context: context,
                              error: error)
            }
        }
        
        do {
            // Create the event
            let eventId = try await eventKitRepository.createEvent(
                event,
                in: calendar,
                maxRetries: 3
            )
            
            // Publish success event
            await MainActor.run {
                eventBus.publish(.calendarEventCreated(
                    memoId: event.memoId ?? UUID(), // Fallback if no memo ID
                    eventId: eventId
                ))
            }
            
            logger.info("Calendar event created successfully",
                       category: .eventkit,
                       context: LogContext(correlationId: correlationId, additionalInfo: [
                           "eventId": eventId
                       ]))
            
            return eventId
            
        } catch {
            logger.error("Failed to create calendar event",
                        category: .eventkit,
                        context: context,
                        error: error)
            
            // Publish failure event
            await MainActor.run {
                eventBus.publish(.eventCreationFailed(
                    eventTitle: event.title,
                    error: error
                ))
            }
            
            throw error
        }
    }
    
    @MainActor
    func execute(events: [EventsData.DetectedEvent], 
                calendarMapping: [String: EKCalendar]) async throws -> [String: Result<String, Error>] {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "eventCount": events.count,
            "calendarCount": Set(calendarMapping.values).count
        ])
        
        logger.info("Starting batch calendar event creation",
                   category: .eventkit,
                   context: context)
        
        // Validate inputs
        guard !events.isEmpty else {
            throw EventKitError.invalidEventData(field: "events - array is empty")
        }
        
        for event in events {
            try validateEventInput(event)
            guard calendarMapping[event.id] != nil else {
                throw EventKitError.calendarNotFound(identifier: event.id)
            }
        }
        
        // Check permissions
        await permissionService.checkCalendarPermission(ignoreCache: false)
        guard permissionService.calendarPermissionState.isAuthorized else {
            throw EventKitError.permissionDenied(type: .calendar)
        }
        
        // Create events in batch
        let results = try await eventKitRepository.createEvents(
            events,
            calendarMapping: calendarMapping,
            maxRetries: 3
        )
        
        // Analyze results and publish events
        let successCount = results.values.compactMap { try? $0.get() }.count
        let failureCount = events.count - successCount
        
        await MainActor.run {
            // Publish individual success/failure events
            for (eventId, result) in results {
                guard let event = events.first(where: { $0.id == eventId }) else { continue }
                
                switch result {
                case .success(let createdEventId):
                    eventBus.publish(.calendarEventCreated(
                        memoId: event.memoId ?? UUID(),
                        eventId: createdEventId
                    ))
                case .failure(let error):
                    eventBus.publish(.eventCreationFailed(
                        eventTitle: event.title,
                        error: error
                    ))
                }
            }
            
            // Publish batch completion event
            eventBus.publish(.batchEventCreationCompleted(
                totalEvents: events.count,
                successCount: successCount,
                failureCount: failureCount
            ))
        }
        
        logger.info("Batch calendar event creation completed",
                   category: .eventkit,
                   context: LogContext(correlationId: correlationId, additionalInfo: [
                       "successCount": successCount,
                       "failureCount": failureCount,
                       "successRate": Float(successCount) / Float(events.count)
                   ]))
        
        return results
    }
    
    // MARK: - Private Validation
    
    private func validateEventInput(_ event: EventsData.DetectedEvent) throws {
        // Validate title
        guard !event.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventKitError.invalidEventData(field: "title is empty")
        }
        
        // Validate title length (EventKit has a limit)
        guard event.title.count <= 255 else {
            throw EventKitError.invalidEventData(field: "title exceeds maximum length (255)")
        }
        
        // Validate confidence level
        guard event.confidence >= 0.0 && event.confidence <= 1.0 else {
            throw EventKitError.invalidEventData(field: "confidence must be between 0.0 and 1.0")
        }
        
        // Validate dates if provided
        if let startDate = event.startDate, let endDate = event.endDate {
            guard startDate <= endDate else {
                throw EventKitError.invalidEventData(field: "end date must be after start date")
            }
            
            // Check if dates are too far in the past
            let oneYearAgo = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
            guard startDate >= oneYearAgo else {
                throw EventKitError.invalidEventData(field: "start date is too far in the past")
            }
            
            // Check if dates are too far in the future (EventKit has limits)
            let tenYearsFromNow = Calendar.current.date(byAdding: .year, value: 10, to: Date())!
            guard startDate <= tenYearsFromNow else {
                throw EventKitError.invalidEventData(field: "start date is too far in the future")
            }
        }
        
        // Validate location if provided
        if let location = event.location {
            guard location.count <= 500 else {
                throw EventKitError.invalidEventData(field: "location exceeds maximum length (500)")
            }
        }
        
        // Validate source text
        guard !event.sourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EventKitError.invalidEventData(field: "source text is empty")
        }
    }
    
    private func validateCalendarInput(_ calendar: EKCalendar) throws {
        // Check if calendar allows modifications
        guard calendar.allowsContentModifications else {
            throw EventKitError.calendarNotFound(identifier: "Calendar does not allow modifications: \(calendar.title)")
        }
        
        // Check if it's an event calendar (not a reminder calendar)
        guard calendar.type == .local || calendar.type == .calDAV || 
              calendar.type == .exchange || calendar.type == .subscription else {
            throw EventKitError.calendarNotFound(identifier: "Invalid calendar type for events: \(calendar.title)")
        }
    }
}

// MARK: - EventBus Extensions for EventKit Events

extension AppEvent {
    static func calendarEventCreated(memoId: UUID, eventId: String) -> AppEvent {
        // This would need to be added to the AppEvent enum
        // For now, we'll use a generic approach
        return .analysisCompleted(memoId: memoId, type: .events, result: "Event created: \(eventId)")
    }
    
    static func eventCreationFailed(eventTitle: String, error: Error) -> AppEvent {
        // This would also need to be added to the AppEvent enum
        return .analysisCompleted(memoId: UUID(), type: .events, result: "Failed: \(eventTitle) - \(error.localizedDescription)")
    }
    
    static func eventConflictDetected(eventId: String, conflicts: [String]) -> AppEvent {
        return .analysisCompleted(memoId: UUID(), type: .events, result: "Conflicts detected for \(eventId): \(conflicts.joined(separator: ", "))")
    }
    
    static func batchEventCreationCompleted(totalEvents: Int, successCount: Int, failureCount: Int) -> AppEvent {
        return .analysisCompleted(memoId: UUID(), type: .events, result: "Batch complete: \(successCount)/\(totalEvents) succeeded")
    }
}

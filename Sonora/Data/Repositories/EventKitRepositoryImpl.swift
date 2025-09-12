// MARK: - EventKit Concurrency Helpers (Best Practices Approach)

import Foundation
@preconcurrency import EventKit

// MARK: - Sendability for EventKit types
// These types are used only on MainActor, but cross-task boundaries in a few bridges.
// Mark as @unchecked Sendable to satisfy Swift 6 checks while keeping all EventKit
// interactions on MainActor in this repository implementation.
extension EKReminder: @unchecked Sendable {}
extension EKEvent: @unchecked Sendable {}
extension EKCalendar: @unchecked Sendable {}

// MARK: - EventKit Repository with Proper Concurrency
@MainActor
final class EventKitRepositoryImpl: EventKitRepository {
    
    private let eventStore: EKEventStore
    private let logger: LoggerProtocol
    
    // MARK: - Caching Infrastructure (MainActor isolated)
    private var cachedCalendars: [EKCalendar]?
    private var cachedReminderLists: [EKCalendar]?
    private var lastCacheUpdate: Date?
    private let cacheTimeout: TimeInterval = 300 // 5 minutes
    
    // Smart suggestion cache
    private var calendarSuggestionCache: [String: EKCalendar] = [:]
    private var reminderListSuggestionCache: [String: EKCalendar] = [:]
    
    init(eventStore: EKEventStore = EKEventStore(), logger: LoggerProtocol = Logger.shared) {
        self.eventStore = eventStore
        self.logger = logger
        
        // Subscribe to EventKit change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(eventStoreChanged),
            name: .EKEventStoreChanged,
            object: eventStore
        )
        
        logger.debug("EventKitRepositoryImpl initialized",
                    category: .eventkit,
                    context: LogContext())
    }
    
    @objc private func eventStoreChanged() {
        logger.info("EventKit store changed - invalidating cache",
                   category: .eventkit,
                   context: LogContext())
        
        invalidateCache()
    }
    
    // MARK: - Permission Management
    func requestCalendarAccess() async throws -> Bool {
        return await requestCalendarAccessOnMainActor()
    }
    
    private func requestCalendarAccessOnMainActor() async -> Bool {
        do {
            let status = EKEventStore.authorizationStatus(for: .event)
            
            switch status {
            case .notDetermined:
                return try await eventStore.requestFullAccessToEvents()
            case .authorized, .fullAccess:
                return true
            case .denied, .restricted:
                return false
            case .writeOnly:
                // Request full access if we only have write access
                return try await eventStore.requestFullAccessToEvents()
            @unknown default:
                return false
            }
        } catch {
            logger.error("Failed to request calendar access",
                        category: .eventkit,
                        context: LogContext(),
                        error: error)
            return false
        }
    }
    
    func requestReminderAccess() async throws -> Bool {
        return await requestReminderAccessOnMainActor()
    }
    
    private func requestReminderAccessOnMainActor() async -> Bool {
        do {
            let status = EKEventStore.authorizationStatus(for: .reminder)
            
            switch status {
            case .notDetermined:
                return try await eventStore.requestFullAccessToReminders()
            case .authorized, .fullAccess:
                return true
            case .denied, .restricted:
                return false
            case .writeOnly:
                return try await eventStore.requestFullAccessToReminders()
            @unknown default:
                return false
            }
        } catch {
            logger.error("Failed to request reminder access",
                        category: .eventkit,
                        context: LogContext(),
                        error: error)
            return false
        }
    }
    
    // MARK: - Calendar Operations
    func getCalendars() async throws -> [EKCalendar] {
        return getCalendarsOnMainActor()
    }
    
    private func getCalendarsOnMainActor() -> [EKCalendar] {
        // Check cache validity
        if let cached = cachedCalendars,
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheTimeout {
            if !cached.isEmpty {
                logger.debug("Returning cached calendars (\(cached.count) items)",
                            category: .eventkit, context: LogContext())
                return cached
            }
            // If cache is empty but we now have access, refetch to avoid sticky empty cache
            let status = EKEventStore.authorizationStatus(for: .event)
            if status == .notDetermined {
                logger.debug("Permission state transitional (.notDetermined), fetching fresh calendars without caching empty result",
                            category: .eventkit, context: LogContext())
                // Don't return cached empty result when permission is transitional - proceed to fresh fetch
            } else if status == .denied || status == .restricted {
                logger.debug("Returning cached calendars (0 items) - authorization denied/restricted",
                            category: .eventkit, context: LogContext())
                return cached
            }
            logger.debug("Cached calendars empty but authorized; refetching from EventKit",
                        category: .eventkit, context: LogContext())
        }
        
        logger.debug("Fetching fresh calendars from EventKit",
                    category: .eventkit,
                    context: LogContext())
        
        // Fetch fresh calendars
        let calendars = eventStore.calendars(for: .event)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title < $1.title }
        
        // Update cache
        cachedCalendars = calendars
        lastCacheUpdate = Date()
        
        logger.info("Fetched \(calendars.count) writable calendars from EventKit",
                   category: .eventkit,
                   context: LogContext(additionalInfo: [
                       "calendarTitles": calendars.map { $0.title }
                   ]))
        
        return calendars
    }
    
    func getReminderLists() async throws -> [EKCalendar] {
        return getReminderListsOnMainActor()
    }
    
    private func getReminderListsOnMainActor() -> [EKCalendar] {
        // Check cache validity
        if let cached = cachedReminderLists,
           let lastUpdate = lastCacheUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheTimeout {
            if !cached.isEmpty {
                logger.debug("Returning cached reminder lists (\(cached.count) items)",
                            category: .eventkit, context: LogContext())
                return cached
            }
            // If cache is empty but we now have access, refetch
            let status = EKEventStore.authorizationStatus(for: .reminder)
            if status == .notDetermined {
                logger.debug("Permission state transitional (.notDetermined), fetching fresh reminder lists without caching empty result",
                            category: .eventkit, context: LogContext())
                // Don't return cached empty result when permission is transitional - proceed to fresh fetch
            } else if status == .denied || status == .restricted {
                logger.debug("Returning cached reminder lists (0 items) - authorization denied/restricted",
                            category: .eventkit, context: LogContext())
                return cached
            }
            logger.debug("Cached reminder lists empty but authorized; refetching from EventKit",
                        category: .eventkit, context: LogContext())
        }
        
        logger.debug("Fetching fresh reminder lists from EventKit",
                    category: .eventkit,
                    context: LogContext())
        
        // Fetch fresh reminder lists
        let reminderLists = eventStore.calendars(for: .reminder)
            .filter { $0.allowsContentModifications }
            .sorted { $0.title < $1.title }
        
        // Update cache
        cachedReminderLists = reminderLists
        lastCacheUpdate = Date()
        
        logger.info("Fetched \(reminderLists.count) writable reminder lists from EventKit",
                   category: .eventkit,
                   context: LogContext(additionalInfo: [
                       "listTitles": reminderLists.map { $0.title }
                   ]))
        
        return reminderLists
    }
    
    func getDefaultCalendar() async throws -> EKCalendar? {
        let defaultCalendar = eventStore.defaultCalendarForNewEvents
        if let calendar = defaultCalendar {
            logger.debug("Found default calendar: \(calendar.title)",
                        category: .eventkit,
                        context: LogContext())
        } else {
            logger.warning("No default calendar available",
                          category: .eventkit,
                          context: LogContext(),
                          error: nil)
        }
        return defaultCalendar
    }
    
    func getDefaultReminderList() async throws -> EKCalendar? {
        let defaultList = eventStore.defaultCalendarForNewReminders()
        if let list = defaultList {
            logger.debug("Found default reminder list: \(list.title)",
                        category: .eventkit,
                        context: LogContext())
        } else {
            logger.warning("No default reminder list available",
                          category: .eventkit,
                          context: LogContext(),
                          error: nil)
        }
        return defaultList
    }
    
    // MARK: - Event Creation
    func createEvent(_ event: EventsData.DetectedEvent, 
                     in calendar: EKCalendar,
                     maxRetries: Int = 3) async throws -> String {
        return try createEventOnMainActor(event: event, calendar: calendar, maxRetries: maxRetries)
    }
    
    private func createEventOnMainActor(
        event: EventsData.DetectedEvent,
        calendar: EKCalendar,
        maxRetries: Int = 3
    ) throws -> String {
        logger.info("Creating event: \(event.title)",
                   category: .eventkit,
                   context: LogContext(additionalInfo: [
                       "calendar": calendar.title,
                       "confidence": event.confidence,
                       "hasDate": event.startDate != nil
                   ]))
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let ekEvent = try createEKEvent(from: event, in: calendar)
                try eventStore.save(ekEvent, span: .thisEvent, commit: true)
                
                let eventId = ekEvent.eventIdentifier ?? UUID().uuidString
                
                logger.info("Successfully created event: \(event.title)",
                           category: .eventkit,
                           context: LogContext(additionalInfo: [
                               "eventId": eventId,
                               "attempt": attempt,
                               "calendar": calendar.title
                           ]))
                
                return eventId
            } catch {
                lastError = error
                logger.warning("Event creation attempt \(attempt) failed for: \(event.title)",
                              category: .eventkit,
                              context: LogContext(additionalInfo: [
                                  "attempt": attempt,
                                  "maxRetries": maxRetries
                              ]),
                              error: error)
                
                if attempt < maxRetries {
                    // Brief delay before retry
                    Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                }
            }
        }
        
        logger.error("Failed to create event after \(maxRetries) attempts: \(event.title)",
                    category: .eventkit,
                    context: LogContext(),
                    error: lastError)
        
        throw EventKitError.eventCreationError(title: event.title, underlying: lastError!)
    }
    
    // MARK: - Reminder Creation  
    func createReminder(_ reminder: RemindersData.DetectedReminder,
                        in reminderList: EKCalendar,
                        maxRetries: Int = 3) async throws -> String {
        return try createReminderOnMainActor(reminder: reminder, 
                                            reminderList: reminderList, 
                                            maxRetries: maxRetries)
    }
    
    private func createReminderOnMainActor(
        reminder: RemindersData.DetectedReminder,
        reminderList: EKCalendar,
        maxRetries: Int = 3
    ) throws -> String {
        logger.info("Creating reminder: \(reminder.title)",
                   category: .eventkit,
                   context: LogContext(additionalInfo: [
                       "list": reminderList.title,
                       "priority": reminder.priority.rawValue,
                       "hasDueDate": reminder.dueDate != nil
                   ]))
        
        var lastError: Error?
        
        for attempt in 1...maxRetries {
            do {
                let ekReminder = EKReminder(eventStore: eventStore)
                ekReminder.title = reminder.title
                ekReminder.notes = reminder.sourceText
                ekReminder.calendar = reminderList
                
                if let dueDate = reminder.dueDate {
                    let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: dueDate)
                    ekReminder.dueDateComponents = components
                }
                
                // Convert priority
                let ekPriority: Int = switch reminder.priority {
                case .high: 1
                case .medium: 5  
                case .low: 9
                }
                ekReminder.priority = ekPriority
                
                try eventStore.save(ekReminder, commit: true)
                
                let reminderId = ekReminder.calendarItemIdentifier
                
                logger.info("Successfully created reminder: \(reminder.title)",
                           category: .eventkit,
                           context: LogContext(additionalInfo: [
                               "reminderId": reminderId,
                               "attempt": attempt,
                               "list": reminderList.title
                           ]))
                
                return reminderId
                
            } catch {
                lastError = error
                logger.warning("Reminder creation attempt \(attempt) failed for: \(reminder.title)",
                              category: .eventkit,
                              context: LogContext(additionalInfo: [
                                  "attempt": attempt,
                                  "maxRetries": maxRetries
                              ]),
                              error: error)
                
                if attempt < maxRetries {
                    Thread.sleep(forTimeInterval: 0.1 * Double(attempt))
                }
            }
        }
        
        logger.error("Failed to create reminder after \(maxRetries) attempts: \(reminder.title)",
                    category: .eventkit,
                    context: LogContext(),
                    error: lastError)
        
        throw EventKitError.reminderCreationError(title: reminder.title, underlying: lastError!)
    }
    
    // MARK: - Batch Operations
    func createEvents(_ events: [EventsData.DetectedEvent],
                      calendarMapping: [String: EKCalendar],
                      maxRetries: Int = 3) async throws -> [String: Result<String, Error>] {
        return createEventsOnMainActor(events: events, 
                                      calendarMapping: calendarMapping, 
                                      maxRetries: maxRetries)
    }
    
    private func createEventsOnMainActor(
        events: [EventsData.DetectedEvent],
        calendarMapping: [String: EKCalendar],
        maxRetries: Int = 3
    ) -> [String: Result<String, Error>] {
        logger.info("Creating \(events.count) events in batch",
                   category: .eventkit,
                   context: LogContext())
        
        var results: [String: Result<String, Error>] = [:]
        
        for event in events {
            guard let calendar = calendarMapping[event.id] else {
                results[event.id] = .failure(EventKitError.calendarNotFound(identifier: event.id))
                continue
            }
            
            do {
                let eventId = try createEventOnMainActor(event: event, calendar: calendar, maxRetries: maxRetries)
                results[event.id] = .success(eventId)
            } catch {
                results[event.id] = .failure(error)
            }
        }
        
        return results
    }
    
    func createReminders(_ reminders: [RemindersData.DetectedReminder],
                         listMapping: [String: EKCalendar],
                         maxRetries: Int = 3) async throws -> [String: Result<String, Error>] {
        return createRemindersOnMainActor(reminders: reminders,
                                         reminderListMapping: listMapping,
                                         maxRetries: maxRetries)
    }
    
    private func createRemindersOnMainActor(
        reminders: [RemindersData.DetectedReminder],
        reminderListMapping: [String: EKCalendar],
        maxRetries: Int = 3
    ) -> [String: Result<String, Error>] {
        logger.info("Creating \(reminders.count) reminders in batch",
                   category: .eventkit,
                   context: LogContext())
        
        var results: [String: Result<String, Error>] = [:]
        
        for reminder in reminders {
            guard let reminderList = reminderListMapping[reminder.id] else {
                results[reminder.id] = .failure(EventKitError.reminderListNotFound(identifier: reminder.id))
                continue
            }
            
            do {
                let reminderId = try createReminderOnMainActor(reminder: reminder, 
                                                             reminderList: reminderList, 
                                                             maxRetries: maxRetries)
                results[reminder.id] = .success(reminderId)
            } catch {
                results[reminder.id] = .failure(error)
            }
        }
        
        return results
    }
    
    // MARK: - Update/Delete Operations (trimmed from shipped surface)
    
    // MARK: - Conflict Detection
    func detectConflicts(for event: EventsData.DetectedEvent) async throws -> [EKEvent] {
        return checkForConflictsOnMainActor(event: event)
    }
    
    private func checkForConflictsOnMainActor(event: EventsData.DetectedEvent) -> [EKEvent] {
        guard let startDate = event.startDate else {
            logger.debug("No start date for conflict detection: \(event.title)",
                        category: .eventkit,
                        context: LogContext())
            return []
        }
        
        let endDate = event.endDate ?? startDate.addingTimeInterval(3600) // Default 1 hour
        
        logger.debug("Checking for conflicts: \(event.title) from \(startDate) to \(endDate)",
                    category: .eventkit,
                    context: LogContext())
        
        let predicate = eventStore.predicateForEvents(
            withStart: startDate,
            end: endDate,
            calendars: nil // Check all calendars
        )
        
        let existingEvents = eventStore.events(matching: predicate)
            .filter { existingEvent in
                // Filter out all-day events and free time
                !existingEvent.isAllDay && existingEvent.availability != .free
            }
        
        if !existingEvents.isEmpty {
            logger.info("Found \(existingEvents.count) potential conflicts for: \(event.title)",
                       category: .eventkit,
                       context: LogContext(additionalInfo: [
                           "conflictTitles": existingEvents.map { $0.title ?? "Untitled" }
                       ]))
        }
        
        return existingEvents
    }
    
    // MARK: - Smart Suggestions
    func suggestCalendar(for event: EventsData.DetectedEvent) async throws -> EKCalendar? {
        return suggestCalendarOnMainActor(for: event)
    }
    
    private func suggestCalendarOnMainActor(for event: EventsData.DetectedEvent) -> EKCalendar? {
        // Check cache first
        let cacheKey = "\(event.title)|\(event.sourceText)".lowercased()
        if let cached = calendarSuggestionCache[cacheKey] {
            logger.debug("Using cached calendar suggestion for: \(event.title)",
                        category: .eventkit, context: LogContext())
            return cached
        }
        
        let calendars = getCalendarsOnMainActor()
        let eventText = "\(event.title) \(event.sourceText)".lowercased()
        
        logger.debug("Analyzing event content for calendar suggestion: \(event.title)",
                    category: .eventkit,
                    context: LogContext())
        
        // Simple keyword-based suggestion
        let workKeywords = ["meeting", "work", "project", "client", "office", "business"]
        let personalKeywords = ["appointment", "doctor", "personal", "family", "home"]
        let socialKeywords = ["party", "dinner", "social", "friend", "birthday"]
        
        var suggestedCalendar: EKCalendar?
        
        // Find best matching calendar
        for calendar in calendars {
            let calendarName = calendar.title.lowercased()
            
            if workKeywords.contains(where: { eventText.contains($0) }) && 
               (calendarName.contains("work") || calendarName.contains("business")) {
                suggestedCalendar = calendar
                break
            } else if personalKeywords.contains(where: { eventText.contains($0) }) && 
                     (calendarName.contains("personal") || calendarName.contains("home")) {
                suggestedCalendar = calendar
                break
            } else if socialKeywords.contains(where: { eventText.contains($0) }) && 
                     calendarName.contains("social") {
                suggestedCalendar = calendar
                break
            }
        }
        
        // Fallback to default calendar
        if suggestedCalendar == nil {
            suggestedCalendar = eventStore.defaultCalendarForNewEvents ?? calendars.first
        }
        
        // Cache the result
        if let suggested = suggestedCalendar {
            calendarSuggestionCache[cacheKey] = suggested
            logger.info("Suggested calendar '\(suggested.title)' for event: \(event.title)",
                       category: .eventkit, context: LogContext())
        }
        
        return suggestedCalendar
    }
    
    func suggestReminderList(for reminder: RemindersData.DetectedReminder) async throws -> EKCalendar? {
        return suggestReminderListOnMainActor(for: reminder)
    }
    
    private func suggestReminderListOnMainActor(for reminder: RemindersData.DetectedReminder) -> EKCalendar? {
        let lists = getReminderListsOnMainActor()
        
        // Simple priority-based selection
        let listName = switch reminder.priority {
        case .high: "Work"
        case .medium: "Personal"  
        case .low: "Someday"
        }
        
        let suggestedList = lists.first { $0.title.lowercased().contains(listName.lowercased()) }
                         ?? eventStore.defaultCalendarForNewReminders()
                         ?? lists.first
        
        if let suggested = suggestedList {
            logger.debug("Suggested reminder list '\(suggested.title)' for: \(reminder.title)",
                        category: .eventkit, context: LogContext())
        }
        
        return suggestedList
    }
    
    // MARK: - Additional Operations (trimmed from shipped surface)
    
    // MARK: - Helper Methods
    private func createEKEvent(from event: EventsData.DetectedEvent, in calendar: EKCalendar) throws -> EKEvent {
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = event.title
        ekEvent.calendar = calendar
        
        if let startDate = event.startDate {
            ekEvent.startDate = startDate
            ekEvent.endDate = event.endDate ?? startDate.addingTimeInterval(3600) // 1 hour default
        } else {
            // If no date specified, create all-day event for tomorrow
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            ekEvent.startDate = Calendar.current.startOfDay(for: tomorrow)
            ekEvent.endDate = Calendar.current.startOfDay(for: tomorrow).addingTimeInterval(86400) // Full day
            ekEvent.isAllDay = true
        }
        
        if let location = event.location {
            ekEvent.location = location
        }
        
        if let participants = event.participants, !participants.isEmpty {
            ekEvent.notes = "Participants: \(participants.joined(separator: ", "))\n\nOriginal: \(event.sourceText)"
        } else {
            ekEvent.notes = "Original: \(event.sourceText)"
        }
        
        return ekEvent
    }
    
    // MARK: - Cache Management
    func invalidateCache() {
        cachedCalendars = nil
        cachedReminderLists = nil
        lastCacheUpdate = nil
        calendarSuggestionCache.removeAll()
        reminderListSuggestionCache.removeAll()
        
        logger.debug("EventKit cache invalidated",
                     category: .eventkit,
                     context: LogContext())
    }
    
    func cleanupDetectionData() {
        calendarSuggestionCache.removeAll()
        reminderListSuggestionCache.removeAll()
        
        logger.debug("EventKit detection data cleaned up",
                     category: .eventkit,
                     context: LogContext())
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

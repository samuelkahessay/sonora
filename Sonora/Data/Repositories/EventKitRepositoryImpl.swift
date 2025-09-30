// MARK: - EventKit Concurrency Helpers (Best Practices Approach)

@preconcurrency import EventKit
import Foundation

// NOTE: Avoid adding retroactive Sendable conformances to EventKit types.
// All EventKit interactions in this repository are @MainActor-isolated.

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
    // Permission requests are handled by EventKitPermissionService; repository stays focused on data ops.

    // MARK: - Calendar Operations
    func getCalendars() async throws -> [CalendarDTO] {
        let cals = getCalendarsOnMainActor()
        let defId = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
        return cals.map { makeCalendarDTO(from: $0, isDefault: $0.calendarIdentifier == defId, entity: .event) }
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

    func getReminderLists() async throws -> [CalendarDTO] {
        let lists = getReminderListsOnMainActor()
        let defId = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
        return lists.map { makeCalendarDTO(from: $0, isDefault: $0.calendarIdentifier == defId, entity: .reminder) }
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

    func getDefaultCalendar() async throws -> CalendarDTO? {
        let defaultCalendar = eventStore.defaultCalendarForNewEvents
        if let calendar = defaultCalendar {
            logger.debug("Found default calendar: \(calendar.title)",
                        category: .eventkit,
                        context: LogContext())
            return makeCalendarDTO(from: calendar, isDefault: true, entity: .event)
        } else {
            logger.warning("No default calendar available",
                          category: .eventkit,
                          context: LogContext(),
                          error: nil)
            return nil
        }
    }

    func getDefaultReminderList() async throws -> CalendarDTO? {
        let defaultList = eventStore.defaultCalendarForNewReminders()
        if let list = defaultList {
            logger.debug("Found default reminder list: \(list.title)",
                        category: .eventkit,
                        context: LogContext())
            return makeCalendarDTO(from: list, isDefault: true, entity: .reminder)
        } else {
            logger.warning("No default reminder list available",
                          category: .eventkit,
                          context: LogContext(),
                          error: nil)
            return nil
        }
    }

    // MARK: - Event Creation
    func createEvent(_ event: EventsData.DetectedEvent,
                     in calendar: CalendarDTO,
                     maxRetries: Int = 3) async throws -> String {
        guard let ekCalendar = eventStore.calendar(withIdentifier: calendar.id) else {
            throw EventKitError.calendarNotFound(identifier: calendar.id)
        }
        return try createEventOnMainActor(event: event, calendar: ekCalendar, maxRetries: maxRetries)
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
                        in reminderList: CalendarDTO,
                        maxRetries: Int = 3) async throws -> String {
        guard let ekList = eventStore.calendar(withIdentifier: reminderList.id) else {
            throw EventKitError.reminderListNotFound(identifier: reminderList.id)
        }
        return try createReminderOnMainActor(reminder: reminder,
                                            reminderList: ekList,
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
                      calendarMapping: [String: CalendarDTO],
                      maxRetries: Int = 3) async throws -> [String: Result<String, Error>] {
        let ekMap: [String: EKCalendar] = calendarMapping.reduce(into: [:]) { acc, pair in
            let (key, dto) = pair
            if let cal = eventStore.calendar(withIdentifier: dto.id) { acc[key] = cal }
        }
        return createEventsOnMainActor(events: events,
                                       calendarMapping: ekMap,
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

    func deleteEvent(with identifier: String) async throws {
        try await MainActor.run {
            guard let ekEvent = eventStore.event(withIdentifier: identifier) else {
                throw EventKitError.eventNotFound(identifier: identifier)
            }
            try eventStore.remove(ekEvent, span: .thisEvent, commit: true)
            logger.info("Deleted calendar event",
                       category: .eventkit,
                       context: LogContext(additionalInfo: [
                           "eventId": identifier
                       ]))
        }
    }

    func createReminders(_ reminders: [RemindersData.DetectedReminder],
                         listMapping: [String: CalendarDTO],
                         maxRetries: Int = 3) async throws -> [String: Result<String, Error>] {
        let ekMap: [String: EKCalendar] = listMapping.reduce(into: [:]) { acc, pair in
            let (key, dto) = pair
            if let list = eventStore.calendar(withIdentifier: dto.id) { acc[key] = list }
        }
        return createRemindersOnMainActor(reminders: reminders,
                                          reminderListMapping: ekMap,
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

    func deleteReminder(with identifier: String) async throws {
        try await MainActor.run {
            guard let item = eventStore.calendarItem(withIdentifier: identifier) as? EKReminder else {
                throw EventKitError.reminderNotFound(identifier: identifier)
            }
            try eventStore.remove(item, commit: true)
            logger.info("Deleted reminder",
                       category: .eventkit,
                       context: LogContext(additionalInfo: [
                           "reminderId": identifier
                       ]))
        }
    }

    // MARK: - Update/Delete Operations (trimmed from shipped surface)

    // MARK: - Conflict Detection
    func detectConflicts(for event: EventsData.DetectedEvent) async throws -> [ExistingEventDTO] {
        checkForConflictsOnMainActor(event: event).map {
            ExistingEventDTO(
                identifier: $0.eventIdentifier,
                title: $0.title,
                startDate: $0.startDate,
                endDate: $0.endDate,
                isAllDay: $0.isAllDay
            )
        }
    }

    private func checkForConflictsOnMainActor(event: EventsData.DetectedEvent) -> [EKEvent] {
        guard let startDate = event.startDate else {
            logger.debug("No start date for conflict detection: \(event.title)",
                        category: .eventkit,
                        context: LogContext())
            return []
        }

        let endDate = event.endDate ?? startDate.addingTimeInterval(3_600) // Default 1 hour

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
    func suggestCalendar(for event: EventsData.DetectedEvent) async throws -> CalendarDTO? {
        if let cal = suggestCalendarOnMainActor(for: event) {
            let defId = eventStore.defaultCalendarForNewEvents?.calendarIdentifier
            return makeCalendarDTO(from: cal, isDefault: cal.calendarIdentifier == defId, entity: .event)
        }
        return nil
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

    func suggestReminderList(for reminder: RemindersData.DetectedReminder) async throws -> CalendarDTO? {
        if let list = suggestReminderListOnMainActor(for: reminder) {
            let defId = eventStore.defaultCalendarForNewReminders()?.calendarIdentifier
            return makeCalendarDTO(from: list, isDefault: list.calendarIdentifier == defId, entity: .reminder)
        }
        return nil
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
            ekEvent.endDate = event.endDate ?? startDate.addingTimeInterval(3_600) // 1 hour default
        } else {
            // If no date specified, create all-day event for tomorrow
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            ekEvent.startDate = Calendar.current.startOfDay(for: tomorrow)
            ekEvent.endDate = Calendar.current.startOfDay(for: tomorrow).addingTimeInterval(86_400) // Full day
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

// MARK: - DTO Mapping Helpers
extension EventKitRepositoryImpl {
    fileprivate func makeCalendarDTO(from calendar: EKCalendar, isDefault: Bool, entity: CalendarEntityType) -> CalendarDTO {
        CalendarDTO(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            colorHex: hexString(from: calendar.cgColor),
            entityType: entity,
            allowsModifications: calendar.allowsContentModifications,
            isDefault: isDefault
        )
    }

    fileprivate func hexString(from color: CGColor?) -> String? {
        guard var cg = color else { return nil }
        if cg.colorSpace?.model != .rgb, let converted = cg.converted(to: CGColorSpaceCreateDeviceRGB(), intent: .defaultIntent, options: nil) {
            cg = converted
        }
        guard let comps = cg.components else { return nil }
        // Ensure at least 3 components
        let r = Int((!comps.isEmpty ? comps[0] : 0) * 255.0)
        let g = Int((comps.count > 1 ? comps[1] : 0) * 255.0)
        let b = Int((comps.count > 2 ? comps[2] : 0) * 255.0)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

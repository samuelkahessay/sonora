import Foundation
// Domain stays pure; no EventKit types

/// Repository protocol for EventKit operations with smart caching and conflict detection
@MainActor
protocol EventKitRepository: Sendable {
    // MARK: - Calendar Management

    /// Get all available event calendars, respecting cache
    func getCalendars() async throws -> [CalendarDTO]

    /// Get all available reminder lists, respecting cache
    func getReminderLists() async throws -> [CalendarDTO]

    /// Get the default calendar for new events
    func getDefaultCalendar() async throws -> CalendarDTO?

    /// Get the default reminder list for new reminders
    func getDefaultReminderList() async throws -> CalendarDTO?

    // MARK: - Event Operations

    /// Create a calendar event with retry mechanism
    func createEvent(_ event: EventsData.DetectedEvent,
                    in calendar: CalendarDTO,
                    maxRetries: Int) async throws -> String

    /// Create multiple events in batch
    func createEvents(_ events: [EventsData.DetectedEvent],
                     calendarMapping: [String: CalendarDTO],
                     maxRetries: Int) async throws -> [String: Result<String, Error>]

    // Update/delete operations not shipped; trimmed

    /// Delete a calendar event by identifier
    func deleteEvent(with identifier: String) async throws

    // MARK: - Reminder Operations

    /// Create a reminder with retry mechanism
    func createReminder(_ reminder: RemindersData.DetectedReminder,
                       in list: CalendarDTO,
                       maxRetries: Int) async throws -> String

    /// Create multiple reminders in batch
    func createReminders(_ reminders: [RemindersData.DetectedReminder],
                        listMapping: [String: CalendarDTO],
                        maxRetries: Int) async throws -> [String: Result<String, Error>]

    // Update/delete operations not shipped; trimmed

    /// Delete a reminder by identifier
    func deleteReminder(with identifier: String) async throws

    // MARK: - Smart Features

    /// Detect conflicts for a proposed event
    func detectConflicts(for event: EventsData.DetectedEvent) async throws -> [ExistingEventDTO]

    /// Find potential duplicates based on title/source and time proximity (±15 minutes, same day)
    func findDuplicates(similarTo event: EventsData.DetectedEvent) async throws -> [ExistingEventDTO]

    /// Suggest the best calendar for an event based on content
    func suggestCalendar(for event: EventsData.DetectedEvent) async throws -> CalendarDTO?

    /// Suggest the best reminder list for a reminder based on content
    func suggestReminderList(for reminder: RemindersData.DetectedReminder) async throws -> CalendarDTO?

    // Availability and raw queries not shipped; trimmed

    // MARK: - Cache Management

    // Cache management is internal; trimmed from protocol

    // MARK: - Recurring Events

    // Recurrence not shipped; trimmed
}

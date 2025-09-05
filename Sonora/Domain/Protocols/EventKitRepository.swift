import Foundation
import EventKit

/// Repository protocol for EventKit operations with smart caching and conflict detection
@MainActor
protocol EventKitRepository: Sendable {
    // MARK: - Permissions
    
    /// Request calendar access permissions
    func requestCalendarAccess() async throws -> Bool
    
    /// Request reminders access permissions
    func requestReminderAccess() async throws -> Bool
    // MARK: - Calendar Management
    
    /// Get all available calendars, respecting cache
    func getCalendars() async throws -> [EKCalendar]
    
    /// Get all available reminder lists, respecting cache
    func getReminderLists() async throws -> [EKCalendar]
    
    /// Get the default calendar for new events
    func getDefaultCalendar() async throws -> EKCalendar?
    
    /// Get the default reminder list for new reminders
    func getDefaultReminderList() async throws -> EKCalendar?
    
    // MARK: - Event Operations
    
    /// Create a calendar event with retry mechanism
    func createEvent(_ event: EventsData.DetectedEvent, 
                    in calendar: EKCalendar,
                    maxRetries: Int) async throws -> String
    
    /// Create multiple events in batch
    func createEvents(_ events: [EventsData.DetectedEvent],
                     calendarMapping: [String: EKCalendar],
                     maxRetries: Int) async throws -> [String: Result<String, Error>]
    
    /// Update an existing event
    func updateEvent(eventId: String, 
                    with updatedData: EventsData.DetectedEvent) async throws
    
    /// Delete an event by ID
    func deleteEvent(eventId: String) async throws
    
    // MARK: - Reminder Operations
    
    /// Create a reminder with retry mechanism
    func createReminder(_ reminder: RemindersData.DetectedReminder,
                       in list: EKCalendar,
                       maxRetries: Int) async throws -> String
    
    /// Create multiple reminders in batch
    func createReminders(_ reminders: [RemindersData.DetectedReminder],
                        listMapping: [String: EKCalendar],
                        maxRetries: Int) async throws -> [String: Result<String, Error>]
    
    /// Update an existing reminder
    func updateReminder(reminderId: String,
                       with updatedData: RemindersData.DetectedReminder) async throws
    
    /// Delete a reminder by ID
    func deleteReminder(reminderId: String) async throws
    
    // MARK: - Smart Features
    
    /// Detect conflicts for a proposed event
    func detectConflicts(for event: EventsData.DetectedEvent) async throws -> [EKEvent]
    
    /// Suggest the best calendar for an event based on content
    func suggestCalendar(for event: EventsData.DetectedEvent) async throws -> EKCalendar?
    
    /// Suggest the best reminder list for a reminder based on content
    func suggestReminderList(for reminder: RemindersData.DetectedReminder) async throws -> EKCalendar?
    
    /// Check if a specific time slot is available
    func checkAvailability(startDate: Date, endDate: Date, excludeCalendars: [String]?) async throws -> Bool
    
    /// Get events in a date range
    func getEvents(from startDate: Date, to endDate: Date, calendars: [EKCalendar]?) async throws -> [EKEvent]
    
    /// Get reminders matching criteria
    func getReminders(completed: Bool?, 
                     dueAfter: Date?, 
                     dueBefore: Date?, 
                     lists: [EKCalendar]?) async throws -> [EKReminder]
    
    // MARK: - Cache Management
    
    /// Invalidate all cached data
    func invalidateCache()
    
    /// Clean up temporary detection data and optimize memory usage
    func cleanupDetectionData()
    
    /// Get cache statistics for debugging
    func getCacheStats() -> [String: Any]
    
    // MARK: - Recurring Events
    
    /// Detect if an event should be recurring based on content
    func detectRecurrencePattern(for event: EventsData.DetectedEvent) async -> EKRecurrenceRule?
    
    /// Create a recurring event
    func createRecurringEvent(_ event: EventsData.DetectedEvent,
                             in calendar: EKCalendar,
                             recurrenceRule: EKRecurrenceRule) async throws -> String
}

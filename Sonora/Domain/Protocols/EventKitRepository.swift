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
    
    // Update/delete operations not shipped; trimmed
    
    // MARK: - Reminder Operations
    
    /// Create a reminder with retry mechanism
    func createReminder(_ reminder: RemindersData.DetectedReminder,
                       in list: EKCalendar,
                       maxRetries: Int) async throws -> String
    
    /// Create multiple reminders in batch
    func createReminders(_ reminders: [RemindersData.DetectedReminder],
                        listMapping: [String: EKCalendar],
                        maxRetries: Int) async throws -> [String: Result<String, Error>]
    
    // Update/delete operations not shipped; trimmed
    
    // MARK: - Smart Features
    
    /// Detect conflicts for a proposed event
    func detectConflicts(for event: EventsData.DetectedEvent) async throws -> [EKEvent]
    
    /// Suggest the best calendar for an event based on content
    func suggestCalendar(for event: EventsData.DetectedEvent) async throws -> EKCalendar?
    
    /// Suggest the best reminder list for a reminder based on content
    func suggestReminderList(for reminder: RemindersData.DetectedReminder) async throws -> EKCalendar?
    
    // Availability and raw queries not shipped; trimmed
    
    // MARK: - Cache Management
    
    // Cache management is internal; trimmed from protocol
    
    // MARK: - Recurring Events
    
    // Recurrence not shipped; trimmed
}

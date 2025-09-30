import Foundation

/// Comprehensive error types for EventKit integration operations
public enum EventKitError: LocalizedError, Sendable {
    case permissionDenied(type: EventKitType)
    case permissionRestricted(type: EventKitType)
    case permissionUnknown(type: EventKitType)
    case calendarNotFound(identifier: String)
    case reminderListNotFound(identifier: String)
    case eventNotFound(identifier: String)
    case reminderNotFound(identifier: String)
    case eventCreationFailed(underlying: Error)
    case reminderCreationFailed(underlying: Error)
    case eventStoreSyncFailed
    case conflictDetected(existingEvents: [String])
    case networkUnavailable
    case cacheExpired
    case invalidEventData(field: String)
    case eventStoreUnavailable

    public enum EventKitType: String, Sendable {
        case calendar = "Calendar"
        case reminder = "Reminders"

        var permissionKey: String {
            switch self {
            case .calendar: return "NSCalendarsUsageDescription"
            case .reminder: return "NSRemindersUsageDescription"
            }
        }
    }

    public var errorDescription: String? {
        switch self {
        case .permissionDenied(let type):
            return "\(type.rawValue) access is required to create \(type.rawValue.lowercased()). Please enable it in Settings."
        case .permissionRestricted(let type):
            return "\(type.rawValue) access is restricted by your device settings or parental controls."
        case .permissionUnknown(let type):
            return "Unable to determine \(type.rawValue.lowercased()) permission status. Please try again."
        case .calendarNotFound(let id):
            return "The selected calendar (\(id)) could not be found. It may have been deleted."
        case .reminderListNotFound(let id):
            return "The selected reminder list (\(id)) could not be found. It may have been deleted."
        case .eventNotFound(let id):
            return "The calendar event (\(id)) could not be found. It may have been deleted."
        case .reminderNotFound(let id):
            return "The reminder (\(id)) could not be found. It may have been deleted."
        case .eventCreationFailed(let error):
            return "Failed to create calendar event: \(error.localizedDescription)"
        case .reminderCreationFailed(let error):
            return "Failed to create reminder: \(error.localizedDescription)"
        case .eventStoreSyncFailed:
            return "Failed to sync with your calendars. Check your internet connection and try again."
        case .conflictDetected(let events):
            let count = events.count
            return "Found \(count) conflicting event\(count == 1 ? "" : "s") at this time."
        case .networkUnavailable:
            return "Network connection is required for calendar sync with iCloud."
        case .cacheExpired:
            return "Calendar data needs to be refreshed. Pull down to refresh."
        case .invalidEventData(let field):
            return "Invalid event data: \(field) is missing or invalid."
        case .eventStoreUnavailable:
            return "EventKit is not available on this device."
        }
    }

    public var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Tap 'Settings' to open Settings and grant permission."
        case .permissionRestricted:
            return "Check Screen Time or other device restrictions in Settings."
        case .permissionUnknown:
            return "Restart the app or check your device settings."
        case .calendarNotFound, .reminderListNotFound, .eventNotFound, .reminderNotFound:
            return "Select a different calendar or create a new one in the Calendar app."
        case .eventCreationFailed, .reminderCreationFailed:
            return "Check your internet connection and try again, or try creating the event manually."
        case .eventStoreSyncFailed:
            return "Pull down to refresh your calendars or check your iCloud settings."
        case .conflictDetected:
            return "Review the conflicting events or choose a different time."
        case .networkUnavailable:
            return "Connect to Wi-Fi or cellular data and try again."
        case .cacheExpired:
            return "Refreshing calendar data automatically..."
        case .invalidEventData:
            return "Please check the event details and try again."
        case .eventStoreUnavailable:
            return "EventKit features require iOS 6.0 or later."
        }
    }

    public var failureReason: String? {
        switch self {
        case .permissionDenied, .permissionRestricted:
            return "Insufficient permissions to access calendars or reminders."
        case .permissionUnknown:
            return "Permission state could not be determined."
        case .calendarNotFound, .reminderListNotFound, .eventNotFound, .reminderNotFound:
            return "The target calendar or list is no longer available."
        case .eventCreationFailed, .reminderCreationFailed:
            return "EventKit was unable to save the item."
        case .eventStoreSyncFailed:
            return "EventKit synchronization with calendar services failed."
        case .conflictDetected:
            return "Existing events overlap with the requested time."
        case .networkUnavailable:
            return "No internet connection is available for calendar sync."
        case .cacheExpired:
            return "Cached calendar data is outdated."
        case .invalidEventData:
            return "The event data does not meet EventKit requirements."
        case .eventStoreUnavailable:
            return "EventKit framework is not available."
        }
    }

    /// Whether the error can potentially be resolved by retrying the operation
    public var isRetryable: Bool {
        switch self {
        case .networkUnavailable, .eventStoreSyncFailed, .cacheExpired, .permissionUnknown:
            return true
        case .permissionDenied, .permissionRestricted, .calendarNotFound, .reminderListNotFound,
             .eventStoreUnavailable, .invalidEventData, .eventNotFound, .reminderNotFound:
            return false
        case .eventCreationFailed, .reminderCreationFailed, .conflictDetected:
            return true // These might be transient
        }
    }

    /// Whether the error requires user intervention to resolve
    public var requiresUserAction: Bool {
        switch self {
        case .permissionDenied, .permissionRestricted, .calendarNotFound, .reminderListNotFound, .eventNotFound, .reminderNotFound, .conflictDetected:
            return true
        case .networkUnavailable, .cacheExpired, .eventStoreSyncFailed, .permissionUnknown,
             .eventCreationFailed, .reminderCreationFailed, .invalidEventData, .eventStoreUnavailable:
            return false
        }
    }

    /// Analytics-friendly error code
    public var analyticsCode: String {
        switch self {
        case .permissionDenied(let type): return "permission_denied_\(type.rawValue.lowercased())"
        case .permissionRestricted(let type): return "permission_restricted_\(type.rawValue.lowercased())"
        case .permissionUnknown(let type): return "permission_unknown_\(type.rawValue.lowercased())"
        case .calendarNotFound: return "calendar_not_found"
        case .reminderListNotFound: return "reminder_list_not_found"
        case .eventNotFound: return "event_not_found"
        case .reminderNotFound: return "reminder_not_found"
        case .eventCreationFailed: return "event_creation_failed"
        case .reminderCreationFailed: return "reminder_creation_failed"
        case .eventStoreSyncFailed: return "eventstore_sync_failed"
        case .conflictDetected: return "conflict_detected"
        case .networkUnavailable: return "network_unavailable"
        case .cacheExpired: return "cache_expired"
        case .invalidEventData: return "invalid_event_data"
        case .eventStoreUnavailable: return "eventstore_unavailable"
        }
    }
}

// MARK: - Convenience Error Creation

extension EventKitError {
    /// Create a permission error based on EventKit authorization status
    public static func fromAuthorizationStatus(_ status: Any, type: EventKitType) -> EventKitError? {
        // This will be implemented when we add EventKit import
        // For now, return nil to avoid import issues during compilation
        return nil
    }

    /// Create an event creation error with context
    public static func eventCreationError(title: String, underlying: Error) -> EventKitError {
        return .eventCreationFailed(underlying: NSError(
            domain: "EventKitError",
            code: -1,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed to create event '\(title)'",
                NSUnderlyingErrorKey: underlying
            ]
        ))
    }

    /// Create a reminder creation error with context  
    public static func reminderCreationError(title: String, underlying: Error) -> EventKitError {
        return .reminderCreationFailed(underlying: NSError(
            domain: "EventKitError",
            code: -2,
            userInfo: [
                NSLocalizedDescriptionKey: "Failed to create reminder '\(title)'",
                NSUnderlyingErrorKey: underlying
            ]
        ))
    }
}

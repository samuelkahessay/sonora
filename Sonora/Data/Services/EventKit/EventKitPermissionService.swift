@preconcurrency import EventKit
import Foundation

/// Service for managing EventKit permissions with caching and state management
@MainActor
final class EventKitPermissionService: ObservableObject, @unchecked Sendable {
    @Published var calendarPermissionState: PermissionState = .unknown
    @Published var reminderPermissionState: PermissionState = .unknown
    @Published var isRequestingPermission = false

    private let eventStore: EKEventStore
    private let logger: LoggerProtocol

    // Permission caching (track per-entity to avoid cross-suppression)
    private var lastCalendarCheck: Date?
    private var lastReminderCheck: Date?
    private let permissionCacheTimeout: TimeInterval = 30 // 30 seconds

    enum PermissionState: String, CaseIterable, Sendable {
        case unknown = "Unknown"
        case notDetermined = "Not Requested"
        case denied = "Denied"
        case authorized = "Authorized"
        case restricted = "Restricted"
        case writeOnly = "Write Only"

        var canRequest: Bool {
            self == .notDetermined || self == .unknown
        }

        var isAuthorized: Bool {
            self == .authorized || self == .writeOnly
        }

        var displayText: String {
            switch self {
            case .unknown: return "Checking..."
            case .notDetermined: return "Permission not requested"
            case .denied: return "Access denied"
            case .authorized: return "Full access granted"
            case .writeOnly: return "Write access granted"
            case .restricted: return "Access restricted"
            }
        }

        var systemIconName: String {
            switch self {
            case .unknown: return "questionmark.circle"
            case .notDetermined: return "minus.circle"
            case .denied: return "xmark.circle.fill"
            case .authorized: return "checkmark.circle.fill"
            case .writeOnly: return "checkmark.circle"
            case .restricted: return "lock.circle.fill"
            }
        }

        var statusColor: String {
            switch self {
            case .unknown: return "gray"
            case .notDetermined: return "orange"
            case .denied, .restricted: return "red"
            case .authorized, .writeOnly: return "green"
            }
        }
    }

    init(eventStore: EKEventStore = EKEventStore(), logger: LoggerProtocol = Logger.shared) {
        self.eventStore = eventStore
        self.logger = logger

        // Check initial permissions
        Task {
            await checkInitialPermissions()
        }

        logger.debug("EventKitPermissionService initialized",
                    category: .system,
                    context: LogContext())
    }

    // MARK: - Permission Checking

    private func checkInitialPermissions() async {
        await checkCalendarPermission()
        await checkReminderPermission()

        logger.info("Initial EventKit permissions checked",
                   category: .system,
                   context: LogContext(additionalInfo: [
                       "calendarState": calendarPermissionState.rawValue,
                       "reminderState": reminderPermissionState.rawValue
                   ]))
    }

    func checkCalendarPermission(ignoreCache: Bool = false) async {
        // Check cache unless forced refresh (calendar-specific)
        if !ignoreCache, let lastCheck = lastCalendarCheck,
           Date().timeIntervalSince(lastCheck) < permissionCacheTimeout {
            logger.debug("Using cached calendar permission state: \(calendarPermissionState.rawValue)",
                        category: .system, context: LogContext())
            return
        }

        let status = EKEventStore.authorizationStatus(for: .event)
        let newState = mapAuthorizationStatus(status)

        if newState != calendarPermissionState {
            logger.info("Calendar permission state changed: \(calendarPermissionState.rawValue) → \(newState.rawValue)",
                       category: .system,
                       context: LogContext())
        }

        calendarPermissionState = newState
        lastCalendarCheck = Date()

        logger.debug("Calendar permission checked: \(newState.rawValue)",
                    category: .system,
                    context: LogContext())
    }

    func checkReminderPermission(ignoreCache: Bool = false) async {
        // Check cache unless forced refresh (reminder-specific)
        if !ignoreCache, let lastCheck = lastReminderCheck,
           Date().timeIntervalSince(lastCheck) < permissionCacheTimeout {
            logger.debug("Using cached reminder permission state: \(reminderPermissionState.rawValue)",
                        category: .system, context: LogContext())
            return
        }

        let status = EKEventStore.authorizationStatus(for: .reminder)
        let newState = mapAuthorizationStatus(status)

        if newState != reminderPermissionState {
            logger.info("Reminder permission state changed: \(reminderPermissionState.rawValue) → \(newState.rawValue)",
                       category: .system,
                       context: LogContext())
        }

        reminderPermissionState = newState
        lastReminderCheck = Date()

        logger.debug("Reminder permission checked: \(newState.rawValue)",
                    category: .system,
                    context: LogContext())
    }

    // MARK: - Permission Requesting

    func requestCalendarAccess() async throws -> Bool {
        guard calendarPermissionState.canRequest else {
            logger.warning("Cannot request calendar permission in current state: \(calendarPermissionState.rawValue)",
                          category: .system,
                          context: LogContext(),
                          error: nil)

            if calendarPermissionState == .denied {
                throw EventKitError.permissionDenied(type: .calendar)
            } else if calendarPermissionState == .restricted {
                throw EventKitError.permissionRestricted(type: .calendar)
            }
            return calendarPermissionState.isAuthorized
        }

        isRequestingPermission = true
        defer { isRequestingPermission = false }

        logger.info("Requesting calendar access from user",
                   category: .system,
                   context: LogContext())

        do {
            let granted = try await eventStore.requestFullAccessToEvents()

            // Update state immediately
            calendarPermissionState = granted ? .authorized : .denied
            lastCalendarCheck = Date()

            logger.info("Calendar access request completed: \(granted ? "granted" : "denied")",
                       category: .system,
                       context: LogContext())

            if !granted {
                throw EventKitError.permissionDenied(type: .calendar)
            }

            return granted
        } catch {
            logger.error("Failed to request calendar access",
                        category: .system,
                        context: LogContext(),
                        error: error)

            // Update state based on error
            if let ekError = error as? EventKitError {
                throw ekError
            } else {
                calendarPermissionState = .denied
                throw EventKitError.permissionDenied(type: .calendar)
            }
        }
    }

    func requestReminderAccess() async throws -> Bool {
        guard reminderPermissionState.canRequest else {
            logger.warning("Cannot request reminder permission in current state: \(reminderPermissionState.rawValue)",
                          category: .system,
                          context: LogContext(),
                          error: nil)

            if reminderPermissionState == .denied {
                throw EventKitError.permissionDenied(type: .reminder)
            } else if reminderPermissionState == .restricted {
                throw EventKitError.permissionRestricted(type: .reminder)
            }
            return reminderPermissionState.isAuthorized
        }

        isRequestingPermission = true
        defer { isRequestingPermission = false }

        logger.info("Requesting reminder access from user",
                   category: .system,
                   context: LogContext())

        do {
            let granted = try await eventStore.requestFullAccessToReminders()

            // Update state immediately
            reminderPermissionState = granted ? .authorized : .denied
            lastReminderCheck = Date()

            logger.info("Reminder access request completed: \(granted ? "granted" : "denied")",
                       category: .system,
                       context: LogContext())

            if !granted {
                throw EventKitError.permissionDenied(type: .reminder)
            }

            return granted
        } catch {
            logger.error("Failed to request reminder access",
                        category: .system,
                        context: LogContext(),
                        error: error)

            // Update state based on error
            if let ekError = error as? EventKitError {
                throw ekError
            } else {
                reminderPermissionState = .denied
                throw EventKitError.permissionDenied(type: .reminder)
            }
        }
    }

    // MARK: - Utility Methods

    private func mapAuthorizationStatus(_ status: EKAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .fullAccess: return .authorized
        case .writeOnly: return .writeOnly
        @unknown default:
            logger.warning("Unknown EKAuthorizationStatus: \(status.rawValue)",
                          category: .system,
                          context: LogContext(),
                          error: nil)
            return .unknown
        }
    }

    func refreshPermissions() async {
        logger.debug("Refreshing EventKit permissions",
                    category: .system,
                    context: LogContext())

        await checkCalendarPermission(ignoreCache: true)
        await checkReminderPermission(ignoreCache: true)
    }

    /// Check if both calendar and reminder permissions are granted
    var hasAllPermissions: Bool {
        calendarPermissionState.isAuthorized && reminderPermissionState.isAuthorized
    }

    /// Check if any EventKit permissions are granted
    var hasAnyPermissions: Bool {
        calendarPermissionState.isAuthorized || reminderPermissionState.isAuthorized
    }

    /// Get comprehensive permission status for debugging
    var detailedStatus: String {
        """
        EventKit Permissions Status:
        - Calendar: \(calendarPermissionState.displayText) (\(calendarPermissionState.rawValue))
        - Reminders: \(reminderPermissionState.displayText) (\(reminderPermissionState.rawValue))
        - Calendar cache age: \(lastCalendarCheck?.timeIntervalSinceNow.magnitude ?? 0)s
        - Reminders cache age: \(lastReminderCheck?.timeIntervalSinceNow.magnitude ?? 0)s
        - Is requesting: \(isRequestingPermission)
        """
    }

    /// Get analytics-friendly permission data
    var analyticsData: [String: Any] {
        [
            "calendar_permission": calendarPermissionState.rawValue,
            "reminder_permission": reminderPermissionState.rawValue,
            "has_all_permissions": hasAllPermissions,
            "has_any_permissions": hasAnyPermissions,
            "is_requesting": isRequestingPermission,
            "calendar_cache_age_seconds": lastCalendarCheck?.timeIntervalSinceNow.magnitude ?? 0,
            "reminder_cache_age_seconds": lastReminderCheck?.timeIntervalSinceNow.magnitude ?? 0
        ]
    }
}

// MARK: - Protocol for Dependency Injection

@MainActor
protocol EventKitPermissionServiceProtocol: ObservableObject {
    var calendarPermissionState: EventKitPermissionService.PermissionState { get }
    var reminderPermissionState: EventKitPermissionService.PermissionState { get }
    var isRequestingPermission: Bool { get }
    var hasAllPermissions: Bool { get }
    var hasAnyPermissions: Bool { get }

    func checkCalendarPermission(ignoreCache: Bool) async
    func checkReminderPermission(ignoreCache: Bool) async
    func requestCalendarAccess() async throws -> Bool
    func requestReminderAccess() async throws -> Bool
    func refreshPermissions() async
}

extension EventKitPermissionService: EventKitPermissionServiceProtocol {}

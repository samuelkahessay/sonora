import Foundation

/// App-wide events that can be published and subscribed to
/// Supports reactive programming patterns and loose coupling between components
public enum AppEvent: Equatable {
    
    // MARK: - Memo Lifecycle Events
    
    /// Published when a new memo is created and saved
    case memoCreated(Memo)
    
    // MARK: - Recording Events
    
    /// Published when audio recording starts for a memo
    case recordingStarted(memoId: UUID)
    
    /// Published when audio recording completes successfully
    case recordingCompleted(memoId: UUID)
    
    // MARK: - Transcription Events
    
    /// Published when transcription completes successfully
    case transcriptionCompleted(memoId: UUID, text: String)
    
    /// Published when a route is decided for a transcription request
    /// route: "local" or "cloud"; reason: optional description for fallback
    case transcriptionRouteDecided(memoId: UUID, route: String, reason: String?)

    /// Published when transcription makes progress (0.0 ... 1.0)
    /// step is an optional human-readable status message
    case transcriptionProgress(memoId: UUID, fraction: Double, step: String?)
    
    // MARK: - Analysis Events
    
    /// Published when any analysis type completes successfully
    case analysisCompleted(memoId: UUID, type: AnalysisMode, result: String)

    // MARK: - EventKit Events (Calendar/Reminders)

    /// Calendar event created successfully
    case calendarEventCreated(memoId: UUID, eventId: String)

    /// Calendar event creation failed
    case eventCreationFailed(eventTitle: String, message: String)

    /// Batch calendar event creation summary
    case batchEventCreationCompleted(totalEvents: Int, successCount: Int, failureCount: Int)

    /// Conflicts detected for a proposed calendar event
    case eventConflictDetected(eventTitle: String, conflicts: [String])

    /// Reminder created successfully
    case reminderCreated(memoId: UUID, reminderId: String)

    /// Reminder creation failed
    case reminderCreationFailed(reminderTitle: String, message: String)

    /// Batch reminder creation summary
    case batchReminderCreationCompleted(totalReminders: Int, successCount: Int, failureCount: Int)

    // MARK: - Navigation/UI Events (migrated from NotificationCenter)

    /// Navigate to the root of the Memos view
    case navigatePopToRootMemos

    /// Open a specific memo by its ID (deep link or Spotlight)
    case navigateOpenMemoByID(memoId: UUID)

    // MARK: - Configuration/Settings Events

    /// Whisper model selection normalized to an installed model
    case whisperModelNormalized(previous: String, normalized: String)

    // MARK: - Permission Events

    /// Microphone permission status changed (result of a permission request)
    case microphonePermissionStatusChanged(status: MicrophonePermissionStatus)
    
    // MARK: - Event Properties
    
    /// The memo ID associated with this event (if applicable)
    public var memoId: UUID? {
        switch self {
        case .memoCreated(let memo):
            return memo.id
        case .recordingStarted(let memoId), 
             .recordingCompleted(let memoId),
             .transcriptionCompleted(let memoId, _),
             .transcriptionRouteDecided(let memoId, _, _),
             .transcriptionProgress(let memoId, _, _),
             .analysisCompleted(let memoId, _, _):
            return memoId
        case .navigatePopToRootMemos:
            return nil
        case .navigateOpenMemoByID(let memoId):
            return memoId
        case .whisperModelNormalized(_, _):
            return nil
        case .microphonePermissionStatusChanged(_):
            return nil
        case .calendarEventCreated(let memoId, _):
            return memoId
        case .reminderCreated(let memoId, _):
            return memoId
        case .eventCreationFailed, .batchEventCreationCompleted, .eventConflictDetected,
             .reminderCreationFailed, .batchReminderCreationCompleted:
            return nil
        }
    }
    
    /// Human-readable description of the event
    public var description: String {
        switch self {
        case .memoCreated(let memo):
            return "Memo created: \(memo.filename)"
        case .recordingStarted(let memoId):
            return "Recording started for memo: \(memoId)"
        case .recordingCompleted(let memoId):
            return "Recording completed for memo: \(memoId)"
        case .transcriptionCompleted(let memoId, _):
            return "Transcription completed for memo: \(memoId)"
        case .transcriptionRouteDecided(let memoId, let route, let reason):
            if let reason, !reason.isEmpty {
                return "Transcription route decided for memo: \(memoId) — \(route.uppercased()) (\(reason))"
            } else {
                return "Transcription route decided for memo: \(memoId) — \(route.uppercased())"
            }
        case .transcriptionProgress(let memoId, let fraction, let step):
            if let step = step, !step.isEmpty {
                return String(format: "Transcription progress for memo: %@ — %.0f%% (%@)", memoId.uuidString, fraction * 100, step)
            } else {
                return String(format: "Transcription progress for memo: %@ — %.0f%%", memoId.uuidString, fraction * 100)
            }
        case .analysisCompleted(let memoId, let type, _):
            return "\(type.displayName) analysis completed for memo: \(memoId)"
        case .navigatePopToRootMemos:
            return "Navigate: Pop to root memos"
        case .navigateOpenMemoByID(let memoId):
            return "Navigate: Open memo: \(memoId.uuidString)"
        case .whisperModelNormalized(let previous, let normalized):
            return "Whisper model normalized: \(previous) → \(normalized)"
        case .microphonePermissionStatusChanged(let status):
            return "Microphone permission status changed: \(status.displayName)"
        case .calendarEventCreated(_, let eventId):
            return "Calendar event created: \(eventId)"
        case .eventCreationFailed(let title, let message):
            return "Calendar event creation failed: \(title) — \(message)"
        case .batchEventCreationCompleted(let total, let success, let failure):
            return "Calendar batch: total=\(total), success=\(success), failure=\(failure)"
        case .eventConflictDetected(let title, let conflicts):
            return "Conflicts for event '\(title)': \(conflicts.joined(separator: ", "))"
        case .reminderCreated(_, let reminderId):
            return "Reminder created: \(reminderId)"
        case .reminderCreationFailed(let title, let message):
            return "Reminder creation failed: \(title) — \(message)"
        case .batchReminderCreationCompleted(let total, let success, let failure):
            return "Reminders batch: total=\(total), success=\(success), failure=\(failure)"
        }
    }
    
    /// Event category for filtering or logging purposes
    public var category: EventCategory {
        switch self {
        case .memoCreated:
            return .memo
        case .recordingStarted, .recordingCompleted:
            return .recording
        case .transcriptionCompleted, .transcriptionProgress, .transcriptionRouteDecided:
            return .transcription
        case .analysisCompleted:
            return .analysis
        case .navigatePopToRootMemos, .navigateOpenMemoByID:
            return .memo
        case .whisperModelNormalized:
            return .analysis
        case .microphonePermissionStatusChanged:
            return .recording
        case .calendarEventCreated, .eventCreationFailed, .batchEventCreationCompleted, .eventConflictDetected,
             .reminderCreated, .reminderCreationFailed, .batchReminderCreationCompleted:
            return .analysis
        }
    }
}

// MARK: - Event Categories

/// Categories for organizing and filtering events
public enum EventCategory: String, CaseIterable {
    case memo = "memo"
    case recording = "recording"
    case transcription = "transcription"
    case analysis = "analysis"
    
    public var displayName: String {
        switch self {
        case .memo: return "Memo"
        case .recording: return "Recording"
        case .transcription: return "Transcription"
        case .analysis: return "Analysis"
        }
    }
}

// MARK: - Event Type Identifiers

/// Protocol for type-safe event subscription
public protocol AppEventType {
    static var eventTypeIdentifier: ObjectIdentifier { get }
}

extension AppEvent: AppEventType {
    public static var eventTypeIdentifier: ObjectIdentifier {
        return ObjectIdentifier(AppEvent.self)
    }
}

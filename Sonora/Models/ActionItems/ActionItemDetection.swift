import Foundation

public enum ActionItemDetectionKind: String, Sendable, Equatable {
    case event
    case reminder
}

public enum ActionItemConfidence: String, Sendable, Equatable {
    case high
    case medium
    case low

    public static func from(_ value: Float) -> Self {
        switch value {
        case 0.8...1.0: return .high
        case 0.6..<0.8: return .medium
        default: return .low
        }
    }
}

// Domain-bridging model for detections, without transient UI flags.
public struct ActionItemDetection: Equatable, Sendable {
    public let sourceId: String
    public var kind: ActionItemDetectionKind
    public let confidence: ActionItemConfidence
    public let sourceQuote: String
    public var title: String

    // Suggested timing
    public var suggestedDate: Date?
    public var isAllDay: Bool
    public var location: String?
    // For reminders
    public var priorityLabel: String?

    public var memoId: UUID?

    public init(
        sourceId: String,
        kind: ActionItemDetectionKind,
        confidence: ActionItemConfidence,
        sourceQuote: String,
        title: String,
        suggestedDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        priorityLabel: String? = nil,
        memoId: UUID? = nil
    ) {
        self.sourceId = sourceId
        self.kind = kind
        self.confidence = confidence
        self.sourceQuote = sourceQuote
        self.title = title
        self.suggestedDate = suggestedDate
        self.isAllDay = isAllDay
        self.location = location
        self.priorityLabel = priorityLabel
        self.memoId = memoId
    }
}

public extension ActionItemDetection {
    static func fromEvent(_ event: EventsData.DetectedEvent) -> ActionItemDetection {
        ActionItemDetection(
            sourceId: event.id,
            kind: .event,
            confidence: .from(event.confidence),
            sourceQuote: event.sourceText,
            title: event.title,
            suggestedDate: event.startDate,
            isAllDay: false,
            location: event.location,
            priorityLabel: nil,
            memoId: event.memoId
        )
    }

    static func fromReminder(_ reminder: RemindersData.DetectedReminder) -> ActionItemDetection {
        ActionItemDetection(
            sourceId: reminder.id,
            kind: .reminder,
            confidence: .from(reminder.confidence),
            sourceQuote: reminder.sourceText,
            title: reminder.title,
            suggestedDate: reminder.dueDate,
            isAllDay: false,
            location: nil,
            priorityLabel: reminder.priority.rawValue,
            memoId: reminder.memoId
        )
    }
}


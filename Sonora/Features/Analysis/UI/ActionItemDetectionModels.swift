import Foundation
import SwiftUI

enum ActionItemDetectionKind: String, Sendable, Equatable {
    case event
    case reminder
}

enum ActionItemConfidence: String, Sendable, Equatable {
    case high
    case medium
    case low

    static func from(_ value: Float) -> ActionItemConfidence {
        switch value {
        case 0.8...1.0: return .high
        case 0.6..<0.8: return .medium
        default: return .low
        }
    }
}

struct ActionItemDetectionUI: Identifiable, Equatable {
    let id: UUID
    let sourceId: String
    let kind: ActionItemDetectionKind
    let confidence: ActionItemConfidence
    let sourceQuote: String
    var title: String

    // Suggested timing
    var suggestedDate: Date?
    var isAllDay: Bool
    var location: String?
    // For reminders
    var priorityLabel: String?

    var memoId: UUID?

    // UI state (local-only)
    var isEditing: Bool = false
    var isAdded: Bool = false
    var isDismissed: Bool = false
    var isProcessing: Bool = false

    init(
        id: UUID = UUID(),
        sourceId: String,
        kind: ActionItemDetectionKind,
        confidence: ActionItemConfidence,
        sourceQuote: String,
        title: String,
        suggestedDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        priorityLabel: String? = nil,
        memoId: UUID? = nil,
        isEditing: Bool = false,
        isAdded: Bool = false,
        isDismissed: Bool = false,
        isProcessing: Bool = false
    ) {
        self.id = id
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
        self.isEditing = isEditing
        self.isAdded = isAdded
        self.isDismissed = isDismissed
        self.isProcessing = isProcessing
    }
}

extension ActionItemDetectionUI {
    var typeBadgeText: String { kind == .reminder ? "REMINDER" : "CALENDAR" }
    var canQuickChip: Bool { true }
    var confidenceText: String {
        switch confidence {
        case .high: return "High confidence"
        case .medium: return "Medium confidence"
        case .low: return "Low confidence"
        }
    }
}

extension ActionItemDetectionUI {
    static func fromEvent(_ e: EventsData.DetectedEvent) -> ActionItemDetectionUI {
        ActionItemDetectionUI(
            sourceId: e.id,
            kind: .event,
            confidence: .from(e.confidence),
            sourceQuote: e.sourceText,
            title: e.title,
            suggestedDate: e.startDate,
            isAllDay: false,
            location: e.location,
            priorityLabel: nil,
            memoId: e.memoId
        )
    }

    static func fromReminder(_ r: RemindersData.DetectedReminder) -> ActionItemDetectionUI {
        ActionItemDetectionUI(
            sourceId: r.id,
            kind: .reminder,
            confidence: .from(r.confidence),
            sourceQuote: r.sourceText,
            title: r.title,
            suggestedDate: r.dueDate,
            isAllDay: false,
            location: nil,
            priorityLabel: r.priority.rawValue,
            memoId: r.memoId
        )
    }
}

extension DateFormatter {
    static let ai_short: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()
}

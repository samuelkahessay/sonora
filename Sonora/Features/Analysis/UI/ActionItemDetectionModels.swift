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

    // UI state (local-only)
    var isEditing: Bool = false
    var isAdded: Bool = false
    var isDismissed: Bool = false

    init(
        id: UUID = UUID(),
        kind: ActionItemDetectionKind,
        confidence: ActionItemConfidence,
        sourceQuote: String,
        title: String,
        suggestedDate: Date? = nil,
        isAllDay: Bool = false,
        location: String? = nil,
        priorityLabel: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.confidence = confidence
        self.sourceQuote = sourceQuote
        self.title = title
        self.suggestedDate = suggestedDate
        self.isAllDay = isAllDay
        self.location = location
        self.priorityLabel = priorityLabel
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
            kind: .event,
            confidence: .from(e.confidence),
            sourceQuote: e.sourceText,
            title: e.title,
            suggestedDate: e.startDate,
            isAllDay: false,
            location: e.location,
            priorityLabel: nil
        )
    }

    static func fromReminder(_ r: RemindersData.DetectedReminder) -> ActionItemDetectionUI {
        ActionItemDetectionUI(
            kind: .reminder,
            confidence: .from(r.confidence),
            sourceQuote: r.sourceText,
            title: r.title,
            suggestedDate: r.dueDate,
            isAllDay: false,
            location: nil,
            priorityLabel: r.priority.rawValue
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


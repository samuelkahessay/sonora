import Foundation
import SwiftUI

struct ActionItemDetectionUI: Identifiable, Equatable {
    let id: UUID
    let sourceId: String
    var kind: ActionItemDetectionKind
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

// Presentation adapter
extension ActionItemDetectionUI {
    static func fromDomain(_ d: ActionItemDetection, id: UUID, flags: (isEditing: Bool, isAdded: Bool, isDismissed: Bool, isProcessing: Bool) = (false, false, false, false)) -> ActionItemDetectionUI {
        ActionItemDetectionUI(
            id: id,
            sourceId: d.sourceId,
            kind: d.kind,
            confidence: d.confidence,
            sourceQuote: d.sourceQuote,
            title: d.title,
            suggestedDate: d.suggestedDate,
            isAllDay: d.isAllDay,
            location: d.location,
            priorityLabel: d.priorityLabel,
            memoId: d.memoId,
            isEditing: flags.isEditing,
            isAdded: flags.isAdded,
            isDismissed: flags.isDismissed,
            isProcessing: flags.isProcessing
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

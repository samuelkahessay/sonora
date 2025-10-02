import Foundation

// Utility helpers for rendering and de-duplicating detection results

internal func eventLine(_ ev: EventsData.DetectedEvent) -> String {
    var parts: [String] = [ev.title]
    if let start = ev.startDate {
        parts.append("– " + formatShortDate(start))
    }
    if let loc = ev.location, !loc.isEmpty {
        parts.append("@ " + loc)
    }
    return parts.joined(separator: " ")
}

internal func reminderLine(_ r: RemindersData.DetectedReminder) -> String {
    var parts: [String] = [r.title]
    if let due = r.dueDate {
        parts.append("– due " + formatShortDate(due))
    }
    parts.append("[" + r.priority.rawValue + "]")
    return parts.joined(separator: " ")
}

internal func formatShortDate(_ date: Date) -> String {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .short
    return df.string(from: date)
}

// Deduplicate and normalize detection results for UI consumption

// Build payloads from edited UI models and detection bases
internal func buildEventPayload(from item: ActionItemDetectionUI, base: EventsData.DetectedEvent) -> EventsData.DetectedEvent {
    let startDate = item.suggestedDate ?? base.startDate
    var endDate = base.endDate

    if let baseStart = base.startDate, let baseEnd = base.endDate, let startDate {
        let duration = baseEnd.timeIntervalSince(baseStart)
        if duration > 0 {
            endDate = startDate.addingTimeInterval(duration)
        }
    }

    return EventsData.DetectedEvent(
        id: base.id,
        title: item.title,
        startDate: startDate,
        endDate: endDate,
        location: item.location ?? base.location,
        participants: base.participants,
        confidence: base.confidence,
        sourceText: base.sourceText,
        memoId: base.memoId
    )
}

internal func buildReminderPayload(from item: ActionItemDetectionUI, base: RemindersData.DetectedReminder) -> RemindersData.DetectedReminder {
    RemindersData.DetectedReminder(
        id: base.id,
        title: item.title,
        dueDate: item.suggestedDate ?? base.dueDate,
        priority: base.priority,
        confidence: base.confidence,
        sourceText: base.sourceText,
        memoId: base.memoId
    )
}

// Separate pure partitioning logic for readability and lint friendliness
// Domain-level deduplication now handles overlap; UI helpers remain for formatting and payload building.

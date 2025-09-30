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
internal func dedupeDetections(
    events: [EventsData.DetectedEvent],
    reminders: [RemindersData.DetectedReminder]
) -> ([EventsData.DetectedEvent], [RemindersData.DetectedReminder]) {
    var finalReminders = reminders

    func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func reminderKey(for reminder: RemindersData.DetectedReminder) -> String {
        let source = reminder.sourceText.isEmpty ? reminder.title : reminder.sourceText
        return normalize(source)
    }

    func eventKey(for event: EventsData.DetectedEvent) -> String {
        let source = event.sourceText.isEmpty ? event.title : event.sourceText
        return normalize(source)
    }

    let meetingKeywords = [
        "meeting", "meet", "sync", "call", "review", "session",
        "standup", "retro", "1:1", "one-on-one", "interview", "doctor",
        "appointment", "consult", "therapy", "coaching"
    ]
    // Partition events into true events and reminder-like tasks
    let (finalEvents, reservedKeys) = partitionEvents(
        events: events,
        meetingKeywords: meetingKeywords,
        reminderKey: reminderKey,
        eventKey: eventKey,
        finalReminders: &finalReminders
    )

    if !reservedKeys.isEmpty {
        finalReminders.removeAll { reminder in
            let key = reminderKey(for: reminder)
            return !key.isEmpty && reservedKeys.contains(key)
        }
    }

    // Deduplicate reminders by key while preserving order
    var seenReminderKeys = Set<String>()
    finalReminders = finalReminders.filter { reminder in
        let key = reminderKey(for: reminder)
        if key.isEmpty { return true }
        if seenReminderKeys.contains(key) {
            return false
        }
        seenReminderKeys.insert(key)
        return true
    }

    return (finalEvents, finalReminders)
}

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
private func partitionEvents(
    events: [EventsData.DetectedEvent],
    meetingKeywords: [String],
    reminderKey: (RemindersData.DetectedReminder) -> String,
    eventKey: (EventsData.DetectedEvent) -> String,
    finalReminders: inout [RemindersData.DetectedReminder]
) -> ([EventsData.DetectedEvent], Set<String>) {
    var finalEvents: [EventsData.DetectedEvent] = []
    var reservedReminderKeys = Set<String>()

    for event in events {
        let key = eventKey(event)
        let titleLower = event.title.lowercased()
        let hasKeyword = meetingKeywords.contains { titleLower.contains($0) }
        let hasParticipants = !(event.participants?.isEmpty ?? true)
        let hasLocation = !(event.location?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        let hasStartDate = event.startDate != nil
        let qualifiesAsEvent = hasStartDate && (hasKeyword || hasParticipants || hasLocation)

        if qualifiesAsEvent {
            finalEvents.append(event)
            if !key.isEmpty { reservedReminderKeys.insert(key) }
        } else {
            let alreadyHasReminder = finalReminders.contains { reminderKey($0) == key && !key.isEmpty }
            if !alreadyHasReminder {
                let converted = RemindersData.DetectedReminder(
                    id: event.id,
                    title: event.title,
                    dueDate: event.startDate,
                    priority: .medium,
                    confidence: event.confidence,
                    sourceText: event.sourceText,
                    memoId: event.memoId
                )
                finalReminders.append(converted)
            }
        }
    }

    return (finalEvents, reservedReminderKeys)
}

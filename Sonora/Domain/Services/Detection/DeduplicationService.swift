import Foundation

/// Pure domain service for de-duplicating and normalizing event and reminder detections.
enum DeduplicationService {
    /// Returns deduplicated and normalized results, ensuring no event/reminder overlap.
    static func dedupe(
        events: EventsData?,
        reminders: RemindersData?
    ) -> (events: EventsData?, reminders: RemindersData?) {
        let e = events?.events ?? []
        let r = reminders?.reminders ?? []

        var finalReminders = r

        func normalize(_ text: String) -> String {
            text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        }

        func reminderKey(_ reminder: RemindersData.DetectedReminder) -> String {
            let source = reminder.sourceText.isEmpty ? reminder.title : reminder.sourceText
            return normalize(source)
        }

        func eventKey(_ event: EventsData.DetectedEvent) -> String {
            let source = event.sourceText.isEmpty ? event.title : event.sourceText
            return normalize(source)
        }

        let meetingKeywords = [
            "meeting", "meet", "sync", "call", "review", "session",
            "standup", "retro", "1:1", "one-on-one", "interview", "doctor",
            "appointment", "consult", "therapy", "coaching"
        ]

        var finalEvents: [EventsData.DetectedEvent] = []
        var reservedReminderKeys = Set<String>()

        for event in e {
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
                // Convert quasi-event into a reminder unless an equivalent reminder already exists
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

        if !reservedReminderKeys.isEmpty {
            finalReminders.removeAll { reminder in
                let key = reminderKey(reminder)
                return !key.isEmpty && reservedReminderKeys.contains(key)
            }
        }

        // Deduplicate reminders by normalized key while preserving order
        var seen = Set<String>()
        finalReminders = finalReminders.filter { reminder in
            let key = reminderKey(reminder)
            if key.isEmpty { return true }
            if seen.contains(key) { return false }
            seen.insert(key)
            return true
        }

        return (
            finalEvents.isEmpty ? nil : EventsData(events: finalEvents),
            finalReminders.isEmpty ? nil : RemindersData(reminders: finalReminders)
        )
    }
}


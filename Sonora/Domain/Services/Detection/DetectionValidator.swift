import Foundation

/// Validates detected Events/Reminders from the server and filters malformed items.
/// Domain-pure utility: no side effects, no logging required.
struct DetectionValidator {
    static func validateEvents(_ data: EventsData?) -> EventsData? {
        guard let data else { return nil }

        var seen = Set<String>()
        let cleaned: [EventsData.DetectedEvent] = data.events.compactMap { ev in
            // Drop empty titles
            let title = ev.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }

            // Confidence bounds
            guard ev.confidence >= 0.0, ev.confidence <= 1.0 else { return nil }

            // Dates sanity: if both present, require end >= start
            if let s = ev.startDate, let e = ev.endDate, e < s { return nil }

            // Unique ids
            guard !seen.contains(ev.id) else { return nil }
            seen.insert(ev.id)

            // Deduplicate participants
            let participants = ev.participants.map { Array(Set($0.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })) }

            return EventsData.DetectedEvent(
                id: ev.id,
                title: title,
                startDate: ev.startDate,
                endDate: ev.endDate,
                location: ev.location?.trimmingCharacters(in: .whitespacesAndNewlines),
                participants: participants,
                confidence: ev.confidence,
                sourceText: ev.sourceText,
                memoId: ev.memoId
            )
        }

        return cleaned.isEmpty ? nil : EventsData(events: cleaned)
    }

    static func validateReminders(_ data: RemindersData?) -> RemindersData? {
        guard let data else { return nil }

        var seen = Set<String>()
        let cleaned: [RemindersData.DetectedReminder] = data.reminders.compactMap { r in
            let title = r.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            guard r.confidence >= 0.0, r.confidence <= 1.0 else { return nil }

            guard !seen.contains(r.id) else { return nil }
            seen.insert(r.id)

            return RemindersData.DetectedReminder(
                id: r.id,
                title: title,
                dueDate: r.dueDate,
                priority: r.priority,
                confidence: r.confidence,
                sourceText: r.sourceText,
                memoId: r.memoId
            )
        }

        return cleaned.isEmpty ? nil : RemindersData(reminders: cleaned)
    }
}

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

            let recurrence = validateRecurrence(ev.recurrence)

            return EventsData.DetectedEvent(
                id: ev.id,
                title: title,
                startDate: ev.startDate,
                endDate: ev.endDate,
                location: ev.location?.trimmingCharacters(in: .whitespacesAndNewlines),
                participants: participants,
                confidence: ev.confidence,
                sourceText: ev.sourceText,
                memoId: ev.memoId,
                recurrence: recurrence
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

// MARK: - Recurrence validation
extension DetectionValidator {
    private static func validateRecurrence(_ rec: EventsData.DetectedEvent.Recurrence?) -> EventsData.DetectedEvent.Recurrence? {
        guard let rec else { return nil }
        let allowed = Set(["daily", "weekly", "monthly", "yearly"])
        guard allowed.contains(rec.frequency.lowercased()) else { return nil }

        let interval = (rec.interval ?? 1)
        let clampedInterval = max(1, interval)

        var weekdays: [String]? = rec.byWeekday?.compactMap { normalizeWeekday($0) }
        if weekdays?.isEmpty == true { weekdays = nil }

        let end = rec.end.flatMap { end in
            let count = end.count.map { max(1, $0) }
            return EventsData.DetectedEvent.Recurrence.End(until: end.until, count: count)
        }

        return EventsData.DetectedEvent.Recurrence(
            frequency: rec.frequency.lowercased(),
            interval: clampedInterval,
            byWeekday: weekdays,
            end: end
        )
    }

    private static func normalizeWeekday(_ day: String) -> String? {
        let map: [String: String] = [
            "monday": "Mon", "mon": "Mon",
            "tuesday": "Tue", "tue": "Tue",
            "wednesday": "Wed", "wed": "Wed",
            "thursday": "Thu", "thu": "Thu",
            "friday": "Fri", "fri": "Fri",
            "saturday": "Sat", "sat": "Sat",
            "sunday": "Sun", "sun": "Sun"
        ]
        return map[day.lowercased()]
    }
}

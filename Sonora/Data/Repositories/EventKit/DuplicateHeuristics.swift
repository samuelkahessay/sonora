import Foundation

/// Internal helper for duplicate detection heuristics (pure Swift, testable).
struct DuplicateHeuristics {
    struct SimpleEvent: Equatable {
        let title: String?
        let startDate: Date
        let endDate: Date
        let isAllDay: Bool
        let notes: String?
    }

    /// Returns events considered duplicates of the target event based on rules:
    /// - Same calendar day
    /// - Start within ±15 minutes
    /// - Title equality (normalized) OR notes contain an "Original:" section matching target source text
    static func match(target: EventsData.DetectedEvent, sourceText: String, in candidates: [SimpleEvent], windowMinutes: Int = 15) -> [SimpleEvent] {
        guard let targetStart = target.startDate else { return [] }
        let window = TimeInterval(windowMinutes * 60)
        let normalizedTitle = normalize(target.title)
        let normalizedSource = normalize(sourceText)

        return candidates.filter { ev in
            guard !ev.isAllDay else { return false }
            let sameDay = Calendar.current.isDate(ev.startDate, inSameDayAs: targetStart)
            let delta = abs(ev.startDate.timeIntervalSince(targetStart))
            let within = delta <= window
            let titleMatch = normalize(ev.title ?? "") == normalizedTitle
            let sourceMatch = matchSource(in: ev.notes, against: normalizedSource)
            return sameDay && within && (titleMatch || sourceMatch)
        }
    }

    static func normalize(_ text: String) -> String {
        text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func matchSource(in notes: String?, against normalizedSource: String) -> Bool {
        guard let notes = notes?.lowercased() else { return false }
        if let range = notes.range(of: "original:") {
            let extracted = String(notes[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            let normalized = normalize(extracted)
            return normalized.contains(normalizedSource) || normalizedSource.contains(normalized)
        }
        return false
    }
}


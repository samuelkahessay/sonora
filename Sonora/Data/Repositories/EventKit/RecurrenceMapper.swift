@preconcurrency import EventKit
import Foundation

enum EventKitRecurrenceMapper {
    static func rules(from rec: EventsData.DetectedEvent.Recurrence) -> [EKRecurrenceRule] {
        let freq: EKRecurrenceFrequency = {
            switch rec.frequency.lowercased() {
            case "daily": return .daily
            case "weekly": return .weekly
            case "monthly": return .monthly
            case "yearly": return .yearly
            default: return .weekly
            }
        }()
        let interval = max(1, rec.interval ?? 1)

        let end: EKRecurrenceEnd? = {
            if let e = rec.end {
                if let until = e.until { return EKRecurrenceEnd(end: until) }
                if let count = e.count, count > 0 { return EKRecurrenceEnd(occurrenceCount: count) }
            }
            return nil
        }()

        let days: [EKRecurrenceDayOfWeek]? = {
            guard freq == .weekly, let weekdays = rec.byWeekday, !weekdays.isEmpty else { return nil }
            let map: [String: EKWeekday] = [
                "Mon": .monday, "Tue": .tuesday, "Wed": .wednesday, "Thu": .thursday,
                "Fri": .friday, "Sat": .saturday, "Sun": .sunday
            ]
            let result = weekdays.compactMap { abbrev in
                map[abbrev].map { EKRecurrenceDayOfWeek($0) }
            }
            return result.isEmpty ? nil : result
        }()

        let rule = EKRecurrenceRule(recurrenceWith: freq, interval: interval, daysOfTheWeek: days, daysOfTheMonth: nil, monthsOfTheYear: nil, weeksOfTheYear: nil, daysOfTheYear: nil, setPositions: nil, end: end)
        return [rule]
    }
}


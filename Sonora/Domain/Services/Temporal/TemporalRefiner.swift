import Foundation

/// Utility to refine detected reminder times using temporal phrases in the source text.
enum TemporalRefiner {
    enum TimeResolution {
        case explicitTime
        case relativeNamedDay
        case relativeDays
        case weekend
        case week
        case partOfDay
    }

    private struct RelativeReference {
        let anchorDate: Date
        let defaultHour: Int?
        let resolution: TimeResolution
    }

    /// Refine reminder due dates when the transcript/sourceText contains explicit time phrases
    /// like "6 pm" that may have been lost upstream (defaulting to noon, etc.).
    /// - Parameters:
    ///   - remindersData: The detected reminders payload.
    ///   - transcript: Full transcript as a fallback context when sourceText is empty.
    ///   - now: Reference date for resolving relative terms like "today"/"tomorrow".
    /// - Returns: A new reminders payload with refined due dates when applicable.
    static func refine(remindersData: RemindersData?, transcript: String, now: Date = Date()) -> RemindersData? {
        guard let remindersData = remindersData else { return nil }
        if remindersData.reminders.isEmpty { return remindersData }

        var refined: [RemindersData.DetectedReminder] = []
        let calendar = Calendar.current

        for reminder in remindersData.reminders {
            let contextText = reminder.sourceText.isEmpty ? transcript : reminder.sourceText
            var newDue = reminder.dueDate

            if let match = firstTemporalMatch(in: contextText) {
                let matchString = (contextText as NSString).substring(with: match.range)
                let explicitTime = extractExplicitTime(from: matchString)
                let matchedDate = match.date
                let relative = resolveRelativeReference(in: matchString, now: now, calendar: calendar)

                if let (h, m) = explicitTime {
                    if let due = newDue {
                        let comps = calendar.dateComponents([.hour, .minute], from: due)
                        let currentHour = comps.hour ?? 12
                        let currentMinute = comps.minute ?? 0

                        // Apply explicit time if it differs from backend time
                        // (previously only applied if backend was noon/midnight)
                        if currentHour != h || currentMinute != m {
                            newDue = calendar.date(bySettingHour: h, minute: m, second: 0, of: due)
                        }
                    } else if let relative = relative {
                        let base = calendar.startOfDay(for: relative.anchorDate)
                        newDue = calendar.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
                    } else if let md = matchedDate {
                        newDue = md
                    } else {
                        let base = calendar.startOfDay(for: now)
                        newDue = calendar.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
                    }
                } else if let due = newDue, let md = matchedDate {
                    let dueComps = calendar.dateComponents([.hour, .minute], from: due)
                    let mdComps = calendar.dateComponents([.hour, .minute], from: md)
                    let currentHour = dueComps.hour ?? 12
                    let currentMinute = dueComps.minute ?? 0
                    let mdHour = mdComps.hour ?? 12
                    let mdMinute = mdComps.minute ?? 0

                    // Apply NSDataDetector's parsed time if it differs from backend time
                    // (previously only applied if backend was noon and matched was non-noon)
                    if currentHour != mdHour || currentMinute != mdMinute {
                        newDue = calendar.date(bySettingHour: mdHour, minute: mdMinute, second: 0, of: due)
                    }
                }

                if let relative = relative {
                    if let due = newDue {
                        let expectedDay = calendar.startOfDay(for: relative.anchorDate)
                        let dueDay = calendar.startOfDay(for: due)
                        let comps = calendar.dateComponents([.hour, .minute], from: due)
                        let defaultHour = relative.defaultHour ?? comps.hour ?? 12
                        let defaultMinute = comps.minute ?? 0
                        if dueDay != expectedDay {
                            newDue = calendar.date(bySettingHour: defaultHour, minute: defaultMinute, second: 0, of: expectedDay) ?? expectedDay
                        } else if let relHour = relative.defaultHour {
                            let isDefaultNoon = comps.hour == 12 && comps.minute == 0
                            let isDefaultMidnight = comps.hour == 0 && comps.minute == 0
                            if isDefaultNoon || isDefaultMidnight {
                                newDue = calendar.date(bySettingHour: relHour, minute: defaultMinute, second: 0, of: expectedDay) ?? expectedDay
                            }
                        }
                    } else {
                        let defaultHour = relative.defaultHour ?? 17
                        let base = calendar.startOfDay(for: relative.anchorDate)
                        newDue = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: base) ?? base
                    }
                }
            } else if let relative = resolveRelativeReference(in: contextText, now: now, calendar: calendar), newDue == nil {
                let defaultHour = relative.defaultHour ?? 17
                let base = calendar.startOfDay(for: relative.anchorDate)
                newDue = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: base) ?? base
            }

            refined.append(
                RemindersData.DetectedReminder(
                    id: reminder.id,
                    title: reminder.title,
                    dueDate: newDue,
                    priority: reminder.priority,
                    confidence: reminder.confidence,
                    sourceText: reminder.sourceText,
                    memoId: reminder.memoId
                )
            )
        }

        return RemindersData(reminders: refined)
    }

    /// Refine event start/end dates when the transcript/sourceText contains explicit time phrases.
    static func refine(eventsData: EventsData?, transcript: String, now: Date = Date()) -> EventsData? {
        guard let eventsData = eventsData else { return nil }
        if eventsData.events.isEmpty { return eventsData }

        var refined: [EventsData.DetectedEvent] = []
        let calendar = Calendar.current

        for event in eventsData.events {
            let contextText = event.sourceText.isEmpty ? transcript : event.sourceText
            var newStart = event.startDate
            var newEnd = event.endDate

            if let match = firstTemporalMatch(in: contextText) {
                let matchString = (contextText as NSString).substring(with: match.range)
                let explicitTime = extractExplicitTime(from: matchString)
                let matchedDate = match.date
                let relative = resolveRelativeReference(in: matchString, now: now, calendar: calendar)

                if let (h, m) = explicitTime {
                    if let start = newStart {
                        let startComps = calendar.dateComponents([.hour, .minute], from: start)
                        let currentHour = startComps.hour ?? 12
                        let currentMinute = startComps.minute ?? 0

                        // Apply explicit time if it differs from backend time
                        // (previously only applied if backend was noon/midnight)
                        if currentHour != h || currentMinute != m {
                            let originalStart = start
                            newStart = calendar.date(bySettingHour: h, minute: m, second: 0, of: start)
                            if let duration = durationBetween(start: originalStart, end: newEnd), let adjustedStart = newStart {
                                newEnd = adjustedStart.addingTimeInterval(duration)
                            }
                        }
                    } else if let relative = relative {
                        let base = calendar.startOfDay(for: relative.anchorDate)
                        newStart = calendar.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
                        if let duration = durationBetween(start: event.startDate, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    } else if let md = matchedDate {
                        newStart = md
                        if let duration = durationBetween(start: event.startDate, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    } else {
                        let base = calendar.startOfDay(for: now)
                        newStart = calendar.date(bySettingHour: h, minute: m, second: 0, of: base) ?? base
                        if let duration = durationBetween(start: event.startDate, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    }
                } else if let start = newStart, let md = matchedDate {
                    let startComps = calendar.dateComponents([.hour, .minute], from: start)
                    let mdComps = calendar.dateComponents([.hour, .minute], from: md)
                    let currentHour = startComps.hour ?? 12
                    let currentMinute = startComps.minute ?? 0
                    let mdHour = mdComps.hour ?? 12
                    let mdMinute = mdComps.minute ?? 0

                    // Apply NSDataDetector's parsed time if it differs from backend time
                    // (previously only applied if backend was noon and matched was non-noon)
                    if currentHour != mdHour || currentMinute != mdMinute {
                        let originalStart = start
                        newStart = calendar.date(bySettingHour: mdHour, minute: mdMinute, second: 0, of: start)
                        if let duration = durationBetween(start: originalStart, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    }
                }

                if let relative = relative, let start = newStart {
                    let expectedDay = calendar.startOfDay(for: relative.anchorDate)
                    let startDay = calendar.startOfDay(for: start)
                    var startComps = calendar.dateComponents([.hour, .minute], from: start)
                    let minute = startComps.minute ?? 0
                    if startDay != expectedDay {
                        let hour = relative.defaultHour ?? startComps.hour ?? 12
                        let originalStart = start
                        newStart = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: expectedDay) ?? expectedDay
                        if let duration = durationBetween(start: originalStart, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    } else if let relHour = relative.defaultHour {
                        let isDefaultNoon = startComps.hour == 12 && startComps.minute == 0
                        let isDefaultMidnight = startComps.hour == 0 && startComps.minute == 0
                        if isDefaultNoon || isDefaultMidnight {
                            let originalStart = start
                            startComps.hour = relHour
                            newStart = calendar.date(bySettingHour: relHour, minute: minute, second: 0, of: start) ?? start
                            if let duration = durationBetween(start: originalStart, end: newEnd), let adjustedStart = newStart {
                                newEnd = adjustedStart.addingTimeInterval(duration)
                            }
                        }
                    }
                } else if let relative = relative, newStart == nil {
                    let defaultHour = relative.defaultHour ?? 9
                    let base = calendar.startOfDay(for: relative.anchorDate)
                    newStart = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: base) ?? base
                    if let duration = durationBetween(start: event.startDate, end: newEnd), let adjustedStart = newStart {
                        newEnd = adjustedStart.addingTimeInterval(duration)
                    }
                }
            } else if let relative = resolveRelativeReference(in: contextText, now: now, calendar: calendar), newStart == nil {
                let defaultHour = relative.defaultHour ?? 9
                let base = calendar.startOfDay(for: relative.anchorDate)
                newStart = calendar.date(bySettingHour: defaultHour, minute: 0, second: 0, of: base) ?? base
                if let duration = durationBetween(start: event.startDate, end: newEnd), let adjustedStart = newStart {
                    newEnd = adjustedStart.addingTimeInterval(duration)
                }
            }

            refined.append(
                EventsData.DetectedEvent(
                    id: event.id,
                    title: event.title,
                    startDate: newStart,
                    endDate: newEnd,
                    location: event.location,
                    participants: event.participants,
                    confidence: event.confidence,
                    sourceText: event.sourceText,
                    memoId: event.memoId
                )
            )
        }

        return EventsData(events: refined)
    }

    // MARK: - Helpers

    /// First temporal match using NSDataDetector
    private static func firstTemporalMatch(in text: String) -> NSTextCheckingResult? {
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return detector.matches(in: text, options: [], range: range).first
    }

    /// Returns hour/minute if an explicit time-of-day (e.g., 6 pm, 6:30 p.m., 18:00) is present.
    private static func extractExplicitTime(from text: String) -> (Int, Int)? {
        let lower = text.lowercased()

        // 12-hour with am/pm, optional minutes, supports a.m./p.m. variants
        let pattern12 = #"\b(1[0-2]|0?\d)(?::([0-5]\d))?\s?(?:a\.?m\.?|p\.?m\.?|am|pm)\b"#
        if let (h, m, isPM) = match12Hour(lower, pattern: pattern12) {
            var hour = h
            if isPM, hour < 12 { hour += 12 }
            if !isPM, hour == 12 { hour = 0 } // 12am -> 0
            return (hour, m)
        }

        // 24-hour (e.g., 18:00)
        let pattern24 = #"\b([01]?\d|2[0-3]):([0-5]\d)\b"#
        if let match = lower.range(of: pattern24, options: .regularExpression) {
            let token = String(lower[match])
            let parts = token.split(separator: ":")
            if let h = Int(parts[0]), let m = Int(parts[1]) { return (h, m) }
        }

        // Bare hour without am/pm (e.g., "at 5" or "at 3") - default to PM for 1-11, AM for 12
        let patternBare = #"\b(?:at|around|about)\s+(1[0-2]|0?[1-9])(?:\s|$|[,.])"#
        if let regex = try? NSRegularExpression(pattern: patternBare, options: []) {
            let range = NSRange(lower.startIndex..<lower.endIndex, in: lower)
            if let match = regex.firstMatch(in: lower, options: [], range: range), match.numberOfRanges >= 2 {
                let hourStr = (lower as NSString).substring(with: match.range(at: 1))
                if let hour = Int(hourStr) {
                    // Default to PM for hours 1-11, keep 12 as 12 (noon)
                    let adjustedHour = (hour >= 1 && hour <= 11) ? hour + 12 : hour
                    return (adjustedHour, 0)
                }
            }
        }

        return nil
    }

    private static func match12Hour(_ text: String, pattern: String) -> (Int, Int, Bool)? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let m = regex.firstMatch(in: text, options: [], range: range) else { return nil }
        guard m.numberOfRanges >= 2 else { return nil }

        let hourStr = (text as NSString).substring(with: m.range(at: 1))
        let minuteStr = m.range(at: 2).location != NSNotFound ? (text as NSString).substring(with: m.range(at: 2)) : "0"
        let suffixRange = m.range(at: 0)
        let suffix = (text as NSString).substring(with: suffixRange)
        let isPM = suffix.contains("pm") || suffix.contains("p.m")
        guard let hour = Int(hourStr), let minute = Int(minuteStr) else { return nil }
        return (hour, minute, isPM)
    }

    private static func resolveRelativeReference(
        in text: String,
        now: Date,
        calendar: Calendar
    ) -> RelativeReference? {
        let lower = text.lowercased()

        if lower.contains("tomorrow") {
            let day = calendar.date(byAdding: .day, value: 1, to: now) ?? now
            return RelativeReference(
                anchorDate: calendar.startOfDay(for: day),
                defaultHour: nil,
                resolution: .relativeNamedDay
            )
        }

        if lower.contains("tonight") {
            return RelativeReference(
                anchorDate: calendar.startOfDay(for: now),
                defaultHour: 20,
                resolution: .partOfDay
            )
        }

        if lower.contains("today") {
            return RelativeReference(
                anchorDate: calendar.startOfDay(for: now),
                defaultHour: nil,
                resolution: .relativeNamedDay
            )
        }

        if lower.contains("next weekend") {
            let weekend = upcomingWeekendStart(after: now, calendar: calendar, includeCurrent: false)
            return RelativeReference(anchorDate: weekend, defaultHour: 10, resolution: .weekend)
        }

        if lower.contains("this weekend") || lower.contains("the weekend") || lower.contains("weekend") {
            let weekend = upcomingWeekendStart(after: now, calendar: calendar, includeCurrent: true)
            return RelativeReference(anchorDate: weekend, defaultHour: 10, resolution: .weekend)
        }

        if lower.contains("next week") {
            let weekStart = nextWeekStart(after: now, calendar: calendar)
            return RelativeReference(anchorDate: weekStart, defaultHour: 9, resolution: .week)
        }

        if let days = parseRelativeDays(lower) {
            let date = calendar.date(byAdding: .day, value: days, to: now) ?? now
            return RelativeReference(
                anchorDate: calendar.startOfDay(for: date),
                defaultHour: nil,
                resolution: .relativeDays
            )
        }

        if let weeks = parseRelativeWeeks(lower) {
            let date = calendar.date(byAdding: .day, value: weeks * 7, to: now) ?? now
            return RelativeReference(
                anchorDate: calendar.startOfDay(for: date),
                defaultHour: nil,
                resolution: .week
            )
        }

        return nil
    }

    private static func parseRelativeDays(_ text: String) -> Int? {
        if let regex = try? NSRegularExpression(pattern: #"in\s+(\d+)\s+day[s]?"#, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 {
                let numberRange = match.range(at: 1)
                if let substring = Range(numberRange, in: text), let value = Int(text[substring]) {
                    return value
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: #"in\s+(one|two|three|four|five|six|seven|eight|nine|ten)\s+day[s]?"#, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 {
                let wordRange = match.range(at: 1)
                if let substring = Range(wordRange, in: text), let value = wordNumberValue(String(text[substring])) {
                    return value
                }
            }
        }

        if text.contains("in a few days") || text.contains("in few days") { return 3 }
        if text.contains("in a couple days") || text.contains("in a couple of days") { return 2 }

        return nil
    }

    private static func parseRelativeWeeks(_ text: String) -> Int? {
        if let regex = try? NSRegularExpression(pattern: #"in\s+(\d+)\s+week[s]?"#, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 {
                let numberRange = match.range(at: 1)
                if let substring = Range(numberRange, in: text), let value = Int(text[substring]) {
                    return value
                }
            }
        }

        if let regex = try? NSRegularExpression(pattern: #"in\s+(one|two|three|four|five|six|seven|eight|nine|ten)\s+week[s]?"#, options: []) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 {
                let wordRange = match.range(at: 1)
                if let substring = Range(wordRange, in: text), let value = wordNumberValue(String(text[substring])) {
                    return value
                }
            }
        }

        if text.contains("in a few weeks") { return 3 }
        if text.contains("in a couple weeks") || text.contains("in a couple of weeks") { return 2 }

        return nil
    }

    private static func wordNumberValue(_ word: String) -> Int? {
        switch word {
        case "one": return 1
        case "two": return 2
        case "three": return 3
        case "four": return 4
        case "five": return 5
        case "six": return 6
        case "seven": return 7
        case "eight": return 8
        case "nine": return 9
        case "ten": return 10
        default: return nil
        }
    }

    private static func upcomingWeekendStart(after now: Date, calendar: Calendar, includeCurrent: Bool) -> Date {
        let startOfDay = calendar.startOfDay(for: now)

        if includeCurrent, calendar.isDateInWeekend(now) {
            let weekday = calendar.component(.weekday, from: now)
            if weekday == 7 { // Saturday
                return startOfDay
            } else {
                return calendar.date(byAdding: .day, value: -1, to: startOfDay) ?? startOfDay
            }
        }

        let nextSaturday = calendar.nextDate(
            after: now,
            matching: DateComponents(weekday: 7),
            matchingPolicy: .nextTimePreservingSmallerComponents,
            direction: .forward
        ) ?? now
        let candidate = calendar.startOfDay(for: nextSaturday)
        if includeCurrent {
            return candidate
        }
        return calendar.date(byAdding: .day, value: 7, to: candidate) ?? candidate
    }

    private static func nextWeekStart(after now: Date, calendar: Calendar) -> Date {
        let nextMonday = calendar.nextDate(
            after: now,
            matching: DateComponents(weekday: 2),
            matchingPolicy: .nextTimePreservingSmallerComponents,
            direction: .forward
        ) ?? now
        return calendar.startOfDay(for: nextMonday)
    }

    private static func durationBetween(start: Date?, end: Date?) -> TimeInterval? {
        guard let start, let end else { return nil }
        let duration = end.timeIntervalSince(start)
        return duration >= 0 ? duration : nil
    }
}

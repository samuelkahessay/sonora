import Foundation

/// Utility to refine detected reminder times using temporal phrases in the source text.
enum TemporalRefiner {
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

        for r in remindersData.reminders {
            let contextText = r.sourceText.isEmpty ? transcript : r.sourceText
            var newDue = r.dueDate

            // Find the first temporal match in the context text
            if let match = firstTemporalMatch(in: contextText) {
                let matchString = (contextText as NSString).substring(with: match.range)
                let explicitTime = extractExplicitTime(from: matchString)
                let matchedDate = match.date // May be noon if no time phrase

                // If we have an explicit time in text, prefer its time-of-day
                if let (h, m) = explicitTime {
                    if let due = newDue {
                        let comps = calendar.dateComponents([.hour, .minute], from: due)
                        // Only override "default" times (noon or midnight) to avoid clobbering good upstream times
                        let isDefaultNoon = comps.hour == 12 && comps.minute == 0
                        let isDefaultMidnight = comps.hour == 0 && comps.minute == 0
                        if isDefaultNoon || isDefaultMidnight {
                            newDue = calendar.date(bySettingHour: h, minute: m, second: 0, of: due)
                        }
                    } else if let offset = dayOffset(in: matchString) {
                        let base = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: now) ?? now)
                        newDue = calendar.date(bySettingHour: h, minute: m, second: 0, of: base)
                    } else {
                        // If upstream didn't provide a date but we have an explicit time, try to use detector's date
                        // (if present), otherwise fall back to today at the detected time.
                        if let md = matchedDate {
                            newDue = md
                        } else {
                            let base = calendar.startOfDay(for: now)
                            newDue = calendar.date(bySettingHour: h, minute: m, second: 0, of: base)
                        }
                    }
                } else if let due = newDue, let md = matchedDate {
                    // No explicit time phrase, but detector has a date (may still be noon).
                    // If upstream due is default noon, and detector's date has a non-noon time, adopt it.
                    let dueComps = calendar.dateComponents([.hour, .minute], from: due)
                    let mdComps = calendar.dateComponents([.hour, .minute], from: md)
                    let isDueDefaultNoon = dueComps.hour == 12 && dueComps.minute == 0
                    let mdIsNonNoon = !(mdComps.hour == 12 && mdComps.minute == 0)
                    if isDueDefaultNoon && mdIsNonNoon {
                        newDue = calendar.date(bySettingHour: mdComps.hour ?? 12, minute: mdComps.minute ?? 0, second: 0, of: due)
                    }
                }

                // Align date to relative indicators (today/tomorrow) if clearly specified
                if let offset = dayOffset(in: matchString), let due = newDue {
                    let expectedDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: now) ?? now)
                    let dueDay = calendar.startOfDay(for: due)
                    if dueDay != expectedDay {
                        let comps = calendar.dateComponents([.hour, .minute], from: due)
                        newDue = calendar.date(bySettingHour: comps.hour ?? 12, minute: comps.minute ?? 0, second: 0, of: expectedDay)
                    }
                }
            }

            // Append possibly refined reminder
            refined.append(
                RemindersData.DetectedReminder(
                    id: r.id,
                    title: r.title,
                    dueDate: newDue,
                    priority: r.priority,
                    confidence: r.confidence,
                    sourceText: r.sourceText,
                    memoId: r.memoId
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

        for e in eventsData.events {
            let contextText = e.sourceText.isEmpty ? transcript : e.sourceText
            var newStart = e.startDate
            var newEnd = e.endDate

            if let match = firstTemporalMatch(in: contextText) {
                let matchString = (contextText as NSString).substring(with: match.range)
                let explicitTime = extractExplicitTime(from: matchString)
                let matchedDate = match.date

                if let (h, m) = explicitTime {
                    if let start = newStart {
                        let startComps = calendar.dateComponents([.hour, .minute], from: start)
                        let isDefaultNoon = startComps.hour == 12 && startComps.minute == 0
                        let isDefaultMidnight = startComps.hour == 0 && startComps.minute == 0
                        if isDefaultNoon || isDefaultMidnight {
                            let originalStart = start
                            newStart = calendar.date(bySettingHour: h, minute: m, second: 0, of: start)
                            if let duration = durationBetween(start: originalStart, end: newEnd), let adjustedStart = newStart {
                                newEnd = adjustedStart.addingTimeInterval(duration)
                            }
                        }
                    } else if let offset = dayOffset(in: matchString) {
                        let base = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: now) ?? now)
                        newStart = calendar.date(bySettingHour: h, minute: m, second: 0, of: base)
                        if let duration = durationBetween(start: e.startDate, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    } else {
                        if let md = matchedDate {
                            newStart = md
                        } else {
                            let base = calendar.startOfDay(for: now)
                            newStart = calendar.date(bySettingHour: h, minute: m, second: 0, of: base)
                        }
                        if let duration = durationBetween(start: e.startDate, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    }
                } else if let start = newStart, let md = matchedDate {
                    let startComps = calendar.dateComponents([.hour, .minute], from: start)
                    let mdComps = calendar.dateComponents([.hour, .minute], from: md)
                    let isStartDefaultNoon = startComps.hour == 12 && startComps.minute == 0
                    let mdIsNonNoon = !(mdComps.hour == 12 && mdComps.minute == 0)
                    if isStartDefaultNoon && mdIsNonNoon {
                        let originalStart = start
                        newStart = calendar.date(bySettingHour: mdComps.hour ?? 12, minute: mdComps.minute ?? 0, second: 0, of: start)
                        if let duration = durationBetween(start: originalStart, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    }
                }

                if let offset = dayOffset(in: matchString), let start = newStart {
                    let expectedDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: now) ?? now)
                    let startDay = calendar.startOfDay(for: start)
                    if startDay != expectedDay {
                        let comps = calendar.dateComponents([.hour, .minute], from: start)
                        let originalStart = start
                        newStart = calendar.date(bySettingHour: comps.hour ?? 12, minute: comps.minute ?? 0, second: 0, of: expectedDay)
                        if let duration = durationBetween(start: originalStart, end: newEnd), let adjustedStart = newStart {
                            newEnd = adjustedStart.addingTimeInterval(duration)
                        }
                    }
                }
            }

            refined.append(
                EventsData.DetectedEvent(
                    id: e.id,
                    title: e.title,
                    startDate: newStart,
                    endDate: newEnd,
                    location: e.location,
                    participants: e.participants,
                    confidence: e.confidence,
                    sourceText: e.sourceText,
                    memoId: e.memoId
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

    /// Returns 0 for today, 1 for tomorrow when clearly indicated in the text.
    private static func dayOffset(in text: String) -> Int? {
        let lower = text.lowercased()
        if lower.contains("tomorrow") { return 1 }
        if lower.contains("today") { return 0 }
        if lower.contains("tonight") { return 0 }
        return nil
    }

    private static func durationBetween(start: Date?, end: Date?) -> TimeInterval? {
        guard let start, let end else { return nil }
        let duration = end.timeIntervalSince(start)
        return duration >= 0 ? duration : nil
    }
}

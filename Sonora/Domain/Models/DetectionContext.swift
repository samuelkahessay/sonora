import Foundation

/// Lightweight, pure-Swift feature context extracted from a transcript
/// Used for adaptive thresholding and simple routing heuristics.
struct DetectionContext: Sendable {
    let memoId: UUID
    let transcriptLength: Int
    let sentenceCount: Int
    let hasDatesOrTimes: Bool
    let hasCalendarPhrases: Bool
    let imperativeVerbDensity: Double // 0.0 – 1.0 (approximate)
    let localeIdentifier: String
    let avgSentenceLength: Double
}

/// Utility to derive DetectionContext features from raw transcript text.
enum DetectionContextBuilder {
    static func build(memoId: UUID, transcript: String, locale: Locale = .current) -> DetectionContext {
        let trimmed = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        let length = trimmed.count

        // Rough sentence segmentation by punctuation.
        let sentenceSeparators = CharacterSet(charactersIn: ".!?\n")
        let parts = trimmed.components(separatedBy: sentenceSeparators).filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let sentenceCount = max(parts.count, 1)
        let avgSentenceLen = Double(length) / Double(sentenceCount)

        // Very lightweight regex signals (pure Swift, no frameworks)
        let hasDatesTimes = Self.containsDateOrTime(trimmed)
        let hasCalendar = Self.containsCalendarPhrase(trimmed)
        let impDensity = Self.estimateImperativeDensity(trimmed)

        return DetectionContext(
            memoId: memoId,
            transcriptLength: length,
            sentenceCount: sentenceCount,
            hasDatesOrTimes: hasDatesTimes,
            hasCalendarPhrases: hasCalendar,
            imperativeVerbDensity: impDensity,
            localeIdentifier: locale.identifier,
            avgSentenceLength: avgSentenceLen
        )
    }

    private static func containsDateOrTime(_ text: String) -> Bool {
        // Expanded signals: times of day, parts of week, natural phrases
        let lower = text.lowercased()
        let timePatterns = [":", "am", "pm", "eod", "end of day", "noon", "midnight",
                            "morning", "afternoon", "evening", "tonight", "today", "tomorrow",
                            "next "]
        let weekdays = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        let months = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
        if timePatterns.contains(where: { lower.contains($0) }) { return true }
        if weekdays.contains(where: { lower.contains($0) }) { return true }
        if months.contains(where: { lower.contains($0) }) { return true }
        // simple numeric date like 12/25 or 2025-01-02
        if lower.range(of: #"\b\d{1,2}[/-]\d{1,2}(?:[/-]\d{2,4})?\b"#, options: .regularExpression) != nil { return true }
        if lower.range(of: #"\b\d{4}-\d{2}-\d{2}\b"#, options: .regularExpression) != nil { return true }
        // explicit clock time like 2pm or 10am PST
        if lower.range(of: #"\b\d{1,2}\s?(?:am|pm)(?:\s?[a-z]{2,4})?\b"#, options: .regularExpression) != nil { return true }
        return false
    }

    private static func containsCalendarPhrase(_ text: String) -> Bool {
        let lower = text.lowercased()
        // Expanded lexicon capturing common planning verbs/nouns and shorthand
        let phrases = [
            "schedule", "meeting", "meet", "call", "appointment", "calendar", "sync",
            "lock in", "lock-in", "review", "audit", "onboarding", "teardown",
            "remind", "reminder", "follow up", "follow-up", "due", "deadline", "push",
            "circle back", "circle-back"
        ]
        return phrases.contains(where: { lower.contains($0) })
    }

    private static func estimateImperativeDensity(_ text: String) -> Double {
        let lower = text.lowercased()
        let tokens = lower.split { !$0.isLetter }
        guard !tokens.isEmpty else { return 0 }
        // common imperative/command-like verbs
        let imperative = Set(["schedule", "set", "remind", "email", "call", "ping", "book", "reserve", "send", "follow", "prepare", "draft", "finish", "complete", "review"])
        let hits = tokens.filter { imperative.contains(String($0)) }.count
        return Double(hits) / Double(tokens.count)
    }
}

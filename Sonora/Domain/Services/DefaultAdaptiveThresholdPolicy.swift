import Foundation

/// Heuristic, fast policy that adapts confidence thresholds to reduce false positives.
/// Pure Swift, no external dependencies. Tunable via weight constants.
struct DefaultAdaptiveThresholdPolicy: AdaptiveThresholdPolicy, Sendable {
    func thresholds(for context: DetectionContext) -> (event: Float, reminder: Float) {
        // Base thresholds (slightly lower to improve recall)
        var event: Double = 0.65
        var reminder: Double = 0.60

        // Make short/simple content stricter to suppress spurious detections
        if context.transcriptLength < 80 || context.sentenceCount <= 2 {
            event += 0.10
            reminder += 0.10
        }

        // If explicit date/time present, lower event threshold more aggressively
        if context.hasDatesOrTimes { event -= 0.15 }

        // Calendar phrasing indicates intent; allow a bit more leniency for reminders
        if context.hasCalendarPhrases { reminder -= 0.10 }

        // High imperative density often correlates with todo-like content; favor reminders
        if context.imperativeVerbDensity > 0.02 { reminder -= 0.08 }

        // Very long or dense transcripts can produce many candidates; tighten slightly
        if context.transcriptLength > 1500 || context.avgSentenceLength > 120 {
            event += 0.05
            reminder += 0.05
        }

        // Clamp bounds
        let e = Float(min(max(event, 0.45), 0.90))
        let r = Float(min(max(reminder, 0.45), 0.90))
        return (e, r)
    }
}

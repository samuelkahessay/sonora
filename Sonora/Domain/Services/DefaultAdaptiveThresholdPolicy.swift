import Foundation

/// Heuristic, fast policy that adapts confidence thresholds to reduce false positives.
/// Pure Swift, no external dependencies. Tunable via weight constants.
struct DefaultAdaptiveThresholdPolicy: AdaptiveThresholdPolicy, Sendable {
    func thresholds(for context: DetectionContext) -> (event: Float, reminder: Float) {
        // Base thresholds (match previous defaults ~0.7)
        var event: Double = 0.70
        var reminder: Double = 0.70

        // Make short/simple content stricter to suppress spurious detections
        if context.transcriptLength < 80 || context.sentenceCount <= 2 {
            event += 0.10
            reminder += 0.10
        }

        // If explicit date/time present, slightly lower event threshold to capture real events
        if context.hasDatesOrTimes { event -= 0.05 }

        // Calendar phrasing indicates intent; allow a bit more leniency for reminders
        if context.hasCalendarPhrases { reminder -= 0.05 }

        // High imperative density often correlates with todo-like content; favor reminders
        if context.imperativeVerbDensity > 0.02 { reminder -= 0.05 }

        // Very long or dense transcripts can produce many candidates; tighten slightly
        if context.transcriptLength > 1500 || context.avgSentenceLength > 120 {
            event += 0.05
            reminder += 0.05
        }

        // Clamp bounds
        let e = Float(min(max(event, 0.50), 0.90))
        let r = Float(min(max(reminder, 0.50), 0.90))
        return (e, r)
    }
}


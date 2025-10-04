import Foundation

/// Heuristic, fast policy that adapts confidence thresholds to reduce false positives.
/// Pure Swift, no external dependencies. Tunable via weight constants.
struct DefaultAdaptiveThresholdPolicy: AdaptiveThresholdPolicy, Sendable {
    func thresholds(for context: DetectionContext) -> (event: Float, reminder: Float) {
        // Baseline thresholds
        var eventThreshold: Float = 0.45
        var reminderThreshold: Float = 0.40

        // Raise thresholds for short, simple content to reduce false positives
        let isShortContent = context.transcriptLength < 50
        let isSimpleContent = context.sentenceCount <= 1

        if isShortContent && isSimpleContent {
            // Very little context → be more conservative
            eventThreshold = 0.75
            reminderThreshold = 0.70
        }

        // Lower thresholds when strong calendar signals are present
        let hasStrongCalendarSignals = context.hasDatesOrTimes
            && context.hasCalendarPhrases
            && (context.hasRelativeDatePhrases || context.hasWeekendReferences)

        if hasStrongCalendarSignals && !isShortContent {
            // Rich temporal context → more permissive detection
            reminderThreshold = max(0.35, reminderThreshold - 0.10)
            eventThreshold = max(0.40, eventThreshold - 0.05)
        }

        return (eventThreshold, reminderThreshold)
    }
}

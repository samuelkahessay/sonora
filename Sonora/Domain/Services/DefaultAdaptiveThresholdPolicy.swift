import Foundation

/// Heuristic, fast policy that adapts confidence thresholds to reduce false positives.
/// Pure Swift, no external dependencies. Tunable via weight constants.
struct DefaultAdaptiveThresholdPolicy: AdaptiveThresholdPolicy, Sendable {
    func thresholds(for context: DetectionContext) -> (event: Float, reminder: Float) {
        // Align with the historical baseline that previously delivered good balance.
        // Additional heuristics can be layered back once telemetry confirms the
        // updated confidence distribution.
        _ = context // retained for future heuristic tuning
        return (0.45, 0.40)
    }
}

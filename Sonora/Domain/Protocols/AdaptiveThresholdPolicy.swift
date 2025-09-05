import Foundation

/// Provides adaptive confidence thresholds based on transcript/context features
protocol AdaptiveThresholdPolicy: Sendable {
    func thresholds(for context: DetectionContext) -> (event: Float, reminder: Float)
}


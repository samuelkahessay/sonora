import Foundation
import Combine

/// Repository for tracking per-day recording usage (in seconds)
/// Domain-facing protocol; implementations live in Data layer.
public protocol RecordingUsageRepository: Sendable {
    /// Returns usage seconds for the provided day (start-of-day considered via Calendar).
    func usage(for day: Date) async -> TimeInterval
    /// Adds usage seconds for the provided day (accumulates atomically).
    func addUsage(_ seconds: TimeInterval, for day: Date) async
    /// Resets in-memory state if the day has changed; useful on app foreground or before new session.
    func resetIfDayChanged(now: Date) async
    /// Publishes the current day's usage in seconds (updates when usage changes or rolls over).
    var todayUsagePublisher: AnyPublisher<TimeInterval, Never> { get }
}


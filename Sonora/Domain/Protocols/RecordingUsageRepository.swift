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

    // MARK: - Monthly (additive)
    /// Returns usage seconds from the start of the specified month to date.
    func monthToDateUsage(for monthStart: Date) async -> TimeInterval
    /// Adds usage seconds to the month bucket corresponding to `day`.
    func addMonthlyUsage(_ seconds: TimeInterval, for day: Date) async
    /// Resets in-memory month state if the month boundary has changed.
    func resetIfMonthChanged(now: Date) async
    /// Publishes the current month-to-date usage in seconds.
    var monthUsagePublisher: AnyPublisher<TimeInterval, Never> { get }
}

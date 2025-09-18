import Foundation
@preconcurrency import Combine

/// UserDefaults-backed implementation of RecordingUsageRepository
/// Stores usage seconds per local day (yyyy-MM-dd), publishes today's usage.
final class RecordingUsageRepositoryImpl: RecordingUsageRepository, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let dateFormatter: DateFormatter
    private let queue = DispatchQueue(label: "RecordingUsageRepository.queue")

    private let subject: CurrentValueSubject<TimeInterval, Never>
    private var currentDayKey: String

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.dateFormatter = DateFormatter()
        self.dateFormatter.calendar = calendar
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.dateFormat = "yyyy-MM-dd"

        let today = calendar.startOfDay(for: Date())
        let dayKey = Self.makeDayKey(today, formatter: dateFormatter)
        self.currentDayKey = dayKey
        let initial = userDefaults.double(forKey: Self.storageKey(for: dayKey))
        self.subject = CurrentValueSubject<TimeInterval, Never>(initial)
    }

    var todayUsagePublisher: AnyPublisher<TimeInterval, Never> { subject.eraseToAnyPublisher() }

    func usage(for day: Date) async -> TimeInterval {
        let key = Self.makeDayKey(calendar.startOfDay(for: day), formatter: dateFormatter)
        return queue.sync { userDefaults.double(forKey: Self.storageKey(for: key)) }
    }

    func addUsage(_ seconds: TimeInterval, for day: Date) async {
        let add = max(0, seconds)
        let dayKey = Self.makeDayKey(calendar.startOfDay(for: day), formatter: dateFormatter)
        let publishValue: TimeInterval? = queue.sync {
            let storageKey = Self.storageKey(for: dayKey)
            let current = userDefaults.double(forKey: storageKey)
            let updated = current + add
            userDefaults.set(updated, forKey: storageKey)
            return dayKey == currentDayKey ? updated : nil
        }

        if let value = publishValue {
            await MainActor.run {
                subject.send(value)
            }
        }
    }

    func resetIfDayChanged(now: Date) async {
        let dayKey = Self.makeDayKey(calendar.startOfDay(for: now), formatter: dateFormatter)
        let publishValue: TimeInterval? = queue.sync {
            guard dayKey != currentDayKey else { return nil }
            currentDayKey = dayKey
            let storageKey = Self.storageKey(for: dayKey)
            return userDefaults.double(forKey: storageKey)
        }

        if let value = publishValue {
            await MainActor.run {
                subject.send(value)
            }
        }
    }

    private static func makeDayKey(_ date: Date, formatter: DateFormatter) -> String {
        return formatter.string(from: date)
    }

    private static func storageKey(for dayKey: String) -> String {
        return "recording_usage_" + dayKey
    }
}

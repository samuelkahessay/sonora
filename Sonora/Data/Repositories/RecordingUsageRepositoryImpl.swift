import Foundation
@preconcurrency import Combine

/// UserDefaults-backed implementation of RecordingUsageRepository
/// Stores usage seconds per local day (yyyy-MM-dd), publishes today's usage.
final class RecordingUsageRepositoryImpl: RecordingUsageRepository, @unchecked Sendable {
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private let dateFormatter: DateFormatter // yyyy-MM-dd
    private let monthFormatter: DateFormatter // yyyy-MM
    private let queue = DispatchQueue(label: "RecordingUsageRepository.queue")

    private let subject: CurrentValueSubject<TimeInterval, Never>
    private let monthSubject: CurrentValueSubject<TimeInterval, Never>
    private var currentDayKey: String
    private var currentMonthKey: String

    init(userDefaults: UserDefaults = .standard, calendar: Calendar = .current) {
        self.userDefaults = userDefaults
        self.calendar = calendar
        self.dateFormatter = DateFormatter()
        self.dateFormatter.calendar = calendar
        self.dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.dateFormatter.dateFormat = "yyyy-MM-dd"

        self.monthFormatter = DateFormatter()
        self.monthFormatter.calendar = calendar
        self.monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.monthFormatter.dateFormat = "yyyy-MM"

        let now = Date()
        let today = calendar.startOfDay(for: now)
        let dayKey = Self.makeDayKey(today, formatter: dateFormatter)
        self.currentDayKey = dayKey
        let initialDay = userDefaults.double(forKey: Self.storageKey(for: dayKey))
        self.subject = CurrentValueSubject<TimeInterval, Never>(initialDay)

        let monthKey = Self.makeMonthKey(now, formatter: monthFormatter, calendar: calendar)
        self.currentMonthKey = monthKey
        let initialMonth = userDefaults.double(forKey: Self.storageMonthKey(for: monthKey))
        self.monthSubject = CurrentValueSubject<TimeInterval, Never>(initialMonth)
    }

    var todayUsagePublisher: AnyPublisher<TimeInterval, Never> { subject.eraseToAnyPublisher() }
    var monthUsagePublisher: AnyPublisher<TimeInterval, Never> { monthSubject.eraseToAnyPublisher() }

    func usage(for day: Date) async -> TimeInterval {
        let key = Self.makeDayKey(calendar.startOfDay(for: day), formatter: dateFormatter)
        return queue.sync { userDefaults.double(forKey: Self.storageKey(for: key)) }
    }

    func addUsage(_ seconds: TimeInterval, for day: Date) async {
        let add = max(0, seconds)
        let dayKey = Self.makeDayKey(calendar.startOfDay(for: day), formatter: dateFormatter)
        let monthKey = Self.makeMonthKey(day, formatter: monthFormatter, calendar: calendar)
        let (publishDay, publishMonth): (TimeInterval?, TimeInterval?) = queue.sync {
            let storageKey = Self.storageKey(for: dayKey)
            let current = userDefaults.double(forKey: storageKey)
            let updated = current + add
            userDefaults.set(updated, forKey: storageKey)
            // Update monthly bucket
            let monthStorageKey = Self.storageMonthKey(for: monthKey)
            let monthCur = userDefaults.double(forKey: monthStorageKey)
            let monthUpdated = monthCur + add
            userDefaults.set(monthUpdated, forKey: monthStorageKey)

            let dayPublish: TimeInterval? = (dayKey == currentDayKey) ? updated : nil
            let monthPublish: TimeInterval? = (monthKey == currentMonthKey) ? monthUpdated : nil
            return (dayPublish, monthPublish)
        }

        if let value = publishDay {
            await MainActor.run {
                subject.send(value)
            }
        }
        if let mvalue = publishMonth {
            await MainActor.run {
                monthSubject.send(mvalue)
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

    func monthToDateUsage(for monthStart: Date) async -> TimeInterval {
        let key = Self.makeMonthKey(monthStart, formatter: monthFormatter, calendar: calendar)
        return queue.sync { userDefaults.double(forKey: Self.storageMonthKey(for: key)) }
    }

    func addMonthlyUsage(_ seconds: TimeInterval, for day: Date) async {
        let add = max(0, seconds)
        let monthKey = Self.makeMonthKey(day, formatter: monthFormatter, calendar: calendar)
        let publishValue: TimeInterval? = queue.sync {
            let storageKey = Self.storageMonthKey(for: monthKey)
            let current = userDefaults.double(forKey: storageKey)
            let updated = current + add
            userDefaults.set(updated, forKey: storageKey)
            return monthKey == currentMonthKey ? updated : nil
        }
        if let value = publishValue {
            await MainActor.run { monthSubject.send(value) }
        }
    }

    func resetIfMonthChanged(now: Date) async {
        let monthKey = Self.makeMonthKey(now, formatter: monthFormatter, calendar: calendar)
        let publishValue: TimeInterval? = queue.sync {
            guard monthKey != currentMonthKey else { return nil }
            currentMonthKey = monthKey
            let storageKey = Self.storageMonthKey(for: monthKey)
            return userDefaults.double(forKey: storageKey)
        }
        if let value = publishValue {
            await MainActor.run { monthSubject.send(value) }
        }
    }

    private static func makeDayKey(_ date: Date, formatter: DateFormatter) -> String {
        return formatter.string(from: date)
    }

    private static func storageKey(for dayKey: String) -> String {
        return "recording_usage_" + dayKey
    }

    private static func makeMonthKey(_ date: Date, formatter: DateFormatter, calendar: Calendar) -> String {
        // Normalize to start of month in the current calendar/timezone
        if let interval = calendar.dateInterval(of: .month, for: date) {
            return formatter.string(from: interval.start)
        }
        return formatter.string(from: date)
    }

    private static func storageMonthKey(for monthKey: String) -> String {
        return "recording_usage_month_" + monthKey
    }
}

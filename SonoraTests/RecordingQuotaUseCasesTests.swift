import Combine
import Foundation
@testable import Sonora
import Testing

// In-memory RecordingUsageRepository mock
final class InMemoryRecordingUsageRepository: RecordingUsageRepository {
    private var store: [String: TimeInterval] = [:]
    private var monthStore: [String: TimeInterval] = [:]
    private let subject = CurrentValueSubject<TimeInterval, Never>(0)
    private let monthSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let calendar: Calendar
    private let formatter: DateFormatter
    private var currentKey: String
    private let monthFormatter: DateFormatter
    private var currentMonthKey: String

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.formatter = DateFormatter()
        self.formatter.calendar = calendar
        self.formatter.locale = Locale(identifier: "en_US_POSIX")
        self.formatter.dateFormat = "yyyy-MM-dd"
        let today = calendar.startOfDay(for: Date())
        self.currentKey = formatter.string(from: today)
        self.subject.send(0)

        self.monthFormatter = DateFormatter()
        self.monthFormatter.calendar = calendar
        self.monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        self.monthFormatter.dateFormat = "yyyy-MM"
        if let interval = calendar.dateInterval(of: .month, for: Date()) {
            self.currentMonthKey = monthFormatter.string(from: interval.start)
        } else {
            self.currentMonthKey = monthFormatter.string(from: Date())
        }
        self.monthSubject.send(0)
    }

    var todayUsagePublisher: AnyPublisher<TimeInterval, Never> { subject.eraseToAnyPublisher() }
    var monthUsagePublisher: AnyPublisher<TimeInterval, Never> { monthSubject.eraseToAnyPublisher() }

    func usage(for day: Date) async -> TimeInterval {
        let key = formatter.string(from: calendar.startOfDay(for: day))
        return store[key] ?? 0
    }

    func addUsage(_ seconds: TimeInterval, for day: Date) async {
        let key = formatter.string(from: calendar.startOfDay(for: day))
        let cur = store[key] ?? 0
        let next = cur + max(0, seconds)
        store[key] = next
        if key == currentKey { subject.send(next) }

        // monthly
        let monthKey: String = {
            if let interval = calendar.dateInterval(of: .month, for: day) {
                return monthFormatter.string(from: interval.start)
            }
            return monthFormatter.string(from: day)
        }()
        let mcur = monthStore[monthKey] ?? 0
        let mnext = mcur + max(0, seconds)
        monthStore[monthKey] = mnext
        if monthKey == currentMonthKey { monthSubject.send(mnext) }
    }

    func resetIfDayChanged(now: Date) async {
        let key = formatter.string(from: calendar.startOfDay(for: now))
        if key != currentKey {
            currentKey = key
            subject.send(store[key] ?? 0)
        }
    }

    func monthToDateUsage(for monthStart: Date) async -> TimeInterval {
        let key = monthFormatter.string(from: monthStart)
        return monthStore[key] ?? 0
    }

    func addMonthlyUsage(_ seconds: TimeInterval, for day: Date) async {
        let key = monthFormatter.string(from: day)
        let cur = monthStore[key] ?? 0
        let next = cur + max(0, seconds)
        monthStore[key] = next
        if key == currentMonthKey { monthSubject.send(next) }
    }

    func resetIfMonthChanged(now: Date) async {
        let key: String
        if let interval = calendar.dateInterval(of: .month, for: now) {
            key = monthFormatter.string(from: interval.start)
        } else {
            key = monthFormatter.string(from: now)
        }
        if key != currentMonthKey {
            currentMonthKey = key
            monthSubject.send(monthStore[key] ?? 0)
        }
    }
}

struct RecordingQuotaUseCasesTests {
    @Test
    @MainActor
    func testCanStartRecordingUseCase_AllowsAndClamps_Monthly() async throws {
        let repo = InMemoryRecordingUsageRepository()
        // Compose monthly UC over the in-memory repo and default policy (free)
        let monthlyUC = GetRemainingMonthlyQuotaUseCase(quotaPolicy: DefaultRecordingQuotaPolicy(), usageRepository: repo)
        let canStart = CanStartRecordingUseCase(getRemainingMonthlyQuotaUseCase: monthlyUC)

        // Fresh month: remaining=3_600
        let allowed1 = try await canStart.execute(service: .cloudAPI)
        #expect(allowed1 == 3_600)

        // Consume 3_590s
        await repo.addUsage(3_590, for: Date())
        let allowed2 = try await canStart.execute(service: .cloudAPI)
        #expect(allowed2 == 10)

        // Consume remaining 10
        await repo.addUsage(10, for: Date())
        do {
            _ = try await canStart.execute(service: .cloudAPI)
            #expect(Bool(false)) // Should not reach
        } catch let err as RecordingQuotaError {
            switch err { case .limitReached(let remaining): #expect(remaining == 0) }
        }
    }

    @Test
    @MainActor
    func testConsumeAndRemainingMonthlyUseCases() async throws {
        let repo = InMemoryRecordingUsageRepository()
        let consume = ConsumeRecordingUsageUseCase(usageRepository: repo)
        let monthly = GetRemainingMonthlyQuotaUseCase(quotaPolicy: DefaultRecordingQuotaPolicy(), usageRepository: repo)

        // Start with 0 used for cloud
        var rem = try await monthly.execute()
        #expect(rem == 3_600)

        // Consume 125s (adds to month via addUsage inside consume)
        await consume.execute(elapsed: 125, service: .cloudAPI)
        rem = try await monthly.execute()
        #expect(rem == 3_600 - 125)
    }
}

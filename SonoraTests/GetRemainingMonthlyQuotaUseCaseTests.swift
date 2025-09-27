import Testing
import Foundation
@testable import Sonora

// Reuse the in-memory repo used in RecordingQuotaUseCasesTests but ensure month API is available.
final class InMemoryMonthlyUsageRepo: RecordingUsageRepository {
    private var day: [String: TimeInterval] = [:]
    private var month: [String: TimeInterval] = [:]
    private let daySubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let monthSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let cal: Calendar
    private let dayFmt: DateFormatter
    private let monFmt: DateFormatter
    private var curDayKey: String
    private var curMonthKey: String

    init(calendar: Calendar = .current) {
        self.cal = calendar
        self.dayFmt = DateFormatter(); dayFmt.calendar = calendar; dayFmt.locale = Locale(identifier: "en_US_POSIX"); dayFmt.dateFormat = "yyyy-MM-dd"
        self.monFmt = DateFormatter(); monFmt.calendar = calendar; monFmt.locale = Locale(identifier: "en_US_POSIX"); monFmt.dateFormat = "yyyy-MM"
        let now = Date()
        let dk = dayFmt.string(from: calendar.startOfDay(for: now))
        self.curDayKey = dk
        if let interval = calendar.dateInterval(of: .month, for: now) {
            self.curMonthKey = monFmt.string(from: interval.start)
        } else {
            self.curMonthKey = monFmt.string(from: now)
        }
    }

    var todayUsagePublisher: AnyPublisher<TimeInterval, Never> { daySubject.eraseToAnyPublisher() }
    var monthUsagePublisher: AnyPublisher<TimeInterval, Never> { monthSubject.eraseToAnyPublisher() }

    func usage(for day: Date) async -> TimeInterval {
        let key = dayFmt.string(from: cal.startOfDay(for: day))
        return self.day[key] ?? 0
    }
    func addUsage(_ seconds: TimeInterval, for day: Date) async {
        let key = dayFmt.string(from: cal.startOfDay(for: day))
        let cur = self.day[key] ?? 0
        let add = max(0, seconds)
        let upd = cur + add
        self.day[key] = upd
        if key == curDayKey { daySubject.send(upd) }

        // monthly
        let mkey: String = {
            if let iv = cal.dateInterval(of: .month, for: day) { return monFmt.string(from: iv.start) }
            return monFmt.string(from: day)
        }()
        let mcur = self.month[mkey] ?? 0
        let mupd = mcur + add
        self.month[mkey] = mupd
        if mkey == curMonthKey { monthSubject.send(mupd) }
    }
    func resetIfDayChanged(now: Date) async {
        let key = dayFmt.string(from: cal.startOfDay(for: now))
        if key != curDayKey { curDayKey = key; daySubject.send(day[key] ?? 0) }
    }

    func monthToDateUsage(for monthStart: Date) async -> TimeInterval {
        let key = monFmt.string(from: monthStart)
        return month[key] ?? 0
    }
    func addMonthlyUsage(_ seconds: TimeInterval, for day: Date) async {
        let add = max(0, seconds)
        let mkey = monFmt.string(from: day)
        let cur = month[mkey] ?? 0
        let upd = cur + add
        month[mkey] = upd
        if mkey == curMonthKey { monthSubject.send(upd) }
    }
    func resetIfMonthChanged(now: Date) async {
        let mkey: String
        if let iv = cal.dateInterval(of: .month, for: now) { mkey = monFmt.string(from: iv.start) } else { mkey = monFmt.string(from: now) }
        if mkey != curMonthKey { curMonthKey = mkey; monthSubject.send(month[mkey] ?? 0) }
    }
}

struct GetRemainingMonthlyQuotaUseCaseTests {
    @Test @MainActor func testProUser_ReturnsInfinity() async throws {
        let policy = DefaultRecordingQuotaPolicy(isProProvider: { true })
        let repo = InMemoryMonthlyUsageRepo()
        let uc = GetRemainingMonthlyQuotaUseCase(quotaPolicy: policy, usageRepository: repo)
        let remaining = try await uc.execute()
        #expect(remaining == .infinity)
    }

    @Test @MainActor func testFreeUser_ZeroUsage_Returns3600() async throws {
        let policy = DefaultRecordingQuotaPolicy(isProProvider: { false })
        let repo = InMemoryMonthlyUsageRepo()
        let uc = GetRemainingMonthlyQuotaUseCase(quotaPolicy: policy, usageRepository: repo)
        let remaining = try await uc.execute()
        #expect(remaining == 3600)
    }

    @Test @MainActor func testFreeUser_1800Used_Returns1800() async throws {
        let policy = DefaultRecordingQuotaPolicy(isProProvider: { false })
        let repo = InMemoryMonthlyUsageRepo()
        // Add 1800s this month
        await repo.addUsage(1800, for: Date())
        let uc = GetRemainingMonthlyQuotaUseCase(quotaPolicy: policy, usageRepository: repo)
        let remaining = try await uc.execute()
        #expect(remaining == 1800)
    }

    @Test @MainActor func testFreeUser_OverCap_ReturnsZero() async throws {
        let policy = DefaultRecordingQuotaPolicy(isProProvider: { false })
        let repo = InMemoryMonthlyUsageRepo()
        await repo.addUsage(4000, for: Date())
        let uc = GetRemainingMonthlyQuotaUseCase(quotaPolicy: policy, usageRepository: repo)
        let remaining = try await uc.execute()
        #expect(remaining == 0)
    }
}


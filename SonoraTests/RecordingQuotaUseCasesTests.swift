import Testing
import Foundation
import Combine
@testable import Sonora

// In-memory RecordingUsageRepository mock
final class InMemoryRecordingUsageRepository: RecordingUsageRepository {
    private var store: [String: TimeInterval] = [:]
    private let subject = CurrentValueSubject<TimeInterval, Never>(0)
    private let calendar: Calendar
    private let formatter: DateFormatter
    private var currentKey: String

    init(calendar: Calendar = .current) {
        self.calendar = calendar
        self.formatter = DateFormatter()
        self.formatter.calendar = calendar
        self.formatter.locale = Locale(identifier: "en_US_POSIX")
        self.formatter.dateFormat = "yyyy-MM-dd"
        let today = calendar.startOfDay(for: Date())
        self.currentKey = formatter.string(from: today)
        self.subject.send(0)
    }

    var todayUsagePublisher: AnyPublisher<TimeInterval, Never> { subject.eraseToAnyPublisher() }

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
    }

    func resetIfDayChanged(now: Date) async {
        let key = formatter.string(from: calendar.startOfDay(for: now))
        if key != currentKey {
            currentKey = key
            subject.send(store[key] ?? 0)
        }
    }
}

struct RecordingQuotaUseCasesTests {
    @Test @MainActor func testCanStartRecordingUseCase_AllowsAndClamps() async throws {
        let repo = InMemoryRecordingUsageRepository()
        let canStart = CanStartRecordingUseCase(usageRepository: repo)

        // Fresh day: remaining=600, allowed per-session equals remaining (no per-session cap)
        let allowed1 = try await canStart.execute(service: .cloudAPI)
        #expect(allowed1 == 600)

        // Consume 590s
        await repo.addUsage(590, for: Date())
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

    @Test @MainActor func testConsumeAndRemainingUseCases() async throws {
        let repo = InMemoryRecordingUsageRepository()
        let consume = ConsumeRecordingUsageUseCase(usageRepository: repo)
        let remaining = GetRemainingDailyQuotaUseCase(usageRepository: repo)

        // Start with 0 used for cloud
        var remCloud = await remaining.execute(service: .cloudAPI)
        #expect(remCloud == 600)

        // Consume 125s
        await consume.execute(elapsed: 125, service: .cloudAPI)
        remCloud = await remaining.execute(service: .cloudAPI)
        #expect(remCloud == 475)
    }
}

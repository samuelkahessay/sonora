@testable import Sonora
import XCTest

// MARK: - Test Doubles

@MainActor
final class FakePromptUsageRepository: PromptUsageRepository {
    private struct UsageEntry {
        var lastShownAt: Date?
        var lastUsedAt: Date?
        var useCount: Int
        var isFavorite: Bool
    }
    
    private var map: [String: UsageEntry] = [:]

    func markShown(promptId: String, at date: Date) throws {
        var entry = map[promptId] ?? UsageEntry(lastShownAt: nil, lastUsedAt: nil, useCount: 0, isFavorite: false)
        entry.lastShownAt = date
        map[promptId] = entry
    }

    func markUsed(promptId: String, at date: Date) throws {
        var entry = map[promptId] ?? UsageEntry(lastShownAt: nil, lastUsedAt: nil, useCount: 0, isFavorite: false)
        entry.lastUsedAt = date
        entry.useCount += 1
        map[promptId] = entry
    }

    func setFavorite(promptId: String, isFavorite: Bool, at date: Date) throws {
        var entry = map[promptId] ?? UsageEntry(lastShownAt: nil, lastUsedAt: nil, useCount: 0, isFavorite: false)
        entry.isFavorite = isFavorite
        map[promptId] = entry
    }

    func favorites() throws -> Set<String> {
        Set(map.compactMap { $0.value.isFavorite ? $0.key : nil })
    }

    func recentlyUsedPromptIds(since date: Date) throws -> Set<String> {
        Set(map.compactMap { key, v in
            if let d = v.lastUsedAt, d >= date { return key }
            return nil
        })
    }

    func lastUsedAt(for promptId: String) throws -> Date? {
        map[promptId]?.lastUsedAt
    }

    func recentlyShownPromptIds(since date: Date) throws -> Set<String> {
        Set(map.compactMap { key, v in
            if let d = v.lastShownAt, d >= date { return key }
            return nil
        })
    }

    func lastShownAt(for promptId: String) throws -> Date? {
        map[promptId]?.lastShownAt
    }
}

struct FixedDateProvider: DateProvider, Sendable {
    let fixedNow: Date
    let calendar: Calendar
    let timeZone: TimeZone
    let locale: Locale

    init(_ date: Date, calendar: Calendar = .init(identifier: .gregorian), timeZone: TimeZone = .gmt, locale: Locale = .init(identifier: "en_US")) {
        var cal = calendar
        cal.timeZone = timeZone
        self.fixedNow = date
        self.calendar = cal
        self.timeZone = timeZone
        self.locale = locale
    }

    var now: Date { fixedNow }

    func dayPart(for date: Date) -> DayPart {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5...11: return .morning
        case 12...16: return .afternoon
        case 17...20: return .evening
        default: return .night
        }
    }

    func weekPart(for date: Date) -> WeekPart {
        let weekday = calendar.component(.weekday, from: date)
        let first = calendar.firstWeekday
        let offset = (weekday - first + 7) % 7
        switch offset { case 0, 1: return .startOfWeek; case 2, 3: return .midWeek; default: return .endOfWeek }
    }
}

struct StubLocalizationProvider: LocalizationProvider, Sendable {
    func localizedString(_ key: String, locale: Locale) -> String {
        switch key {
        case "daypart.morning": return "morning"
        case "daypart.afternoon": return "afternoon"
        case "daypart.evening": return "evening"
        case "daypart.night": return "night"
        case "weekpart.start": return "start of the week"
        case "weekpart.mid": return "mid-week"
        case "weekpart.end": return "end of the week"
        case "test.token": return "Good [DayPart], [Name]! It's [WeekPart]."
        default: return key
        }
    }
}

struct FakePromptCatalog: PromptCatalog, Sendable {
    let prompts: [RecordingPrompt]
    func allPrompts() -> [RecordingPrompt] { prompts }
}

// MARK: - Tests

final class GetDynamicPromptUseCaseTests: XCTestCase {
    @MainActor
    func test_NoRepeatWithinSevenDays_SelectsAlternatePrompt() async throws {
        // Given a Monday morning context
        let date = components(year: 2_025, month: 1, day: 6, hour: 9) // Monday 9am
        let provider = FixedDateProvider(date)
        let usage = FakePromptUsageRepository()
        let loc = StubLocalizationProvider()

        let p1 = RecordingPrompt(
            id: "p1",
            localizationKey: "test.token",
            category: .growth,
            emotionalDepth: .light,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek],
            weight: 2
        )
        let p2 = RecordingPrompt(
            id: "p2",
            localizationKey: "test.token",
            category: .growth,
            emotionalDepth: .light,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek],
            weight: 1
        )
        let catalog = FakePromptCatalog(prompts: [p1, p2])
        let useCase = GetDynamicPromptUseCase(catalog: catalog, usageRepository: usage, dateProvider: provider, localization: loc)

        // Mark p1 used yesterday (within 7 days)
        try usage.markUsed(promptId: "p1", at: provider.calendar.date(byAdding: .day, value: -1, to: date)!)

        // When
        let result = try await useCase.execute(userName: "Alex")

        // Then pick p2 due to 7-day no-repeat
        XCTAssertEqual(result?.id, "p2")

        // And when p1 last used 8 days ago, it becomes eligible again
        try usage.markUsed(promptId: "p1", at: provider.calendar.date(byAdding: .day, value: -8, to: date)!)
        let result2 = try await useCase.execute(userName: "Alex")
        XCTAssertEqual(result2?.id, "p1")
    }

    @MainActor
    func test_TokenInterpolation_UsesNameDayPartWeekPart() async throws {
        let date = components(year: 2_025, month: 1, day: 6, hour: 9) // Monday morning
        let provider = FixedDateProvider(date)
        let usage = FakePromptUsageRepository()
        let loc = StubLocalizationProvider()
        let p = RecordingPrompt(
            id: "p",
            localizationKey: "test.token",
            category: .goals,
            emotionalDepth: .light,
            allowedDayParts: [.morning],
            allowedWeekParts: [.startOfWeek]
        )
        let catalog = FakePromptCatalog(prompts: [p])
        let useCase = GetDynamicPromptUseCase(catalog: catalog, usageRepository: usage, dateProvider: provider, localization: loc)

        let result = try await useCase.execute(userName: "Alex")
        let text = result?.text ?? ""
        XCTAssertTrue(text.contains("morning"))
        XCTAssertTrue(text.contains("Alex"))
        XCTAssertTrue(text.contains("start of the week"))
    }
}

// Helpers
private func components(year: Int, month: Int, day: Int, hour: Int, minute: Int = 0) -> Date {
    var comp = DateComponents()
    comp.year = year; comp.month = month; comp.day = day; comp.hour = hour; comp.minute = minute
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = .gmt
    return cal.date(from: comp)!
}

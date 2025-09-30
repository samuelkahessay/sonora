@testable import Sonora
import XCTest

final class EnumBoundaryTests: XCTestCase {

    func test_DayPartBoundaries() {
        let cal = Calendar(identifier: .gregorian)
        let tz = TimeZone.gmt
        let locale = Locale(identifier: "en_US")
        let provider = DefaultDateProvider(calendar: cal, timeZone: tz, locale: locale)

        func date(_ h: Int, _ m: Int) -> Date {
            var c = DateComponents(); c.year = 2_025; c.month = 1; c.day = 6; c.hour = h; c.minute = m
            var cal = Calendar(identifier: .gregorian); cal.timeZone = tz
            return cal.date(from: c)!
        }

        XCTAssertEqual(provider.dayPart(for: date(4, 59)), .night)
        XCTAssertEqual(provider.dayPart(for: date(5, 0)), .morning)
        XCTAssertEqual(provider.dayPart(for: date(11, 59)), .morning)
        XCTAssertEqual(provider.dayPart(for: date(12, 0)), .afternoon)
        XCTAssertEqual(provider.dayPart(for: date(16, 59)), .afternoon)
        XCTAssertEqual(provider.dayPart(for: date(17, 0)), .evening)
        XCTAssertEqual(provider.dayPart(for: date(20, 59)), .evening)
        XCTAssertEqual(provider.dayPart(for: date(21, 0)), .night)
    }

    func test_WeekPartLocale_MondayStart() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 2 // Monday
        let tz = TimeZone.gmt
        let locale = Locale(identifier: "en_GB")
        let provider = DefaultDateProvider(calendar: cal, timeZone: tz, locale: locale)

        // 2025-01-06 is Monday
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 6)), .startOfWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 7)), .startOfWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 8)), .midWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 9)), .midWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 10)), .endOfWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 11)), .endOfWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 12)), .endOfWeek)
    }

    func test_WeekPartLocale_SundayStart() {
        var cal = Calendar(identifier: .gregorian)
        cal.firstWeekday = 1 // Sunday
        let tz = TimeZone.gmt
        let locale = Locale(identifier: "en_US")
        let provider = DefaultDateProvider(calendar: cal, timeZone: tz, locale: locale)

        // 2025-01-05 is Sunday
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 5)), .startOfWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 6)), .startOfWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 7)), .midWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 8)), .midWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 9)), .endOfWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 10)), .endOfWeek)
        XCTAssertEqual(provider.weekPart(for: date(2_025, 1, 11)), .endOfWeek)
    }

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var c = DateComponents(); c.year = y; c.month = m; c.day = d
        var cal = Calendar(identifier: .gregorian); cal.timeZone = .gmt
        return cal.date(from: c)!
    }
}

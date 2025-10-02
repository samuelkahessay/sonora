@testable import Sonora
import XCTest
@preconcurrency import EventKit

final class RecurrenceMappingTests: XCTestCase {
    func testWeeklyMonWedMapping() throws {
        let rec = EventsData.DetectedEvent.Recurrence(
            frequency: "weekly",
            interval: 1,
            byWeekday: ["Mon", "Wed"],
            end: nil
        )

        let rules = EventKitRecurrenceMapper.rules(from: rec)
        XCTAssertEqual(rules.count, 1)
        let rule = rules[0]
        XCTAssertEqual(rule.interval, 1)
        let days = rule.daysOfTheWeek ?? []
        let names = Set(days.map { $0.dayOfTheWeek.rawValue })
        // EKWeekday raw values are 1..7 (Sunday=1), so ensure Monday(2) and Wednesday(4)
        XCTAssertTrue(names.contains(2))
        XCTAssertTrue(names.contains(4))
    }

    // No repo needed for mapper test
}

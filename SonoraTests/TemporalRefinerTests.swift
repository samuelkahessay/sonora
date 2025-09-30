@testable import Sonora
import XCTest

final class TemporalRefinerTests: XCTestCase {
    func testRefinesTodayAtSixPMFromSourceText() {
        // Given
        let transcript = "I plan to go to the gym tomorrow. I also need to pick up milk today at 6 p.m."
        let calendar = Calendar.current

        // Use a fixed reference date for determinism
        var comps = DateComponents()
        comps.year = 2_025
        comps.month = 9
        comps.day = 28
        comps.hour = 9
        comps.minute = 0
        comps.second = 0
        let now = calendar.date(from: comps) ?? Date()

        // Upstream (incorrect) due at noon
        let baseDay = calendar.startOfDay(for: now)
        let upstreamDue = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: baseDay)

        let reminder = RemindersData.DetectedReminder(
            title: "Pick up milk",
            dueDate: upstreamDue,
            priority: .medium,
            confidence: 0.9,
            sourceText: "I also need to pick up milk today at 6 p.m.",
            memoId: UUID()
        )

        let input = RemindersData(reminders: [reminder])

        // When
        let refined = TemporalRefiner.refine(remindersData: input, transcript: transcript, now: now)

        // Then
        guard let r = refined?.reminders.first, let due = r.dueDate else {
            XCTFail("Expected refined reminder with due date")
            return
        }
        let dc = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: due)
        XCTAssertEqual(dc.year, 2_025)
        XCTAssertEqual(dc.month, 9)
        XCTAssertEqual(dc.day, 28)
        XCTAssertEqual(dc.hour, 18)
        XCTAssertEqual(dc.minute, 0)
    }

    func testRefinesEventStartAndEndToExplicitTime() {
        let transcript = "Plans to go to the gym today at 6 p.m."
        let calendar = Calendar.current

        var comps = DateComponents()
        comps.year = 2_025
        comps.month = 9
        comps.day = 28
        comps.hour = 9
        comps.minute = 0
        let now = calendar.date(from: comps) ?? Date()

        let startDay = calendar.startOfDay(for: now)
        let upstreamStart = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: startDay)
        let upstreamEnd = upstreamStart.flatMap { calendar.date(byAdding: .hour, value: 1, to: $0) }

        let event = EventsData.DetectedEvent(
            title: "Gym session",
            startDate: upstreamStart,
            endDate: upstreamEnd,
            location: "Gym",
            participants: nil,
            confidence: 0.9,
            sourceText: "Plans to go to the gym today at 6 p.m.",
            memoId: UUID()
        )

        let input = EventsData(events: [event])

        let refined = TemporalRefiner.refine(eventsData: input, transcript: transcript, now: now)

        guard let e = refined?.events.first, let start = e.startDate else {
            XCTFail("Expected refined event with start date")
            return
        }
        let startComponents = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: start)
        XCTAssertEqual(startComponents.year, 2_025)
        XCTAssertEqual(startComponents.month, 9)
        XCTAssertEqual(startComponents.day, 28)
        XCTAssertEqual(startComponents.hour, 18)
        XCTAssertEqual(startComponents.minute, 0)

        if let end = e.endDate {
            let duration = end.timeIntervalSince(start)
            XCTAssertEqual(duration, 3_600, accuracy: 0.5)
        } else {
            XCTFail("Expected event end date")
        }
    }

    func testRefinesReminderForNextWeekDefaultsToMorning() {
        let transcript = "Remember to follow up with the vendor next week."
        let calendar = Calendar.current

        var comps = DateComponents()
        comps.year = 2_025
        comps.month = 9
        comps.day = 29 // Monday
        comps.hour = 10
        let now = calendar.date(from: comps) ?? Date()

        let reminder = RemindersData.DetectedReminder(
            title: "Follow up with vendor",
            dueDate: nil,
            priority: .medium,
            confidence: 0.7,
            sourceText: transcript,
            memoId: UUID()
        )

        let refined = TemporalRefiner.refine(remindersData: RemindersData(reminders: [reminder]), transcript: transcript, now: now)
        guard let due = refined?.reminders.first?.dueDate else {
            XCTFail("Expected generated due date")
            return
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: due)
        XCTAssertEqual(components.weekday, 2) // Monday
        XCTAssertEqual(components.hour, 9)
        XCTAssertEqual(components.minute, 0)
    }

    func testRefinesEventForThisWeekendDefaultsToLateMorning() {
        let transcript = "Let's catch up this weekend."
        let calendar = Calendar.current

        var comps = DateComponents()
        comps.year = 2_025
        comps.month = 9
        comps.day = 24 // Wednesday
        comps.hour = 11
        let now = calendar.date(from: comps) ?? Date()

        let event = EventsData.DetectedEvent(
            title: "Weekend catch up",
            startDate: nil,
            endDate: nil,
            location: nil,
            participants: ["Alex"],
            confidence: 0.65,
            sourceText: transcript,
            memoId: UUID()
        )

        let refined = TemporalRefiner.refine(eventsData: EventsData(events: [event]), transcript: transcript, now: now)
        guard let scheduled = refined?.events.first?.startDate else {
            XCTFail("Expected start date")
            return
        }

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday], from: scheduled)
        XCTAssertEqual(components.weekday, 7) // Saturday
        XCTAssertEqual(components.hour, 10)
        XCTAssertEqual(components.minute, 0)
    }
}

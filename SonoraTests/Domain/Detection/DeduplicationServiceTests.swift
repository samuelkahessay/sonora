@testable import Sonora
import XCTest

final class DeduplicationServiceTests: XCTestCase {
    func testDedupRemovesOverlapAndDuplicates() {
        let event1 = EventsData.DetectedEvent(
            id: "e1",
            title: "Design sync",
            startDate: Date(),
            endDate: nil,
            location: nil,
            participants: ["Alex"],
            confidence: 0.8,
            sourceText: "design sync",
            memoId: nil
        )
        let event2 = EventsData.DetectedEvent(
            id: "e2",
            title: "Gym",
            startDate: nil,
            endDate: nil,
            location: nil,
            participants: nil,
            confidence: 0.7,
            sourceText: "go to gym",
            memoId: nil
        )
        let r1 = RemindersData.DetectedReminder(
            id: "r1",
            title: "Design sync",
            dueDate: nil,
            priority: .medium,
            confidence: 0.7,
            sourceText: "design sync",
            memoId: nil
        )
        let r2 = RemindersData.DetectedReminder(
            id: "r2",
            title: "Design sync",
            dueDate: nil,
            priority: .medium,
            confidence: 0.7,
            sourceText: "design sync",
            memoId: nil
        )

        let deduped = DeduplicationService.dedupe(events: EventsData(events: [event1, event2]), reminders: RemindersData(reminders: [r1, r2]))

        // event1 stays as event; reminders with matching key removed
        XCTAssertEqual(deduped.events?.events.count, 1)
        XCTAssertEqual(deduped.events?.events.first?.id, "e1")

        // event2 converts into a reminder (no startDate/participants/location)
        XCTAssertEqual(deduped.reminders?.reminders.isEmpty, false)
        let titles = Set(deduped.reminders!.reminders.map { $0.title })
        XCTAssertTrue(titles.contains("Gym"))
        XCTAssertFalse(titles.contains("Design sync"))
    }
}

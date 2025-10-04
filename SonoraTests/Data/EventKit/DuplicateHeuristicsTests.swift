@testable import Sonora
import XCTest

final class DuplicateHeuristicsTests: XCTestCase {
    func testTitleMatchWithinWindowSameDay() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let target = EventsData.DetectedEvent(
            id: "1", title: "Design Sync", startDate: now, endDate: now.addingTimeInterval(3_600), location: nil, participants: nil, confidence: 0.9, sourceText: "discuss design", memoId: nil
        )
        let candidate = DuplicateHeuristics.SimpleEvent(title: "design sync", startDate: now.addingTimeInterval(10 * 60), endDate: now.addingTimeInterval(70 * 60), isAllDay: false, notes: nil)
        let out = DuplicateHeuristics.match(target: target, sourceText: target.sourceText, in: [candidate])
        XCTAssertEqual(out.count, 1)
    }

    func testSourceMatchWithinWindowSameDay() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let target = EventsData.DetectedEvent(
            id: "1", title: "Weekly", startDate: now, endDate: now.addingTimeInterval(3_600), location: nil, participants: nil, confidence: 0.9, sourceText: "plan roadmap", memoId: nil
        )
        let notes = "Participants: A\n\nOriginal: plan roadmap"
        let candidate = DuplicateHeuristics.SimpleEvent(title: "Different Title", startDate: now.addingTimeInterval(-14 * 60), endDate: now.addingTimeInterval(46 * 60), isAllDay: false, notes: notes)
        let out = DuplicateHeuristics.match(target: target, sourceText: target.sourceText, in: [candidate])
        XCTAssertEqual(out.count, 1)
    }

    func testOutsideWindowOrDifferentDayIsNotDuplicate() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let target = EventsData.DetectedEvent(
            id: "1", title: "Design Sync", startDate: now, endDate: now.addingTimeInterval(3_600), location: nil, participants: nil, confidence: 0.9, sourceText: "discuss", memoId: nil
        )
        let far = DuplicateHeuristics.SimpleEvent(title: "design sync", startDate: now.addingTimeInterval(60 * 60), endDate: now.addingTimeInterval(2 * 60 * 60), isAllDay: false, notes: nil)
        let out1 = DuplicateHeuristics.match(target: target, sourceText: target.sourceText, in: [far])
        XCTAssertEqual(out1.count, 0)

        let nextDay = DuplicateHeuristics.SimpleEvent(title: "design sync", startDate: Calendar.current.date(byAdding: .day, value: 1, to: now)!, endDate: Calendar.current.date(byAdding: .day, value: 1, to: now)!.addingTimeInterval(3_600), isAllDay: false, notes: nil)
        let out2 = DuplicateHeuristics.match(target: target, sourceText: target.sourceText, in: [nextDay])
        XCTAssertEqual(out2.count, 0)
    }
}

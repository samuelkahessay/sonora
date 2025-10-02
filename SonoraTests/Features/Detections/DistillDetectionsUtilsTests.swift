@testable import Sonora
import XCTest

final class DistillDetectionsUtilsTests: XCTestCase {
    func testBuildEventPayloadPreservesDurationWhenDateEdited() {
        let baseStart = Date(timeIntervalSince1970: 1_700_000_000)
        let baseEnd = baseStart.addingTimeInterval(5_400) // 90 minutes
        let base = EventsData.DetectedEvent(
            id: "e1",
            title: "Design Review",
            startDate: baseStart,
            endDate: baseEnd,
            location: "HQ",
            participants: ["Alex"],
            confidence: 0.9,
            sourceText: "design review",
            memoId: nil
        )
        var model = ActionItemDetectionUI.fromDomain(ActionItemDetection.fromEvent(base), id: UUID())
        let newStart = baseStart.addingTimeInterval(3_600)
        model.suggestedDate = newStart

        let payload = buildEventPayload(from: model, base: base)
        XCTAssertEqual(payload.startDate, newStart)
        XCTAssertEqual(payload.endDate, newStart.addingTimeInterval(5_400))
        XCTAssertEqual(payload.title, model.title)
        XCTAssertEqual(payload.sourceText, base.sourceText)
        XCTAssertEqual(payload.participants ?? [], ["Alex"])
    }

    func testBuildReminderPayloadUsesEditedTitleAndDate() {
        let base = RemindersData.DetectedReminder(
            id: "r1",
            title: "Email team",
            dueDate: nil,
            priority: .medium,
            confidence: 0.7,
            sourceText: "email team",
            memoId: nil
        )
        var model = ActionItemDetectionUI.fromDomain(ActionItemDetection.fromReminder(base), id: UUID())
        model.title = "Email design team"
        model.suggestedDate = Date(timeIntervalSince1970: 1_700_000_000)

        let payload = buildReminderPayload(from: model, base: base)
        XCTAssertEqual(payload.title, "Email design team")
        XCTAssertEqual(payload.dueDate, model.suggestedDate)
        XCTAssertEqual(payload.priority, .medium)
        XCTAssertEqual(payload.sourceText, base.sourceText)
    }
}

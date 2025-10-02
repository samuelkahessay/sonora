@testable import Sonora
import XCTest

@MainActor
final class ActionItemViewModelTests: XCTestCase {
    func testInitAndBasicIntents() async throws {
        // Given two initial detections
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let event = EventsData.DetectedEvent(
            id: "e1",
            title: "Design sync",
            startDate: now,
            endDate: now.addingTimeInterval(3_600),
            location: "HQ",
            participants: ["Alex"],
            confidence: 0.8,
            sourceText: "design sync",
            memoId: nil
        )
        let reminder = RemindersData.DetectedReminder(
            id: "r1",
            title: "Email notes",
            dueDate: nil,
            priority: .medium,
            confidence: 0.6,
            sourceText: "email notes",
            memoId: nil
        )

        let vm = ActionItemViewModel(memoId: nil, initialEvents: [event], initialReminders: [reminder])

        // Then visible items exist
        XCTAssertEqual(vm.visibleItems.count, 2)

        // When toggling edit on first item
        let id = vm.visibleItems.first!.id
        vm.handleEditToggle(id)

        // Then the item reflects editing state
        let after = vm.visibleItems.first { $0.id == id }
        XCTAssertEqual(after?.isEditing, true)

        // When dismissing the first item
        vm.handleDismiss(id)
        XCTAssertEqual(vm.visibleItems.count, 1)

        // When merging incoming another event
        let e2 = EventsData.DetectedEvent(
            id: "e2",
            title: "Roadmap review",
            startDate: now,
            endDate: now.addingTimeInterval(1_800),
            location: nil,
            participants: ["PM"],
            confidence: 0.7,
            sourceText: "roadmap review",
            memoId: nil
        )
        vm.mergeIncoming(events: [e2], reminders: [])

        // Then the new event appears among visible items
        let hasE2 = vm.visibleItems.contains { $0.sourceId == "e2" }
        XCTAssertTrue(hasE2)
    }
}

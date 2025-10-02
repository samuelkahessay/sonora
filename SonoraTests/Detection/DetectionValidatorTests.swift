import Foundation
@testable import Sonora
import Testing

struct DetectionValidatorTests {

    @Test
    func testValidateEventsDropsInvalidAndDuplicate() async throws {
        // Reversed endDate should be dropped; duplicate id should be dropped
        let s = ISO8601DateFormatter()
        let start = s.date(from: "2025-01-15T10:00:00Z")!
        let endEarlier = s.date(from: "2025-01-15T09:00:00Z")!

        let ev1 = EventsData.DetectedEvent(
            id: "same",
            title: "Team meeting",
            startDate: start,
            endDate: endEarlier,
            location: nil,
            participants: ["Alice", "Alice"],
            confidence: 0.9,
            sourceText: "team meeting at 10",
            memoId: nil
        )
        let ev2 = EventsData.DetectedEvent(
            id: "same",
            title: "Team meeting",
            startDate: start,
            endDate: nil,
            location: "",
            participants: ["Alice", "Bob"],
            confidence: 0.9,
            sourceText: "team meeting at 10",
            memoId: nil
        )
        let data = EventsData(events: [ev1, ev2])

        let validated = DetectionValidator.validateEvents(data)
        #expect(validated?.events.count == 1)
        #expect(validated?.events.first?.participants?.count == 2)
    }

    @Test
    func testValidateRemindersDropsInvalid() async throws {
        let r1 = RemindersData.DetectedReminder(
            id: "1",
            title: "   ", // invalid empty title
            dueDate: nil,
            priority: .medium,
            confidence: 0.7,
            sourceText: "",
            memoId: nil
        )
        let r2 = RemindersData.DetectedReminder(
            id: "2",
            title: "Email Alice",
            dueDate: nil,
            priority: .high,
            confidence: 0.7,
            sourceText: "",
            memoId: nil
        )
        let data = RemindersData(reminders: [r1, r2])
        let validated = DetectionValidator.validateReminders(data)
        #expect(validated?.reminders.count == 1)
        #expect(validated?.reminders.first?.title == "Email Alice")
    }
}


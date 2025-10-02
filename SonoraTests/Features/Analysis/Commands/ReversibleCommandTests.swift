@testable import Sonora
import XCTest

@MainActor
final class ReversibleCommandTests: XCTestCase {
    func testAddEventCommandExecuteUndoAndSeed() async throws {
        var store: [String] = []

        let create: AddEventCommand.CreateClosure = {
            let id = "event-123"
            store.append(id)
            return id
        }
        let delete: AddEventCommand.DeleteClosure = { id in
            store.removeAll { $0 == id }
        }

        let cmd = AddEventCommand(create: create, delete: delete)
        XCTAssertTrue(store.isEmpty)

        try await cmd.execute()
        XCTAssertEqual(store, ["event-123"]) // created
        XCTAssertEqual(cmd.createdId, "event-123")

        try await cmd.undo()
        XCTAssertTrue(store.isEmpty) // deleted
        XCTAssertNil(cmd.createdId)

        // Seed an id and undo should delete without execute
        store = ["seeded-1"]
        let seeded = AddEventCommand(create: create, delete: delete)
        seeded.seedCreatedId("seeded-1")
        try await seeded.undo()
        XCTAssertTrue(store.isEmpty)
    }

    func testAddReminderCommandExecuteUndoAndRedo() async throws {
        var store: [String] = []

        let create: AddReminderCommand.CreateClosure = {
            let id = "rem-1"
            store.append(id)
            return id
        }
        let delete: AddReminderCommand.DeleteClosure = { id in
            store.removeAll { $0 == id }
        }

        let cmd = AddReminderCommand(create: create, delete: delete)
        XCTAssertTrue(store.isEmpty)

        try await cmd.execute()
        XCTAssertEqual(store, ["rem-1"]) // created

        try await cmd.undo()
        XCTAssertTrue(store.isEmpty) // deleted

        // Redo by executing again
        try await cmd.execute()
        XCTAssertEqual(store, ["rem-1"]) // re-created
    }
}

import Foundation

@MainActor
final class AddReminderCommand: ReversibleCommand {
    typealias CreateClosure = () async throws -> String
    typealias DeleteClosure = (_ id: String) async throws -> Void

    private let create: CreateClosure
    private let delete: DeleteClosure
    private(set) var createdId: String?

    init(create: @escaping CreateClosure, delete: @escaping DeleteClosure) {
        self.create = create
        self.delete = delete
    }

    func execute() async throws {
        guard createdId == nil else { return }
        let id = try await create()
        createdId = id
    }

    func undo() async throws {
        guard let id = createdId else { return }
        try await delete(id)
        createdId = nil
    }

    /// Allows seeding a previously created identifier (e.g., when restoring a command into the undo stack).
    func seedCreatedId(_ id: String) {
        createdId = id
    }
}

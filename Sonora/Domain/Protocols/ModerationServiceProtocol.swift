import Foundation

@MainActor
protocol ModerationServiceProtocol: AnyObject {
    func moderate(text: String) async throws -> ModerationResult
}

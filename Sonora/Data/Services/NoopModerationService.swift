import Foundation

final class NoopModerationService: ModerationServiceProtocol {
    func moderate(text: String) async throws -> ModerationResult {
        return ModerationResult(flagged: false, categories: nil, category_scores: nil)
    }
}


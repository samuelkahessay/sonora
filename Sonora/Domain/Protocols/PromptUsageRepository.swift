import Foundation

/// Persistence for prompt usage and favorites (SwiftData-backed in Data layer).
public protocol PromptUsageRepository: Sendable {
    @MainActor
    func markShown(promptId: String, at date: Date) throws
    @MainActor
    func markUsed(promptId: String, at date: Date) throws
    @MainActor
    func setFavorite(promptId: String, isFavorite: Bool, at date: Date) throws
    @MainActor
    func favorites() throws -> Set<String>
    @MainActor
    func recentlyUsedPromptIds(since date: Date) throws -> Set<String>
    @MainActor
    func lastUsedAt(for promptId: String) throws -> Date?
}


import XCTest
import SwiftData
@testable import Sonora

@MainActor
final class PromptUsageRepositoryImplTests: XCTestCase {

    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([PromptUsageRecord.self])
        // Attempt in-memory configuration; fallback to default if unavailable
        if let configInit = ModelConfigurationInit.inMemory() {
            let container = try ModelContainer(for: schema, configurations: configInit)
            return ModelContext(container)
        } else {
            let container = try ModelContainer(for: schema)
            return ModelContext(container)
        }
    }

    func test_MarkUsed_And_RecentlyUsed() throws {
        let ctx = try makeInMemoryContext()
        let repo = PromptUsageRepositoryImpl(context: ctx)

        let now = Date()
        try repo.markUsed(promptId: "a", at: now)
        try repo.markUsed(promptId: "b", at: now.addingTimeInterval(-60*60*24*8)) // 8 days ago

        let recent = try repo.recentlyUsedPromptIds(since: now.addingTimeInterval(-60*60*24*7))
        XCTAssertTrue(recent.contains("a"))
        XCTAssertFalse(recent.contains("b"))
    }

    func test_Favorites_Toggle() throws {
        let ctx = try makeInMemoryContext()
        let repo = PromptUsageRepositoryImpl(context: ctx)

        try repo.setFavorite(promptId: "x", isFavorite: true, at: Date())
        var favs = try repo.favorites()
        XCTAssertTrue(favs.contains("x"))

        try repo.setFavorite(promptId: "x", isFavorite: false, at: Date())
        favs = try repo.favorites()
        XCTAssertFalse(favs.contains("x"))
    }
}

// Helper to conditionally construct in-memory configuration based on API availability
enum ModelConfigurationInit {
    static func inMemory() -> ModelConfiguration? {
        // Attempt to call a potential initializer; adjust if API differs at runtime.
        // If this fails to compile in a given Xcode, fallback path above uses default container.
        return ModelConfiguration(isStoredInMemoryOnly: true)
    }
}

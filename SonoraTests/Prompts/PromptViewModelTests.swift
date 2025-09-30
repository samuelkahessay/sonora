import XCTest
@testable import Sonora

@MainActor
final class PromptViewModelTests: XCTestCase {
    final class FakeGetDynamic: GetDynamicPromptUseCaseProtocol {
        var called = false
        var result: InterpolatedPrompt?
        func execute(userName: String?) async throws -> InterpolatedPrompt? {
            called = true
            return result
        }
    }

    final class FakeGetCategory: GetPromptCategoryUseCaseProtocol {
        var setFavArgs: (id: String, isFav: Bool)?
        var used: String?
        func execute(category: PromptCategory, userName: String?) async throws -> [InterpolatedPrompt] { [] }
        func setFavorite(promptId: String, isFavorite: Bool) throws { setFavArgs = (promptId, isFavorite) }
        func markUsed(promptId: String) throws { used = promptId }
    }

    func test_Refresh_LoadsPrompt() async throws {
        let dyn = FakeGetDynamic()
        let cat = FakeGetCategory()
        let vm = PromptViewModel(getDynamic: dyn, getCategory: cat)

        dyn.result = InterpolatedPrompt(id: "id1", text: "Hello", category: .growth, emotionalDepth: .light, dayPart: .morning, weekPart: .startOfWeek)

        vm.refresh()
        // Allow task to complete
        try await Task.sleep(nanoseconds: 50_000_000)
        XCTAssertTrue(dyn.called)
        XCTAssertEqual(vm.currentPrompt?.id, "id1")
        XCTAssertFalse(vm.isLoading)
    }

    func test_MarkUsed_TogglesFavoriteSafely() throws {
        let dyn = FakeGetDynamic()
        let cat = FakeGetCategory()
        let vm = PromptViewModel(getDynamic: dyn, getCategory: cat)
        vm.currentPrompt = InterpolatedPrompt(id: "pX", text: "", category: .goals, emotionalDepth: .light, dayPart: .evening, weekPart: .endOfWeek)

        vm.markUsed()
        XCTAssertEqual(cat.used, "pX")

        vm.toggleFavorite()
        XCTAssertEqual(cat.setFavArgs?.id, "pX")
        XCTAssertEqual(cat.setFavArgs?.isFav, true)
    }
}

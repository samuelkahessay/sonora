import Foundation
import Combine

@MainActor
final class PromptViewModel: ObservableObject {
    @Published var currentPrompt: InterpolatedPrompt?
    @Published var isLoading: Bool = false
    @Published var showInspireSheet: Bool = false

    private let getDynamic: any GetDynamicPromptUseCaseProtocol
    private let getCategory: any GetPromptCategoryUseCaseProtocol
    private var refreshTask: Task<Void, Never>?

    init(getDynamic: any GetDynamicPromptUseCaseProtocol, getCategory: any GetPromptCategoryUseCaseProtocol) {
        self.getDynamic = getDynamic
        self.getCategory = getCategory
    }

    func loadInitial() {
        guard FeatureFlags.usePrompts else { return }
        refresh()
    }

    func refresh() {
        guard FeatureFlags.usePrompts else { return }
        refreshTask?.cancel()
        isLoading = true
        let name = OnboardingConfiguration.shared.getUserName()
        refreshTask = Task { [weak self] in
            do {
                let prompt = try await self?.getDynamic.execute(userName: name)
                await MainActor.run { [weak self] in
                    self?.currentPrompt = prompt
                    self?.isLoading = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.currentPrompt = nil
                    self?.isLoading = false
                }
            }
        }
    }

    func toggleFavorite() {
        guard let id = currentPrompt?.id else { return }
        // For now, toggle favorite blindly to true (idempotent); a full UI would reflect state
        try? getCategory.setFavorite(promptId: id, isFavorite: true)
    }

    func markUsed() {
        guard let id = currentPrompt?.id else { return }
        try? getCategory.markUsed(promptId: id)
    }
}


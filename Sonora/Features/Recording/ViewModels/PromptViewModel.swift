import Foundation
import Combine

@MainActor
final class PromptViewModel: ObservableObject {
    @Published var currentPrompt: InterpolatedPrompt?
    @Published var isLoading: Bool = false

    private let getDynamic: any GetDynamicPromptUseCaseProtocol
    private let getCategory: any GetPromptCategoryUseCaseProtocol
    private var refreshTask: Task<Void, Never>?
    private var rotationToken: PromptRotationToken? = nil

    init(getDynamic: any GetDynamicPromptUseCaseProtocol, getCategory: any GetPromptCategoryUseCaseProtocol) {
        self.getDynamic = getDynamic
        self.getCategory = getCategory
}

    func loadInitial() {
        // Preserve current prompt across tab switches; only load if empty
        if currentPrompt == nil {
            refresh()
        }
    }

    func refresh(excludingCurrent: Bool = false) {
        refreshTask?.cancel()
        isLoading = true
        let name = OnboardingConfiguration.shared.getUserName()
        let currentId = excludingCurrent ? currentPrompt?.id : nil
        refreshTask = Task { [weak self] in
            do {
                // Use policy-driven selection with rotation for exploration
                let policy: PromptSelectionPolicy = excludingCurrent ? .exploration : .contextAware
                let req = SelectPromptRequest(userName: name, policy: policy, currentPromptId: currentId, rotationToken: excludingCurrent ? self?.rotationToken : nil)
                let res = try await self?.getDynamic.next(req)
                await MainActor.run { [weak self] in
                    self?.currentPrompt = res?.prompt
                    // Reset or update rotation token based on policy
                    if excludingCurrent {
                        self?.rotationToken = res?.rotationToken
                    } else {
                        self?.rotationToken = nil
                    }
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

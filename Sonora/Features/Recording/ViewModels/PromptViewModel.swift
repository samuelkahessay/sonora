import Combine
import Foundation

@MainActor
final class PromptViewModel: ObservableObject {
    // MARK: - Lightweight State
    enum State: Equatable {
        case idle(current: InterpolatedPrompt?)
        case loading(current: InterpolatedPrompt?)
        case ready(current: InterpolatedPrompt)
        case error(current: InterpolatedPrompt?, message: String?)
    }

    @Published var currentPrompt: InterpolatedPrompt?
    @Published var isLoading: Bool = false
    @Published private(set) var state: State = .idle(current: nil)

    private let getDynamic: any GetDynamicPromptUseCaseProtocol
    private let getCategory: any GetPromptCategoryUseCaseProtocol
    private let onboardingConfiguration: OnboardingConfiguration
    private var cancellables: Set<AnyCancellable> = []
    private var refreshTask: Task<Void, Never>?
    private var rotationToken: PromptRotationToken?

    init(
        getDynamic: any GetDynamicPromptUseCaseProtocol,
        getCategory: any GetPromptCategoryUseCaseProtocol,
        onboardingConfiguration: OnboardingConfiguration = .shared
    ) {
        self.getDynamic = getDynamic
        self.getCategory = getCategory
        self.onboardingConfiguration = onboardingConfiguration
        observeUserNameChanges()
    }

    func loadInitial() {
        // Preserve current prompt across tab switches; only load if empty
        if currentPrompt == nil {
            refresh()
        } else if let prompt = currentPrompt {
            state = .ready(current: prompt)
        }
    }

    func refresh(excludingCurrent: Bool = false) {
        refreshTask?.cancel()
        isLoading = true
        state = .loading(current: currentPrompt)
        let name = onboardingConfiguration.getUserName()
        let currentId = excludingCurrent ? currentPrompt?.id : nil
        refreshTask = Task { [weak self] in
            do {
                // Use policy-driven selection with rotation for exploration
                let policy: PromptSelectionPolicy = excludingCurrent ? .exploration : .contextAware
                let req = SelectPromptRequest(userName: name, policy: policy, currentPromptId: currentId, rotationToken: excludingCurrent ? self?.rotationToken : nil)
                let res = try await self?.getDynamic.next(req)
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    self.currentPrompt = res?.prompt
                    // Reset or update rotation token based on policy
                    if excludingCurrent {
                        self.rotationToken = res?.rotationToken
                    } else {
                        self.rotationToken = nil
                    }
                    self.isLoading = false
                    if let prompt = self.currentPrompt {
                        self.state = .ready(current: prompt)
                    } else {
                        self.state = .idle(current: nil)
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    // Keep prior prompt visible on error for a graceful fallback
                    self.isLoading = false
                    self.state = .error(current: self.currentPrompt, message: (error as NSError).localizedDescription)
                }
            }
        }
    }

    func clear() {
        refreshTask?.cancel()
        refreshTask = nil
        currentPrompt = nil
        isLoading = false
        state = .idle(current: nil)
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

    private func observeUserNameChanges() {
        onboardingConfiguration.$currentUserName
            .dropFirst()
            .removeDuplicates()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { @MainActor in
                    self.refresh()
                }
            }
            .store(in: &cancellables)
    }
}

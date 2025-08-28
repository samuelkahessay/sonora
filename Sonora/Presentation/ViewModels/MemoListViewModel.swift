import Foundation
import Combine
import SwiftUI

/// ViewModel for handling memo list functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class MemoListViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let loadMemosUseCase: LoadMemosUseCaseProtocol
    private let deleteMemoUseCase: DeleteMemoUseCaseProtocol
    private let playMemoUseCase: PlayMemoUseCaseProtocol
    private let startTranscriptionUseCase: StartTranscriptionUseCaseProtocol
    private let retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol
    private let getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol
    private let memoRepository: any MemoRepository // Still needed for state updates
    private let transcriptionRepository: any TranscriptionRepository // For transcription states
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published var memos: [Memo] = []
    @Published var playingMemo: Memo?
    @Published var isPlaying: Bool = false
    @Published var navigationPath = NavigationPath()
    @Published var transcriptionStates: [String: TranscriptionState] = [:]
    
    // MARK: - Computed Properties
    
    /// Whether the memo list is empty
    var isEmpty: Bool {
        memos.isEmpty
    }
    
    /// Empty state message for UI
    var emptyStateTitle: String {
        "No Memos Yet"
    }
    
    /// Empty state subtitle for UI
    var emptyStateSubtitle: String {
        "Start recording to see your audio memos here"
    }
    
    /// Empty state icon name
    var emptyStateIcon: String {
        "mic.slash"
    }
    
    // MARK: - Initialization
    
    init(
        loadMemosUseCase: LoadMemosUseCaseProtocol,
        deleteMemoUseCase: DeleteMemoUseCaseProtocol,
        playMemoUseCase: PlayMemoUseCaseProtocol,
        startTranscriptionUseCase: StartTranscriptionUseCaseProtocol,
        retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol,
        getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol,
        memoRepository: any MemoRepository,
        transcriptionRepository: any TranscriptionRepository
    ) {
        self.loadMemosUseCase = loadMemosUseCase
        self.deleteMemoUseCase = deleteMemoUseCase
        self.playMemoUseCase = playMemoUseCase
        self.startTranscriptionUseCase = startTranscriptionUseCase
        self.retryTranscriptionUseCase = retryTranscriptionUseCase
        self.getTranscriptionStateUseCase = getTranscriptionStateUseCase
        self.memoRepository = memoRepository
        self.transcriptionRepository = transcriptionRepository
        
        setupBindings()
        loadMemos()
        
        print("📱 MemoListViewModel: Initialized with dependency injection")
    }
    
    /// Convenience initializer using DIContainer
    /// CRITICAL FIX: Uses proper dependency injection following Clean Architecture
    convenience init() {
        let container = DIContainer.shared
        let memoRepository = container.memoRepository()
        let transcriptionRepository = container.transcriptionRepository()
        let transcriptionAPI = container.transcriptionAPI()
        
        // Use direct repository initialization to ensure real persistence
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI,
            operationCoordinator: container.operationCoordinator()
        )
        let retryTranscriptionUseCase = RetryTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI
        )
        let getTranscriptionStateUseCase = GetTranscriptionStateUseCase(
            transcriptionRepository: transcriptionRepository
        )
        
        self.init(
            loadMemosUseCase: LoadMemosUseCase(memoRepository: memoRepository),
            deleteMemoUseCase: DeleteMemoUseCase(memoRepository: memoRepository),
            playMemoUseCase: PlayMemoUseCase(memoRepository: memoRepository),
            startTranscriptionUseCase: startTranscriptionUseCase,
            retryTranscriptionUseCase: retryTranscriptionUseCase,
            getTranscriptionStateUseCase: getTranscriptionStateUseCase,
            memoRepository: memoRepository,
            transcriptionRepository: transcriptionRepository
        )
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // Observe memo repository changes
        memoRepository.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFromRepository()
            }
            .store(in: &cancellables)

        // Observe transcription repository state changes
        transcriptionRepository.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateTranscriptionStates()
            }
            .store(in: &cancellables)

        // Listen for navigation notifications
        NotificationCenter.default.publisher(for: .popToRootMemos)
            .sink { [weak self] _ in
                self?.popToRoot()
            }
            .store(in: &cancellables)
        
        // Initial update
        updateFromRepository()
        updateTranscriptionStates()
    }
    
    private func updateFromRepository() {
        memos = memoRepository.memos
        playingMemo = memoRepository.playingMemo
        isPlaying = memoRepository.isPlaying
    }
    
    private func updateTranscriptionStates() {
        transcriptionStates = transcriptionRepository.transcriptionStates
    }
    
    // MARK: - Public Methods
    
    /// Load memos from repository
    func loadMemos() {
        print("📱 MemoListViewModel: Loading memos")
        Task {
            do {
                try await loadMemosUseCase.execute()
            } catch {
                print("❌ MemoListViewModel: Failed to load memos: \(error)")
            }
        }
    }
    
    /// Refresh memos (same as loadMemos, for pull-to-refresh)
    func refreshMemos() {
        loadMemos()
    }
    
    /// Delete memo at specific index
    func deleteMemo(at index: Int) {
        guard index < memos.count else { return }
        let memo = memos[index]
        print("📱 MemoListViewModel: Deleting memo: \(memo.filename)")
        Task {
            do {
                try await deleteMemoUseCase.execute(memo: memo)
            } catch {
                print("❌ MemoListViewModel: Failed to delete memo: \(error)")
            }
        }
    }
    
    /// Delete memos at multiple indices
    func deleteMemos(at offsets: IndexSet) {
        print("📱 MemoListViewModel: Deleting \(offsets.count) memos")
        Task {
            for index in offsets {
                if index < memos.count {
                    do {
                        try await deleteMemoUseCase.execute(memo: memos[index])
                    } catch {
                        print("❌ MemoListViewModel: Failed to delete memo at index \(index): \(error)")
                    }
                }
            }
        }
    }
    
    /// Play or pause a memo
    func playMemo(_ memo: Memo) {
        print("📱 MemoListViewModel: Playing memo: \(memo.filename)")
        Task {
            do {
                try await playMemoUseCase.execute(memo: memo)
            } catch {
                print("❌ MemoListViewModel: Failed to play memo: \(error)")
            }
        }
    }
    
    /// Start transcription for a memo
    func startTranscription(for memo: Memo) {
        print("📱 MemoListViewModel: Starting transcription for: \(memo.filename)")
        Task {
            do {
                try await startTranscriptionUseCase.execute(memo: memo)
            } catch {
                print("❌ MemoListViewModel: Failed to start transcription: \(error)")
            }
        }
    }
    
    /// Retry transcription for a memo
    func retryTranscription(for memo: Memo) {
        print("📱 MemoListViewModel: Retrying transcription for: \(memo.filename)")
        Task {
            do {
                try await retryTranscriptionUseCase.execute(memo: memo)
            } catch {
                print("❌ MemoListViewModel: Failed to retry transcription: \(error)")
            }
        }
    }
    
    /// Get transcription state for a memo
    func getTranscriptionState(for memo: Memo) -> TranscriptionState {
        return getTranscriptionStateUseCase.execute(memo: memo)
    }
    
    /// Pop navigation to root
    func popToRoot() {
        if !navigationPath.isEmpty {
            print("📱 MemoListViewModel: Popping to root, removing \(navigationPath.count) items")
            navigationPath.removeLast(navigationPath.count)
        }
    }
    
    // MARK: - View Helper Methods
    
    /// Get play button icon for a memo
    func playButtonIcon(for memo: Memo) -> String {
        if playingMemo?.id == memo.id && isPlaying {
            return "pause.circle.fill"
        } else {
            return "play.circle.fill"
        }
    }
    
    /// Check if memo is currently playing
    func isMemoPaying(_ memo: Memo) -> Bool {
        return playingMemo?.id == memo.id && isPlaying
    }
    
    /// Get transcription action button text for a memo
    func transcriptionActionText(for memo: Memo) -> String? {
        let state = getTranscriptionState(for: memo)
        if state.isFailed {
            return "Retry"
        } else if state.isNotStarted {
            return "Transcribe"
        } else if state.isInProgress {
            return "Processing..."
        }
        return nil
    }
    
    /// Get transcription action button color for a memo
    func transcriptionActionColor(for memo: Memo) -> Color {
        let state = getTranscriptionState(for: memo)
        if state.isFailed {
            return .orange
        } else if state.isNotStarted {
            return .blue
        } else {
            return .secondary
        }
    }
    
    /// Check if transcription action is available for a memo
    func canPerformTranscriptionAction(for memo: Memo) -> Bool {
        let state = getTranscriptionState(for: memo)
        return state.isFailed || state.isNotStarted
    }
    
    /// Perform transcription action for a memo
    func performTranscriptionAction(for memo: Memo) {
        let state = getTranscriptionState(for: memo)
        if state.isFailed {
            retryTranscription(for: memo)
        } else if state.isNotStarted {
            startTranscription(for: memo)
        }
    }
    
    // MARK: - Lifecycle Methods
    
    func onViewAppear() {
        print("📱 MemoListViewModel: View appeared")
        loadMemos()
    }
    
    func onViewDisappear() {
        print("📱 MemoListViewModel: View disappeared")
    }
}

// MARK: - MemoRow ViewModel Support

extension MemoListViewModel {
    
    /// Create memo row state for a specific memo
    func memoRowState(for memo: Memo) -> MemoRowState {
        MemoRowState(
            memo: memo,
            transcriptionState: getTranscriptionState(for: memo),
            isPlaying: isMemoPaying(memo),
            playButtonIcon: playButtonIcon(for: memo)
        )
    }
}

// MARK: - Supporting Types

/// State object for individual memo rows
struct MemoRowState {
    let memo: Memo
    let transcriptionState: TranscriptionState
    let isPlaying: Bool
    let playButtonIcon: String
}

// MARK: - Debug Helpers

extension MemoListViewModel {
    
    /// Get debug information about the current state
    var debugInfo: String {
        return """
        MemoListViewModel State:
        - memos count: \(memos.count)
        - isEmpty: \(isEmpty)
        - playingMemo: \(playingMemo?.filename ?? "none")
        - isPlaying: \(isPlaying)
        - navigationPath count: \(navigationPath.count)
        - transcriptionStates count: \(transcriptionStates.count)
        """
    }
}

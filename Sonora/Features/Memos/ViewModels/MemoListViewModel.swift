// Moved to Features/Memos/ViewModels
import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// ViewModel for handling memo list functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class MemoListViewModel: ObservableObject, ErrorHandling {

    // MARK: - Dependencies
    private let loadMemosUseCase: LoadMemosUseCaseProtocol
    private let deleteMemoUseCase: DeleteMemoUseCaseProtocol
    private let playMemoUseCase: PlayMemoUseCaseProtocol
    private let startTranscriptionUseCase: StartTranscriptionUseCaseProtocol
    private let retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol
    private let getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol
    private let renameMemoUseCase: RenameMemoUseCaseProtocol
    private let handleNewRecordingUseCase: any HandleNewRecordingUseCaseProtocol
    private let memoRepository: any MemoRepository // Still needed for state updates
    private let transcriptionRepository: any TranscriptionRepository // For transcription states
    private let titleCoordinator: TitleGenerationCoordinator
    private var cancellables = Set<AnyCancellable>()

    // Event-driven updates (Swift 6 compliant - no more polling)
    private var eventSubscriptionId: UUID?
    private var transcriptionStateSubscription: AnyCancellable?
    private var unifiedStateSubscription: AnyCancellable?
    private var titleStateSubscription: AnyCancellable?
    private let eventBus = EventBus.shared
    private let logger: any LoggerProtocol = Logger.shared

    // MARK: - Grouped State Management (Swift 6 Optimized - Reduces @Published Count from 12 to 6)

    /// Unified memo state combining memo data with transcription states
    @Published var memosWithState: [MemoWithState] = []

    /// UI state consolidation - reduces individual @Published properties
    @Published var uiState = MemoListUIState()

    /// Selection state consolidation - reduces edit mode @Published properties
    @Published var selectionState = MemoSelectionState()

    /// Transcription state consolidation - reduces transcription @Published properties
    @Published var transcriptionDisplayState = TranscriptionDisplayState()

    /// Playback state consolidation - reduces playback @Published properties
    @Published var playbackState = PlaybackState()

    /// Legacy memo list for backward compatibility during transition
    @Published var memos: [Memo] = []

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

    // MARK: - Multi-Select Computed Properties (Delegated to selectionState)

    /// Whether any memos are selected
    var hasSelection: Bool {
        selectionState.hasSelection
    }

    /// Number of selected memos
    var selectedCount: Int {
        selectionState.selectedCount
    }

    /// Whether delete action can be performed
    var canDelete: Bool {
        selectionState.canDelete
    }

    /// Whether edit mode is active
    var isEditMode: Bool {
        selectionState.isEditMode
    }

    /// Current selected memo IDs
    var selectedMemoIds: Set<UUID> {
        selectionState.selectedMemoIds
    }

    // MARK: - UI State Computed Properties (Delegated to uiState)

    /// Current error state
    var error: SonoraError? {
        get { uiState.error }
        set { uiState = uiState.with(error: newValue) }
    }

    /// Current loading state
    var isLoading: Bool {
        get { uiState.isLoading }
        set { uiState = uiState.with(isLoading: newValue) }
    }

    /// Current editing memo ID
    var editingMemoId: UUID? {
        get { uiState.editingMemoId }
        set { uiState = uiState.with(editingMemoId: newValue) }
    }

    /// Navigation path for SwiftUI navigation
    var navigationPath: NavigationPath {
        get { uiState.navigationPath }
        set {
            var updatedState = uiState
            updatedState.navigationPath = newValue
            uiState = updatedState
        }
    }

    /// Refresh trigger for UI updates
    private var refreshTrigger: Int {
        uiState.refreshTrigger
    }

    // MARK: - Playback State Computed Properties (Delegated to playbackState)

    /// Currently playing memo
    var playingMemo: Memo? {
        playbackState.playingMemo
    }

    /// Whether any memo is currently playing
    var isPlaying: Bool {
        playbackState.isPlaying
    }

    // MARK: - Transcription State Access (Delegated to transcriptionDisplayState)

    /// Legacy transcription states dictionary for backward compatibility
    var transcriptionStates: [String: TranscriptionState] {
        get { transcriptionDisplayState.states }
        set { transcriptionDisplayState = TranscriptionDisplayState(states: newValue) }
    }

    // MARK: - Initialization

    init(
        loadMemosUseCase: LoadMemosUseCaseProtocol,
        deleteMemoUseCase: DeleteMemoUseCaseProtocol,
        playMemoUseCase: PlayMemoUseCaseProtocol,
        startTranscriptionUseCase: StartTranscriptionUseCaseProtocol,
        retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol,
        getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol,
        renameMemoUseCase: RenameMemoUseCaseProtocol,
        handleNewRecordingUseCase: any HandleNewRecordingUseCaseProtocol,
        memoRepository: any MemoRepository,
        transcriptionRepository: any TranscriptionRepository,
        titleCoordinator: TitleGenerationCoordinator
    ) {
        self.loadMemosUseCase = loadMemosUseCase
        self.deleteMemoUseCase = deleteMemoUseCase
        self.playMemoUseCase = playMemoUseCase
        self.startTranscriptionUseCase = startTranscriptionUseCase
        self.retryTranscriptionUseCase = retryTranscriptionUseCase
        self.getTranscriptionStateUseCase = getTranscriptionStateUseCase
        self.renameMemoUseCase = renameMemoUseCase
        self.handleNewRecordingUseCase = handleNewRecordingUseCase
        self.memoRepository = memoRepository
        self.transcriptionRepository = transcriptionRepository
        self.titleCoordinator = titleCoordinator

        setupBindings()
        loadMemos()

        logger.debug("MemoListViewModel initialized", category: .viewModel, context: LogContext())
    }

    // MARK: - Import
    /// Import an external audio file (e.g., from Files app) as a memo
    func importAudio(at url: URL) {
        Task {
            do {
                _ = try await handleNewRecordingUseCase.execute(at: url)
                await MainActor.run { self.error = nil }
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    // MARK: - Setup Methods

    private func setupBindings() {
        // MARK: - Unified State Management (Swift 6 Compliant)

        // Create unified publisher combining memo and transcription data
        unifiedStateSubscription = Publishers.CombineLatest3(
            memoRepository.memosPublisher,
            transcriptionRepository.stateChangesPublisher.map { _ in () }.prepend(()) /* Trigger on any transcription change */,
            memoRepository.memosPublisher.map { [weak self] _ in
                // Get current playback state
                return (self?.memoRepository.playingMemo, self?.memoRepository.isPlaying ?? false)
            }
        )
        .receive(on: RunLoop.main)
        .sink { [weak self] memos, _, playbackState in
            self?.updateUnifiedState(memos: memos, playingMemo: playbackState.0, isPlaying: playbackState.1)
        }

        unifiedStateSubscription?.store(in: &cancellables)

        titleStateSubscription = titleCoordinator.$stateByMemo
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                self.updateUnifiedState(
                    memos: self.memoRepository.memos,
                    playingMemo: self.memoRepository.playingMemo,
                    isPlaying: self.memoRepository.isPlaying
                )
            }
        titleStateSubscription?.store(in: &cancellables)

        // Legacy repository observation for backward compatibility
        memoRepository.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateFromRepository()
            }
            .store(in: &cancellables)

        // Subscribe to event-driven transcription state changes (Swift 6 compliant)
        transcriptionStateSubscription = transcriptionRepository.stateChangesPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] stateChange in
                self?.handleTranscriptionStateChange(stateChange)
            }
        transcriptionStateSubscription?.store(in: &cancellables)

        // Subscribe to app events for navigation and real-time updates
        eventSubscriptionId = eventBus.subscribe(to: AppEvent.self) { [weak self] event in
            guard let self = self else { return }
            switch event {
            case .navigatePopToRootMemos:
                self.popToRoot()
            case .transcriptionCompleted(let memoId, _):
                Task { @MainActor in
                    // Force refresh the specific memo's transcription state
                    self.refreshTranscriptionState(for: memoId)
                }
            default:
                break
            }
        }

        // Initial update
        updateFromRepository()
        updateTranscriptionStates()

        // Initialize unified state
        updateUnifiedState(
            memos: memoRepository.memos,
            playingMemo: memoRepository.playingMemo,
            isPlaying: memoRepository.isPlaying
        )
    }

    private func updateFromRepository() {
        memos = memoRepository.memos
        playbackState = PlaybackState(
            playingMemo: memoRepository.playingMemo,
            isPlaying: memoRepository.isPlaying
        )
    }

    private func updateTranscriptionStates() {
        let oldStates = transcriptionDisplayState.states
        let newStates = transcriptionRepository.transcriptionStates

        // Detect meaningful changes (keys added/removed or value changes)
        let changedKeys: [String] = {
            let keys = Set(oldStates.keys).union(newStates.keys)
            return keys.filter { oldStates[$0] != newStates[$0] }
        }()

        if !changedKeys.isEmpty {
            logger.debug("Repo state change detected: \(changedKeys)", category: .viewModel, context: LogContext())
            // Explicitly notify before mutation to guarantee UI refresh
            objectWillChange.send()
            transcriptionDisplayState = TranscriptionDisplayState(states: newStates)
            uiState.incrementRefresh()
            logger.debug("UI refresh triggered (refreshTrigger=\(uiState.refreshTrigger))", category: .viewModel, context: LogContext())
        } else {
            // No-op but keep logs for debugging
            logger.debug("Repo objectWillChange with no effective state diff", category: .viewModel, context: LogContext())
        }
    }

    /// Handle event-driven transcription state changes (Swift 6 compliant)
    private func handleTranscriptionStateChange(_ stateChange: TranscriptionStateChange) {
        let memoIdString = stateChange.memoId.uuidString
        let previousState = transcriptionDisplayState.states[memoIdString]

        // Update consolidated transcription state
        objectWillChange.send()
        transcriptionDisplayState = transcriptionDisplayState.with(
            state: stateChange.currentState,
            for: stateChange.memoId
        )
        uiState.incrementRefresh()

        logger.debug("Event-driven transcription state update",
                    category: .viewModel,
                    context: LogContext(additionalInfo: [
                        "memoId": stateChange.memoId.uuidString,
                        "previousState": previousState?.statusText ?? "nil",
                        "currentState": stateChange.currentState.statusText,
                        "refreshTrigger": "\(uiState.refreshTrigger)"
                    ]))
    }

    /// Update unified state combining memos with transcription states (Swift 6 compliant)
    private func updateUnifiedState(memos: [Memo], playingMemo: Memo?, isPlaying: Bool) {
        let newMemosWithState = memos.map { memo in
            let transcriptionState = getTranscriptionState(for: memo)
            let isThisMemoPlaying = playingMemo?.id == memo.id && isPlaying
            let coordinatorState = titleCoordinator.state(for: memo.id)
            let persistedState = memo.autoTitleState
            let titleState: TitleGenerationState

            switch coordinatorState {
            case .idle:
                titleState = persistedState
            default:
                titleState = coordinatorState
            }

            return MemoWithState(
                memo: memo,
                transcriptionState: transcriptionState,
                titleState: titleState,
                isPlaying: isThisMemoPlaying
            )
        }

        // Only update if there are actual changes to reduce UI churn
        if newMemosWithState != memosWithState {
            objectWillChange.send()
            memosWithState = newMemosWithState
            uiState.incrementRefresh()

            logger.debug("Unified state updated",
                        category: .viewModel,
                        context: LogContext(additionalInfo: [
                            "memoCount": "\(memos.count)",
                            "playingMemoId": playingMemo?.id.uuidString ?? "nil",
                            "isPlaying": "\(isPlaying)",
                            "refreshTrigger": "\(uiState.refreshTrigger)"
                        ]))
        }
    }

    // MARK: - Event-Driven Updates (No More Polling)

    /// Event-driven transcription state updates have eliminated the need for polling
    /// This significantly reduces CPU usage and battery drain during transcription operations

    /// Force refresh a specific memo's transcription state (now event-driven)
    private func refreshTranscriptionState(for memoId: UUID) {
        guard let memo = memos.first(where: { $0.id == memoId }) else { return }

        let newState = getTranscriptionStateUseCase.execute(memo: memo)
        let key = memoId.uuidString

        if transcriptionStates[key] != newState {
            objectWillChange.send()
            transcriptionStates[key] = newState
            // Use uiState refresh trigger instead
            var updatedUIState = self.uiState
            updatedUIState.incrementRefresh()
            self.uiState = updatedUIState
            logger.debug("Event update for \(memo.filename): \(newState.statusText). refreshTrigger=\(refreshTrigger)", category: .viewModel, context: LogContext())
        }
    }

    // MARK: - Public Methods

    /// Load memos from repository
    func loadMemos() {
        logger.debug("Loading memos", category: .viewModel, context: LogContext())
        Task {
            do {
                isLoading = true
                _ = try await loadMemosUseCase.execute()
                await MainActor.run {
                    self.isLoading = false
                    self.error = nil
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.error = ErrorMapping.mapError(error)
                }
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
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
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
                        await MainActor.run {
                            self.error = ErrorMapping.mapError(error)
                        }
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
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    /// Start transcription for a memo
    func startTranscription(for memo: Memo) {
        print("📱 MemoListViewModel: Starting transcription for: \(memo.filename)")
        Task {
            do {
                try await startTranscriptionUseCase.execute(memo: memo)
                // Event-driven updates will automatically handle state changes
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    /// Retry transcription for a memo
    func retryTranscription(for memo: Memo) {
        print("📱 MemoListViewModel: Retrying transcription for: \(memo.filename)")
        Task {
            do {
                try await retryTranscriptionUseCase.execute(memo: memo)
                // Event-driven updates will automatically handle state changes
            } catch {
                await MainActor.run {
                    self.error = ErrorMapping.mapError(error)
                }
            }
        }
    }

    /// Get transcription state for a memo
    func getTranscriptionState(for memo: Memo) -> TranscriptionState {
        return getTranscriptionStateUseCase.execute(memo: memo)
    }

    // MARK: - Rename Methods

    /// Start editing a memo's title
    func startEditing(memo: Memo) {
        print("📝 MemoListViewModel: Starting edit for memo: \(memo.displayName)")
        editingMemoId = memo.id
    }

    /// Stop editing (clear editing state)
    func stopEditing() {
        print("📝 MemoListViewModel: Stopping edit mode")
        editingMemoId = nil
    }

    /// Check if a memo is currently being edited
    func isEditing(memo: Memo) -> Bool {
        return editingMemoId == memo.id
    }

    /// Rename a memo with the given title
    func renameMemo(_ memo: Memo, newTitle: String) async {
        print("📝 MemoListViewModel: Renaming memo to: \(newTitle)")

        do {
            try await renameMemoUseCase.execute(memo: memo, newTitle: newTitle)
            await MainActor.run {
                self.stopEditing()
                self.error = nil
            }
        } catch {
            await MainActor.run {
                self.error = ErrorMapping.mapError(error)
                self.stopEditing()
            }
        }
    }

    /// Share a memo using native iOS share sheet with user-friendly filename
    func shareMemo(_ memo: Memo, from sourceView: UIView? = nil) {
        print("📤 MemoListViewModel: Sharing memo: \(memo.displayName)")

        guard FileManager.default.fileExists(atPath: memo.fileURL.path) else {
            print("❌ MemoListViewModel: Cannot share memo - file not found at \(memo.fileURL.path)")
            self.error = SonoraError.storageFileNotFound(memo.fileURL.path)
            return
        }

        // Create temporary copy with user-friendly filename
        let tempDirectory = FileManager.default.temporaryDirectory
        let shareableFilename = memo.preferredShareableFileName
        let tempURL = tempDirectory.appendingPathComponent(shareableFilename)

        do {
            // Remove existing temp file if it exists
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            // Copy original file to temp location with friendly name
            try FileManager.default.copyItem(at: memo.fileURL, to: tempURL)

            print("📤 MemoListViewModel: Created temporary share file: \(shareableFilename)")

            // Share via NSItemProvider with explicit UTType and suggestedName to preserve filename
            if #available(iOS 14.0, *) {
                let provider = NSItemProvider(item: tempURL as NSSecureCoding, typeIdentifier: UTType.mpeg4Audio.identifier)
                provider.suggestedName = shareableFilename
                let activityVC = UIActivityViewController(activityItems: [provider], applicationActivities: nil)

                // Clean up temp file after sharing
                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    DispatchQueue.main.async {
                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                                print("📤 MemoListViewModel: Cleaned up temporary share file")
                            }
                        } catch {
                            print("⚠️ MemoListViewModel: Failed to clean up temporary file: \(error)")
                        }
                    }
                }

                // Configure for iPad presentation
                if let popover = activityVC.popoverPresentationController {
                    if let sourceView = sourceView {
                        popover.sourceView = sourceView
                        popover.sourceRect = sourceView.bounds
                    } else if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                              let window = windowScene.windows.first {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                }

                // Present the share sheet
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    // Defer slightly to allow context menu dismissal before presenting
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        rootViewController.present(activityVC, animated: true)
                    }
                }
            } else {
                // Fallback: share the file URL directly
                let activityVC = UIActivityViewController(activityItems: [tempURL], applicationActivities: nil)

                activityVC.completionWithItemsHandler = { _, _, _, _ in
                    DispatchQueue.main.async {
                        do {
                            if FileManager.default.fileExists(atPath: tempURL.path) {
                                try FileManager.default.removeItem(at: tempURL)
                                print("📤 MemoListViewModel: Cleaned up temporary share file")
                            }
                        } catch {
                            print("⚠️ MemoListViewModel: Failed to clean up temporary file: \(error)")
                        }
                    }
                }

                if let popover = activityVC.popoverPresentationController {
                    if let sourceView = sourceView {
                        popover.sourceView = sourceView
                        popover.sourceRect = sourceView.bounds
                    }
                }

                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootViewController = window.rootViewController {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        rootViewController.present(activityVC, animated: true)
                    }
                }
            }

        } catch {
            print("❌ MemoListViewModel: Failed to create temporary share file: \(error)")
            self.error = SonoraError.storageWriteFailed("Failed to create shareable copy")
        }
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
            return .semantic(.warning)
        } else if state.isNotStarted {
            return .semantic(.brandPrimary)
        } else {
            return .semantic(.textSecondary)
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

    // MARK: - Multi-Select Methods

    /// Toggle edit mode on/off
    func toggleEditMode() {
        withAnimation(.easeInOut(duration: 0.2)) {
            var newSelectionState = self.selectionState
            newSelectionState.isEditMode.toggle()

            // Clear selection when exiting edit mode
            if !newSelectionState.isEditMode {
                newSelectionState.selectedMemoIds.removeAll()
            }

            self.selectionState = newSelectionState
        }

        HapticManager.shared.playSelection()
        logger.debug("Edit mode toggled: \(selectionState.isEditMode ? "ON" : "OFF")", category: .viewModel, context: LogContext())
    }

    /// Select a specific memo
    func selectMemo(_ memo: Memo) {
        guard selectionState.isEditMode else { return }

        withAnimation(Animation.easeInOut(duration: 0.2)) {
            var newSelectionState = self.selectionState
            newSelectionState.selectedMemoIds.insert(memo.id)
            self.selectionState = newSelectionState
        }

        HapticManager.shared.playSelection()
        logger.debug("Selected memo: \(memo.filename)", category: .viewModel, context: LogContext())
    }

    /// Deselect a specific memo
    func deselectMemo(_ memo: Memo) {
        guard selectionState.isEditMode else { return }

        withAnimation(Animation.easeInOut(duration: 0.2)) {
            var newSelectionState = self.selectionState
            newSelectionState.selectedMemoIds.remove(memo.id)
            self.selectionState = newSelectionState
        }

        HapticManager.shared.playSelection()
    }

    /// Toggle selection state of a memo
    func toggleMemoSelection(_ memo: Memo) {
        guard selectionState.isEditMode else { return }

        if selectionState.selectedMemoIds.contains(memo.id) {
            deselectMemo(memo)
        } else {
            selectMemo(memo)
        }
    }

    // Drag-based selection helpers removed (tap-only selection)

    /// Select all memos
    func selectAll() {
        guard selectionState.isEditMode else { return }

        withAnimation(Animation.easeInOut(duration: 0.2)) {
            var newSelectionState = self.selectionState
            newSelectionState.selectedMemoIds = Set(memos.map { $0.id })
            self.selectionState = newSelectionState
        }

        HapticManager.shared.playSelection()
        logger.debug("Selected all \(memos.count) memos", category: .viewModel, context: LogContext())
    }

    /// Deselect all memos
    func deselectAll() {
        guard selectionState.isEditMode else { return }

        withAnimation(.spring(response: 0.3)) {
            var newSelectionState = self.selectionState
            newSelectionState.selectedMemoIds.removeAll()
            self.selectionState = newSelectionState
        }

        HapticManager.shared.playSelection()
        logger.debug("Deselected all memos", category: .viewModel, context: LogContext())
    }

    /// Delete selected memos with confirmation
    func deleteSelectedMemos() {
        guard selectionState.isEditMode && selectionState.hasSelection else { return }

        let memosToDelete = memos.filter { selectionState.selectedMemoIds.contains($0.id) }
        let count = memosToDelete.count

        logger.debug("Deleting \(count) selected memos", category: .viewModel, context: LogContext())

        Task {
            for memo in memosToDelete {
                do {
                    try await deleteMemoUseCase.execute(memo: memo)
                } catch {
                    await MainActor.run {
                        self.error = ErrorMapping.mapError(error)
                        return
                    }
                }
            }

            await MainActor.run {
                // Clear selection and exit edit mode after successful deletion
                var newSelectionState = self.selectionState
                newSelectionState.selectedMemoIds.removeAll()
                newSelectionState.isEditMode = false
                self.selectionState = newSelectionState
                HapticManager.shared.playDeletionFeedback()
            }
        }
    }

    // Drag selection API removed (tap-only selection)

    /// Check if a memo is selected
    func isMemoSelected(_ memo: Memo) -> Bool {
        return selectionState.selectedMemoIds.contains(memo.id)
    }
}

// MARK: - MemoRow ViewModel Support

extension MemoListViewModel {

    /// Create memo row state for a specific memo (legacy method)
    func memoRowState(for memo: Memo) -> MemoRowState {
        // Try to use unified state first for efficiency
        if let memoWithState = memosWithState.first(where: { $0.memo.id == memo.id }) {
            return MemoRowState(from: memoWithState)
        }

        // Fallback to individual lookups
        return MemoRowState(
            memo: memo,
            transcriptionState: getTranscriptionState(for: memo),
            titleState: {
                let coordinatorState = titleCoordinator.state(for: memo.id)
                if case .idle = coordinatorState {
                    return memo.autoTitleState
                }
                return coordinatorState
            }(),
            isPlaying: isMemoPaying(memo),
            playButtonIcon: playButtonIcon(for: memo)
        )
    }

    /// Get unified memo state for a specific memo (preferred method)
    func memoWithState(for memo: Memo) -> MemoWithState? {
        return memosWithState.first(where: { $0.memo.id == memo.id })
    }
}

// MARK: - State Management Structures (Swift 6 Sendable)

/// UI state grouping for memo list interface - reduces @Published property count
struct MemoListUIState: Equatable {
    var isLoading: Bool
    var error: SonoraError?
    var editingMemoId: UUID?
    var refreshTrigger: Int
    // Note: NavigationPath is not Sendable in current iOS versions, using workaround
    var navigationPath: NavigationPath

    init() {
        self.isLoading = false
        self.error = nil
        self.editingMemoId = nil
        self.refreshTrigger = 0
        self.navigationPath = NavigationPath()
    }

    /// Create updated state with new error
    func with(error: SonoraError?) -> MemoListUIState {
        var updated = self
        updated.error = error
        return updated
    }

    /// Create updated state with loading status
    func with(isLoading: Bool) -> MemoListUIState {
        var updated = self
        updated.isLoading = isLoading
        return updated
    }

    /// Create updated state with editing memo ID
    func with(editingMemoId: UUID?) -> MemoListUIState {
        var updated = self
        updated.editingMemoId = editingMemoId
        return updated
    }

    /// Increment refresh trigger for UI updates
    mutating func incrementRefresh() {
        refreshTrigger = refreshTrigger &+ 1
    }
}

/// Selection state for multi-select edit mode - reduces @Published property count
struct MemoSelectionState: Equatable {
    var isEditMode: Bool
    var selectedMemoIds: Set<UUID>

    init() {
        self.isEditMode = false
        self.selectedMemoIds = Set()
    }

    /// Whether any memos are selected
    var hasSelection: Bool {
        !selectedMemoIds.isEmpty
    }

    /// Number of selected memos
    var selectedCount: Int {
        selectedMemoIds.count
    }

    /// Whether delete action can be performed
    var canDelete: Bool {
        hasSelection
    }
}

/// Transcription display state grouping - consolidates transcription-related @Published properties
struct TranscriptionDisplayState: Equatable {
    var states: [String: TranscriptionState]

    init() {
        self.states = [:]
    }

    init(states: [String: TranscriptionState]) {
        self.states = states
    }

    /// Get transcription state for memo ID
    func state(for memoId: UUID) -> TranscriptionState? {
        return states[memoId.uuidString]
    }

    /// Create updated state with new transcription state
    func with(state: TranscriptionState, for memoId: UUID) -> TranscriptionDisplayState {
        var updated = self
        updated.states[memoId.uuidString] = state
        return updated
    }
}

/// Playback state grouping - consolidates playback-related @Published properties
struct PlaybackState: Equatable {
    var playingMemo: Memo?
    var isPlaying: Bool

    init() {
        self.playingMemo = nil
        self.isPlaying = false
    }

    init(playingMemo: Memo?, isPlaying: Bool) {
        self.playingMemo = playingMemo
        self.isPlaying = isPlaying
    }

    /// Whether a specific memo is currently playing
    func isPlaying(memo: Memo) -> Bool {
        return playingMemo?.id == memo.id && isPlaying
    }

    /// Get appropriate play button icon for a memo
    func playButtonIcon(for memo: Memo) -> String {
        if playingMemo?.id == memo.id && isPlaying {
            return "pause.circle.fill"
        } else {
            return "play.circle.fill"
        }
    }
}

// MARK: - Supporting Types

/// Unified memo state combining memo data with transcription state (Swift 6 Sendable)
struct MemoWithState: Identifiable, Equatable, Sendable {
    let memo: Memo
    let transcriptionState: TranscriptionState
    let titleState: TitleGenerationState
    let isPlaying: Bool
    let playButtonIcon: String

    var id: UUID { memo.id }

    init(memo: Memo, transcriptionState: TranscriptionState, titleState: TitleGenerationState, isPlaying: Bool = false) {
        self.memo = memo
        self.transcriptionState = transcriptionState
        self.titleState = titleState
        self.isPlaying = isPlaying

        if isPlaying {
            self.playButtonIcon = "pause.circle.fill"
        } else {
            self.playButtonIcon = "play.circle.fill"
        }
    }

    /// Convenience accessors for common memo properties
    var displayName: String { memo.displayName }
    var filename: String { memo.filename }
    var creationDate: Date { memo.creationDate }
    var fileURL: URL { memo.fileURL }
}

/// Legacy row view state for memo list rows.
/// Kept for compatibility with older UI components while migrating to `MemoWithState`.
struct MemoRowState: Identifiable, Equatable {
    let memo: Memo
    let transcriptionState: TranscriptionState
    let titleState: TitleGenerationState
    let isPlaying: Bool
    let playButtonIcon: String

    var id: UUID { memo.id }
    var displayName: String { memo.displayName }
    var filename: String { memo.filename }
    var creationDate: Date { memo.creationDate }
    var fileURL: URL { memo.fileURL }

    init(memo: Memo, transcriptionState: TranscriptionState, titleState: TitleGenerationState, isPlaying: Bool, playButtonIcon: String) {
        self.memo = memo
        self.transcriptionState = transcriptionState
        self.titleState = titleState
        self.isPlaying = isPlaying
        self.playButtonIcon = playButtonIcon
    }

    init(from unified: MemoWithState) {
        self.memo = unified.memo
        self.transcriptionState = unified.transcriptionState
        self.titleState = unified.titleState
        self.isPlaying = unified.isPlaying
        self.playButtonIcon = unified.playButtonIcon
    }
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
        - error: \(error?.localizedDescription ?? "none")
        - isLoading: \(isLoading)
        """
    }

    // MARK: - ErrorHandling Protocol

    func retryLastOperation() {
        clearError()
        loadMemos()
    }

    // MARK: - Cleanup

    /// Clean up resources before deallocation
    func cleanup() {
        // Clean up event subscription
        if let subscriptionId = eventSubscriptionId {
            eventBus.unsubscribe(subscriptionId)
            eventSubscriptionId = nil
        }

        // Clean up transcription state subscription
        transcriptionStateSubscription?.cancel()
        transcriptionStateSubscription = nil

        // Clean up unified state subscription
        unifiedStateSubscription?.cancel()
        unifiedStateSubscription = nil

        print("📱 MemoListViewModel: Cleaned up all subscriptions including unified state management")
    }

    // Note: deinit cannot be used with @MainActor classes
    // The timer cancellable will be automatically released
    // EventBus subscriptions should be cleaned up manually via cleanup() if needed
}

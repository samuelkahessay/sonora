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
    private let memoRepository: any MemoRepository // Still needed for state updates
    private let transcriptionRepository: any TranscriptionRepository // For transcription states
    private var cancellables = Set<AnyCancellable>()
    
    // Event-driven and polling for real-time updates
    private var eventSubscriptionId: UUID?
    private var pollingTimer: AnyCancellable?
    private let eventBus = EventBus.shared
    private let logger: any LoggerProtocol = Logger.shared
    // Throttle bookkeeping for "no change" poll logs
    private var noChangeCounter: Int = 0
    private var lastNoChangeLogAt: Date? = nil
    private let noChangeLogInterval: TimeInterval = 15 // seconds
    
    // MARK: - Published Properties
    @Published var memos: [Memo] = []
    @Published var playingMemo: Memo?
    @Published var isPlaying: Bool = false
    @Published var navigationPath = NavigationPath()
    @Published var transcriptionStates: [String: TranscriptionState] = [:]
    @Published var error: SonoraError?
    @Published var isLoading: Bool = false
    @Published var editingMemoId: UUID? // Track which memo is being edited
    // Force SwiftUI refresh when needed (not read by UI directly)
    @Published private var refreshTrigger: Int = 0
    
    // MARK: - Multi-Select Edit Mode
    @Published var isEditMode: Bool = false
    @Published var selectedMemoIds: Set<UUID> = []
    @Published var isDragSelecting: Bool = false
    @Published var dragStartIndex: Int? = nil
    @Published var dragCurrentIndex: Int? = nil
    
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
    
    // MARK: - Multi-Select Computed Properties
    
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
    
    // MARK: - Initialization
    
    init(
        loadMemosUseCase: LoadMemosUseCaseProtocol,
        deleteMemoUseCase: DeleteMemoUseCaseProtocol,
        playMemoUseCase: PlayMemoUseCaseProtocol,
        startTranscriptionUseCase: StartTranscriptionUseCaseProtocol,
        retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol,
        getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol,
        renameMemoUseCase: RenameMemoUseCaseProtocol,
        memoRepository: any MemoRepository,
        transcriptionRepository: any TranscriptionRepository
    ) {
        self.loadMemosUseCase = loadMemosUseCase
        self.deleteMemoUseCase = deleteMemoUseCase
        self.playMemoUseCase = playMemoUseCase
        self.startTranscriptionUseCase = startTranscriptionUseCase
        self.retryTranscriptionUseCase = retryTranscriptionUseCase
        self.getTranscriptionStateUseCase = getTranscriptionStateUseCase
        self.renameMemoUseCase = renameMemoUseCase
        self.memoRepository = memoRepository
        self.transcriptionRepository = transcriptionRepository
        
        setupBindings()
        loadMemos()
        
        logger.debug("MemoListViewModel initialized", category: .viewModel, context: LogContext())
    }
    
    /// Convenience initializer using DIContainer
    /// CRITICAL FIX: Uses proper dependency injection following Clean Architecture
    convenience init() {
        let container = DIContainer.shared
        let memoRepository = container.memoRepository()
        let transcriptionRepository = container.transcriptionRepository()
        // Use routed transcription service from factory (respects preference + availability)
        let transcriptionAPI = container.createTranscriptionService()
        
        // Use direct repository initialization to ensure real persistence
        let startTranscriptionUseCase = StartTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI,
            eventBus: container.eventBus(),
            operationCoordinator: container.operationCoordinator(),
            moderationService: container.moderationService()
        )
        let retryTranscriptionUseCase = RetryTranscriptionUseCase(
            transcriptionRepository: transcriptionRepository,
            transcriptionAPI: transcriptionAPI
        )
        let getTranscriptionStateUseCase = GetTranscriptionStateUseCase(
            transcriptionRepository: transcriptionRepository
        )
        let renameMemoUseCase = RenameMemoUseCase(
            memoRepository: memoRepository
        )
        
        self.init(
            loadMemosUseCase: LoadMemosUseCase(memoRepository: memoRepository),
            deleteMemoUseCase: DeleteMemoUseCase(
                memoRepository: memoRepository,
                analysisRepository: container.analysisRepository(),
                transcriptionRepository: transcriptionRepository,
                logger: container.logger()
            ),
            playMemoUseCase: PlayMemoUseCase(memoRepository: memoRepository),
            startTranscriptionUseCase: startTranscriptionUseCase,
            retryTranscriptionUseCase: retryTranscriptionUseCase,
            getTranscriptionStateUseCase: getTranscriptionStateUseCase,
            renameMemoUseCase: renameMemoUseCase,
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
        
        // Subscribe to transcription completed events for real-time updates
        eventSubscriptionId = eventBus.subscribe(to: AppEvent.self) { [weak self] event in
            guard let self = self else { return }
            switch event {
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
        
        // Start polling timer for active transcriptions
        startPollingIfNeeded()
    }
    
    private func updateFromRepository() {
        memos = memoRepository.memos
        playingMemo = memoRepository.playingMemo
        isPlaying = memoRepository.isPlaying
    }
    
    private func updateTranscriptionStates() {
        let oldStates = transcriptionStates
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
            transcriptionStates = newStates
            refreshTrigger &+= 1
            logger.debug("UI refresh triggered (refreshTrigger=\(refreshTrigger))", category: .viewModel, context: LogContext())
        } else {
            // No-op but keep logs for debugging
            logger.debug("Repo objectWillChange with no effective state diff", category: .viewModel, context: LogContext())
        }

        startPollingIfNeeded() // Check if polling should start based on new states
    }
    
    // MARK: - Polling and Real-time Update Methods
    
    /// Start polling when there are in-progress transcriptions
    private func startPollingIfNeeded() {
        // Check if any transcriptions are in progress
        let hasActiveTranscriptions = transcriptionStates.values.contains { $0.isInProgress }
        
        if hasActiveTranscriptions && pollingTimer == nil {
            // Start 2-second polling timer
            pollingTimer = Timer.publish(every: 2.0, on: .main, in: .common)
                .autoconnect()
                .sink { [weak self] _ in
                    self?.pollTranscriptionStates()
                }
            logger.debug("Started polling for transcription updates", category: .viewModel, context: LogContext())
        } else if !hasActiveTranscriptions && pollingTimer != nil {
            // Stop polling when no active transcriptions
            stopPolling()
        }
    }
    
    /// Stop polling timer
    private func stopPolling() {
        pollingTimer?.cancel()
        pollingTimer = nil
        logger.debug("Stopped polling", category: .viewModel, context: LogContext())
    }
    
    /// Poll transcription states for all in-progress memos
    private func pollTranscriptionStates() {
        var hasChanges = false
        var changedMemos: [String] = []

        for memo in memos {
            let key = memo.id.uuidString
            let currentState = transcriptionStates[key]

            // Only check memos that are currently in-progress
            if currentState?.isInProgress == true {
                let newState = getTranscriptionStateUseCase.execute(memo: memo)

                if newState != currentState {
                    logger.debug("Poll change for \(memo.filename): \(currentState?.statusText ?? "nil") → \(newState.statusText)", category: .viewModel, context: LogContext())
                    // Explicitly send before mutation to ensure observers refresh
                    objectWillChange.send()
                    transcriptionStates[key] = newState
                    hasChanges = true
                    changedMemos.append(memo.filename)
                }
            }
        }

        if hasChanges {
            refreshTrigger &+= 1
            logger.debug("Poll applied updates: \(changedMemos). refreshTrigger=\(refreshTrigger)", category: .viewModel, context: LogContext())
            // Reset throttle counters on actual change
            noChangeCounter = 0
            lastNoChangeLogAt = nil
        } else {
            noChangeCounter &+= 1
            let now = Date()
            if let last = lastNoChangeLogAt {
                if now.timeIntervalSince(last) >= noChangeLogInterval {
                    logger.debug("Poll found no changes (\(noChangeCounter) cycles)", category: .viewModel, context: LogContext())
                    lastNoChangeLogAt = now
                    noChangeCounter = 0
                }
            } else {
                // Log first time, then throttle
                logger.debug("Poll found no changes", category: .viewModel, context: LogContext())
                lastNoChangeLogAt = now
                noChangeCounter = 0
            }
        }

        // Start/stop polling based on latest states
        startPollingIfNeeded()
    }
    
    /// Force refresh a specific memo's transcription state
    private func refreshTranscriptionState(for memoId: UUID) {
        guard let memo = memos.first(where: { $0.id == memoId }) else { return }
        
        let newState = getTranscriptionStateUseCase.execute(memo: memo)
        let key = memoId.uuidString
        
        if transcriptionStates[key] != newState {
            objectWillChange.send()
            transcriptionStates[key] = newState
            refreshTrigger &+= 1
            logger.debug("Event update for \(memo.filename): \(newState.statusText). refreshTrigger=\(refreshTrigger)", category: .viewModel, context: LogContext())
        }
        
        // Restart or stop polling based on current states
        startPollingIfNeeded()
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
                await MainActor.run {
                    // Start polling immediately when transcription begins
                    self.startPollingIfNeeded()
                }
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
                await MainActor.run {
                    // Start polling immediately when transcription retry begins
                    self.startPollingIfNeeded()
                }
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
            isEditMode.toggle()
            
            // Clear selection when exiting edit mode
            if !isEditMode {
                selectedMemoIds.removeAll()
                isDragSelecting = false
                dragStartIndex = nil
                dragCurrentIndex = nil
            }
        }
        
        HapticManager.shared.playSelection()
        logger.debug("Edit mode toggled: \(isEditMode ? "ON" : "OFF")", category: .viewModel, context: LogContext())
    }
    
    /// Select a specific memo
    func selectMemo(_ memo: Memo) {
        guard isEditMode else { return }
        
        withAnimation(Animation.easeInOut(duration: 0.2)) {
            selectedMemoIds.insert(memo.id)
        }
        
        HapticManager.shared.playSelection()
        logger.debug("Selected memo: \(memo.filename)", category: .viewModel, context: LogContext())
    }
    
    /// Deselect a specific memo
    func deselectMemo(_ memo: Memo) {
        guard isEditMode else { return }
        
        withAnimation(Animation.easeInOut(duration: 0.2)) {
            selectedMemoIds.remove(memo.id)
        }
        
        HapticManager.shared.playSelection()
    }
    
    /// Toggle selection state of a memo
    func toggleMemoSelection(_ memo: Memo) {
        guard isEditMode else { return }
        
        if selectedMemoIds.contains(memo.id) {
            deselectMemo(memo)
        } else {
            selectMemo(memo)
        }
    }
    
    /// Select all memos
    func selectAll() {
        guard isEditMode else { return }
        
        withAnimation(Animation.easeInOut(duration: 0.2)) {
            selectedMemoIds = Set(memos.map { $0.id })
        }
        
        HapticManager.shared.playSelection()
        logger.debug("Selected all \(memos.count) memos", category: .viewModel, context: LogContext())
    }
    
    /// Deselect all memos
    func deselectAll() {
        guard isEditMode else { return }
        
        withAnimation(.spring(response: 0.3)) {
            selectedMemoIds.removeAll()
        }
        
        HapticManager.shared.playSelection()
        logger.debug("Deselected all memos", category: .viewModel, context: LogContext())
    }
    
    /// Delete selected memos with confirmation
    func deleteSelectedMemos() {
        guard isEditMode && hasSelection else { return }
        
        let memosToDelete = memos.filter { selectedMemoIds.contains($0.id) }
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
                self.selectedMemoIds.removeAll()
                self.isEditMode = false
                HapticManager.shared.playDeletionFeedback()
            }
        }
    }
    
    /// Update drag selection to a specific index
    func updateDragSelection(to index: Int) {
        guard isEditMode && isDragSelecting else { return }
        guard index >= 0 && index < memos.count else { return }
        
        dragCurrentIndex = index
        
        // Select range from start to current
        if let startIndex = dragStartIndex {
            let range = min(startIndex, index)...max(startIndex, index)
            let memosInRange = Array(memos[range])
            
            withAnimation(.easeOut(duration: 0.1)) {
                for memo in memosInRange {
                    selectedMemoIds.insert(memo.id)
                }
            }
            
            // Provide light haptic feedback during drag
            if range.count > 1 {
                HapticManager.shared.playSelection()
            }
        }
    }
    
    /// Check if a memo is selected
    func isMemoSelected(_ memo: Memo) -> Bool {
        return selectedMemoIds.contains(memo.id)
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
        
        // Stop polling timer
        stopPolling()
        
        print("📱 MemoListViewModel: Cleaned up subscriptions and timers")
    }
    
    // Note: deinit cannot be used with @MainActor classes
    // The timer cancellable will be automatically released
    // EventBus subscriptions should be cleaned up manually via cleanup() if needed
}

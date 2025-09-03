//
//  MemosView.swift
//  Sonora
//
//  Main memo list container view
//

import SwiftUI

struct MemosView: View {
    @StateObject private var viewModel = MemoListViewModel()
    @StateObject private var dragCoordinator = DragSelectionCoordinator()
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme
    @State private var velocityTracker = DragVelocityTracker()
    @State private var autoScrollTimer: Timer? = nil
    let popToRoot: (() -> Void)?
    
    init(popToRoot: (() -> Void)? = nil) {
        self.popToRoot = popToRoot
    }

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            VStack(spacing: 0) {
                AlternativeSelectionControls(viewModel: viewModel)
                mainContent
            }
            .navigationTitle("Memos")
            .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        MemoListTopBarView(
                            isEmpty: viewModel.isEmpty,
                            isEditMode: viewModel.isEditMode,
                            onToggleEdit: { viewModel.toggleEditMode() }
                        )
                    }
                }
                .navigationDestination(for: Memo.self) { memo in
                    MemoDetailView(memo: memo)
                }
                .errorAlert($viewModel.error) { viewModel.retryLastOperation() }
                .loadingState(isLoading: viewModel.isLoading, message: "Loading memos...")
                .onReceive(NotificationCenter.default.publisher(for: .openMemoByID)) { note in
                    guard let idStr = note.userInfo?["memoId"] as? String, let id = UUID(uuidString: idStr) else { return }
                    if let memo = DIContainer.shared.memoRepository().getMemo(by: id) {
                        viewModel.navigationPath.append(memo)
                    }
                }
        }
        .overlay(alignment: .bottom) {
            // Bottom delete bar (only visible when in edit mode with selections)
            if viewModel.isEditMode && viewModel.hasSelection {
                MemoBottomDeleteBar(selectedCount: viewModel.selectedCount) { viewModel.deleteSelectedMemos() }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .selectionAnimation(value: viewModel.hasSelection)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Drag selection indicator
            if dragCoordinator.isDragSelecting {
                DragSelectionIndicatorView()
                    .transition(.scale.combined(with: .opacity))
                    .selectionAnimation(value: dragCoordinator.isDragSelecting)
            }
        }
    }

    // MARK: - Composed Content
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isEmpty {
            MemoEmptyStateView()
        } else {
            memoListView
        }
    }

    @ViewBuilder
    private var memoListView: some View {
        ScrollViewReader { proxy in
            List {
                ForEach(viewModel.memos, id: \.id) { memo in
                    let separatorConfig = separatorConfiguration(for: memo)
                    let rowContent = MemoRowView(memo: memo, viewModel: viewModel)
                        .dragSelectionAccessibility(
                            memo: memo,
                            viewModel: viewModel,
                            isSelected: viewModel.isMemoSelected(memo)
                        )
                        .background(
                        // Measure row height using the first visible row
                        viewModel.memos.first?.id == memo.id ? GeometryReader { geometry in
                            Color.clear.onAppear {
                                viewModel.updateRowHeight(geometry.size.height)
                            }
                        } : nil
                        )
                
                    if viewModel.isEditMode {
                        rowContent
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.toggleMemoSelection(memo) }
                            .memoRowListItem(colorScheme: colorScheme, separator: separatorConfig)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                MemoSwipeActionsView(memo: memo, viewModel: viewModel)
                            }
                    } else {
                        NavigationLink(value: memo) { rowContent }
                            .buttonStyle(.plain)
                            .memoRowListItem(colorScheme: colorScheme, separator: separatorConfig)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                MemoSwipeActionsView(memo: memo, viewModel: viewModel)
                            }
                    }
                }
                .onDelete { offsets in
                    HapticManager.shared.playDeletionFeedback()
                    viewModel.deleteMemos(at: offsets)
                }
            }
            .accessibilityLabel(MemoListConstants.AccessibilityLabels.mainList)
            .listStyle(MemoListConstants.listStyle)
            .scrollContentBackground(.hidden)
            .background(MemoListColors.containerBackground(for: colorScheme))
            .coordinateSpace(name: "memoList")
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 8) }
            .refreshable { viewModel.refreshMemos() }
            // Leading selection lane overlay to capture drag selection like Apple apps
            .overlay(alignment: .leading) {
                if viewModel.isEditMode {
                    Color.clear
                        .contentShape(Rectangle())
                        .frame(width: 44) // Selection lane width
                        .gesture(selectionDragGesture)
                }
            }
            // Auto-scroll while dragging near edges
            .onChange(of: dragCoordinator.edgeScrollDirection) { _, direction in
                guard viewModel.isEditMode else { return }
                stopAutoScroll()
                guard let direction else { return }
                autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { _ in
                    guard dragCoordinator.isDragSelecting else { stopAutoScroll(); return }
                    if let nextIndex = dragCoordinator.advanceSelection(direction: direction, viewModel: viewModel) {
                        let memoId = viewModel.memos[nextIndex].id
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(memoId, anchor: direction == .up ? .top : .bottom)
                        }
                    }
                }
            }
        }
    }

    private var selectionDragGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("memoList"))
            .onChanged { value in handleDragChanged(value) }
            .onEnded { value in handleDragEnded(value) }
    }
    
    /// Position-specific separator configuration for clean design
    /// Handles edge cases: first memo (no separators), middle memos (top & bottom), last memo (top only)
    private func separatorConfiguration(for memo: Memo) -> (visibility: Visibility, edges: VerticalEdge.Set) {
        let count = viewModel.memos.count
        guard count > 1 else { return (.hidden, []) }
        let isFirst = viewModel.memos.first?.id == memo.id
        let isLast = viewModel.memos.last?.id == memo.id
        if isFirst { return (.hidden, []) }
        if isLast { return (.visible, .top) }
        return (.visible, .all)
    }
}


// MARK: - Swipe Action Components

/// **Swipe Actions Configuration**
extension MemosView {
    
    /// **Contextual Transcription Actions**
    /// Contextual actions based on memo transcription state (excluding delete)
    /// 
    /// **Design Philosophy:**
    /// - Progressive disclosure: Show relevant actions only
    /// - Visual hierarchy: Primary action (transcribe) vs secondary (delete)
    /// - Accessibility: Full VoiceOver support with descriptive labels
    @ViewBuilder
    private func contextualTranscriptionActions(for memo: Memo) -> some View { EmptyView() }
    
    // MARK: Transcription Actions
    
    /// **Transcribe Button**
    /// Primary action for unprocessed memos
    @ViewBuilder
    private func transcribeButton(for memo: Memo) -> some View { EmptyView() }
    
    /// **Retry Transcription Button**
    /// Recovery action for failed transcriptions
    @ViewBuilder
    private func retryTranscriptionButton(for memo: Memo) -> some View { EmptyView() }
    
    // MARK: Destructive Actions
    
    /// **Delete Button**
    /// Destructive action with appropriate styling and feedback
    @ViewBuilder
    private func deleteButton(for memo: Memo) -> some View { EmptyView() }
    
    // MARK: - Bottom Delete Bar
    
    /// Bottom delete bar for bulk deletion
    @ViewBuilder
    private var bottomDeleteBar: some View { EmptyView() }
    
    // MARK: - Drag Selection Indicator
    
    /// Visual indicator during drag selection
    @ViewBuilder
    private var dragSelectionIndicator: some View {
        VStack(spacing: 8) {
            Image(systemName: "hand.draw")
                .font(.title2)
                .foregroundColor(.semantic(.brandPrimary))
            
            Text("Drag to select")
                .font(.caption)
                .foregroundColor(.semantic(.textSecondary))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.thinMaterial, in: Capsule())
        .shadow(radius: 4, y: 2)
        .padding(.top, 8)
        .padding(.trailing, 16)
    }
    
    // MARK: - Performance-Optimized Drag Selection Methods
    
    /// Handle drag gesture changes with performance optimization and gesture conflict resolution
    private func handleDragChanged(_ value: DragGesture.Value) {
        // Update velocity tracking
        velocityTracker.addSample(point: value.location)

        // Get list bounds for edge detection
        let listBounds = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)

        // Handle drag through coordinator (selection lane only)
        dragCoordinator.handleDragChanged(
            value: value,
            viewModel: viewModel,
            listBounds: listBounds,
            rowHeight: viewModel.measuredRowHeight
        )

        // Accessibility progress
        DragSelectionAccessibility.announceSelectionProgress(
            count: viewModel.selectedCount,
            total: viewModel.memos.count
        )
    }
    
    /// Handle end of drag gesture with cleanup
    private func handleDragEnded(_ value: DragGesture.Value? = nil) {
        let selectionCount = viewModel.selectedCount
        
        // If no drag selection started (quick tap in the lane), toggle the tapped row
        if !(dragCoordinator.isDragSelecting || viewModel.isDragSelecting), let value {
            let adjustedY = value.location.y - 8
            let index = max(0, min(Int(adjustedY / max(viewModel.measuredRowHeight, 1)), viewModel.memos.count - 1))
            if index >= 0 && index < viewModel.memos.count {
                viewModel.toggleMemoSelection(viewModel.memos[index])
            }
        }

        dragCoordinator.handleDragEnded(viewModel: viewModel)
        viewModel.endDragSelection()
        velocityTracker.reset()
        stopAutoScroll()
        
        // Announce completion for accessibility
        if selectionCount > 0 {
            DragSelectionAccessibility.announceSelectionComplete(count: selectionCount)
        }
    }

    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

#Preview { MemosView(popToRoot: nil) }

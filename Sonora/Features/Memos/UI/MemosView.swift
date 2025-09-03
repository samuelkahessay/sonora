//
//  MemosView.swift
//  Sonora
//
//  Main memo list container view
//

import SwiftUI

struct MemosView: View {
    @StateObject private var viewModel = MemoListViewModel()
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme
    let popToRoot: (() -> Void)?
    
    init(popToRoot: (() -> Void)? = nil) {
        self.popToRoot = popToRoot
    }

    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            mainContent
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
                    .animation(.spring(response: 0.3), value: viewModel.hasSelection)
            }
        }
        .overlay(alignment: .topTrailing) {
            // Drag selection indicator
            if viewModel.isDragSelecting {
                DragSelectionIndicatorView()
                    .transition(.scale.combined(with: .opacity))
                    .animation(.spring(response: 0.2), value: viewModel.isDragSelecting)
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
        List {
            ForEach(viewModel.memos) { memo in
                let separatorConfig = separatorConfiguration(for: memo)
                if viewModel.isEditMode {
                    MemoRowView(memo: memo, viewModel: viewModel)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.toggleMemoSelection(memo) }
                        .memoRowListItem(colorScheme: colorScheme, separator: separatorConfig)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            MemoSwipeActionsView(memo: memo, viewModel: viewModel)
                        }
                } else {
                    NavigationLink(value: memo) { MemoRowView(memo: memo, viewModel: viewModel) }
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
        .simultaneousGesture(selectionDragGesture)
        .safeAreaInset(edge: .top) { Color.clear.frame(height: 8) }
        .refreshable { viewModel.refreshMemos() }
    }

    private var selectionDragGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in dragSelectionChanged(value: value) }
            .onEnded { _ in dragSelectionEnded() }
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
    
    // MARK: - Drag Selection Methods
    
    /// Handle drag selection gesture changes
    private func dragSelectionChanged(value: DragGesture.Value) {
        guard viewModel.isEditMode else { return }
        
        // Calculate which row we're over based on drag location
        // Note: This is an approximation - actual row height may vary
        let approximateRowHeight: CGFloat = 80
        let topInset: CGFloat = 8 // From safeAreaInset
        let adjustedY = value.location.y - topInset
        let currentIndex = max(0, Int(adjustedY / approximateRowHeight))
        
        // Initialize drag selection on first movement
        if viewModel.dragStartIndex == nil {
            viewModel.dragStartIndex = currentIndex
            viewModel.isDragSelecting = true
        }
        
        // Update selection range
        viewModel.updateDragSelection(to: currentIndex)
    }
    
    /// Handle end of drag selection gesture
    private func dragSelectionEnded() {
        guard viewModel.isEditMode else { return }
        
        viewModel.isDragSelecting = false
        viewModel.dragStartIndex = nil
        viewModel.dragCurrentIndex = nil
        
        // Play completion haptic
        HapticManager.shared.playSelection()
    }
}

#Preview { MemosView(popToRoot: nil) }

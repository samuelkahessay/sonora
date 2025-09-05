//
//  MemosView.swift
//  Sonora
//
//  Main memo list container view
//

import SwiftUI

struct MemosView: View {
    @StateObject private var viewModel = DIContainer.shared.viewModelFactory().createMemoListViewModel()
    @SwiftUI.Environment(\.colorScheme) private var colorScheme: ColorScheme
    let popToRoot: (() -> Void)?
    
    init(popToRoot: (() -> Void)? = nil) {
        self.popToRoot = popToRoot
    }

    @State private var eventSubscriptionId: UUID? = nil

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
                .onAppear {
                    // Subscribe to deep link navigation events
                    eventSubscriptionId = EventBus.shared.subscribe(to: AppEvent.self) { [weak viewModel] event in
                        switch event {
                        case .navigateOpenMemoByID(let id):
                            if let memo = DIContainer.shared.memoRepository().getMemo(by: id) {
                                viewModel?.navigationPath.append(memo)
                            }
                        default:
                            break
                        }
                    }
                }
                .onDisappear {
                    if let id = eventSubscriptionId { EventBus.shared.unsubscribe(id) }
                    eventSubscriptionId = nil
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
        // Drag selection indicator removed (tap-only selection)
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
                
                    if viewModel.isEditMode {
                        rowContent
                            .contentShape(Rectangle())
                            .onTapGesture { viewModel.toggleMemoSelection(memo) }
                            .memoRowListItem(colorScheme: colorScheme, separator: separatorConfig)
                            .listRowBackground(
                                SelectedRowBackground(
                                    selected: viewModel.isMemoSelected(memo),
                                    colorScheme: colorScheme
                                )
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                MemoSwipeActionsView(memo: memo, viewModel: viewModel)
                            }
                    } else {
                        NavigationLink(value: memo) { rowContent }
                            .buttonStyle(.plain)
                            .memoRowListItem(colorScheme: colorScheme, separator: separatorConfig)
                            .listRowBackground(
                                SelectedRowBackground(
                                    selected: false,
                                    colorScheme: colorScheme
                                )
                            )
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
            // Always allow scrolling (drag selection removed)
            .background(MemoListColors.containerBackground(for: colorScheme))
            .coordinateSpace(name: "memoList")
            .safeAreaInset(edge: .top) { Color.clear.frame(height: 8) }
            .conditionalRefreshable(!viewModel.isEditMode) {
                await MainActor.run { viewModel.refreshMemos() }
            }
            // Drag selection lane and auto-scroll removed (tap-only selection)
        }
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
    
    // Drag selection helpers removed (tap-only selection)
}

#Preview { MemosView(popToRoot: nil) }

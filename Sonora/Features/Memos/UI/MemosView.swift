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
            Group {
                if viewModel.isEmpty {
                    UnifiedStateView.noMemos()
                    .accessibilityLabel("No memos yet. Start recording to see your audio memos here.")
                } else {
                    // MARK: - Memos List
                    /// **Polished List Configuration**
                    /// Optimized for readability, navigation, and modern iOS appearance
                    List {
                        ForEach(viewModel.memos) { memo in
                            // MARK: Navigation Row Configuration
                            let separatorConfig = separatorConfiguration(for: memo)
                            NavigationLink(value: memo) {
                                MemoRowView(memo: memo, viewModel: viewModel)
                            }
                            .buttonStyle(.plain)
                            // **Row Visual Configuration**
                            .listRowSeparator(separatorConfig.visibility, edges: separatorConfig.edges)
                            .listRowInsets(MemoListConstants.rowInsets)
                            .memoRowBackground(colorScheme)
                            // MARK: - Swipe Actions Configuration
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                deleteButton(for: memo)
                                contextualTranscriptionActions(for: memo)
                            }
                        }
                        // **Bulk Operations**
                        .onDelete { offsets in
                            HapticManager.shared.playDeletionFeedback()
                            viewModel.deleteMemos(at: offsets)
                        }
                    }
                    // **List Styling Configuration**
                    .accessibilityLabel(MemoListConstants.AccessibilityLabels.mainList)
                    .listStyle(MemoListConstants.listStyle) // Modern grouped appearance
                    .scrollContentBackground(.hidden) // Clean background
                    .background(MemoListColors.containerBackground(for: colorScheme)) // Unified color management
                    // Add a small top inset so first row doesn't touch nav bar hairline
                    .safeAreaInset(edge: .top) {
                        Color.clear.frame(height: 8)
                    }
                    .refreshable { viewModel.refreshMemos() } // Pull-to-refresh support
                }
            }
            .navigationTitle("Memos")
            .navigationDestination(for: Memo.self) { memo in
                MemoDetailView(memo: memo)
            }
            .errorAlert($viewModel.error) {
                viewModel.retryLastOperation()
            }
            .loadingState(
                isLoading: viewModel.isLoading,
                message: "Loading memos..."
            )
            .onReceive(NotificationCenter.default.publisher(for: .openMemoByID)) { note in
                guard let idStr = note.userInfo?["memoId"] as? String, let id = UUID(uuidString: idStr) else { return }
                if let memo = DIContainer.shared.memoRepository().getMemo(by: id) {
                    viewModel.navigationPath.append(memo)
                }
            }
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
    private func contextualTranscriptionActions(for memo: Memo) -> some View {
        let transcriptionState = viewModel.getTranscriptionState(for: memo)
        
        // **Transcription Actions**
        // Show transcription-related actions based on current state
        if transcriptionState.isNotStarted {
            transcribeButton(for: memo)
        } else if transcriptionState.isFailed {
            retryTranscriptionButton(for: memo)
        }
    }
    
    // MARK: Transcription Actions
    
    /// **Transcribe Button**
    /// Primary action for unprocessed memos
    @ViewBuilder
    private func transcribeButton(for memo: Memo) -> some View {
        Button {
            HapticManager.shared.playSelection()
            viewModel.startTranscription(for: memo)
        } label: {
            Label(MemoListConstants.SwipeActions.transcribeTitle, 
                  systemImage: MemoListConstants.SwipeActions.transcribeIcon)
        }
        .tint(.semantic(.brandPrimary))
        .accessibilityLabel("Transcribe \(memo.displayName)")
        .accessibilityHint(MemoListConstants.AccessibilityLabels.transcribeHint)
    }
    
    /// **Retry Transcription Button**
    /// Recovery action for failed transcriptions
    @ViewBuilder
    private func retryTranscriptionButton(for memo: Memo) -> some View {
        Button {
            HapticManager.shared.playSelection()
            viewModel.retryTranscription(for: memo)
        } label: {
            Label(MemoListConstants.SwipeActions.retryTitle,
                  systemImage: MemoListConstants.SwipeActions.retryIcon)
        }
        .tint(.semantic(.warning))
        .accessibilityLabel("Retry transcription for \(memo.displayName)")
        .accessibilityHint(MemoListConstants.AccessibilityLabels.retryHint)
    }
    
    // MARK: Destructive Actions
    
    /// **Delete Button**
    /// Destructive action with appropriate styling and feedback
    @ViewBuilder
    private func deleteButton(for memo: Memo) -> some View {
        Button(role: .destructive) {
            HapticManager.shared.playDeletionFeedback()
            if let idx = viewModel.memos.firstIndex(where: { $0.id == memo.id }) {
                viewModel.deleteMemo(at: idx)
            }
        } label: {
            Label(MemoListConstants.SwipeActions.deleteTitle,
                  systemImage: MemoListConstants.SwipeActions.deleteIcon)
        }
        .accessibilityLabel("Delete \(memo.displayName)")
        .accessibilityHint(MemoListConstants.AccessibilityLabels.deleteHint)
    }
}

#Preview { MemosView(popToRoot: nil) }

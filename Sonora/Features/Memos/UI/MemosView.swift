//
//  MemosView.swift (moved to Features/Memos/UI)
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

extension Notification.Name {
    static let popToRootMemos = Notification.Name("popToRootMemos")
    static let openMemoByID = Notification.Name("openMemoByID")
}

struct MemosView: View {
    @StateObject private var viewModel = MemoListViewModel()
    let popToRoot: (() -> Void)?
    
    init(popToRoot: (() -> Void)? = nil) {
        self.popToRoot = popToRoot
    }
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if viewModel.isEmpty {
                    UnifiedStateView.noMemos {
                        // Navigate to recording - could trigger navigation or show recording view
                        // For now, just refresh to show user something happened
                        viewModel.refreshMemos()
                    }
                    .background(Color.semantic(.bgSecondary))
                    .accessibilityLabel("No memos yet. Start recording to see your audio memos here.")
                } else {
                    List {
                        ForEach(viewModel.memos) { memo in
                            NavigationLink(value: memo) {
                                MemoCardView(memo: memo, viewModel: viewModel)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(
                                top: Spacing.sm,
                                leading: Spacing.md,
                                bottom: Spacing.sm,
                                trailing: Spacing.md
                            ))
                            .accessibilityHint("Double tap to open memo details, swipe for more actions")
                            .swipeActions(allowsFullSwipe: false) {
                                // Transcription actions
                                if viewModel.getTranscriptionState(for: memo).isNotStarted {
                                    Button {
                                        HapticManager.shared.playSelection()
                                        viewModel.startTranscription(for: memo)
                                    } label: {
                                        Label("Transcribe", systemImage: "text.quote")
                                    }
                                    .tint(.semantic(.brandPrimary))
                                    .accessibilityLabel("Transcribe \(memo.displayName)")
                                } else if viewModel.getTranscriptionState(for: memo).isFailed {
                                    Button {
                                        HapticManager.shared.playSelection()
                                        viewModel.retryTranscription(for: memo)
                                    } label: {
                                        Label("Retry", systemImage: "arrow.clockwise")
                                    }
                                    .tint(.semantic(.warning))
                                    .accessibilityLabel("Retry transcription for \(memo.displayName)")
                                }
                                
                                // Delete action
                                Button(role: .destructive) {
                                    HapticManager.shared.playDeletionFeedback()
                                    if let idx = viewModel.memos.firstIndex(where: { $0.id == memo.id }) {
                                        viewModel.deleteMemo(at: idx)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .accessibilityLabel("Delete \(memo.displayName)")
                                .accessibilityHint("Double tap to permanently delete this memo")
                            }
                        }
                        .onDelete { offsets in
                            HapticManager.shared.playDeletionFeedback()
                            viewModel.deleteMemos(at: offsets)
                        }
                    }
                    .accessibilityLabel("Memos list")
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(Color.semantic(.bgSecondary))
                    .refreshable { viewModel.refreshMemos() }
                }
            }
            .navigationTitle("Memos")
            .navigationDestination(for: Memo.self) { memo in
                MemoDetailView(memo: memo)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        HapticManager.shared.playSelection()
                        viewModel.loadMemos()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.body.weight(.medium))
                    }
                    .accessibilityLabel("Refresh memos")
                    .accessibilityHint("Double tap to reload the list of memos")
                }
            }
            .toolbarBackground(Color.semantic(.bgPrimary).opacity(0.8), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .errorAlert($viewModel.error) {
                viewModel.retryLastOperation()
            }
            .loadingState(
                isLoading: viewModel.isLoading,
                message: "Loading memos...",
                error: $viewModel.error
            ) {
                viewModel.retryLastOperation()
            }
            .onReceive(NotificationCenter.default.publisher(for: .openMemoByID)) { note in
                guard let idStr = note.userInfo?["memoId"] as? String, let id = UUID(uuidString: idStr) else { return }
                if let memo = DIContainer.shared.memoRepository().getMemo(by: id) {
                    viewModel.navigationPath.append(memo)
                }
            }
        }
    }
}

/// Modern memo card component following native iOS design patterns
struct MemoCardView: View {
    let memo: Memo
    let viewModel: MemoListViewModel
    @State private var transcriptionState: TranscriptionState = .notStarted
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main content area
            HStack(spacing: Spacing.md) {
                // Play button - primary action
                playButton
                
                // Content area
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    // Title
                    Text(memo.displayName)
                        .font(.system(.body, design: .default, weight: .medium))
                        .foregroundColor(.semantic(.textPrimary))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    
                    // Metadata row
                    HStack(spacing: Spacing.sm) {
                        // Duration
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.system(.caption2, weight: .medium))
                            Text(memo.durationString)
                                .monospacedDigit()
                        }
                        .font(.caption)
                        .foregroundColor(.semantic(.textSecondary))
                        
                        // Date
                        Text(RelativeDateTimeFormatter().localizedString(for: memo.creationDate, relativeTo: Date()))
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                        
                        Spacer()
                        
                        // Transcription status indicator
                        transcriptionStatusIndicator
                    }
                }
            }
            .padding(Spacing.md)
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.semantic(.bgPrimary))
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
        )
        .onAppear { updateTranscriptionState() }
        .onReceive(viewModel.$transcriptionStates) { _ in updateTranscriptionState() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(getMemoAccessibilityLabel())
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private var playButton: some View {
        Button(action: { 
            HapticManager.shared.playSelection()
            viewModel.playMemo(memo)
        }) {
            Image(systemName: viewModel.playButtonIcon(for: memo))
                .font(.title2.weight(.medium))
                .foregroundColor(.semantic(.brandPrimary))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.bordered)
        .tint(.semantic(.brandPrimary))
        .accessibilityLabel(getPlayButtonAccessibilityLabel())
        .accessibilityHint("Double tap to \(viewModel.isMemoPaying(memo) ? "pause" : "play") this memo")
        .accessibilityAddTraits(.startsMediaSession)
    }
    
    @ViewBuilder
    private var transcriptionStatusIndicator: some View {
        switch transcriptionState {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.semantic(.success))
                .font(.caption.weight(.medium))
                .accessibilityLabel("Transcribed")
                .accessibilityAddTraits(.isStaticText)
            
        case .inProgress:
            LoadingIndicator(size: .small)
                .accessibilityLabel("Transcribing")
                .accessibilityAddTraits(.isStaticText)
            
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.semantic(.warning))
                .font(.caption.weight(.medium))
                .accessibilityLabel("Transcription failed")
                .accessibilityAddTraits(.isStaticText)
            
        case .notStarted:
            Image(systemName: "text.quote")
                .foregroundColor(.semantic(.textSecondary))
                .font(.caption.weight(.medium))
                .accessibilityLabel("Not transcribed")
                .accessibilityAddTraits(.isStaticText)
        }
    }
    
    // MARK: - Helper Methods
    
    private func updateTranscriptionState() {
        transcriptionState = viewModel.getTranscriptionState(for: memo)
    }
    
    private func getPlayButtonAccessibilityLabel() -> String {
        if viewModel.isMemoPaying(memo) {
            return "Pause \(memo.displayName)"
        } else {
            return "Play \(memo.displayName)"
        }
    }
    
    private func getMemoAccessibilityLabel() -> String {
        var components: [String] = []
        
        // Add memo name
        components.append(memo.displayName)
        
        // Add duration and date
        components.append("Duration: \(memo.durationString)")
        let relativeDateFormatter = RelativeDateTimeFormatter()
        components.append("Created \(relativeDateFormatter.localizedString(for: memo.creationDate, relativeTo: Date()))")
        
        // Add transcription status
        switch transcriptionState {
        case .completed:
            components.append("Transcribed")
        case .inProgress:
            components.append("Transcribing")
        case .failed:
            components.append("Transcription failed")
        case .notStarted:
            components.append("Not transcribed")
        }
        
        // Add playing status
        if viewModel.isMemoPaying(memo) {
            components.append("Currently playing")
        }
        
        return components.joined(separator: ", ")
    }
}


// MARK: - MemosView Extensions

// Accessibility helpers have been moved to MemoCardView for better encapsulation

#Preview { MemosView(popToRoot: nil) }

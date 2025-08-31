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
                    .accessibilityLabel("No memos yet. Start recording to see your audio memos here.")
                } else {
                    List {
                        ForEach(viewModel.memos) { memo in
                            NavigationLink(value: memo) {
                                MemoRowView(memo: memo, viewModel: viewModel)
                            }
                            .accessibilityLabel(getMemoAccessibilityLabel(for: memo))
                            .accessibilityHint("Double tap to open memo details, swipe for more actions")
                            .swipeActions(allowsFullSwipe: true) {
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
                    .listStyle(.insetGrouped)
                    .refreshable { viewModel.refreshMemos() }
                }
            }
            .navigationTitle("Memos")
            .navigationDestination(for: Memo.self) { memo in
                MemoDetailView(memo: memo)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") { 
                        HapticManager.shared.playSelection()
                        viewModel.loadMemos()
                    }
                    .accessibilityLabel("Refresh memos")
                    .accessibilityHint("Double tap to reload the list of memos")
                }
            }
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

struct MemoRowView: View {
    let memo: Memo
    let viewModel: MemoListViewModel
    @State private var transcriptionState: TranscriptionState = .notStarted
    
    // MARK: - Accessibility Helpers
    
    private func getPlayButtonAccessibilityLabel(for memo: Memo) -> String {
        if viewModel.isMemoPaying(memo) {
            return "Pause \(memo.displayName)"
        } else {
            return "Play \(memo.displayName)"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { 
                    HapticManager.shared.playSelection()
                    viewModel.playMemo(memo)
                }) {
                    Image(systemName: viewModel.playButtonIcon(for: memo))
                        .font(.title2)
                        .fontWeight(.semibold)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(getPlayButtonAccessibilityLabel(for: memo))
                .accessibilityHint("Double tap to \(viewModel.isMemoPaying(memo) ? "pause" : "play") this memo")
                .accessibilityAddTraits(.startsMediaSession)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(memo.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(memo.filename)
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer()
                        Text(memo.durationString)
                            .font(.caption)
                            .foregroundColor(.semantic(.textSecondary))
                            .monospacedDigit()
                    }
                }
            }
            
            HStack {
                TranscriptionStatusView(state: transcriptionState, compact: true)
                Spacer()
                if transcriptionState.isFailed {
                    Button("Retry") { 
                        HapticManager.shared.playSelection()
                        viewModel.retryTranscription(for: memo)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Retry transcription")
                    .accessibilityHint("Double tap to retry failed transcription")
                } else if transcriptionState.isInProgress {
                    HStack(spacing: 6) {
                        LoadingIndicator(size: .small)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.semantic(.info))
                    }
                    .accessibilityLabel("Transcription in progress")
                    .accessibilityAddTraits(.updatesFrequently)
                } else if transcriptionState.isNotStarted {
                    Button("Transcribe") { 
                        HapticManager.shared.playSelection()
                        viewModel.startTranscription(for: memo)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Start transcription")
                    .accessibilityHint("Double tap to transcribe this memo using AI")
                }
            }
            .font(.caption)
        }
        .onAppear { updateTranscriptionState() }
        .accessibilityElement(children: .combine)
        .onReceive(viewModel.$transcriptionStates) { _ in updateTranscriptionState() }
    }
    
    private func updateTranscriptionState() {
        transcriptionState = viewModel.getTranscriptionState(for: memo)
    }
}


// MARK: - MemosView Accessibility Extensions

extension MemosView {
    
    private func getMemoAccessibilityLabel(for memo: Memo) -> String {
        var components: [String] = []
        
        // Add memo name
        components.append(memo.displayName)
        
        // Add duration
        components.append("Duration: \(memo.durationString)")
        
        // Add transcription status
        let transcriptionState = viewModel.getTranscriptionState(for: memo)
        if transcriptionState.isCompleted {
            components.append("Transcribed")
        } else if transcriptionState.isInProgress {
            components.append("Transcription in progress")
        } else if transcriptionState.isFailed {
            components.append("Transcription failed")
        } else {
            components.append("Not transcribed")
        }
        
        // Add playing status
        if viewModel.isMemoPaying(memo) {
            components.append("Currently playing")
        }
        
        return components.joined(separator: ", ")
    }
}

#Preview { MemosView(popToRoot: nil) }

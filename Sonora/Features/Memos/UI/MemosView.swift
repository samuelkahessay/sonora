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
                                MemoCardView(memo: memo, viewModel: viewModel)
                            }
                            .listRowSeparator(.visible, edges: .bottom)
                            .listRowInsets(EdgeInsets(
                                top: 0,
                                leading: 0,
                                bottom: 0,
                                trailing: 0
                            ))
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
                    .listStyle(.insetGrouped)
                    .refreshable { viewModel.refreshMemos() }
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

/// Clean memo row component for navigation-focused list
struct MemoCardView: View {
    let memo: Memo
    let viewModel: MemoListViewModel
    
    var body: some View {
        HStack(spacing: Spacing.md) {
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
                }
            }
            
            Spacer()
        }
        .padding(.vertical, Spacing.sm)
        .padding(.horizontal, Spacing.md)
        .contentShape(Rectangle()) // Ensure entire row is tappable
        .accessibilityElement(children: .combine)
        .accessibilityLabel(getMemoAccessibilityLabel())
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Double tap to view memo details")
    }
    
    // MARK: - Helper Methods
    
    private func getMemoAccessibilityLabel() -> String {
        var components: [String] = []
        
        // Add memo name
        components.append(memo.displayName)
        
        // Add duration and date
        components.append("Duration: \(memo.durationString)")
        let relativeDateFormatter = RelativeDateTimeFormatter()
        components.append("Created \(relativeDateFormatter.localizedString(for: memo.creationDate, relativeTo: Date()))")
        
        return components.joined(separator: ", ")
    }
}


// MARK: - MemosView Extensions

// Accessibility helpers have been moved to MemoCardView for better encapsulation

#Preview { MemosView(popToRoot: nil) }

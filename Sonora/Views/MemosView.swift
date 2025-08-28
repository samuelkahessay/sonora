//
//  MemosView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

extension Notification.Name {
    static let popToRootMemos = Notification.Name("popToRootMemos")
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
                    VStack(spacing: 12) {
                        Image(systemName: viewModel.emptyStateIcon)
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(viewModel.emptyStateTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text(viewModel.emptyStateSubtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.memos) { memo in
                            NavigationLink(value: memo) {
                                MemoRowView(memo: memo, viewModel: viewModel)
                            }
                        }
                    }
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
                    Button("Refresh") { viewModel.loadMemos() }
                }
            }
        }
    }
}

struct MemoRowView: View {
    let memo: Memo
    let viewModel: MemoListViewModel
    @State private var transcriptionState: TranscriptionState = .notStarted
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Button(action: { viewModel.playMemo(memo) }) {
                    Image(systemName: viewModel.playButtonIcon(for: memo))
                        .font(.system(size: 24, weight: .semibold))
                }
                .buttonStyle(.bordered)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(memo.displayName)
                        .font(.headline)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        Text(memo.filename)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Spacer()
                        Text(memo.durationString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                }
            }
            
            HStack {
                TranscriptionStatusView(state: transcriptionState, compact: true)
                Spacer()
                if transcriptionState.isFailed {
                    Button("Retry") { viewModel.retryTranscription(for: memo) }
                        .buttonStyle(.bordered)
                } else if transcriptionState.isInProgress {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.8)
                        Text("Processing...")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                } else if transcriptionState.isNotStarted {
                    Button("Transcribe") { viewModel.startTranscription(for: memo) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .font(.caption)
        }
        .onAppear { updateTranscriptionState() }
        .onReceive(viewModel.$transcriptionStates) { _ in updateTranscriptionState() }
    }
    
    private func updateTranscriptionState() {
        transcriptionState = viewModel.getTranscriptionState(for: memo)
    }
}

#Preview { MemosView(popToRoot: nil) }


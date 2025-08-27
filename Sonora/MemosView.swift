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
    @EnvironmentObject var memoStore: MemoStore // Keep for transition compatibility
    let popToRoot: (() -> Void)?
    
    init(popToRoot: (() -> Void)? = nil) {
        self.popToRoot = popToRoot
    }
    
    var body: some View {
        NavigationStack(path: $viewModel.navigationPath) {
            Group {
                if viewModel.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: viewModel.emptyStateIcon)
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text(viewModel.emptyStateTitle)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text(viewModel.emptyStateSubtitle)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(viewModel.memos) { memo in
                            NavigationLink(value: memo) {
                                MemoRowView(memo: memo, viewModel: viewModel)
                            }
                        }
                        .onDelete(perform: viewModel.deleteMemos)
                    }
                    .refreshable {
                        viewModel.refreshMemos()
                    }
                }
            }
            .navigationTitle("Memos")
            .navigationDestination(for: Memo.self) { memo in
                MemoDetailView(memo: memo)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        viewModel.loadMemos()
                    }
                }
            }
        }
        .onAppear {
            viewModel.onViewAppear()
        }
    }
    
}

struct MemoRowView: View {
    let memo: Memo
    let viewModel: MemoListViewModel
    @EnvironmentObject var memoStore: MemoStore // Keep for transition compatibility
    @State private var transcriptionState: TranscriptionState = .notStarted
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(memo.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(memo.filename)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(spacing: 4) {
                    Button(action: {
                        viewModel.playMemo(memo)
                    }) {
                        Image(systemName: viewModel.playButtonIcon(for: memo))
                            .font(.title2)
                            .foregroundColor(.blue)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Text(memo.durationString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            
            // Transcription Status Row
            HStack {
                TranscriptionStatusView(state: transcriptionState, compact: true)
                
                Spacer()
                
                if transcriptionState.isFailed {
                    Button("Retry") {
                        viewModel.retryTranscription(for: memo)
                    }
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                } else if transcriptionState.isInProgress {
                    Text("Processing...")
                        .font(.caption)
                        .foregroundColor(.blue)
                } else if transcriptionState.isNotStarted {
                    Button("Transcribe") {
                        viewModel.startTranscription(for: memo)
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            updateTranscriptionState()
        }
        .onReceive(viewModel.$transcriptionStates) { _ in
            updateTranscriptionState()
        }
    }
    
    private func updateTranscriptionState() {
        transcriptionState = viewModel.getTranscriptionState(for: memo)
    }
    
}

#Preview {
    MemosView(popToRoot: nil)
        .environmentObject(MemoStore(transcriptionRepository: TranscriptionRepositoryImpl()))
}
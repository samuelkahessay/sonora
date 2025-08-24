//
//  MemosView.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import SwiftUI

struct MemosView: View {
    @EnvironmentObject var memoStore: MemoStore
    
    var body: some View {
        NavigationView {
            Group {
                if memoStore.memos.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mic.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Memos Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("Start recording to see your audio memos here")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(memoStore.memos) { memo in
                            NavigationLink(destination: MemoDetailView(memo: memo)) {
                                MemoRowView(memo: memo)
                            }
                        }
                        .onDelete(perform: deleteMemos)
                    }
                    .refreshable {
                        memoStore.loadMemos()
                    }
                }
            }
            .navigationTitle("Memos")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        memoStore.loadMemos()
                    }
                }
            }
        }
    }
    
    private func deleteMemos(at offsets: IndexSet) {
        for index in offsets {
            memoStore.deleteMemo(memoStore.memos[index])
        }
    }
}

struct MemoRowView: View {
    let memo: Memo
    @EnvironmentObject var memoStore: MemoStore
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
                        memoStore.playMemo(memo)
                    }) {
                        Image(systemName: playButtonIcon(for: memo))
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
                        memoStore.retryTranscription(for: memo)
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
                        memoStore.sharedTranscriptionManager.startTranscription(for: memo)
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
        .onReceive(memoStore.sharedTranscriptionManager.$transcriptionStates) { _ in
            updateTranscriptionState()
        }
    }
    
    private func updateTranscriptionState() {
        transcriptionState = memoStore.getTranscriptionState(for: memo)
    }
    
    private func playButtonIcon(for memo: Memo) -> String {
        if memoStore.playingMemo?.id == memo.id && memoStore.isPlaying {
            return "pause.circle.fill"
        } else {
            return "play.circle.fill"
        }
    }
}

#Preview {
    MemosView()
        .environmentObject(MemoStore())
}
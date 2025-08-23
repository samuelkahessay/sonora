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
                            MemoRowView(memo: memo)
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
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(memo.displayName)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text(memo.filename)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text(memo.durationString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                }
            }
            
            Spacer()
            
            Button(action: {
                memoStore.playMemo(memo)
            }) {
                Image(systemName: playButtonIcon(for: memo))
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, 4)
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
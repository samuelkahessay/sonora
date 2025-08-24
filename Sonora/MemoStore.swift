//
//  MemoStore.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import Foundation
import AVFoundation
import Combine

struct Memo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let filename: String
    let url: URL
    let createdAt: Date
    
    var displayName: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: createdAt)
    }
    
    @available(iOS, introduced: 11.0, deprecated: 16.0)
    var duration: TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    @available(iOS, introduced: 11.0, deprecated: 16.0)
    var durationString: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

final class AudioPlayerProxy: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}

@MainActor
class MemoStore: ObservableObject {
    @Published var memos: [Memo] = []
    @Published var playingMemo: Memo?
    @Published var isPlaying = false
    
    private var audioPlayer: AVAudioPlayer?
    private var audioPlayerProxy = AudioPlayerProxy()
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let transcriptionManager = TranscriptionManager()
    private let metadataManager = MemoMetadataManager()
    
    init() {
        setupAudioPlayerProxy()
        loadMemos()
    }
    
    private func setupAudioPlayerProxy() {
        audioPlayerProxy.onFinish = { [weak self] in
            DispatchQueue.main.async {
                self?.stopPlaying()
            }
        }
    }
    
    func loadMemos() {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: documentsPath, includingPropertiesForKeys: [.creationDateKey], options: [])
            
            let memoFiles = files.filter { $0.pathExtension == "m4a" }
            
            var loadedMemos: [Memo] = []
            
            for file in memoFiles {
                let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
                let creationDate = resourceValues.creationDate ?? Date()
                
                let memo = Memo(
                    filename: file.lastPathComponent,
                    url: file,
                    createdAt: creationDate
                )
                loadedMemos.append(memo)
            }
            
            DispatchQueue.main.async {
                let sortedMemos = loadedMemos.sorted { $0.createdAt > $1.createdAt }
                print("📋 MemoStore: Loaded \(sortedMemos.count) memos")
                self.memos = sortedMemos
            }
        } catch {
            print("Error loading memos: \(error)")
        }
    }
    
    func deleteMemo(_ memo: Memo) {
        do {
            try FileManager.default.removeItem(at: memo.url)
            metadataManager.deleteMetadata(for: memo.url)
            memos.removeAll { $0.id == memo.id }
            
            if playingMemo?.id == memo.id {
                stopPlaying()
            }
        } catch {
            print("Error deleting memo: \(error)")
        }
    }
    
    func playMemo(_ memo: Memo) {
        if playingMemo?.id == memo.id && isPlaying {
            pausePlaying()
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: memo.url)
            audioPlayer?.delegate = audioPlayerProxy
            audioPlayer?.play()
            
            playingMemo = memo
            isPlaying = true
            
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
        } catch {
            print("Error playing memo: \(error)")
        }
    }
    
    func pausePlaying() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func stopPlaying() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingMemo = nil
        isPlaying = false
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)
    }
    
    func handleNewRecording(at url: URL) {
        print("📁 MemoStore: 🚨 NEW RECORDING RECEIVED - STARTING INSTANT AUTO-TRANSCRIPTION")
        print("📁 MemoStore: File URL: \(url.lastPathComponent)")
        print("📁 MemoStore: Full path: \(url.path)")
        
        // First load memos to get the actual memo object from the list
        loadMemos()
        
        // Small delay to ensure file is available and memos are loaded
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("📁 MemoStore: Looking for memo in loaded list...")
            
            if let existingMemo = self.memos.first(where: { $0.url == url }) {
                print("🎯 MemoStore: Found existing memo in list: \(existingMemo.filename)")
                print("🚀 MemoStore: STARTING TRANSCRIPTION with existing memo object!")
                self.transcriptionManager.startTranscription(for: existingMemo)
            } else {
                print("❌ MemoStore: Memo not found in list, creating new one...")
                // Fallback: create memo object directly
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                    let creationDate = resourceValues.creationDate ?? Date()
                    
                    let newMemo = Memo(
                        filename: url.lastPathComponent,
                        url: url,
                        createdAt: creationDate
                    )
                    
                    print("🎯 MemoStore: Created new memo object for \(newMemo.filename)")
                    self.transcriptionManager.startTranscription(for: newMemo)
                } catch {
                    print("❌ MemoStore: Failed to create memo: \(error)")
                }
            }
        }
    }
    
    func getTranscriptionState(for memo: Memo) -> TranscriptionState {
        let state = transcriptionManager.getTranscriptionState(for: memo)
        print("🏪 MemoStore: Getting transcription state for \(memo.filename)")
        print("🏪 MemoStore: State from TranscriptionManager: \(state.statusText)")
        print("🏪 MemoStore: State is completed: \(state.isCompleted)")
        return state
    }
    
    func retryTranscription(for memo: Memo) {
        transcriptionManager.retryTranscription(for: memo)
    }
    
    var sharedTranscriptionManager: TranscriptionManager {
        return transcriptionManager
    }
}

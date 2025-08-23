//
//  MemoStore.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-08-23.
//

import Foundation
import AVFoundation
import Combine

struct Memo: Identifiable, Equatable {
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
    
    var duration: TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
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

class MemoStore: ObservableObject {
    @Published var memos: [Memo] = []
    @Published var playingMemo: Memo?
    @Published var isPlaying = false
    
    private var audioPlayer: AVAudioPlayer?
    private var audioPlayerProxy = AudioPlayerProxy()
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
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
                self.memos = loadedMemos.sorted { $0.createdAt > $1.createdAt }
            }
        } catch {
            print("Error loading memos: \(error)")
        }
    }
    
    func deleteMemo(_ memo: Memo) {
        do {
            try FileManager.default.removeItem(at: memo.url)
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
}
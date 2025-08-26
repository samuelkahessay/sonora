import Foundation
import Combine
import AVFoundation

@MainActor
final class MemoRepositoryImpl: ObservableObject, MemoRepository {
    @Published var memos: [Memo] = []
    
    // Playback state
    @Published private(set) var playingMemo: Memo?
    @Published private(set) var isPlaying: Bool = false
    
    private var player: AVAudioPlayer?
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let metadataManager = MemoMetadataManager()
    
    init() {
        loadMemos()
    }
    
    // MARK: - Playback
    func playMemo(_ memo: Memo) {
        // Stop current if different
        if let current = playingMemo, current.id != memo.id {
            stopPlaying()
        }
        do {
            let audio = try AVAudioPlayer(contentsOf: memo.url)
            player = audio
            audio.prepareToPlay()
            audio.play()
            playingMemo = memo
            isPlaying = true
            print("▶️ MemoRepository: Playing \(memo.filename)")

        } catch {
            print("❌ MemoRepository: Failed to play \(memo.filename): \(error)")
            stopPlaying()

        }
    }
    
    // Playback handling
    func stopPlaying() {
        player?.stop()
        player = nil
        isPlaying = false
        playingMemo = nil
        print("⏹️ MemoRepository: Stopped playback")
    }
    
    func loadMemos() {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsPath, 
                includingPropertiesForKeys: [.creationDateKey], 
                options: []
            )
            
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
            
            let sortedMemos = loadedMemos.sorted { $0.createdAt > $1.createdAt }
            print("📋 MemoRepository: Loaded \(sortedMemos.count) memos")
            self.memos = sortedMemos
            
        } catch {
            print("❌ MemoRepository: Error loading memos: \(error)")
        }
    }
    
    func saveMemo(_ memo: Memo) {
        if !memos.contains(where: { $0.id == memo.id }) {
            memos.append(memo)
            memos.sort { $0.createdAt > $1.createdAt }
        }
    }
    
    func deleteMemo(_ memo: Memo) {
        do {
            if playingMemo?.id == memo.id {
                stopPlaying()
            }
            try FileManager.default.removeItem(at: memo.url)
            metadataManager.deleteMetadata(for: memo.url)
            memos.removeAll { $0.id == memo.id }
            
            print("✅ MemoRepository: Deleted memo \(memo.filename)")
        } catch {
            print("❌ MemoRepository: Error deleting memo: \(error)")
        }
    }
    
    func getMemo(by id: UUID) -> Memo? {
        return memos.first { $0.id == id }
    }
    
    func getMemo(by url: URL) -> Memo? {
        return memos.first { $0.url == url }
    }
    
    func handleNewRecording(at url: URL) {
        print("📁 MemoRepository: NEW RECORDING RECEIVED")
        print("📁 MemoRepository: File URL: \(url.lastPathComponent)")
        print("📁 MemoRepository: Full path: \(url.path)")
        
        loadMemos()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            print("📁 MemoRepository: Looking for memo in loaded list...")
            
            if let existingMemo = self.memos.first(where: { $0.url == url }) {
                print("🎯 MemoRepository: Found existing memo in list: \(existingMemo.filename)")
            } else {
                print("❌ MemoRepository: Memo not found in list, creating new one...")
                do {
                    let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
                    let creationDate = resourceValues.creationDate ?? Date()
                    
                    let newMemo = Memo(
                        filename: url.lastPathComponent,
                        url: url,
                        createdAt: creationDate
                    )
                    
                    self.saveMemo(newMemo)
                    print("🎯 MemoRepository: Created and saved new memo for \(newMemo.filename)")
                } catch {
                    print("❌ MemoRepository: Failed to create memo: \(error)")
                }
            }
        }
    }
    
    func updateMemoMetadata(_ memo: Memo, metadata: [String: Any]) {
        print("📝 MemoRepository: Updating metadata for memo \(memo.filename)")
    }
}

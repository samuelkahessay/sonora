import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioRepositoryImpl: ObservableObject, AudioRepository {
    @Published var playingMemo: Memo?
    @Published var isPlaying = false
    
    private var audioPlayer: AVAudioPlayer?
    private var audioPlayerProxy = AudioPlayerProxy()
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    init() {
        setupAudioPlayerProxy()
    }
    
    private func setupAudioPlayerProxy() {
        audioPlayerProxy.onFinish = { [weak self] in
            DispatchQueue.main.async {
                self?.stopAudio()
            }
        }
    }
    
    func loadAudioFiles() -> [Memo] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsPath, 
                includingPropertiesForKeys: [.creationDateKey], 
                options: []
            )
            
            let audioFiles = files.filter { $0.pathExtension == "m4a" }
            var loadedMemos: [Memo] = []
            
            for file in audioFiles {
                let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
                let creationDate = resourceValues.creationDate ?? Date()
                
                let memo = Memo(
                    filename: file.lastPathComponent,
                    url: file,
                    createdAt: creationDate
                )
                loadedMemos.append(memo)
            }
            
            return loadedMemos.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("❌ AudioRepository: Error loading audio files: \(error)")
            return []
        }
    }
    
    func deleteAudioFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
        
        if playingMemo?.url == url {
            stopAudio()
        }
    }
    
    func saveAudioFile(from sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
    
    func getAudioMetadata(for url: URL) throws -> (duration: TimeInterval, creationDate: Date) {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        
        let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
        let creationDate = resourceValues.creationDate ?? Date()
        
        return (duration: duration, creationDate: creationDate)
    }
    
    func playAudio(at url: URL) throws {
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = audioPlayerProxy
        audioPlayer?.play()
        
        if let memo = playingMemo, memo.url == url, isPlaying {
            audioPlayer?.pause()
            isPlaying = false
            return
        }
        
        let playingMemoForURL = Memo(
            filename: url.lastPathComponent,
            url: url,
            createdAt: Date()
        )
        
        playingMemo = playingMemoForURL
        isPlaying = true
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playback, mode: .default)
        try audioSession.setActive(true)
    }
    
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingMemo = nil
        isPlaying = false
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)
    }
    
    func isAudioPlaying(for memo: Memo) -> Bool {
        return playingMemo?.id == memo.id && isPlaying
    }
    
    func getDocumentsDirectory() -> URL {
        return documentsPath
    }
}
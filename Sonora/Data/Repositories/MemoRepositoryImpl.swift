import Foundation
import Combine
import AVFoundation

// MARK: - MemoFileMetadata Structure
struct MemoFileMetadata: Codable {
    let id: String
    let filename: String
    let createdAt: Date
    let audioPath: String // relative path to audio file
    let fileSize: Int64?
    let duration: TimeInterval?
    
    init(memo: Memo, audioPath: String, fileSize: Int64? = nil, duration: TimeInterval? = nil) {
        self.id = memo.id.uuidString
        self.filename = memo.filename
        self.createdAt = memo.createdAt
        self.audioPath = audioPath
        self.fileSize = fileSize
        self.duration = duration
    }
}

// MARK: - MemoIndex Structure
struct MemoIndex: Codable {
    var memos: [String] // Array of memo IDs
    var lastUpdated: Date
    
    init() {
        self.memos = []
        self.lastUpdated = Date()
    }
}

@MainActor
final class MemoRepositoryImpl: ObservableObject, MemoRepository {
    @Published var memos: [Memo] = []
    
    // Playback state
    @Published private(set) var playingMemo: Memo?
    @Published private(set) var isPlaying: Bool = false
    
    private var player: AVAudioPlayer?
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let memosDirectoryPath: URL
    private let indexPath: URL
    private let metadataManager = MemoMetadataManager()
    
    // MARK: - Initialization
    init() {
        self.memosDirectoryPath = documentsPath.appendingPathComponent("Memos")
        self.indexPath = memosDirectoryPath.appendingPathComponent("index.json")
        createDirectoriesIfNeeded()
        loadMemos()
    }
    
    // MARK: - Directory Management
    private func createDirectoriesIfNeeded() {
        do {
            try FileManager.default.createDirectory(at: memosDirectoryPath, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
            print("✅ MemoRepository: Created Memos directory at \(memosDirectoryPath.path)")
        } catch {
            print("❌ MemoRepository: Failed to create Memos directory: \(error)")
        }
    }
    
    private func memoDirectoryPath(for memoId: UUID) -> URL {
        return memosDirectoryPath.appendingPathComponent(memoId.uuidString)
    }
    
    private func audioFilePath(for memoId: UUID) -> URL {
        return memoDirectoryPath(for: memoId).appendingPathComponent("audio.m4a")
    }
    
    private func metadataFilePath(for memoId: UUID) -> URL {
        return memoDirectoryPath(for: memoId).appendingPathComponent("memo.json")
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
    
    // MARK: - Atomic File Operations
    private func atomicWrite<T: Codable>(_ data: T, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        
        let jsonData = try encoder.encode(data)
        try jsonData.write(to: url, options: .atomic)
    }
    
    private func atomicRead<T: Codable>(_ type: T.Type, from url: URL) throws -> T {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MemoRepositoryError.fileNotFound(url.path)
        }
        
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(type, from: data)
    }
    
    private func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // MARK: - Index Management
    private func loadIndex() -> MemoIndex {
        do {
            return try atomicRead(MemoIndex.self, from: indexPath)
        } catch {
            print("📋 MemoRepository: No existing index found, creating new one")
            return MemoIndex()
        }
    }
    
    private func saveIndex(_ index: MemoIndex) {
        do {
            try atomicWrite(index, to: indexPath)
            print("💾 MemoRepository: Index saved with \(index.memos.count) memos")
        } catch {
            print("❌ MemoRepository: Failed to save index: \(error)")
        }
    }
    
    func loadMemos() {
        var loadedMemos: [Memo] = []
        let index = loadIndex()
        
        print("📋 MemoRepository: Loading \(index.memos.count) memos from index")
        
        for memoIdString in index.memos {
            guard let memoId = UUID(uuidString: memoIdString) else {
                print("⚠️ MemoRepository: Invalid memo ID: \(memoIdString)")
                continue
            }
            
            do {
                let metadataPath = metadataFilePath(for: memoId)
                let audioPath = audioFilePath(for: memoId)
                
                // Check if both files exist
                guard fileExists(at: metadataPath), fileExists(at: audioPath) else {
                    print("⚠️ MemoRepository: Missing files for memo \(memoId), skipping")
                    continue
                }
                
                let metadata = try atomicRead(MemoFileMetadata.self, from: metadataPath)
                
                let memo = Memo(
                    filename: metadata.filename,
                    url: audioPath,
                    createdAt: metadata.createdAt
                )
                
                // Verify memo ID matches
                if memo.id.uuidString == metadata.id {
                    loadedMemos.append(memo)
                } else {
                    print("⚠️ MemoRepository: ID mismatch for memo \(metadata.filename)")
                }
                
            } catch {
                print("❌ MemoRepository: Failed to load memo \(memoId): \(error)")
            }
        }
        
        let sortedMemos = loadedMemos.sorted { $0.createdAt > $1.createdAt }
        print("✅ MemoRepository: Successfully loaded \(sortedMemos.count) memos")
        self.memos = sortedMemos
    }
    
    func saveMemo(_ memo: Memo) {
        do {
            let memoDirectoryPath = memoDirectoryPath(for: memo.id)
            let audioDestination = audioFilePath(for: memo.id)
            let metadataPath = metadataFilePath(for: memo.id)
            
            // Create memo directory
            try FileManager.default.createDirectory(at: memoDirectoryPath, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
            
            // Copy audio file if it's not already in the correct location
            if memo.url != audioDestination {
                if fileExists(at: audioDestination) {
                    try FileManager.default.removeItem(at: audioDestination)
                }
                try FileManager.default.copyItem(at: memo.url, to: audioDestination)
                print("📁 MemoRepository: Audio file copied to \(audioDestination.lastPathComponent)")
            }
            
            // Get file size
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioDestination.path)
            let fileSize = fileAttributes[.size] as? Int64
            
            // Get duration
            let asset = AVURLAsset(url: audioDestination)
            let duration = CMTimeGetSeconds(asset.duration)
            
            // Create metadata
            let metadata = MemoFileMetadata(
                memo: memo,
                audioPath: "audio.m4a",
                fileSize: fileSize,
                duration: duration.isFinite ? duration : nil
            )
            
            // Save metadata atomically
            try atomicWrite(metadata, to: metadataPath)
            
            // Update index
            var index = loadIndex()
            if !index.memos.contains(memo.id.uuidString) {
                index.memos.append(memo.id.uuidString)
                index.lastUpdated = Date()
                saveIndex(index)
            }
            
            // Update in-memory list
            if !memos.contains(where: { $0.id == memo.id }) {
                // Create new memo with updated URL
                let savedMemo = Memo(
                    filename: memo.filename,
                    url: audioDestination,
                    createdAt: memo.createdAt
                )
                memos.append(savedMemo)
                memos.sort { $0.createdAt > $1.createdAt }
            }
            
            print("✅ MemoRepository: Successfully saved memo \(memo.filename)")
            
        } catch {
            print("❌ MemoRepository: Failed to save memo \(memo.filename): \(error)")
        }
    }
    
    func deleteMemo(_ memo: Memo) {
        do {
            if playingMemo?.id == memo.id {
                stopPlaying()
            }
            
            let memoDirectory = memoDirectoryPath(for: memo.id)
            
            // Remove entire memo directory
            if fileExists(at: memoDirectory) {
                try FileManager.default.removeItem(at: memoDirectory)
                print("🗑️ MemoRepository: Deleted memo directory for \(memo.filename)")
            }
            
            // Update index
            var index = loadIndex()
            index.memos.removeAll { $0 == memo.id.uuidString }
            index.lastUpdated = Date()
            saveIndex(index)
            
            // Update in-memory list
            memos.removeAll { $0.id == memo.id }
            
            // Clean up old metadata manager entry
            metadataManager.deleteMetadata(for: memo.url)
            
            print("✅ MemoRepository: Successfully deleted memo \(memo.filename)")
            
        } catch {
            print("❌ MemoRepository: Failed to delete memo \(memo.filename): \(error)")
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
        
        // Verify file exists and is accessible
        guard fileExists(at: url) else {
            print("❌ MemoRepository: Recording file does not exist at \(url.path)")
            return
        }
        
        do {
            let resourceValues = try url.resourceValues(forKeys: [.creationDateKey, .fileSizeKey])
            let creationDate = resourceValues.creationDate ?? Date()
            let fileSize = resourceValues.fileSize ?? 0
            
            print("📊 MemoRepository: File size: \(fileSize) bytes")
            
            // Verify file has content
            guard fileSize > 0 else {
                print("⚠️ MemoRepository: Recording file is empty, skipping")
                return
            }
            
            let newMemo = Memo(
                filename: url.lastPathComponent,
                url: url,
                createdAt: creationDate
            )
            
            print("💾 MemoRepository: Saving new recording as memo \(newMemo.filename)")
            saveMemo(newMemo)
            
            print("✅ MemoRepository: Successfully processed new recording")
            
        } catch {
            print("❌ MemoRepository: Failed to process new recording: \(error)")
        }
    }
    
    func updateMemoMetadata(_ memo: Memo, metadata: [String: Any]) {
        do {
            let metadataPath = metadataFilePath(for: memo.id)
            
            // Load existing metadata
            guard fileExists(at: metadataPath) else {
                print("⚠️ MemoRepository: No metadata file found for memo \(memo.filename)")
                return
            }
            
            var existingMetadata = try atomicRead(MemoFileMetadata.self, from: metadataPath)
            
            // Update specific fields if provided
            // For now, we'll just log the update since MemoFileMetadata is a struct
            // In a more complex implementation, we could extend MemoFileMetadata to include additional fields
            
            print("📝 MemoRepository: Metadata update requested for memo \(memo.filename)")
            print("📝 MemoRepository: Update data: \(metadata)")
            
            // Re-save metadata to update lastUpdated timestamp
            try atomicWrite(existingMetadata, to: metadataPath)
            
        } catch {
            print("❌ MemoRepository: Failed to update metadata for memo \(memo.filename): \(error)")
        }
    }
}

// MARK: - Error Types
enum MemoRepositoryError: LocalizedError {
    case fileNotFound(String)
    case invalidMemoData
    case atomicWriteFailed
    case indexCorrupted
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound(let path):
            return "File not found at path: \(path)"
        case .invalidMemoData:
            return "Invalid memo data structure"
        case .atomicWriteFailed:
            return "Failed to write file atomically"
        case .indexCorrupted:
            return "Memo index file is corrupted"
        }
    }
}

import Foundation
import Combine
import AVFoundation
import SwiftData

// Previous file-based metadata/index removed in SwiftData migration

@MainActor
final class MemoRepositoryImpl: ObservableObject, MemoRepository {
    @Published var memos: [Memo] = []
    
    // Playback state
    @Published private(set) var playingMemo: Memo?
    @Published private(set) var isPlaying: Bool = false
    
    // Transcription is handled via dedicated repository and use cases
    private let transcriptionRepository: any TranscriptionRepository
    private let context: ModelContext
    
    private var player: AVAudioPlayer?
    
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private let memosDirectoryPath: URL
    // Legacy sidecar metadata removed with SwiftData migration
    
    // MARK: - Transcription Use Cases
    private let startTranscriptionUseCase: StartTranscriptionUseCaseProtocol
    private let getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol
    private let retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol
    
    // MARK: - Initialization
    init(
        context: ModelContext,
        transcriptionRepository: any TranscriptionRepository,
        startTranscriptionUseCase: StartTranscriptionUseCaseProtocol,
        getTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol,
        retryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol
    ) {
        self.context = context
        self.transcriptionRepository = transcriptionRepository
        self.startTranscriptionUseCase = startTranscriptionUseCase
        self.getTranscriptionStateUseCase = getTranscriptionStateUseCase
        self.retryTranscriptionUseCase = retryTranscriptionUseCase

        self.memosDirectoryPath = documentsPath.appendingPathComponent("Memos")
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
    
    // SwiftData-backed: no sidecar metadata file
    
    // MARK: - Playback
    func playMemo(_ memo: Memo) {
        // Handle pause/resume toggle for same memo
        if playingMemo?.id == memo.id && isPlaying {
            pausePlaying()
            return
        }
        
        // Resume paused memo
        if playingMemo?.id == memo.id && !isPlaying && player != nil {
            player?.play()
            isPlaying = true
            print("▶️ MemoRepository: Resumed \(memo.filename)")
            return
        }
        
        // Stop current if different memo
        if let current = playingMemo, current.id != memo.id {
            stopPlaying()
        }
        
        do {
            let audio = try AVAudioPlayer(contentsOf: memo.fileURL)
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
    
    func pausePlaying() {
        player?.pause()
        isPlaying = false
        print("⏸️ MemoRepository: Paused playback")
    }
    
    func stopPlaying() {
        player?.stop()
        player = nil
        isPlaying = false
        playingMemo = nil
        print("⏹️ MemoRepository: Stopped playback")
    }
    
    // MARK: - File Helpers
    
    private func fileExists(at url: URL) -> Bool {
        return FileManager.default.fileExists(atPath: url.path)
    }
    
    // MARK: - SwiftData Helpers
    private func fetchMemoModel(id: UUID) -> MemoModel? {
        let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    private func mapToDomain(_ model: MemoModel) -> Memo {
        let url = URL(fileURLWithPath: model.audioFilePath)
        // Transcription status is sourced from TranscriptionRepository separately
        let status = mapToDomainStatus(transcriptionRepository.getTranscriptionState(for: model.id))
        return Memo(
            id: model.id,
            filename: model.filename,
            fileURL: url,
            creationDate: model.creationDate,
            transcriptionStatus: status,
            analysisResults: [],
            customTitle: model.customTitle,
            shareableFileName: model.shareableFileName
        )
    }

    private func mapToDomainStatus(_ state: TranscriptionState) -> DomainTranscriptionStatus {
        switch state {
        case .notStarted: return .notStarted
        case .inProgress: return .inProgress
        case .completed(let text): return .completed(text)
        case .failed(let error): return .failed(error)
        }
    }

    private func mapStateStringToTranscriptionState(_ status: String, text: String?) -> TranscriptionState {
        switch status {
        case "completed": return .completed(text ?? "")
        case "inProgress": return .inProgress
        case "failed": return .failed(text ?? "")
        default: return .notStarted
        }
    }
    
    func loadMemos() {
        do {
            let descriptor = FetchDescriptor<MemoModel>(sortBy: [SortDescriptor(\.creationDate, order: .reverse)])
            let models = try context.fetch(descriptor)
            self.memos = models.map(mapToDomain)
            print("✅ MemoRepository: Loaded \(memos.count) memos from SwiftData")
        } catch {
            print("❌ MemoRepository: Failed to fetch memos from SwiftData: \(error)")
            self.memos = []
        }
    }
    
    func saveMemo(_ memo: Memo) {
        do {
            let memoDirectoryPath = memoDirectoryPath(for: memo.id)
            let audioDestination = audioFilePath(for: memo.id)
            
            // Create memo directory
            try FileManager.default.createDirectory(at: memoDirectoryPath, 
                                                   withIntermediateDirectories: true, 
                                                   attributes: nil)
            
            // Copy audio file if it's not already in the correct location
            if memo.fileURL != audioDestination {
                if fileExists(at: audioDestination) {
                    try FileManager.default.removeItem(at: audioDestination)
                }
                try FileManager.default.copyItem(at: memo.fileURL, to: audioDestination)
                print("📁 MemoRepository: Audio file copied to \(audioDestination.lastPathComponent)")
            }
            
            // Get file size
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioDestination.path)
            let fileSize = fileAttributes[.size] as? Int64
            
            // Get duration using AVAudioFile (avoids deprecated AVAsset.duration)
            let duration: TimeInterval = {
                do {
                    let audioFile = try AVAudioFile(forReading: audioDestination)
                    let frames = Double(audioFile.length)
                    let rate = audioFile.fileFormat.sampleRate
                    let secs = frames / rate
                    return secs
                } catch {
                    return 0
                }
            }()
            
            // Upsert SwiftData model
            if let model = fetchMemoModel(id: memo.id) {
                model.filename = memo.filename
                model.audioFilePath = audioDestination.path
                model.customTitle = memo.customTitle
                model.shareableFileName = memo.shareableFileName
                model.duration = duration.isFinite ? duration : nil
                model.creationDate = memo.creationDate
            } else {
                let shareName = memo.customTitle != nil ? FileNameSanitizer.sanitize(memo.customTitle!) : nil
                let model = MemoModel(
                    id: memo.id,
                    creationDate: memo.creationDate,
                    customTitle: memo.customTitle,
                    filename: memo.filename,
                    audioFilePath: audioDestination.path,
                    duration: duration.isFinite ? duration : nil,
                    shareableFileName: shareName
                )
                context.insert(model)
            }
            try context.save()
            
            // Update in-memory list
            if !memos.contains(where: { $0.id == memo.id }) {
                // Create new memo with the same ID and updated URL
                let savedMemo = Memo(
                    id: memo.id,  // Preserve the original ID
                    filename: memo.filename,
                    fileURL: audioDestination,
                    creationDate: memo.creationDate,
                    transcriptionStatus: memo.transcriptionStatus,
                    analysisResults: memo.analysisResults,
                    customTitle: memo.customTitle,
                    shareableFileName: memo.shareableFileName
                )
                memos.append(savedMemo)
                memos.sort { $0.creationDate > $1.creationDate }
                print("📝 MemoRepository: Added memo \(savedMemo.filename) to in-memory list with ID \(savedMemo.id)")
            }
            
            print("✅ MemoRepository: Successfully saved memo \(memo.filename) [SwiftData]")
            
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
            
            // Delete SwiftData model (cascades to related data)
            if let model = fetchMemoModel(id: memo.id) {
                context.delete(model)
                try context.save()
            }
            
            // Update in-memory list
            memos.removeAll { $0.id == memo.id }
            
            // No legacy sidecar metadata to clean up in SwiftData migration
            
            print("✅ MemoRepository: Successfully deleted memo \(memo.filename)")
            
        } catch {
            print("❌ MemoRepository: Failed to delete memo \(memo.filename): \(error)")
        }
    }
    
    func getMemo(by id: UUID) -> Memo? {
        if let model = fetchMemoModel(id: id) { return mapToDomain(model) }
        return nil
    }
    
    func getMemo(by url: URL) -> Memo? {
        let descriptor = FetchDescriptor<MemoModel>(predicate: #Predicate { $0.audioFilePath == url.path })
        if let model = try? context.fetch(descriptor).first { return mapToDomain(model) }
        return nil
    }
    
    func handleNewRecording(at url: URL) {
        print("📁 MemoRepository: 🚨 NEW RECORDING RECEIVED - STARTING AUTO-TRANSCRIPTION FLOW")
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
                fileURL: url,
                creationDate: creationDate
            )
            
            print("💾 MemoRepository: Saving new recording as memo \(newMemo.filename)")
            saveMemo(newMemo)
            
            // 🚀 CRITICAL FIX: Trigger auto-transcription after saving
            print("🚀 MemoRepository: TRIGGERING AUTO-TRANSCRIPTION for \(newMemo.filename)")
            triggerAutoTranscription(for: newMemo)
            
            print("✅ MemoRepository: Successfully processed new recording with auto-transcription")
            
        } catch {
            print("❌ MemoRepository: Failed to process new recording: \(error)")
        }
    }
    
    // MARK: - Auto-transcription
    
    /// Triggers automatic transcription for a newly saved memo
    /// This uses modern Use Case architecture for clean separation of concerns
    private func triggerAutoTranscription(for memo: Memo) {
        Task { @MainActor in
            do {
                print("🎯 MemoRepository: Starting auto-transcription via StartTranscriptionUseCase for \(memo.filename)")
                try await startTranscriptionUseCase.execute(memo: memo)
                print("✅ MemoRepository: Auto-transcription initiated successfully for \(memo.filename)")
                
            } catch {
                print("❌ MemoRepository: Auto-transcription failed for \(memo.filename): \(error)")
                // Don't fail the entire recording process if transcription fails
                // Just log the error and continue
            }
        }
    }
    
    func renameMemo(_ memo: Memo, newTitle: String) {
        let sanitizedTitle = newTitle.isEmpty ? nil : newTitle
        if let model = fetchMemoModel(id: memo.id) {
            model.customTitle = sanitizedTitle
            model.shareableFileName = sanitizedTitle != nil ? FileNameSanitizer.sanitize(sanitizedTitle!) : nil
            do { try context.save() } catch { print("❌ MemoRepository: Failed to rename memo in SwiftData: \(error)") }
        }
        // Update in-memory memo as well
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            let updatedMemo = memos[index].withCustomTitle(sanitizedTitle)
            memos[index] = updatedMemo
            objectWillChange.send()
            let displayText = sanitizedTitle ?? "default"
            let shareableText = sanitizedTitle != nil ? FileNameSanitizer.sanitize(sanitizedTitle!) : "default filename"
            print("✅ MemoRepository: Successfully renamed memo to '\(displayText)' with shareable filename '\(shareableText)'")
        }
    }
    
    func updateMemoMetadata(_ memo: Memo, metadata: [String: Any]) {
        // SwiftData-backed repo: interpret known keys here if needed.
        // For now, log and ignore to maintain signature.
        print("📝 MemoRepository: Metadata update requested (ignored in SwiftData migration) for memo \(memo.filename) — data: \(metadata)")
    }
    
    // MARK: - Transcription Integration (via use cases)
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

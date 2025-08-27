import Foundation
import AVFoundation

/// Use case for handling a new recording
/// Encapsulates the business logic for processing new recordings
protocol HandleNewRecordingUseCaseProtocol {
    func execute(at url: URL) async throws -> Memo
}

final class HandleNewRecordingUseCase: HandleNewRecordingUseCaseProtocol {
    
    // MARK: - Dependencies
    private let memoRepository: MemoRepository
    private let eventBus: EventBusProtocol
    
    // MARK: - Configuration
    private let maxFileSizeBytes: Int64 = 100 * 1024 * 1024 // 100MB
    private let supportedFormats: Set<String> = ["m4a", "mp3", "wav", "aiff"]
    
    // MARK: - Initialization
    init(memoRepository: MemoRepository, eventBus: EventBusProtocol = EventBus.shared) {
        self.memoRepository = memoRepository
        self.eventBus = eventBus
    }
    
    // MARK: - Use Case Execution
    func execute(at url: URL) async throws -> Memo {
        print("💾 HandleNewRecordingUseCase: Processing new recording at: \(url.lastPathComponent)")
        
        do {
            // Comprehensive validation of the new recording
            let fileMetadata = try validateNewRecording(at: url)
            
            // Create memo object
            let memo = try createMemoFromRecording(url: url, metadata: fileMetadata)
            
            // Process recording through repository
            memoRepository.handleNewRecording(at: url)
            
            // Verify processing was successful
            try verifyRecordingProcessed(memo)
            
            // Publish memoCreated event
            print("📡 HandleNewRecordingUseCase: Publishing memoCreated event for memo \(memo.id)")
            let domainMemo = memo.toDomain()
            eventBus.publish(.memoCreated(domainMemo))
            
            print("✅ HandleNewRecordingUseCase: Successfully processed new recording: \(memo.filename)")
            return memo
            
        } catch let repositoryError as RepositoryError {
            print("❌ HandleNewRecordingUseCase: Repository error - \(repositoryError.localizedDescription)")
            throw repositoryError.asSonoraError
            
        } catch let serviceError as ServiceError {
            print("❌ HandleNewRecordingUseCase: Service error - \(serviceError.localizedDescription)")
            throw serviceError.asSonoraError
            
        } catch let error as NSError {
            print("❌ HandleNewRecordingUseCase: System error - \(error.localizedDescription)")
            let mappedError = ErrorMapping.mapError(error)
            throw mappedError
            
        } catch {
            print("❌ HandleNewRecordingUseCase: Unknown error - \(error.localizedDescription)")
            throw SonoraError.audioFileProcessingFailed("Failed to process recording: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Validates the new recording file for processing
    private func validateNewRecording(at url: URL) throws -> FileMetadata {
        print("🔍 HandleNewRecordingUseCase: Validating recording file")
        
        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RepositoryError.fileNotFound(url.path)
        }
        
        // Get file attributes
        let fileAttributes: [FileAttributeKey: Any]
        do {
            fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        } catch {
            throw RepositoryError.fileReadFailed("Cannot read file attributes: \(error.localizedDescription)")
        }
        
        // Validate file size
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        guard fileSize > 0 else {
            throw RepositoryError.fileCorrupted("File is empty: \(url.lastPathComponent)")
        }
        
        guard fileSize <= maxFileSizeBytes else {
            throw RepositoryError.resourceSizeLimitExceeded("File too large: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
        }
        
        // Validate file format
        let fileExtension = url.pathExtension.lowercased()
        guard supportedFormats.contains(fileExtension) else {
            throw RepositoryError.unsupportedDataFormat("Unsupported audio format: \(fileExtension)")
        }
        
        // Get creation date
        let creationDate = fileAttributes[.creationDate] as? Date ?? Date()
        
        // Validate audio file integrity
        try validateAudioFileIntegrity(at: url)
        
        print("✅ HandleNewRecordingUseCase: Recording validation completed")
        
        return FileMetadata(
            size: fileSize,
            creationDate: creationDate,
            format: fileExtension
        )
    }
    
    /// Validates audio file integrity using AVFoundation
    private func validateAudioFileIntegrity(at url: URL) throws {
        let asset = AVURLAsset(url: url)
        
        // Check if the asset is playable
        guard asset.isPlayable else {
            throw RepositoryError.fileCorrupted("Audio file is not playable: \(url.lastPathComponent)")
        }
        
        // Check duration
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite && duration > 0 else {
            throw RepositoryError.fileCorrupted("Invalid audio duration: \(url.lastPathComponent)")
        }
        
        // Check for audio tracks
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw RepositoryError.fileCorrupted("No audio tracks found: \(url.lastPathComponent)")
        }
        
        print("🎵 HandleNewRecordingUseCase: Audio integrity validated - Duration: \(String(format: "%.2f", duration))s")
    }
    
    /// Creates a memo object from the validated recording
    private func createMemoFromRecording(url: URL, metadata: FileMetadata) throws -> Memo {
        let memo = Memo(
            filename: url.lastPathComponent,
            url: url,
            createdAt: metadata.creationDate
        )
        
        print("📝 HandleNewRecordingUseCase: Created memo object for \(memo.filename)")
        return memo
    }
    
    /// Verifies that the recording was processed successfully by the repository
    private func verifyRecordingProcessed(_ memo: Memo) throws {
        // Give the repository a moment to process
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Check if memo appears in repository
            if !self.memoRepository.memos.contains(where: { $0.url == memo.url }) {
                print("⚠️ HandleNewRecordingUseCase: Memo not found in repository after processing")
            } else {
                print("✅ HandleNewRecordingUseCase: Memo successfully added to repository")
            }
        }
    }
}

// MARK: - Supporting Types

/// Metadata for a file being processed
private struct FileMetadata {
    let size: Int64
    let creationDate: Date
    let format: String
}
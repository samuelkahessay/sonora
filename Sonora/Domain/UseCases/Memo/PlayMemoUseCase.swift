import Foundation
import AVFoundation

/// Use case for playing a memo
/// Encapsulates the business logic for memo playback
protocol PlayMemoUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class PlayMemoUseCase: PlayMemoUseCaseProtocol {
    
    // MARK: - Dependencies
    private let memoRepository: MemoRepository
    
    // MARK: - Initialization
    init(memoRepository: MemoRepository) {
        self.memoRepository = memoRepository
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        print("▶️ PlayMemoUseCase: Starting playback for memo: \(memo.filename)")
        
        do {
            // Validate memo exists in repository
            try validateMemoExists(memo)
            
            // Validate file system state
            try validateFileSystemState(memo)
            
            // Validate audio file integrity
            try validateAudioFile(memo)
            
            // Execute playback via repository
            memoRepository.playMemo(memo)
            
            // Verify playback started successfully
            try verifyPlaybackStarted(memo)
            
            print("✅ PlayMemoUseCase: Successfully initiated playback for memo: \(memo.filename)")
            
        } catch let repositoryError as RepositoryError {
            print("❌ PlayMemoUseCase: Repository error - \(repositoryError.localizedDescription)")
            throw repositoryError.asSonoraError
            
        } catch let serviceError as ServiceError {
            print("❌ PlayMemoUseCase: Service error - \(serviceError.localizedDescription)")
            throw serviceError.asSonoraError
            
        } catch let error as NSError {
            print("❌ PlayMemoUseCase: System error - \(error.localizedDescription)")
            let mappedError = ErrorMapping.mapError(error)
            throw mappedError
            
        } catch {
            print("❌ PlayMemoUseCase: Unknown error - \(error.localizedDescription)")
            throw SonoraError.audioRecordingFailed("Failed to play memo: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Validates that the memo exists in the repository
    private func validateMemoExists(_ memo: Memo) throws {
        guard memoRepository.memos.contains(where: { $0.id == memo.id }) else {
            print("⚠️ PlayMemoUseCase: Memo not found in repository: \(memo.filename)")
            throw RepositoryError.resourceNotFound("Memo with ID \(memo.id) not found")
        }
        
        print("🔍 PlayMemoUseCase: Memo validated and found in repository")
    }
    
    /// Validates file system state before attempting playback
    private func validateFileSystemState(_ memo: Memo) throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: memo.url.path) else {
            print("⚠️ PlayMemoUseCase: Audio file not found: \(memo.url.path)")
            throw RepositoryError.fileNotFound(memo.url.path)
        }
        
        // Check if file is readable
        guard FileManager.default.isReadableFile(atPath: memo.url.path) else {
            throw RepositoryError.permissionDenied("Cannot read audio file: \(memo.url.path)")
        }
        
        // Check file size
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: memo.url.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            guard fileSize > 0 else {
                throw RepositoryError.fileCorrupted("Audio file is empty: \(memo.filename)")
            }
            
            print("🔍 PlayMemoUseCase: File system validation completed - Size: \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))")
            
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.fileReadFailed("Cannot read file attributes: \(error.localizedDescription)")
        }
    }
    
    /// Validates audio file integrity before playback
    private func validateAudioFile(_ memo: Memo) throws {
        let asset = AVURLAsset(url: memo.url)
        
        // Check if the asset is playable
        guard asset.isPlayable else {
            throw RepositoryError.fileCorrupted("Audio file is not playable: \(memo.filename)")
        }
        
        // Check duration
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite && duration > 0 else {
            throw RepositoryError.fileCorrupted("Invalid audio duration: \(memo.filename)")
        }
        
        // Check for audio tracks
        let audioTracks = asset.tracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw RepositoryError.fileCorrupted("No audio tracks found: \(memo.filename)")
        }
        
        print("🎵 PlayMemoUseCase: Audio integrity validated - Duration: \(String(format: "%.2f", duration))s, Tracks: \(audioTracks.count)")
    }
    
    /// Verifies that playback started successfully
    private func verifyPlaybackStarted(_ memo: Memo) throws {
        // Give a brief moment for playback to initialize
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if self.memoRepository.playingMemo?.id == memo.id && self.memoRepository.isPlaying {
                print("✅ PlayMemoUseCase: Playback verification successful")
            } else {
                print("⚠️ PlayMemoUseCase: Playback may not have started correctly")
            }
        }
    }
}
import Foundation

/// Use case for deleting a memo
/// Encapsulates the business logic for memo deletion
protocol DeleteMemoUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class DeleteMemoUseCase: DeleteMemoUseCaseProtocol {
    
    // MARK: - Dependencies
    private let memoRepository: MemoRepository
    
    // MARK: - Initialization
    init(memoRepository: MemoRepository) {
        self.memoRepository = memoRepository
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        print("🗑️ DeleteMemoUseCase: Starting deletion of memo: \(memo.filename)")
        
        do {
            // Validate memo exists in repository
            try validateMemoExists(memo)
            
            // Check if memo is currently playing and stop if needed
            try handlePlaybackIfNeeded(memo)
            
            // Validate file system state before deletion
            try validateFileSystemState(memo)
            
            // Delete memo from repository
            memoRepository.deleteMemo(memo)
            
            // Verify deletion was successful
            try verifyDeletion(memo)
            
            print("✅ DeleteMemoUseCase: Successfully deleted memo: \(memo.filename)")
            
        } catch let repositoryError as RepositoryError {
            print("❌ DeleteMemoUseCase: Repository error - \(repositoryError.localizedDescription)")
            throw repositoryError.asSonoraError
            
        } catch let serviceError as ServiceError {
            print("❌ DeleteMemoUseCase: Service error - \(serviceError.localizedDescription)")
            throw serviceError.asSonoraError
            
        } catch let error as NSError {
            print("❌ DeleteMemoUseCase: System error - \(error.localizedDescription)")
            let mappedError = ErrorMapping.mapError(error)
            throw mappedError
            
        } catch {
            print("❌ DeleteMemoUseCase: Unknown error - \(error.localizedDescription)")
            throw SonoraError.storageDeleteFailed("Failed to delete memo: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Validates that the memo exists in the repository
    private func validateMemoExists(_ memo: Memo) throws {
        guard memoRepository.memos.contains(where: { $0.id == memo.id }) else {
            print("⚠️ DeleteMemoUseCase: Memo not found in repository: \(memo.filename)")
            throw RepositoryError.resourceNotFound("Memo with ID \(memo.id) not found")
        }
        
        print("🔍 DeleteMemoUseCase: Memo validated and found in repository")
    }
    
    /// Handles playback state if the memo is currently playing
    private func handlePlaybackIfNeeded(_ memo: Memo) throws {
        if memoRepository.playingMemo?.id == memo.id && memoRepository.isPlaying {
            print("⏸️ DeleteMemoUseCase: Stopping playback before deletion")
            
            do {
                memoRepository.stopPlaying()
                print("✅ DeleteMemoUseCase: Playback stopped successfully")
            } catch {
                throw ServiceError.audioPlaybackFailed("Failed to stop playback before deletion")
            }
        }
    }
    
    /// Validates file system state before attempting deletion
    private func validateFileSystemState(_ memo: Memo) throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: memo.url.path) else {
            print("⚠️ DeleteMemoUseCase: File already missing: \(memo.url.path)")
            // This is not necessarily an error - file might have been deleted externally
            return
        }
        
        // Check if file is writable (can be deleted)
        guard FileManager.default.isDeletableFile(atPath: memo.url.path) else {
            throw RepositoryError.permissionDenied("Cannot delete file: \(memo.url.path)")
        }
        
        print("🔍 DeleteMemoUseCase: File system state validated for deletion")
    }
    
    /// Verifies that the deletion was successful
    private func verifyDeletion(_ memo: Memo) throws {
        // Check that memo is no longer in repository
        if memoRepository.memos.contains(where: { $0.id == memo.id }) {
            throw RepositoryError.resourceAlreadyExists("Memo still exists in repository after deletion")
        }
        
        // Check that file no longer exists
        if FileManager.default.fileExists(atPath: memo.url.path) {
            throw RepositoryError.fileDeletionFailed("File still exists after deletion: \(memo.url.path)")
        }
        
        print("✅ DeleteMemoUseCase: Deletion verification completed successfully")
    }
}
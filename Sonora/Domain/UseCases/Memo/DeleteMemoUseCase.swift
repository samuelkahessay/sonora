import Foundation

/// Use case for deleting a memo
/// Encapsulates the business logic for memo deletion
protocol DeleteMemoUseCaseProtocol {
    func execute(memo: Memo) async throws
}

final class DeleteMemoUseCase: DeleteMemoUseCaseProtocol {
    
    // MARK: - Dependencies
    private let memoRepository: any MemoRepository
    private let analysisRepository: any AnalysisRepository
    private let transcriptionRepository: any TranscriptionRepository
    private let logger: any LoggerProtocol
    
    // MARK: - Initialization
    init(
        memoRepository: any MemoRepository,
        analysisRepository: any AnalysisRepository,
        transcriptionRepository: any TranscriptionRepository,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.memoRepository = memoRepository
        self.analysisRepository = analysisRepository
        self.transcriptionRepository = transcriptionRepository
        self.logger = logger
    }
    
    // MARK: - Convenience Initializer (for backward compatibility)
    @MainActor
    convenience init(memoRepository: any MemoRepository) {
        let container = DIContainer.shared
        self.init(
            memoRepository: memoRepository,
            analysisRepository: container.analysisRepository(),
            transcriptionRepository: container.transcriptionRepository(),
            logger: container.logger()
        )
    }
    
    // MARK: - Use Case Execution
    func execute(memo: Memo) async throws {
        let correlationId = UUID().uuidString
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "memoId": memo.id.uuidString,
            "filename": memo.filename
        ])
        
        logger.useCase("Starting memo deletion with cascading cleanup", context: context)
        
        do {
            // Validate memo exists in repository
            try await validateMemoExists(memo)
            
            // Check if memo is currently playing and stop if needed
            try await handlePlaybackIfNeeded(memo)
            
            // Validate file system state before deletion
            try validateFileSystemState(memo)
            
            // CRITICAL: Delete all analysis and transcription first (cascading deletion)
            await deleteAnalysisResults(for: memo, correlationId: correlationId)
            await deleteTranscription(for: memo, correlationId: correlationId)
            
            // Delete memo from repository
            await memoRepository.deleteMemo(memo)
            logger.useCase("Memo deleted from repository", 
                         context: LogContext(correlationId: correlationId, additionalInfo: ["memoId": memo.id.uuidString]))
            
            // Verify deletion was successful
            try await verifyDeletion(memo)

            logger.useCase("Memo deletion completed successfully", 
                         level: .info,
                         context: LogContext(correlationId: correlationId, additionalInfo: [
                             "memoId": memo.id.uuidString,
                             "filename": memo.filename,
                             "analysisCleanup": true
                         ]))

            // Update Spotlight index (best-effort)
            Task.detached(priority: .background) {
                await DIContainer.shared.spotlightIndexer().delete(memoID: memo.id)
            }
            
        } catch let repositoryError as RepositoryError {
            logger.error("DeleteMemoUseCase repository error", 
                       category: .useCase, 
                       context: context, 
                       error: repositoryError)
            throw repositoryError.asSonoraError
            
        } catch let serviceError as ServiceError {
            logger.error("DeleteMemoUseCase service error", 
                       category: .useCase, 
                       context: context, 
                       error: serviceError)
            throw serviceError.asSonoraError
            
        } catch let error as NSError {
            logger.error("DeleteMemoUseCase system error", 
                       category: .useCase, 
                       context: context, 
                       error: error)
            let mappedError = ErrorMapping.mapError(error)
            throw mappedError
            
        } catch {
            logger.error("DeleteMemoUseCase unknown error", 
                       category: .useCase, 
                       context: context, 
                       error: error)
            throw SonoraError.storageDeleteFailed("Failed to delete memo: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Validates that the memo exists in the repository
    @MainActor
    private func validateMemoExists(_ memo: Memo) throws {
        guard memoRepository.memos.contains(where: { $0.id == memo.id }) else {
            print("⚠️ DeleteMemoUseCase: Memo not found in repository: \(memo.filename)")
            throw RepositoryError.resourceNotFound("Memo with ID \(memo.id) not found")
        }
        
        print("🔍 DeleteMemoUseCase: Memo validated and found in repository")
    }
    
    /// Handles playback state if the memo is currently playing
    @MainActor
    private func handlePlaybackIfNeeded(_ memo: Memo) throws {
        if memoRepository.playingMemo?.id == memo.id && memoRepository.isPlaying {
            print("⏸️ DeleteMemoUseCase: Stopping playback before deletion")
            
            memoRepository.stopPlaying()
            print("✅ DeleteMemoUseCase: Playback stopped successfully")
        }
    }
    
    /// Validates file system state before attempting deletion
    private func validateFileSystemState(_ memo: Memo) throws {
        // Check if file exists
        guard FileManager.default.fileExists(atPath: memo.fileURL.path) else {
            print("⚠️ DeleteMemoUseCase: File already missing: \(memo.fileURL.path)")
            // This is not necessarily an error - file might have been deleted externally
            return
        }
        
        // Check if file is writable (can be deleted)
        guard FileManager.default.isDeletableFile(atPath: memo.fileURL.path) else {
            throw RepositoryError.permissionDenied("Cannot delete file: \(memo.fileURL.path)")
        }
        
        print("🔍 DeleteMemoUseCase: File system state validated for deletion")
    }
    
    /// Verifies that the deletion was successful
    @MainActor
    private func verifyDeletion(_ memo: Memo) throws {
        // Check that memo is no longer in repository
        if memoRepository.memos.contains(where: { $0.id == memo.id }) {
            throw RepositoryError.resourceAlreadyExists("Memo still exists in repository after deletion")
        }
        
        // Check that file no longer exists
        if FileManager.default.fileExists(atPath: memo.fileURL.path) {
            throw RepositoryError.fileDeletionFailed("File still exists after deletion: \(memo.fileURL.path)")
        }
        
        logger.useCase("Deletion verification completed successfully", 
                     context: LogContext(additionalInfo: ["memoId": memo.id.uuidString]))
    }
    
    /// Delete all analysis results for the memo (cascading deletion)
    private func deleteAnalysisResults(for memo: Memo, correlationId: String) async {
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "memoId": memo.id.uuidString,
            "operation": "cascading_analysis_deletion"
        ])
        
        logger.useCase("Starting cascading analysis deletion", context: context)
        
        await MainActor.run {
            let analysisResults = analysisRepository.getAllAnalysisResults(for: memo.id)
            let analysisCount = analysisResults.count
            
            if analysisCount > 0 {
                logger.useCase("Found \(analysisCount) analysis results to delete", 
                             context: LogContext(correlationId: correlationId, additionalInfo: [
                                 "memoId": memo.id.uuidString,
                                 "analysisCount": analysisCount,
                                 "modes": analysisResults.keys.map { $0.rawValue }
                             ]))
                
                analysisRepository.deleteAnalysisResults(for: memo.id)
                
                logger.useCase("Cascading analysis deletion completed", 
                             level: .info,
                             context: LogContext(correlationId: correlationId, additionalInfo: [
                                 "memoId": memo.id.uuidString,
                                 "deletedAnalysisCount": analysisCount
                             ]))
            } else {
                logger.debug("No analysis results found for memo", category: .useCase, 
                           context: LogContext(correlationId: correlationId, additionalInfo: ["memoId": memo.id.uuidString]))
            }
        }
    }
}

extension DeleteMemoUseCase {
    /// Delete transcription data for the memo
    private func deleteTranscription(for memo: Memo, correlationId: String) async {
        let context = LogContext(correlationId: correlationId, additionalInfo: [
            "memoId": memo.id.uuidString,
            "operation": "cascading_transcription_deletion"
        ])

        logger.useCase("Starting cascading transcription deletion", context: context)

        await MainActor.run {
            transcriptionRepository.deleteTranscriptionData(for: memo.id)
            logger.useCase("Cascading transcription deletion completed", level: .info, context: context)
        }
    }
}

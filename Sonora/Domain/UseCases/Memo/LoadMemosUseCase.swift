import Foundation

/// Use case for loading memos from storage
/// Encapsulates the business logic for memo retrieval
protocol LoadMemosUseCaseProtocol {
    func execute() async throws -> [Memo]
}

final class LoadMemosUseCase: LoadMemosUseCaseProtocol {
    
    // MARK: - Dependencies
    private let memoRepository: MemoRepository
    
    // MARK: - Initialization
    init(memoRepository: MemoRepository) {
        self.memoRepository = memoRepository
    }
    
    // MARK: - Use Case Execution
    func execute() async throws -> [Memo] {
        print("📂 LoadMemosUseCase: Starting memo loading operation")
        
        do {
            // Load memos from repository
            memoRepository.loadMemos()
            
            let loadedMemos = memoRepository.memos
            print("📂 LoadMemosUseCase: Successfully loaded \(loadedMemos.count) memos")
            
            // Validate loaded data
            try validateLoadedMemos(loadedMemos)
            
            return loadedMemos
            
        } catch let repositoryError as RepositoryError {
            print("❌ LoadMemosUseCase: Repository error - \(repositoryError.localizedDescription)")
            throw repositoryError.asSonoraError
            
        } catch let error as NSError {
            print("❌ LoadMemosUseCase: System error - \(error.localizedDescription)")
            let mappedError = ErrorMapping.mapError(error)
            throw mappedError
            
        } catch {
            print("❌ LoadMemosUseCase: Unknown error - \(error.localizedDescription)")
            throw SonoraError.storageReadFailed("Failed to load memos: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Validates the loaded memos for consistency and integrity
    private func validateLoadedMemos(_ memos: [Memo]) throws {
        print("🔍 LoadMemosUseCase: Validating \(memos.count) loaded memos")
        
        // Check for duplicate IDs
        let uniqueIds = Set(memos.map { $0.id })
        guard uniqueIds.count == memos.count else {
            throw RepositoryError.duplicateEntry("Duplicate memo IDs detected")
        }
        
        // Validate file existence for each memo
        for memo in memos {
            guard FileManager.default.fileExists(atPath: memo.url.path) else {
                print("⚠️ LoadMemosUseCase: Missing file for memo \(memo.filename)")
                throw RepositoryError.fileNotFound(memo.url.path)
            }
        }
        
        print("✅ LoadMemosUseCase: All loaded memos validated successfully")
    }
}
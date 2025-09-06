import Foundation

/// Use case for loading memos from storage
/// Encapsulates the business logic for memo retrieval
protocol LoadMemosUseCaseProtocol: Sendable {
    func execute() async throws -> [Memo]
}

final class LoadMemosUseCase: LoadMemosUseCaseProtocol, @unchecked Sendable {
    
    // MARK: - Dependencies
    private let memoRepository: any MemoRepository
    
    // MARK: - Initialization
    init(memoRepository: any MemoRepository) {
        self.memoRepository = memoRepository
    }
    
    // MARK: - Use Case Execution
    @MainActor
    func execute() async throws -> [Memo] {
        print("📂 LoadMemosUseCase: Starting memo loading operation")
        
        // Load memos from repository (repository filters orphans and cleans up in background)
        memoRepository.loadMemos()
        
        let loadedMemos = memoRepository.memos
        print("📂 LoadMemosUseCase: Successfully loaded \(loadedMemos.count) memos")
        
        // Soft-validate without throwing
        validateLoadedMemos(loadedMemos)
        
        return loadedMemos
    }
    
    // MARK: - Private Methods
    
    /// Validates the loaded memos for consistency and integrity (non-fatal)
    private func validateLoadedMemos(_ memos: [Memo]) {
        print("🔍 LoadMemosUseCase: Validating \(memos.count) loaded memos")
        
        // Check for duplicate IDs and log (do not throw - degrade gracefully)
        let ids = memos.map { $0.id }
        let uniqueIds = Set(ids)
        if uniqueIds.count != ids.count {
            let duplicates = ids.reduce(into: [UUID: Int]()) { $0[$1, default: 0] += 1 }
                .filter { $0.value > 1 }
                .map { $0.key }
            print("⚠️ LoadMemosUseCase: Duplicate memo IDs detected (\(duplicates.count)) — continuing")
        }
        
        // Log any missing files (repository should have filtered most already)
        let missing = memos.filter { !FileManager.default.fileExists(atPath: $0.fileURL.path) }
        if !missing.isEmpty {
            print("⚠️ LoadMemosUseCase: Missing files for \(missing.count) memos — they will be ignored in UI")
        }
        
        print("✅ LoadMemosUseCase: Validation completed without critical errors")
    }
}

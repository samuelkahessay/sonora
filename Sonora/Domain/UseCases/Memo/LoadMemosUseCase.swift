import Foundation

/// Use case for loading memos from storage
/// Encapsulates the business logic for memo retrieval
protocol LoadMemosUseCaseProtocol {
    func execute() async throws
}

final class LoadMemosUseCase: LoadMemosUseCaseProtocol {
    
    // MARK: - Dependencies
    private let memoRepository: MemoRepository
    
    // MARK: - Initialization
    init(memoRepository: MemoRepository) {
        self.memoRepository = memoRepository
    }
    
    // MARK: - Use Case Execution
    func execute() async throws {
        print("📂 LoadMemosUseCase: Loading memos from storage")
        
        // Load memos from repository
        memoRepository.loadMemos()
        
        print("📂 LoadMemosUseCase: Successfully loaded \(memoRepository.memos.count) memos")
    }
}
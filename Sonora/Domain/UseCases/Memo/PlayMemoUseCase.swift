import Foundation

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
        // Validate memo exists
        guard memoRepository.memos.contains(where: { $0.id == memo.id }) else {
            throw MemoError.memoNotFound
        }
        
        // Check if file exists
        guard FileManager.default.fileExists(atPath: memo.url.path) else {
            throw MemoError.fileSystemError
        }
        
        print("▶️ PlayMemoUseCase: Playing memo: \(memo.filename)")
        
        // Play memo via repository
        memoRepository.playMemo(memo)
        
        print("▶️ PlayMemoUseCase: Playback initiated for memo: \(memo.filename)")
    }
}
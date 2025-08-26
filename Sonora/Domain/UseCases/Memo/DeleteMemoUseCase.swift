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
        // Validate memo exists
        guard memoRepository.memos.contains(where: { $0.id == memo.id }) else {
            throw MemoError.memoNotFound
        }
        
        // Check if memo is currently playing
        if memoRepository.playingMemo?.id == memo.id && memoRepository.isPlaying {
            // Stop playback first
            memoRepository.stopPlaying()
        }
        
        print("🗑️ DeleteMemoUseCase: Deleting memo: \(memo.filename)")
        
        // Delete memo from repository
        memoRepository.deleteMemo(memo)
        
        print("🗑️ DeleteMemoUseCase: Successfully deleted memo: \(memo.filename)")
    }
}

// MARK: - Memo Errors
enum MemoError: LocalizedError {
    case memoNotFound
    case fileSystemError
    case playbackError(String)
    case invalidMemoState
    
    var errorDescription: String? {
        switch self {
        case .memoNotFound:
            return "Memo not found"
        case .fileSystemError:
            return "File system error occurred"
        case .playbackError(let message):
            return "Playback error: \(message)"
        case .invalidMemoState:
            return "Invalid memo state"
        }
    }
}
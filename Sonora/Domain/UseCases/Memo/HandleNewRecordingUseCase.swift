import Foundation

/// Use case for handling a new recording
/// Encapsulates the business logic for processing new recordings
protocol HandleNewRecordingUseCaseProtocol {
    func execute(at url: URL) async throws
}

final class HandleNewRecordingUseCase: HandleNewRecordingUseCaseProtocol {
    
    // MARK: - Dependencies
    private let memoRepository: MemoRepository
    
    // MARK: - Initialization
    init(memoRepository: MemoRepository) {
        self.memoRepository = memoRepository
    }
    
    // MARK: - Use Case Execution
    func execute(at url: URL) async throws {
        // Validate file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MemoError.fileSystemError
        }
        
        // Validate file size
        let fileSize = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard fileSize > 0 else {
            throw MemoError.invalidMemoState
        }
        
        print("💾 HandleNewRecordingUseCase: Processing new recording at: \(url.lastPathComponent)")
        
        // Handle new recording via repository
        memoRepository.handleNewRecording(at: url)
        
        print("💾 HandleNewRecordingUseCase: Successfully processed new recording")
    }
}
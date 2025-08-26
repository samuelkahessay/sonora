import Foundation

/// Use case for stopping audio recording
/// Encapsulates the business logic for stopping recording sessions with background support
protocol StopRecordingUseCaseProtocol {
    func execute() throws
}

final class StopRecordingUseCase: StopRecordingUseCaseProtocol {
    
    // MARK: - Dependencies
    private let audioRepository: AudioRepository
    
    // MARK: - Initialization
    init(audioRepository: AudioRepository) {
        self.audioRepository = audioRepository
    }
    
    // MARK: - Convenience Initializer (for backward compatibility)
    convenience init(audioRecordingService: AudioRecordingService) {
        // Create a wrapper that implements AudioRepository protocol
        self.init(audioRepository: AudioRecordingServiceWrapper(service: audioRecordingService))
    }
    
    // MARK: - Use Case Execution
    func execute() throws {
        print("🛑 StopRecordingUseCase: Stopping recording")
        
        // Check if AudioRepository supports recording
        if let audioRepoImpl = audioRepository as? AudioRepositoryImpl {
            Task { @MainActor in
                guard audioRepoImpl.isRecording else {
                    print("⚠️ StopRecordingUseCase: No recording in progress")
                    return
                }
                
                // Stop background recording
                audioRepoImpl.stopRecording()
                print("🛑 StopRecordingUseCase: Background recording stopped successfully")
            }
        } else if let wrapper = audioRepository as? AudioRecordingServiceWrapper {
            // Use legacy AudioRecordingService
            let service = wrapper.service
            
            guard service.isRecording else {
                throw RecordingError.notRecording
            }
            
            service.stopRecording()
            print("🛑 StopRecordingUseCase: Recording stopped successfully (legacy)")
        } else {
            throw RecordingError.backgroundRecordingNotSupported
        }
    }
}


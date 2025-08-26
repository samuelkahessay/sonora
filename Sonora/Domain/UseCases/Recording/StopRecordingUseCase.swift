import Foundation

/// Use case for stopping audio recording
/// Encapsulates the business logic for stopping recording sessions
protocol StopRecordingUseCaseProtocol {
    func execute() throws
}

final class StopRecordingUseCase: StopRecordingUseCaseProtocol {
    
    // MARK: - Dependencies
    private let audioRecordingService: AudioRecordingService
    
    // MARK: - Initialization
    init(audioRecordingService: AudioRecordingService) {
        self.audioRecordingService = audioRecordingService
    }
    
    // MARK: - Use Case Execution
    func execute() throws {
        // Check if currently recording
        guard audioRecordingService.isRecording else {
            throw RecordingError.notRecording
        }
        
        // Stop recording
        audioRecordingService.stopRecording()
        
        print("🛑 StopRecordingUseCase: Recording stopped successfully")
    }
}


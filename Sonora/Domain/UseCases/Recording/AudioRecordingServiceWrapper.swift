//
//  AudioRecordingServiceWrapper.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-01-26.
//

import Foundation

// MARK: - AudioRecordingServiceWrapper

/// Temporary wrapper to make AudioRecordingService compatible with AudioRepository protocol
/// This maintains backward compatibility while transitioning to enhanced AudioRepository
final class AudioRecordingServiceWrapper: AudioRepository {
    let service: AudioRecordingService
    
    @Published var playingMemo: Memo?
    @Published var isPlaying = false
    
    init(service: AudioRecordingService) {
        self.service = service
    }
    
    // MARK: - Recording State Properties (delegate to wrapped service)
    var isRecording: Bool { service.isRecording }
    var recordingTime: TimeInterval { service.recordingTime }
    var hasMicrophonePermission: Bool { service.hasPermission }
    var isBackgroundTaskActive: Bool { false } // Not available in legacy service
    
    // MARK: - Recording Control Methods
    func startRecording() async throws -> UUID {
        let memoId = UUID()
        service.startRecording()
        return memoId
    }
    
    func stopRecording() {
        service.stopRecording()
    }
    
    func checkMicrophonePermissions() {
        service.checkPermissions()
    }
    
    // MARK: - Recording Callbacks
    func setRecordingFinishedHandler(_ handler: @escaping (URL) -> Void) {
        service.onRecordingFinished = handler
    }
    
    func setRecordingFailedHandler(_ handler: @escaping (Error) -> Void) {
        // Legacy AudioRecordingService doesn't support failure callbacks - stub implementation
        // This is acceptable during the transition period
    }
    
    // MARK: - AudioRepository methods - minimal implementation for compatibility
    func loadAudioFiles() -> [Memo] { return [] }
    func deleteAudioFile(at url: URL) throws {}
    func saveAudioFile(from sourceURL: URL, to destinationURL: URL) throws {}
    func getAudioMetadata(for url: URL) throws -> (duration: TimeInterval, creationDate: Date) {
        return (0, Date())
    }
    func playAudio(at url: URL) throws {}
    func pauseAudio() {}
    func stopAudio() {}
    func isAudioPlaying(for memo: Memo) -> Bool { return false }
    func getDocumentsDirectory() -> URL {
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}

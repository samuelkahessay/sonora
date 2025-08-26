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
    
    // AudioRepository methods - minimal implementation for compatibility
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

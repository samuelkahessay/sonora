//
//  AudioPlaybackService.swift
//  Sonora
//
//  Audio playback service for memo playback
//  Handles AVAudioPlayer management and playback controls
//

import Foundation
import AVFoundation
import Combine

/// Protocol defining audio playback operations
@MainActor
protocol AudioPlaybackServiceProtocol: ObservableObject {
    var isPlaying: Bool { get }
    var currentPlaybackURL: URL? { get }
    var playbackProgress: TimeInterval { get }
    var playbackDuration: TimeInterval { get }
    
    var isPlayingPublisher: AnyPublisher<Bool, Never> { get }
    var playbackProgressPublisher: AnyPublisher<TimeInterval, Never> { get }
    
    func playAudio(at url: URL) throws
    func pauseAudio()
    func stopAudio()
    func isAudioPlaying(for url: URL) -> Bool
    
    // Callbacks
    var onPlaybackFinished: (() -> Void)? { get set }
    var onPlaybackError: ((Error) -> Void)? { get set }
}

/// Focused service for audio playback functionality
@MainActor
final class AudioPlaybackService: NSObject, AudioPlaybackServiceProtocol, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var isPlaying = false
    @Published var currentPlaybackURL: URL?
    @Published var playbackProgress: TimeInterval = 0
    @Published var playbackDuration: TimeInterval = 0
    
    // MARK: - Publishers
    var isPlayingPublisher: AnyPublisher<Bool, Never> {
        $isPlaying.eraseToAnyPublisher()
    }
    
    var playbackProgressPublisher: AnyPublisher<TimeInterval, Never> {
        $playbackProgress.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?
    
    // MARK: - Callbacks
    var onPlaybackFinished: (() -> Void)?
    var onPlaybackError: ((Error) -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        print("🔊 AudioPlaybackService: Initialized")
    }
    
    deinit {
        // Note: We don't perform cleanup in deinit due to Swift 6 concurrency requirements.
        // The system will handle cleanup of timers and delegates when the service is deallocated.
        print("🔊 AudioPlaybackService: Deinitialized")
    }
    
    // MARK: - Public Interface
    
    /// Plays audio from the specified URL
    func playAudio(at url: URL) throws {
        // Stop any current playback
        stopAudio()
        
        // Configure audio session for playback
        try configurePlaybackSession()
        
        // Create and configure audio player
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.enableRate = true
            player.prepareToPlay()
            
            self.audioPlayer = player
            self.currentPlaybackURL = url
            self.playbackDuration = player.duration
            self.playbackProgress = 0
            
        } catch {
            throw AudioPlaybackError.playerCreationFailed(error)
        }
        
        // Start playback
        guard let player = audioPlayer, player.play() else {
            throw AudioPlaybackError.playbackStartFailed
        }
        
        self.isPlaying = true
        startProgressTimer()
        
        print("🔊 AudioPlaybackService: Started playing \(url.lastPathComponent)")
    }
    
    /// Pauses the current audio playback
    func pauseAudio() {
        guard let player = audioPlayer, player.isPlaying else {
            print("⚠️ AudioPlaybackService: Cannot pause - no active playback")
            return
        }
        
        player.pause()
        self.isPlaying = false
        stopProgressTimer()
        
        print("🔊 AudioPlaybackService: Playback paused")
    }
    
    /// Stops the current audio playback
    func stopAudio() {
        guard audioPlayer != nil else { return }
        
        audioPlayer?.stop()
        cleanup()
        
        print("🔊 AudioPlaybackService: Playback stopped")
    }
    
    /// Checks if audio is currently playing for the specified URL
    func isAudioPlaying(for url: URL) -> Bool {
        return isPlaying && currentPlaybackURL == url
    }
    
    /// Resumes playback if paused
    func resumeAudio() throws {
        guard let player = audioPlayer, !player.isPlaying else {
            throw AudioPlaybackError.noPlaybackToResume
        }
        
        guard player.play() else {
            throw AudioPlaybackError.playbackStartFailed
        }
        
        self.isPlaying = true
        startProgressTimer()
        
        print("🔊 AudioPlaybackService: Playback resumed")
    }
    
    /// Seeks to a specific time in the current audio
    func seek(to time: TimeInterval) throws {
        guard let player = audioPlayer else {
            throw AudioPlaybackError.noActivePlayer
        }
        
        let seekTime = max(0, min(time, player.duration))
        player.currentTime = seekTime
        self.playbackProgress = seekTime
        
        print("🔊 AudioPlaybackService: Seeked to \(seekTime) seconds")
    }
    
    /// Sets the playback rate (0.5 to 2.0)
    func setPlaybackRate(_ rate: Float) throws {
        guard let player = audioPlayer else {
            throw AudioPlaybackError.noActivePlayer
        }
        
        let clampedRate = max(0.5, min(2.0, rate))
        player.rate = clampedRate
        
        print("🔊 AudioPlaybackService: Playback rate set to \(clampedRate)x")
    }
    
    // MARK: - Private Methods
    
    /// Configures audio session for playback
    private func configurePlaybackSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            print("🔊 AudioPlaybackService: Playback session configured")
        } catch {
            throw AudioPlaybackError.sessionConfigurationFailed(error)
        }
    }
    
    /// Starts the progress tracking timer
    private func startProgressTimer() {
        stopProgressTimer()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateProgress()
            }
        }
    }
    
    /// Stops the progress tracking timer
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    /// Updates the current playback progress
    private func updateProgress() {
        guard let player = audioPlayer, player.isPlaying else { return }
        
        playbackProgress = player.currentTime
    }
    
    /// Cleans up playback resources
    private func cleanup() {
        stopProgressTimer()
        
        audioPlayer?.delegate = nil
        audioPlayer = nil
        
        self.currentPlaybackURL = nil
        self.isPlaying = false
        self.playbackProgress = 0
        self.playbackDuration = 0
    }
}

// MARK: - AVAudioPlayerDelegate

extension AudioPlaybackService: AVAudioPlayerDelegate {
    
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        print("🔊 AudioPlaybackService: Playback finished successfully: \(flag)")
        
        Task { @MainActor in
            self.cleanup()
            
            if flag {
                self.onPlaybackFinished?()
            } else {
                let error = AudioPlaybackError.playbackFailed("Playback completed unsuccessfully")
                self.onPlaybackError?(error)
            }
        }
    }
    
    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        let playbackError = AudioPlaybackError.decodingError(error)
        print("❌ AudioPlaybackService: Decoding error occurred: \(playbackError)")
        
        Task { @MainActor in
            self.cleanup()
            self.onPlaybackError?(playbackError)
        }
    }
}

// MARK: - Error Types

enum AudioPlaybackError: LocalizedError {
    case playerCreationFailed(Error)
    case playbackStartFailed
    case playbackFailed(String)
    case sessionConfigurationFailed(Error)
    case decodingError(Error?)
    case noActivePlayer
    case noPlaybackToResume
    case invalidPlaybackRate(Float)
    case seekOutOfBounds(TimeInterval)
    
    var errorDescription: String? {
        switch self {
        case .playerCreationFailed(let error):
            return "Failed to create audio player: \(error.localizedDescription)"
        case .playbackStartFailed:
            return "Failed to start audio playback"
        case .playbackFailed(let message):
            return "Audio playback failed: \(message)"
        case .sessionConfigurationFailed(let error):
            return "Failed to configure playback session: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Audio decoding error: \(error?.localizedDescription ?? "Unknown decoding error")"
        case .noActivePlayer:
            return "No active audio player"
        case .noPlaybackToResume:
            return "No paused playback to resume"
        case .invalidPlaybackRate(let rate):
            return "Invalid playback rate: \(rate). Must be between 0.5 and 2.0"
        case .seekOutOfBounds(let time):
            return "Seek time \(time) is out of bounds"
        }
    }
}
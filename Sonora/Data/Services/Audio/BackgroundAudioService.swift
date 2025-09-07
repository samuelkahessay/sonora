//
//  BackgroundAudioService.swift
//  Sonora
//
//  Orchestrating background audio service that coordinates focused audio services:
//  - AudioSessionService: Session configuration and management
//  - AudioRecordingService: Recording operations and AVAudioRecorder lifecycle
//  - BackgroundTaskService: Background task management
//  - AudioPermissionService: Microphone permission handling
//  - RecordingTimerService: Recording duration tracking and countdown
//  - AudioPlaybackService: Audio playback functionality
//

import Foundation
import AVFoundation
import AVFAudio
import UIKit
import Combine

/// Orchestrating service that coordinates all audio operations through focused services
@MainActor
final class BackgroundAudioService: NSObject, ObservableObject, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasPermission = false
    @Published var isSessionActive = false
    @Published var backgroundTaskActive = false
    @Published var recordingStoppedAutomatically = false
    @Published var autoStopMessage: String?
    @Published var isInCountdown = false
    @Published var remainingTime: TimeInterval = 0
    @Published var audioLevel: Double = 0
    
    // MARK: - Focused Services
    private let sessionService: AudioSessionService
    private let recordingService: AudioRecordingService
    private let backgroundTaskService: BackgroundTaskService
    private let permissionService: AudioPermissionService
    private let timerService: RecordingTimerService
    private let playbackService: AudioPlaybackService
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Configuration
    private let config = AppConfiguration.shared
    
    // MARK: - Dynamic Configuration Properties
    /// Current optimized recording settings (resolved lazily via AudioQualityManager)
    private var currentRecordingSettings: AudioRecordingSettings {
        // Prefer adaptive, voice-optimized settings via the manager when available
        let mgr = DIContainer.shared.audioQualityManager()
        return mgr.getOptimalSettings(for: .voice)
    }
    
    // MARK: - Callbacks
    var onRecordingFinished: ((URL) -> Void)?
    var onRecordingFailed: ((Error) -> Void)?
    var onBackgroundTaskExpired: (() -> Void)?
    
    // MARK: - Interruption Recovery State
    private struct InterruptionState {
        var wasRecordingBeforeInterruption = false
        var recordingURL: URL?
        var recordingStartTime: Date?
        var accumulatedTime: TimeInterval = 0
        
        mutating func reset() {
            wasRecordingBeforeInterruption = false
            recordingURL = nil
            recordingStartTime = nil
            accumulatedTime = 0
        }
    }
    
    private var interruptionState = InterruptionState()
    
    // MARK: - Initialization
    init(sessionService: AudioSessionService = AudioSessionService(),
         recordingService: AudioRecordingService = AudioRecordingService(),
         backgroundTaskService: BackgroundTaskService = BackgroundTaskService(),
         permissionService: AudioPermissionService = AudioPermissionService(),
         timerService: RecordingTimerService = RecordingTimerService(),
         playbackService: AudioPlaybackService = AudioPlaybackService()) {
        
        self.sessionService = sessionService
        self.recordingService = recordingService
        self.backgroundTaskService = backgroundTaskService
        self.permissionService = permissionService
        self.timerService = timerService
        self.playbackService = playbackService
        
        super.init()
        
        setupServiceBindings()
        setupServiceCallbacks()
        permissionService.checkPermissions()
        
        print("🎵 BackgroundAudioService: Initialized with orchestrated services")
    }
    
    deinit {
        // Note: We don't clean up cancellables in deinit due to Swift 6 concurrency requirements.
        // The system will handle cleanup when the service is deallocated.
        print("🎵 BackgroundAudioService: Deinitialized")
    }
    
    // MARK: - Public Interface
    
    /// Starts audio recording with proper orchestration of all services
    func startRecording() throws {
        guard hasPermission else {
            throw AudioServiceError.permissionDenied
        }
        
        guard !isRecording else {
            throw AudioServiceError.alreadyRecording
        }
        
        // 1. Begin background task
        guard backgroundTaskService.beginBackgroundTask() else {
            throw AudioServiceError.backgroundTaskFailed
        }
        
        do {
            // 2. Configure audio session
            let settings = currentRecordingSettings
            try sessionService.configureForRecording(
                sampleRate: settings.sampleRate,
                channels: settings.channels
            )
            
            // 3. Create and start recorder
            let recordingURL = recordingService.generateRecordingURL()
            let recorder = try recordingService.createRecorder(
                url: recordingURL,
                settings: currentRecordingSettings
            )
            
            // 4. Attempt to start recording with fallbacks
            do {
                try recordingService.startRecordingWithFallbacks(with: recorder)
            } catch AudioRecordingError.requiresSessionFallback {
                // Try session fallback and create new recorder
                try sessionService.attemptRecordingFallback()
                let fallbackRecorder = try recordingService.createRecorder(
                    url: recordingURL,
                    settings: currentRecordingSettings
                )
                try recordingService.startRecording(with: fallbackRecorder)
            }
            
            // 5. Start timer with current time provider and recording cap
            let recordingCap = config.effectiveRecordingCapSeconds
            timerService.startTimer(
                with: { [weak self] in self?.recordingService.getCurrentTime() ?? 0 },
                recordingCap: recordingCap
            )
            
            print("🎵 BackgroundAudioService: Recording started successfully")
            
        } catch {
            // Clean up on failure
            backgroundTaskService.endBackgroundTask()
            sessionService.deactivateSession()
            throw error
        }
    }
    
    /// Stops the current recording
    func stopRecording() {
        guard isRecording else {
            print("⚠️ BackgroundAudioService: Cannot stop - no active recording")
            return
        }
        
        print("🎵 BackgroundAudioService: Stopping recording...")
        
        // 1. Stop timer
        timerService.stopTimer()
        
        // 2. Stop recording (cleanup happens in delegate)
        recordingService.stopRecording()
        
        print("🎵 BackgroundAudioService: Recording stop initiated")
    }
    
    /// Checks microphone permissions
    func checkMicrophonePermissions() {
        permissionService.checkPermissions()
    }
    
    /// Requests microphone permissions
    func requestMicrophonePermission() async -> Bool {
        return await permissionService.requestPermission()
    }
    
    // MARK: - Service Binding
    
    /// Sets up reactive bindings between services and published properties
    private func setupServiceBindings() {
        // Permission service bindings
        permissionService.$hasPermission
            .assign(to: \.hasPermission, on: self)
            .store(in: &cancellables)
        
        // Session service bindings
        sessionService.$isSessionActive
            .assign(to: \.isSessionActive, on: self)
            .store(in: &cancellables)
        
        // Recording service bindings
        recordingService.$isRecording
            .assign(to: \.isRecording, on: self)
            .store(in: &cancellables)
        
        recordingService.$audioLevel
            .assign(to: \.audioLevel, on: self)
            .store(in: &cancellables)
        
        // Background task service bindings
        backgroundTaskService.$isBackgroundTaskActive
            .assign(to: \.backgroundTaskActive, on: self)
            .store(in: &cancellables)
        
        // Timer service bindings
        timerService.$recordingTime
            .assign(to: \.recordingTime, on: self)
            .store(in: &cancellables)
        
        timerService.$isInCountdown
            .assign(to: \.isInCountdown, on: self)
            .store(in: &cancellables)
        
        timerService.$remainingTime
            .assign(to: \.remainingTime, on: self)
            .store(in: &cancellables)
        
        timerService.$recordingStoppedAutomatically
            .assign(to: \.recordingStoppedAutomatically, on: self)
            .store(in: &cancellables)
        
        timerService.$autoStopMessage
            .assign(to: \.autoStopMessage, on: self)
            .store(in: &cancellables)
    }
    
    /// Sets up callback connections between services
    private func setupServiceCallbacks() {
        // Recording service callbacks
        recordingService.onRecordingFinished = { [weak self] url in
            self?.handleRecordingFinished(url)
        }
        
        recordingService.onRecordingFailed = { [weak self] error in
            self?.handleRecordingFailed(error)
        }
        
        // Timer service callbacks
        timerService.onAutoStop = { [weak self] in
            self?.stopRecording()
        }
        
        // Background task service callbacks
        backgroundTaskService.onBackgroundTaskExpired = { [weak self] in
            self?.handleBackgroundTaskExpiration()
        }
        
        // Session service callbacks
        sessionService.onInterruptionBegan = { [weak self] in
            self?.handleAudioSessionInterruptionBegan()
        }
        
        sessionService.onInterruptionEnded = { [weak self] shouldResume in
            self?.handleAudioSessionInterruptionEnded(shouldResume: shouldResume)
        }
    }
    
    // MARK: - Event Handlers
    
    /// Handles successful recording completion
    private func handleRecordingFinished(_ url: URL) {
        cleanup()
        
        print("✅ BackgroundAudioService: Recording finished for \(url.lastPathComponent)")
        onRecordingFinished?(url)
    }
    
    /// Handles recording failure
    private func handleRecordingFailed(_ error: Error) {
        cleanup()
        
        print("❌ BackgroundAudioService: Recording failed: \(error)")
        onRecordingFailed?(error)
    }
    
    /// Handles background task expiration
    private func handleBackgroundTaskExpiration() {
        print("⏰ BackgroundAudioService: Background task expired")
        
        // Stop recording gracefully
        if isRecording {
            stopRecording()
        }
        
        // Notify delegate
        onBackgroundTaskExpired?()
    }
    
    /// Handles audio session interruption began
    private func handleAudioSessionInterruptionBegan() {
        print("🔊 BackgroundAudioService: Audio session interruption began")
        
        // Preserve recording state for recovery
        if isRecording {
            interruptionState.wasRecordingBeforeInterruption = true
            interruptionState.recordingURL = recordingService.currentRecordingURL
            interruptionState.recordingStartTime = Date()
            interruptionState.accumulatedTime = recordingService.getCurrentTime()
            
            print("🔊 BackgroundAudioService: Preserved recording state for recovery")
        }
    }
    
    /// Handles audio session interruption ended with comprehensive recovery
    private func handleAudioSessionInterruptionEnded(shouldResume: Bool) {
        print("🔊 BackgroundAudioService: Audio session interruption ended, shouldResume: \(shouldResume)")
        
        guard interruptionState.wasRecordingBeforeInterruption && shouldResume else {
            interruptionState.reset()
            return
        }
        
        Task { @MainActor in
            await attemptRecordingRecovery()
        }
    }
    
    /// Comprehensive recording recovery with recorder recreation
    @MainActor
    private func attemptRecordingRecovery() async {
        guard let recordingURL = interruptionState.recordingURL else {
            print("❌ BackgroundAudioService: No recording URL for recovery")
            handleRecoveryFailure("Missing recording URL")
            return
        }
        
        print("🔄 BackgroundAudioService: Attempting recording recovery")
        
        do {
            // 1. Reconfigure audio session with fallback handling
            try await reconfigureSessionWithFallback()
            
            // 2. Create new recorder (old one is invalid after interruption)
            let newRecorder = try recordingService.createRecorderWithFallback(
                url: recordingURL,
                sampleRate: currentRecordingSettings.sampleRate,
                channels: currentRecordingSettings.channels,
                quality: currentRecordingSettings.quality,
                bitRateOverride: currentRecordingSettings.bitRate
            )
            
            // 3. Attempt to resume recording
            try recordingService.startRecording(with: newRecorder)
            
            // 4. Restore timer state
            timerService.resumeFromInterruption(accumulatedTime: interruptionState.accumulatedTime)
            
            // 5. Update published state
            isRecording = true
            
            print("✅ BackgroundAudioService: Recording recovery successful")
            interruptionState.reset()
            
        } catch {
            print("❌ BackgroundAudioService: Recording recovery failed: \(error)")
            handleRecoveryFailure("Recovery failed: \(error.localizedDescription)")
        }
    }
    
    /// Session reconfiguration with fallback strategies
    private func reconfigureSessionWithFallback() async throws {
        do {
            let settings = currentRecordingSettings
            try sessionService.configureForRecording(
                sampleRate: settings.sampleRate,
                channels: settings.channels
            )
        } catch {
            print("⚠️ BackgroundAudioService: Primary session config failed, trying fallback")
            // Try fallback session configuration
            try sessionService.attemptRecordingFallback()
        }
    }
    
    /// Handle recovery failure with proper cleanup
    private func handleRecoveryFailure(_ reason: String) {
        print("❌ BackgroundAudioService: Recovery failed - \(reason)")
        
        // Clean up state
        isRecording = false
        timerService.resetTimer()
        backgroundTaskService.endBackgroundTask()
        
        // Notify about the failure
        let error = AudioServiceError.recordingFailed("Interruption recovery failed: \(reason)")
        onRecordingFailed?(error)
        
        // Reset interruption state
        interruptionState.reset()
    }
    
    // MARK: - Cleanup
    
    /// Performs complete cleanup of all services
    private func cleanup() {
        print("🧹 BackgroundAudioService: Performing cleanup...")
        
        // Stop timer
        timerService.resetTimer()
        
        // Clean up recording (handled by recording service delegate)
        // Session cleanup (deactivated when safe)
        
        // End background task
        backgroundTaskService.endBackgroundTask()
        
        print("🧹 BackgroundAudioService: Cleanup completed")
    }
}

// MARK: - Legacy Compatibility

extension BackgroundAudioService {
    
    /// Legacy method for backward compatibility
    func configureAudioSession() throws {
        try sessionService.configureForRecording(
            sampleRate: currentRecordingSettings.sampleRate,
            channels: currentRecordingSettings.channels
        )
    }
    
    /// Legacy method for backward compatibility
    func deactivateAudioSession() {
        sessionService.deactivateSession()
    }
}

// MARK: - Error Types

enum AudioServiceError: LocalizedError {
    case permissionDenied
    case alreadyRecording
    case notRecording
    case sessionConfigurationFailed(Error)
    case recordingStartFailed
    case recordingFailed(String)
    case encodingError(Error?)
    case backgroundTaskFailed
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone permission is required for recording"
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording is currently in progress"
        case .sessionConfigurationFailed(let error):
            return "Failed to configure audio session: \(error.localizedDescription)"
        case .recordingStartFailed:
            return "Failed to start audio recording"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .encodingError(let error):
            return "Audio encoding error: \(error?.localizedDescription ?? "Unknown encoding error")"
        case .backgroundTaskFailed:
            return "Failed to manage background task for recording"
        }
    }
}

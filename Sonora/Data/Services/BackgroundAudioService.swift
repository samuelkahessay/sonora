//
//  BackgroundAudioService.swift
//  Sonora
//
//  Created by Samuel Kahessay on 2025-01-26.
//

import Foundation
import AVFoundation
import UIKit
import Combine

/// A comprehensive background audio service that handles:
/// - Proper AVAudioSession configuration for recording and playback
/// - Background task management to continue recording when app enters background
/// - Single AVAudioRecorder instance lifecycle management
/// - Thread-safe operations and state management
final class BackgroundAudioService: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasPermission = false
    @Published var isSessionActive = false
    @Published var backgroundTaskActive = false
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var recordingTimer: Timer?
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // MARK: - Configuration Constants
    private struct AudioConfiguration {
        static let sampleRate: Double = 44100
        static let numberOfChannels: Int = 2
        static let audioQuality: AVAudioQuality = .high
        static let audioFormat: AudioFormatID = kAudioFormatMPEG4AAC
        static let timerInterval: TimeInterval = 0.1
    }
    
    // MARK: - Callbacks
    var onRecordingFinished: ((URL) -> Void)?
    var onRecordingFailed: ((Error) -> Void)?
    var onBackgroundTaskExpired: (() -> Void)?
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationObservers()
        checkMicrophonePermissions()
        print("🎵 BackgroundAudioService: Initialized")
    }
    
    deinit {
        cleanup()
        NotificationCenter.default.removeObserver(self)
        print("🎵 BackgroundAudioService: Deinitialized")
    }
    
    // MARK: - Notification Observers
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    // MARK: - Public Interface
    
    /// Configures and activates the audio session for recording
    func configureAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            // Configure for both recording and playback with speaker output
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP]
            )
            
            // Set preferred sample rate and I/O buffer duration for optimal performance
            try audioSession.setPreferredSampleRate(AudioConfiguration.sampleRate)
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms for low latency
            
            // Activate the session
            try audioSession.setActive(true)
            
            DispatchQueue.main.async {
                self.isSessionActive = true
            }
            
            print("🎵 BackgroundAudioService: Audio session configured successfully")
            print("   - Category: .playAndRecord")
            print("   - Options: .defaultToSpeaker, .allowBluetooth, .allowBluetoothA2DP")
            print("   - Sample Rate: \(AudioConfiguration.sampleRate) Hz")
            
        } catch {
            DispatchQueue.main.async {
                self.isSessionActive = false
            }
            print("❌ BackgroundAudioService: Failed to configure audio session: \(error)")
            throw AudioServiceError.sessionConfigurationFailed(error)
        }
    }
    
    /// Deactivates the audio session
    func deactivateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(false)
            DispatchQueue.main.async {
                self.isSessionActive = false
            }
            print("🎵 BackgroundAudioService: Audio session deactivated")
        } catch {
            print("⚠️ BackgroundAudioService: Failed to deactivate audio session: \(error)")
        }
    }
    
    /// Starts audio recording with proper background task management
    func startRecording() throws {
        guard hasPermission else {
            throw AudioServiceError.permissionDenied
        }
        
        guard !isRecording else {
            throw AudioServiceError.alreadyRecording
        }
        
        // Begin background task before any recording operations
        beginBackgroundTask()
        
        do {
            // Configure audio session
            try configureAudioSession()
            
            // Create recording URL
            let recordingURL = generateRecordingURL()
            
            // Configure audio recorder
            let audioRecorder = try createAudioRecorder(url: recordingURL)
            self.audioRecorder = audioRecorder
            
            // Start recording
            guard audioRecorder.record() else {
                throw AudioServiceError.recordingStartFailed
            }
            
            // Update state and start timer
            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingTime = 0
            }
            
            startRecordingTimer()
            
            print("🎵 BackgroundAudioService: Recording started successfully")
            print("   - File: \(recordingURL.lastPathComponent)")
            print("   - Background task: \(backgroundTaskIdentifier != .invalid ? "Active" : "Inactive")")
            
        } catch {
            // Clean up on failure
            endBackgroundTask()
            deactivateAudioSession()
            
            print("❌ BackgroundAudioService: Failed to start recording: \(error)")
            throw error
        }
    }
    
    /// Stops audio recording and cleans up resources
    func stopRecording() {
        print("🎵 BackgroundAudioService: Stopping recording...")
        
        // Stop recording timer
        stopRecordingTimer()
        
        // Stop audio recorder
        audioRecorder?.stop()
        
        // Update state
        DispatchQueue.main.async {
            self.isRecording = false
        }
        
        // Note: Cleanup of session and background task happens in delegate method
        print("🎵 BackgroundAudioService: Recording stop initiated")
    }
    
    /// Checks microphone permissions
    func checkMicrophonePermissions() {
        requestMicrophonePermission { [weak self] granted in
            DispatchQueue.main.async {
                self?.hasPermission = granted
            }
        }
    }
    
    // MARK: - Background Task Management
    
    /// Begins a background task to allow recording to continue when app enters background
    private func beginBackgroundTask() {
        guard backgroundTaskIdentifier == .invalid else {
            print("🔄 BackgroundAudioService: Background task already active")
            return
        }
        
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "AudioRecording") { [weak self] in
            print("⏰ BackgroundAudioService: Background task expired, cleaning up...")
            self?.handleBackgroundTaskExpiration()
        }
        
        if backgroundTaskIdentifier != .invalid {
            DispatchQueue.main.async {
                self.backgroundTaskActive = true
            }
            print("🔄 BackgroundAudioService: Background task started (ID: \(backgroundTaskIdentifier.rawValue))")
        } else {
            print("❌ BackgroundAudioService: Failed to start background task")
        }
    }
    
    /// Ends the current background task
    private func endBackgroundTask() {
        guard backgroundTaskIdentifier != .invalid else {
            return
        }
        
        print("🔄 BackgroundAudioService: Ending background task (ID: \(backgroundTaskIdentifier.rawValue))")
        
        UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
        backgroundTaskIdentifier = .invalid
        
        DispatchQueue.main.async {
            self.backgroundTaskActive = false
        }
    }
    
    /// Handles background task expiration
    private func handleBackgroundTaskExpiration() {
        print("⏰ BackgroundAudioService: Background task expired")
        
        // Stop recording gracefully
        if isRecording {
            stopRecording()
        }
        
        // Notify delegate about expiration
        onBackgroundTaskExpired?()
        
        // Clean up background task
        endBackgroundTask()
    }
    
    // MARK: - AVAudioRecorder Lifecycle Management
    
    /// Creates and configures a new AVAudioRecorder instance
    private func createAudioRecorder(url: URL) throws -> AVAudioRecorder {
        let settings: [String: Any] = [
            AVFormatIDKey: Int(AudioConfiguration.audioFormat),
            AVSampleRateKey: AudioConfiguration.sampleRate,
            AVNumberOfChannelsKey: AudioConfiguration.numberOfChannels,
            AVEncoderAudioQualityKey: AudioConfiguration.audioQuality.rawValue,
            AVEncoderBitRateKey: 320000, // 320 kbps for high quality
            AVSampleRateConverterAudioQualityKey: AVAudioQuality.max.rawValue
        ]
        
        let recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder.delegate = self
        recorder.isMeteringEnabled = true
        
        return recorder
    }
    
    /// Generates a unique URL for the recording
    private func generateRecordingURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "memo_\(timestamp).m4a"
        return documentsPath.appendingPathComponent(filename)
    }
    
    // MARK: - Recording Timer Management
    
    /// Starts the recording timer for tracking duration
    private func startRecordingTimer() {
        stopRecordingTimer() // Ensure no existing timer
        
        recordingTimer = Timer.scheduledTimer(withTimeInterval: AudioConfiguration.timerInterval, repeats: true) { [weak self] _ in
            self?.updateRecordingTime()
        }
    }
    
    /// Stops the recording timer
    private func stopRecordingTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    /// Updates the recording time from the audio recorder
    private func updateRecordingTime() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return
        }
        
        DispatchQueue.main.async {
            self.recordingTime = recorder.currentTime
        }
    }
    
    // MARK: - Permission Management
    
    /// Requests microphone permission with iOS version compatibility
    private func requestMicrophonePermission(_ completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { allowed in
                completion(allowed)
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { allowed in
                completion(allowed)
            }
        }
    }
    
    // MARK: - Notification Handlers
    
    @objc private func handleAppDidEnterBackground() {
        print("🔄 BackgroundAudioService: App entered background")
        
        if isRecording && backgroundTaskIdentifier == .invalid {
            print("⚠️ BackgroundAudioService: Recording in background without background task!")
            beginBackgroundTask()
        }
    }
    
    @objc private func handleAppWillEnterForeground() {
        print("🔄 BackgroundAudioService: App entering foreground")
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let interruptionTypeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let interruptionType = AVAudioSession.InterruptionType(rawValue: interruptionTypeValue) else {
            return
        }
        
        switch interruptionType {
        case .began:
            print("🔇 BackgroundAudioService: Audio session interrupted")
            if isRecording {
                stopRecording()
            }
            
        case .ended:
            print("🔊 BackgroundAudioService: Audio session interruption ended")
            
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                if options.contains(.shouldResume) {
                    print("🔄 BackgroundAudioService: Should resume after interruption")
                    // Note: Don't auto-resume recording, let user decide
                }
            }
            
        @unknown default:
            print("❓ BackgroundAudioService: Unknown interruption type")
        }
    }
    
    // MARK: - Cleanup
    
    /// Performs complete cleanup of all resources
    private func cleanup() {
        print("🧹 BackgroundAudioService: Performing cleanup...")
        
        // Stop recording if active
        if isRecording {
            audioRecorder?.stop()
        }
        
        // Clean up timer
        stopRecordingTimer()
        
        // Clean up audio recorder
        audioRecorder?.delegate = nil
        audioRecorder = nil
        
        // Deactivate audio session
        deactivateAudioSession()
        
        // End background task
        endBackgroundTask()
        
        // Reset state
        DispatchQueue.main.async {
            self.isRecording = false
            self.recordingTime = 0
            self.isSessionActive = false
            self.backgroundTaskActive = false
        }
        
        print("🧹 BackgroundAudioService: Cleanup completed")
    }
}

// MARK: - AVAudioRecorderDelegate

extension BackgroundAudioService: AVAudioRecorderDelegate {
    
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎵 BackgroundAudioService: Recording finished successfully: \(flag)")
        
        // Clean up resources
        cleanup()
        
        if flag {
            print("✅ BackgroundAudioService: Calling onRecordingFinished for \(recorder.url.lastPathComponent)")
            onRecordingFinished?(recorder.url)
        } else {
            let error = AudioServiceError.recordingFailed("Recording completed unsuccessfully")
            print("❌ BackgroundAudioService: Recording failed")
            onRecordingFailed?(error)
        }
    }
    
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let serviceError = AudioServiceError.encodingError(error)
        print("❌ BackgroundAudioService: Encoding error occurred: \(serviceError)")
        
        cleanup()
        onRecordingFailed?(serviceError)
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

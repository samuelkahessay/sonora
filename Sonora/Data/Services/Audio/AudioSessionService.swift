//
//  AudioSessionService.swift
//  Sonora
//
//  Audio session configuration and management service
//  Handles AVAudioSession setup, interruptions, and route management
//

import Foundation
import AVFoundation
import Combine

/// Protocol defining audio session management operations
@MainActor
protocol AudioSessionServiceProtocol: ObservableObject {
    var isSessionActive: Bool { get }
    var sessionActivePublisher: AnyPublisher<Bool, Never> { get }
    
    func configureForRecording(sampleRate: Double, channels: Int) throws
    func configureForPlayback() throws
    func deactivateSession()
    func handleInterruption(_ notification: Notification)
    func logCurrentRoute(_ prefix: String)
}

/// Focused service for AVAudioSession configuration and management
@MainActor
final class AudioSessionService: NSObject, AudioSessionServiceProtocol, @unchecked Sendable {
    
    // MARK: - Published Properties
    @Published var isSessionActive = false
    
    // MARK: - Publishers
    var sessionActivePublisher: AnyPublisher<Bool, Never> {
        $isSessionActive.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private let audioSession = AVAudioSession.sharedInstance()
    private var wasInterrupted = false
    private var wasRecordingBeforeInterruption = false
    
    // MARK: - Callbacks
    var onInterruptionBegan: (() -> Void)?
    var onInterruptionEnded: ((Bool) -> Void)? // shouldResume parameter
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupNotificationObservers()
        print("🎵 AudioSessionService: Initialized")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        print("🎵 AudioSessionService: Deinitialized")
    }
    
    // MARK: - Configuration Methods
    
    /// Configures audio session for recording with optimal settings
    func configureForRecording(sampleRate: Double, channels: Int) throws {
        do {
            // Configure for both recording and playback with speaker output
            try audioSession.setCategory(
                .playAndRecord,
                mode: .default,
                options: [.defaultToSpeaker, .allowBluetoothHFP]
            )
            
            // Set preferred sample rate and I/O buffer duration for optimal performance
            try audioSession.setPreferredSampleRate(sampleRate)
            try audioSession.setPreferredIOBufferDuration(0.005) // 5ms for low latency
            
            // Activate the session
            try audioSession.setActive(true)
            self.isSessionActive = true
            
            print("🎵 AudioSessionService: Recording session configured successfully")
            print("   - Category: .playAndRecord")
            print("   - Options: .defaultToSpeaker, .allowBluetoothHFP")
            print("   - Sample Rate: \(sampleRate) Hz")
            print("   - Channels: \(channels)")
            logCurrentRoute("post-config")
            
        } catch {
            self.isSessionActive = false
            print("❌ AudioSessionService: Failed to configure recording session: \(error)")
            throw AudioSessionError.configurationFailed(error)
        }
    }
    
    /// Configures audio session for playback
    func configureForPlayback() throws {
        do {
            try audioSession.setCategory(.playback, mode: .default)
            try audioSession.setActive(true)
            self.isSessionActive = true
            
            print("🎵 AudioSessionService: Playback session configured successfully")
            logCurrentRoute("playback-config")
            
        } catch {
            self.isSessionActive = false
            print("❌ AudioSessionService: Failed to configure playback session: \(error)")
            throw AudioSessionError.configurationFailed(error)
        }
    }
    
    /// Attempts fallback configuration for recording when initial config fails
    func attemptRecordingFallback() throws {
        print("⚠️ AudioSessionService: Attempting fallback configuration")
        
        do {
            // First fallback: voiceChat mode
            try audioSession.setActive(false)
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
            
            // Prefer built-in mic if available
            if let builtIn = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try? audioSession.setPreferredInput(builtIn)
            }
            
            self.isSessionActive = true
            logCurrentRoute("voiceChat-fallback")
            print("✅ AudioSessionService: VoiceChat fallback successful")
            
        } catch {
            // Final fallback: record category with default mode
            print("⚠️ AudioSessionService: VoiceChat fallback failed, attempting .record category")
            try audioSession.setActive(false)
            try audioSession.setCategory(.record, mode: .default, options: [])
            try audioSession.setActive(true)
            
            // Prefer built-in mic if available
            if let builtIn = audioSession.availableInputs?.first(where: { $0.portType == .builtInMic }) {
                try? audioSession.setPreferredInput(builtIn)
            }
            
            self.isSessionActive = true
            logCurrentRoute("record-category")
            print("✅ AudioSessionService: Record category fallback successful")
        }
    }
    
    /// Deactivates the audio session
    func deactivateSession() {
        do {
            try audioSession.setActive(false)
            self.isSessionActive = false
            print("🎵 AudioSessionService: Audio session deactivated")
        } catch {
            print("⚠️ AudioSessionService: Failed to deactivate audio session: \(error)")
        }
    }
    
    // MARK: - Route Logging
    
    /// Logs detailed audio session routing information for diagnostics
    func logCurrentRoute(_ prefix: String = "") {
        let permissionDescription: String
        if #available(iOS 17.0, *) {
            permissionDescription = String(describing: AVAudioApplication.shared.recordPermission)
        } else {
            permissionDescription = String(describing: audioSession.recordPermission)
        }
        let isInputAvailable = audioSession.isInputAvailable
        let route = audioSession.currentRoute
        let inputs = route.inputs.map { "\($0.portType.rawValue) [\($0.portName)]" }.joined(separator: ", ")
        let outputs = route.outputs.map { "\($0.portType.rawValue) [\($0.portName)]" }.joined(separator: ", ")
        let availableInputs = (audioSession.availableInputs ?? []).map { "\($0.portType.rawValue) [\($0.portName)]" }.joined(separator: ", ")
        let preferred = audioSession.preferredInput?.portType.rawValue ?? "nil"
        print("🔎 AudioSession Route \(prefix): permission=\(permissionDescription), inputAvailable=\(isInputAvailable)")
        print("🔎 Inputs: \(inputs)")
        print("🔎 Outputs: \(outputs)")
        print("🔎 AvailableInputs: \(availableInputs)")
        print("🔎 PreferredInput: \(preferred)")
    }
    
    // MARK: - Interruption Handling
    
    /// Handles audio session interruptions
    func handleInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            print("🔊 AudioSessionService: Audio session interruption began")
            wasInterrupted = true
            self.isSessionActive = false
            onInterruptionBegan?()
            
        case .ended:
            print("🔊 AudioSessionService: Audio session interruption ended")
            let shouldResume: Bool = {
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    return AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume)
                }
                return false
            }()
            
            if wasInterrupted {
                // Attempt to reactivate session
                do {
                    try audioSession.setActive(true)
                    self.isSessionActive = true
                } catch {
                    print("⚠️ AudioSessionService: Failed to reactivate session after interruption: \(error)")
                }
                
                onInterruptionEnded?(shouldResume)
            }
            wasInterrupted = false
            
        @unknown default:
            print("❓ AudioSessionService: Unknown interruption type")
        }
    }
    
    // MARK: - Private Methods
    
    /// Sets up notification observers for interruptions
    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        // NotificationCenter calls this from a background thread, so we need to dispatch to MainActor
        Task { @MainActor in
            self.handleInterruption(notification)
        }
    }
}

// MARK: - Error Types

enum AudioSessionError: LocalizedError {
    case configurationFailed(Error)
    case activationFailed(Error)
    case deactivationFailed(Error)
    case routeUnavailable
    
    var errorDescription: String? {
        switch self {
        case .configurationFailed(let error):
            return "Failed to configure audio session: \(error.localizedDescription)"
        case .activationFailed(let error):
            return "Failed to activate audio session: \(error.localizedDescription)"
        case .deactivationFailed(let error):
            return "Failed to deactivate audio session: \(error.localizedDescription)"
        case .routeUnavailable:
            return "Audio route is unavailable"
        }
    }
}

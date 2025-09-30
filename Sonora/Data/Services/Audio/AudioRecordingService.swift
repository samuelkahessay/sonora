//
//  AudioRecordingService.swift
//  Sonora
//
//  AVAudioRecorder management and recording operations service
//  Handles recorder lifecycle, configuration, and delegate callbacks
//

import AVFoundation
import Combine
import Foundation
import UIKit

/// Protocol defining audio recording operations
@MainActor
protocol AudioRecordingServiceProtocol: ObservableObject {
    var isRecording: Bool { get }
    var currentRecordingURL: URL? { get }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }

    func createRecorder(url: URL, sampleRate: Double, channels: Int, quality: Float) throws -> AVAudioRecorder
    func startRecording(with recorder: AVAudioRecorder) throws
    func stopRecording()
    func pauseRecording()
    func resumeRecording()
    func getCurrentTime() -> TimeInterval

    // Callbacks
    var onRecordingFinished: ((URL) -> Void)? { get set }
    var onRecordingFailed: ((Error) -> Void)? { get set }
}

/// Focused service for AVAudioRecorder management and recording operations
@MainActor
final class AudioRecordingService: NSObject, AudioRecordingServiceProtocol, @unchecked Sendable {

    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var currentRecordingURL: URL?
    @Published var audioLevel: Double = 0 // 0.0 ... 1.0 normalized RMS proxy

    // MARK: - Publishers
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }

    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
    private var levelTimer: Timer?
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

    // MARK: - Configuration
    private struct AudioConfiguration {
        static let audioQuality: AVAudioQuality = .high

        /// 3-tier fallback format configuration
        struct FormatFallback {
            static let primaryFormat: AudioFormatID = kAudioFormatMPEG4AAC    // Best quality, modern devices
            static let secondaryFormat: AudioFormatID = kAudioFormatAppleLossless  // Wider compatibility  
            static let fallbackFormat: AudioFormatID = kAudioFormatLinearPCM  // Universal compatibility

            static let supportedFormats: [(AudioFormatID, String)] = [
                (primaryFormat, "MPEG4AAC"),
                (secondaryFormat, "Apple Lossless"),
                (fallbackFormat, "Linear PCM")
            ]
        }

        /// Voice-optimized settings for better quality and smaller files
        struct VoiceOptimized {
            private static let config = AppConfiguration.shared

            /// Voice-optimized sample rate from configuration (default: 22050 Hz)
            /// Perfect for voice content - captures full speech frequency range (300-3400 Hz fundamental + harmonics)
            static var sampleRate: Double {
                config.voiceOptimizedSampleRate
            }

            /// Optimal bit rate for voice content from configuration (default: 64000 bps)
            /// Provides excellent clarity while minimizing file size
            static var bitRate: Int {
                config.audioBitRate
            }

            /// Voice-optimized quality setting from configuration (default: 0.7)
            /// Calibrated specifically for speech clarity and compression balance
            static var quality: Float {
                config.voiceOptimizedQuality
            }

            /// Adaptive quality based on current system conditions
            /// Adjusts quality for battery level and thermal state
            @MainActor static func adaptiveQuality(batteryLevel: Float? = nil) -> Float {
                let level = batteryLevel ?? UIDevice.current.batteryLevel
                return config.getOptimalAudioQuality(for: .voice, batteryLevel: level)
            }

            /// Adaptive bit rate based on current system conditions
            @MainActor static func adaptiveBitRate(batteryLevel: Float? = nil) -> Int {
                let level = batteryLevel ?? UIDevice.current.batteryLevel
                return config.getOptimalBitRate(for: .voice, batteryLevel: level)
            }
        }
    }

    // MARK: - Callbacks
    var onRecordingFinished: ((URL) -> Void)?
    var onRecordingFailed: ((Error) -> Void)?

    // MARK: - Initialization
    override init() {
        super.init()
        print("🎙️ AudioRecordingService: Initialized")
    }

    deinit {
        // Cleanup in deinit must be synchronous, so we handle essential cleanup here
        audioRecorder?.delegate = nil
        audioRecorder = nil
        print("🎙️ AudioRecordingService: Deinitialized")
    }

    // MARK: - Public Interface

    /// Creates and configures a new AVAudioRecorder instance with 3-tier fallback
    func createRecorder(url: URL, sampleRate: Double, channels: Int, quality: Float) throws -> AVAudioRecorder {
        try createRecorderWithFallback(url: url, sampleRate: sampleRate, channels: channels, quality: quality)
    }

    /// Creates and configures a new AVAudioRecorder using high-level recording settings
    func createRecorder(url: URL, settings: AudioRecordingSettings) throws -> AVAudioRecorder {
        try createRecorderWithFallback(
            url: url,
            sampleRate: settings.sampleRate,
            channels: settings.channels,
            quality: settings.quality,
            bitRateOverride: settings.bitRate
        )
    }

    /// Creates an optimized recorder for specific content type with adaptive quality
    func createOptimizedRecorder(url: URL, contentType: AudioContentType = .voice) throws -> AVAudioRecorder {
        let sampleRate: Double
        let quality: Float

        switch contentType {
        case .voice, .music, .mixed:
            sampleRate = AudioConfiguration.VoiceOptimized.sampleRate
            quality = AudioConfiguration.VoiceOptimized.adaptiveQuality()
        }

        print("🎙️ AudioRecordingService: Creating \(contentType.displayName) optimized recorder - Sample Rate: \(sampleRate) Hz, Quality: \(quality)")

        return try createRecorderWithFallback(
            url: url,
            sampleRate: sampleRate,
            channels: 1, // Always use mono for optimal file size and compatibility
            quality: quality
        )
    }

    /// Creates recorder with intelligent format fallback for maximum device compatibility
    func createRecorderWithFallback(url: URL, sampleRate: Double, channels: Int, quality: Float, bitRateOverride: Int? = nil) throws -> AVAudioRecorder {
        var lastError: Error?

        for (formatId, formatName) in AudioConfiguration.FormatFallback.supportedFormats {
            do {
                let settings = createAudioSettings(
                    format: formatId,
                    sampleRate: sampleRate,
                    channels: channels,
                    quality: quality,
                    bitRateOverride: bitRateOverride
                )

                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.delegate = self
                recorder.isMeteringEnabled = true

                // Successfully created recorder
                print("🎙️ AudioRecordingService: Successfully created recorder with \(formatName) format")
                return recorder

            } catch {
                lastError = error
                print("⚠️ AudioRecordingService: \(formatName) format failed: \(error.localizedDescription)")
                continue
            }
        }

        // If all formats failed, throw comprehensive error
        throw AudioRecordingError.allFormatsFailedToRecord([lastError].compactMap { $0 })
    }

    /// Creates format-specific audio settings optimized for each codec
    private func createAudioSettings(format: AudioFormatID, sampleRate: Double, channels: Int, quality: Float, bitRateOverride: Int? = nil) -> [String: Any] {
        switch format {
        case kAudioFormatMPEG4AAC:
            var settings: [String: Any] = [
                AVFormatIDKey: Int(format),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderAudioQualityKey: AudioConfiguration.audioQuality.rawValue,
                AVSampleRateConverterAudioQualityKey: AVAudioQuality.max.rawValue
            ]

            // Add explicit bitrate if provided; otherwise use adaptive voice bitrate for 22kHz voice
            if let override = bitRateOverride {
                settings[AVEncoderBitRateKey] = override
                print("🎙️ AudioRecordingService: Using override bitrate: \(override) bps")
            } else if sampleRate <= 22_050.0 {
                let optimizedBitRate = AudioConfiguration.VoiceOptimized.adaptiveBitRate()
                settings[AVEncoderBitRateKey] = optimizedBitRate
                print("🎙️ AudioRecordingService: Using voice-optimized bitrate: \(optimizedBitRate) bps")
            }

            return settings
        case kAudioFormatAppleLossless:
            return [
                AVFormatIDKey: Int(format),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderAudioQualityKey: AudioConfiguration.audioQuality.rawValue
                // Apple Lossless doesn't use bitrate settings
            ]
        case kAudioFormatLinearPCM:
            return [
                AVFormatIDKey: Int(format),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
        default:
            return [:]
        }
    }

    /// Starts recording with the provided recorder
    func startRecording(with recorder: AVAudioRecorder) throws {
        guard !isRecording else {
            throw AudioRecordingError.alreadyRecording
        }

        self.audioRecorder = recorder
        self.currentRecordingURL = recorder.url

        // Prepare and start recording
        recorder.prepareToRecord()
        let started = recorder.record()

        guard started else {
            throw AudioRecordingError.startFailed
        }

        self.isRecording = true
        startLevelMetering()
        print("🎙️ AudioRecordingService: Recording started for \(recorder.url.lastPathComponent)")
    }

    /// Attempts to start recording with fallback configurations
    func startRecordingWithFallbacks(with recorder: AVAudioRecorder) throws {
        guard !isRecording else {
            throw AudioRecordingError.alreadyRecording
        }

        self.audioRecorder = recorder
        self.currentRecordingURL = recorder.url

        // Prepare and start recording
        recorder.prepareToRecord()
        let started = recorder.record()

        if !started {
            print("⚠️ AudioRecordingService: Initial record() failed, will require session fallback")
            throw AudioRecordingError.requiresSessionFallback
        }

        self.isRecording = started
        if started { startLevelMetering() }
        print("🎙️ AudioRecordingService: Recording started for \(recorder.url.lastPathComponent)")
    }

    /// Stops the current recording (supports stopping from paused state)
    func stopRecording() {
        guard let recorder = audioRecorder else {
            print("⚠️ AudioRecordingService: Cannot stop - no recorder instance")
            return
        }
        print("🎙️ AudioRecordingService: Stopping recording...")
        recorder.stop()
        self.isRecording = false
        stopLevelMetering()
        // Note: Cleanup happens in delegate method to ensure proper callback handling
        print("🎙️ AudioRecordingService: Recording stop initiated")
    }

    /// Gets the current recording time
    func getCurrentTime() -> TimeInterval {
        guard let recorder = audioRecorder else { return 0 }
        return recorder.currentTime
    }

    /// Pauses the current recording (does not finalize the file)
    func pauseRecording() {
        guard isRecording, let recorder = audioRecorder, recorder.isRecording else {
            print("⚠️ AudioRecordingService: Cannot pause - not currently recording")
            return
        }
        recorder.pause()
        isRecording = false
        stopLevelMetering()
        print("⏸️ AudioRecordingService: Recording paused at \(recorder.currentTime)s")
    }

    /// Resumes a paused recording into the same file
    func resumeRecording() {
        guard !isRecording, let recorder = audioRecorder, !recorder.isRecording else {
            print("⚠️ AudioRecordingService: Cannot resume - not paused")
            return
        }
        let resumed = recorder.record()
        if resumed {
            isRecording = true
            startLevelMetering()
            print("▶️ AudioRecordingService: Recording resumed at \(recorder.currentTime)s")
        } else {
            print("❌ AudioRecordingService: Failed to resume recording")
        }
    }

    /// Generates a unique URL for a new recording
    func generateRecordingURL() -> URL {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        let filename = "memo_\(timestamp).m4a"
        return documentsPath.appendingPathComponent(filename)
    }

    /// Checks if a recorder is currently recording
    func isRecorderActive() -> Bool {
        audioRecorder?.isRecording ?? false
    }

    // MARK: - Private Methods

    /// Cleans up recorder resources
    private func cleanup() {
        if isRecording {
            audioRecorder?.stop()
        }

        audioRecorder?.delegate = nil
        audioRecorder = nil
        self.currentRecordingURL = nil
        self.isRecording = false
        stopLevelMetering()

        print("🎙️ AudioRecordingService: Cleanup completed")
    }

    // MARK: - Level Metering
    private func startLevelMetering() {
        stopLevelMetering()
        guard let recorder = audioRecorder else { return }
        recorder.isMeteringEnabled = true
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Ensure execution on MainActor to satisfy isolation
            Task { @MainActor in
                self?.sampleLevel()
            }
        }
        if let timer = levelTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func stopLevelMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
        audioLevel = 0
    }

    private func sampleLevel() {
        guard let recorder = audioRecorder, recorder.isRecording else {
            audioLevel = 0
            return
        }
        recorder.updateMeters()
        let power = recorder.averagePower(forChannel: 0) // dBFS (-160...0)
        let linear = max(0.0, min(1.0, pow(10.0, power / 20.0)))
        // Exponential smoothing for calmer visualization
        audioLevel = max(0.0, min(1.0, 0.8 * audioLevel + 0.2 * Double(linear)))
    }
}

// MARK: - AVAudioRecorderDelegate

extension AudioRecordingService: AVAudioRecorderDelegate {

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        print("🎙️ AudioRecordingService: Recording finished successfully: \(flag)")

        // Clean up resources on MainActor
        Task { @MainActor in
            let recordingURL = recorder.url
            self.cleanup()

            if flag {
                print("✅ AudioRecordingService: Calling onRecordingFinished for \(recordingURL.lastPathComponent)")
                self.onRecordingFinished?(recordingURL)
            } else {
                let error = AudioRecordingError.recordingFailed("Recording completed unsuccessfully")
                print("❌ AudioRecordingService: Recording failed")
                self.onRecordingFailed?(error)
            }
        }
    }

    nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        let serviceError = AudioRecordingError.encodingError(error)
        print("❌ AudioRecordingService: Encoding error occurred: \(serviceError)")

        Task { @MainActor in
            self.cleanup()
            self.onRecordingFailed?(serviceError)
        }
    }
}

// MARK: - Error Types

enum AudioRecordingError: LocalizedError {
    case alreadyRecording
    case notRecording
    case startFailed
    case requiresSessionFallback
    case requiresRecorderRecreation
    case recordingFailed(String)
    case encodingError(Error?)
    case recorderCreationFailed(Error)
    case allFormatsFailedToRecord([Error])
    case audioRouteUnavailable
    case bluetoothConnectionFailed

    var errorDescription: String? {
        switch self {
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No recording is currently in progress"
        case .startFailed:
            return "Failed to start audio recording"
        case .requiresSessionFallback:
            return "Recording failed - audio session fallback required"
        case .requiresRecorderRecreation:
            return "Recorder recreation required due to route change"
        case .recordingFailed(let message):
            return "Recording failed: \(message)"
        case .encodingError(let error):
            return "Audio encoding error: \(error?.localizedDescription ?? "Unknown encoding error")"
        case .recorderCreationFailed(let error):
            return "Failed to create audio recorder: \(error.localizedDescription)"
        case .allFormatsFailedToRecord(let errors):
            let descriptions = errors.map { $0.localizedDescription }
            return "All audio formats failed: \(descriptions.joined(separator: ", "))"
        case .audioRouteUnavailable:
            return "Audio route is unavailable for recording"
        case .bluetoothConnectionFailed:
            return "Bluetooth audio connection failed"
        }
    }

    var recoveryAction: RecoveryAction {
        switch self {
        case .requiresSessionFallback:
            return .retryWithSessionFallback
        case .requiresRecorderRecreation:
            return .recreateRecorder
        case .allFormatsFailedToRecord:
            return .switchToBuiltInMic
        case .audioRouteUnavailable:
            return .selectDifferentRoute
        default:
            return .none
        }
    }
}

// MARK: - Recovery Actions

/// Internal recovery actions for handling recording failures.
/// These guide the service or higher-level coordinators on what to attempt next.
enum RecoveryAction {
    /// Retry starting recording after applying an audio session fallback configuration
    case retryWithSessionFallback
    /// Recreate the AVAudioRecorder instance before retrying
    case recreateRecorder
    /// Switch the input route to the built-in microphone and retry
    case switchToBuiltInMic
    /// Prompt user to select a different audio route
    case selectDifferentRoute
    /// No recovery action available
    case none
}

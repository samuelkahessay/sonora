//
//  AudioRecordingService.swift
//  Sonora
//
//  AVAudioRecorder management and recording operations service
//  Handles recorder lifecycle, configuration, and delegate callbacks
//

import Foundation
import AVFoundation
import Combine

/// Protocol defining audio recording operations
@MainActor
protocol AudioRecordingServiceProtocol: ObservableObject {
    var isRecording: Bool { get }
    var currentRecordingURL: URL? { get }
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    
    func createRecorder(url: URL, sampleRate: Double, channels: Int, quality: Float) throws -> AVAudioRecorder
    func startRecording(with recorder: AVAudioRecorder) throws
    func stopRecording()
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
    
    // MARK: - Publishers
    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        $isRecording.eraseToAnyPublisher()
    }
    
    // MARK: - Private Properties
    private var audioRecorder: AVAudioRecorder?
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
            static let sampleRate: Double = 22050  // Perfect for voice (vs 44100 for music)
            static let bitRate: Int = 64000        // 64k optimal for voice clarity
            static let quality: Float = 0.7        // Balanced quality for voice
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
        return try createRecorderWithFallback(url: url, sampleRate: sampleRate, channels: channels, quality: quality)
    }
    
    /// Creates recorder with intelligent format fallback for maximum device compatibility
    func createRecorderWithFallback(url: URL, sampleRate: Double, channels: Int, quality: Float) throws -> AVAudioRecorder {
        var lastError: Error?
        
        for (formatId, formatName) in AudioConfiguration.FormatFallback.supportedFormats {
            do {
                let settings = createAudioSettings(
                    format: formatId,
                    sampleRate: sampleRate,
                    channels: channels,
                    quality: quality
                )
                
                let recorder = try AVAudioRecorder(url: url, settings: settings)
                recorder.delegate = self
                recorder.isMeteringEnabled = true
                
                // Test recording capability before returning
                recorder.prepareToRecord()
                if recorder.record() {
                    recorder.stop() // Stop test recording
                    print("🎙️ AudioRecordingService: Successfully created recorder with \(formatName) format")
                    return recorder
                } else {
                    throw AudioRecordingError.startFailed
                }
                
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
    private func createAudioSettings(format: AudioFormatID, sampleRate: Double, channels: Int, quality: Float) -> [String: Any] {
        switch format {
        case kAudioFormatMPEG4AAC:
            return [
                AVFormatIDKey: Int(format),
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: channels,
                AVEncoderAudioQualityKey: AudioConfiguration.audioQuality.rawValue,
                AVSampleRateConverterAudioQualityKey: AVAudioQuality.max.rawValue
                // Omit explicit bitrate for MPEG4AAC - let system choose for compatibility
            ]
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
        print("🎙️ AudioRecordingService: Recording started for \(recorder.url.lastPathComponent)")
    }
    
    /// Stops the current recording
    func stopRecording() {
        guard isRecording, let recorder = audioRecorder else {
            print("⚠️ AudioRecordingService: Cannot stop - no active recording")
            return
        }
        
        print("🎙️ AudioRecordingService: Stopping recording...")
        recorder.stop()
        self.isRecording = false
        
        // Note: Cleanup happens in delegate method to ensure proper callback handling
        print("🎙️ AudioRecordingService: Recording stop initiated")
    }
    
    /// Gets the current recording time
    func getCurrentTime() -> TimeInterval {
        guard let recorder = audioRecorder, recorder.isRecording else {
            return 0
        }
        return recorder.currentTime
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
        return audioRecorder?.isRecording ?? false
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
        
        print("🎙️ AudioRecordingService: Cleanup completed")
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

enum RecoveryAction {
    case none
    case retryWithSessionFallback
    case recreateRecorder
    case switchToBuiltInMic
    case selectDifferentRoute
}
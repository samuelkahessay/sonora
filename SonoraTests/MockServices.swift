//
//  MockServices.swift
//  SonoraTests
//
//  Created by Claude Code on 2025-01-07.
//  Mock services for testing BackgroundAudioService interruption recovery
//

import Foundation
import AVFoundation
@testable import Sonora

// MARK: - Mock Audio Session Service

@MainActor
class MockAudioSessionService: AudioSessionService {

    var configureForRecordingCalled = false
    var configureForRecordingShouldFail = false
    var attemptRecordingFallbackCalled = false
    var attemptRecordingFallbackShouldFail = false
    var deactivateSessionCalled = false

    override func configureForRecording(sampleRate: Double, channels: Int) throws {
        configureForRecordingCalled = true
        if configureForRecordingShouldFail {
            throw AudioSessionError.configurationFailed("Mock configuration failure")
        }
    }

    override func attemptRecordingFallback() throws {
        attemptRecordingFallbackCalled = true
        if attemptRecordingFallbackShouldFail {
            throw AudioSessionError.configurationFailed("Mock fallback failure")
        }
    }

    override func deactivateSession() {
        deactivateSessionCalled = true
        super.deactivateSession()
    }

    // Test helpers
    func triggerInterruptionBegan() {
        onInterruptionBegan?()
    }

    func triggerInterruptionEnded(shouldResume: Bool) {
        onInterruptionEnded?(shouldResume)
    }
}

// MARK: - Mock Audio Recording Service

@MainActor
class MockAudioRecordingService: AudioRecordingService {

    var createRecorderCalled = false
    var createRecorderWithFallbackCalled = false
    var createRecorderWithFallbackShouldFail = false
    var createRecorderWithFallbackResult: AVAudioRecorder?
    var startRecordingCalled = false
    var startRecordingWithFallbacksCalled = false
    var stopRecordingCalled = false
    var generateRecordingURLResult: URL?
    var currentTimeResult: TimeInterval = 0

    override func createRecorder(url: URL, sampleRate: Double, channels: Int, quality: Float) throws -> AVAudioRecorder {
        createRecorderCalled = true
        return createRecorderWithFallbackResult ?? MockAVAudioRecorder()
    }

    override func createRecorderWithFallback(url: URL, sampleRate: Double, channels: Int, quality: Float) throws -> AVAudioRecorder {
        createRecorderWithFallbackCalled = true
        if createRecorderWithFallbackShouldFail {
            throw AudioRecordingError.recorderCreationFailed(NSError(domain: "MockError", code: 1, userInfo: nil))
        }
        return createRecorderWithFallbackResult ?? MockAVAudioRecorder()
    }

    override func startRecording(with recorder: AVAudioRecorder) throws {
        startRecordingCalled = true
        isRecording = true
        currentRecordingURL = recorder.url
    }

    override func startRecordingWithFallbacks(with recorder: AVAudioRecorder) throws {
        startRecordingWithFallbacksCalled = true
        isRecording = true
        currentRecordingURL = recorder.url
    }

    override func stopRecording() {
        stopRecordingCalled = true
        isRecording = false
        // Simulate successful completion
        if let url = currentRecordingURL {
            onRecordingFinished?(url)
        }
        currentRecordingURL = nil
    }

    override func generateRecordingURL() -> URL {
        return generateRecordingURLResult ?? FileManager.default.temporaryDirectory.appendingPathComponent("mock_recording.m4a")
    }

    override func getCurrentTime() -> TimeInterval {
        return currentTimeResult
    }
}

// MARK: - Mock Recording Timer Service

@MainActor
class MockRecordingTimerService: RecordingTimerService {

    var startTimerCalled = false
    var stopTimerCalled = false
    var resetTimerCalled = false
    var resumeFromInterruptionCalled = false
    var resumeAccumulatedTime: TimeInterval = 0

    override func startTimer(with timeProvider: @escaping () -> TimeInterval, recordingCap: TimeInterval?) {
        startTimerCalled = true
        super.startTimer(with: timeProvider, recordingCap: recordingCap)
    }

    override func stopTimer() {
        stopTimerCalled = true
        super.stopTimer()
    }

    override func resetTimer() {
        resetTimerCalled = true
        super.resetTimer()
    }

    override func resumeFromInterruption(accumulatedTime: TimeInterval) {
        resumeFromInterruptionCalled = true
        resumeAccumulatedTime = accumulatedTime
        super.resumeFromInterruption(accumulatedTime: accumulatedTime)
    }
}

// MARK: - Mock Background Task Service

@MainActor
class MockBackgroundTaskService: BackgroundTaskService {

    var beginBackgroundTaskCalled = false
    var beginBackgroundTaskResult = true
    var endBackgroundTaskCalled = false

    override func beginBackgroundTask() -> Bool {
        beginBackgroundTaskCalled = true
        isBackgroundTaskActive = beginBackgroundTaskResult
        return beginBackgroundTaskResult
    }

    override func endBackgroundTask() {
        endBackgroundTaskCalled = true
        isBackgroundTaskActive = false
    }

    // Test helper
    func triggerBackgroundTaskExpiration() {
        onBackgroundTaskExpired?()
    }
}

// MARK: - Mock Audio Permission Service

@MainActor
class MockAudioPermissionService: AudioPermissionService {

    var checkPermissionsCalled = false
    var requestPermissionCalled = false
    var requestPermissionResult = true

    override func checkPermissions() {
        checkPermissionsCalled = true
        super.checkPermissions()
    }

    override func requestPermission() async -> Bool {
        requestPermissionCalled = true
        hasPermission = requestPermissionResult
        return requestPermissionResult
    }
}

// MARK: - Mock Audio Playback Service

@MainActor
class MockAudioPlaybackService: AudioPlaybackService {

    var playAudioCalled = false
    var stopPlaybackCalled = false

    override func playAudio(from url: URL, completion: @escaping (Bool) -> Void) {
        playAudioCalled = true
        // Simulate successful playback
        DispatchQueue.main.async {
            completion(true)
        }
    }

    override func stopPlayback() {
        stopPlaybackCalled = true
        super.stopPlayback()
    }
}

// MARK: - Mock AVAudioRecorder

class MockAVAudioRecorder: AVAudioRecorder {

    private var _url: URL
    private var _isRecording = false
    private var _currentTime: TimeInterval = 0
    private var _isMeteringEnabled = true

    init() {
        _url = FileManager.default.temporaryDirectory.appendingPathComponent("mock.m4a")

        // Create minimal settings for initialization
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 22050.0,
            AVNumberOfChannelsKey: 1
        ]

        try! super.init(url: _url, settings: settings)
    }

    override var url: URL {
        return _url
    }

    override var isRecording: Bool {
        return _isRecording
    }

    override var currentTime: TimeInterval {
        return _currentTime
    }

    override var isMeteringEnabled: Bool {
        get { return _isMeteringEnabled }
        set { _isMeteringEnabled = newValue }
    }

    override func prepareToRecord() -> Bool {
        return true
    }

    override func record() -> Bool {
        _isRecording = true
        return true
    }

    override func stop() {
        _isRecording = false
        // Simulate successful recording
        delegate?.audioRecorderDidFinishRecording(self, successfully: true)
    }

    override func pause() {
        _isRecording = false
    }
}

// MARK: - Error Types for Testing

enum MockError: Error, LocalizedError {
    case simulatedFailure(String)
    case sessionConfigurationFailed
    case recorderCreationFailed

    var errorDescription: String? {
        switch self {
        case .simulatedFailure(let message):
            return "Mock simulated failure: \(message)"
        case .sessionConfigurationFailed:
            return "Mock session configuration failed"
        case .recorderCreationFailed:
            return "Mock recorder creation failed"
        }
    }
}

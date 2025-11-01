import Combine
import Foundation

@MainActor
protocol AudioRepository {
    // MARK: - Playback Properties
    var playingMemo: Memo? { get set }
    var isPlaying: Bool { get set }

    // MARK: - Recording State Properties
    var isRecording: Bool { get }
    var recordingTime: TimeInterval { get }
    var hasMicrophonePermission: Bool { get }
    var isBackgroundTaskActive: Bool { get }
    var recordingStoppedAutomatically: Bool { get }
    var autoStopMessage: String? { get }
    var isInCountdown: Bool { get }
    var remainingTime: TimeInterval { get }

    // MARK: - Reactive Publishers
    var isRecordingPublisher: AnyPublisher<Bool, Never> { get }
    var recordingTimePublisher: AnyPublisher<TimeInterval, Never> { get }
    var permissionStatusPublisher: AnyPublisher<MicrophonePermissionStatus, Never> { get }
    /// Emits a tuple of (isInCountdown, remainingTime)
    var countdownPublisher: AnyPublisher<(Bool, TimeInterval), Never> { get }

    // MARK: - Audio Metering Publishers
    /// Normalized average audio level (0.0 to 1.0), smoothed; emits only while recording
    var audioLevelPublisher: AnyPublisher<Double, Never> { get }
    /// Normalized peak audio level (0.0 to 1.0); captures transients
    var peakLevelPublisher: AnyPublisher<Double, Never> { get }
    /// Voice activity level (0.0 to 1.0); distinguishes speech from silence
    var voiceActivityPublisher: AnyPublisher<Double, Never> { get }
    /// Frequency band energy for voice-centric visualization
    var frequencyBandsPublisher: AnyPublisher<FrequencyBands, Never> { get }

    /// Emits pause state updates
    var isPausedPublisher: AnyPublisher<Bool, Never> { get }
    /// Current pause state snapshot
    var isPaused: Bool { get }

    // MARK: - Playback Control
    func playAudio(at url: URL) throws
    func pauseAudio()
    func stopAudio()
    func isAudioPlaying(for memo: Memo) -> Bool

    // MARK: - Recording Control
    /// Start recording with optional per-session cap override (seconds). Pass nil for default behavior.
    func startRecording(allowedCap: TimeInterval?) async throws -> UUID
    /// Backward-compatible start method (calls startRecording(allowedCap: nil))
    func startRecording() async throws -> UUID
    func stopRecording()
    func pauseRecording()
    func resumeRecording()
    func checkMicrophonePermissions()

    // MARK: - Recording Callbacks
    func setRecordingFinishedHandler(_ handler: @escaping (URL) -> Void)
    func setRecordingFailedHandler(_ handler: @escaping (Error) -> Void)
}

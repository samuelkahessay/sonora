import AVFoundation
@preconcurrency import Combine
import Foundation

final class AudioPlayerProxy: NSObject, AVAudioPlayerDelegate {
    var onFinish: (() -> Void)?

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        onFinish?()
    }
}

@MainActor
final class AudioRepositoryImpl: ObservableObject, AudioRepository {
    @Published var playingMemo: Memo?
    @Published var isPlaying = false

    // MARK: - Audio Services
    private var audioPlayer: AVAudioPlayer?
    private var audioPlayerProxy = AudioPlayerProxy()
    private let backgroundAudioService: BackgroundAudioService

    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    private let isRecordingSubject = CurrentValueSubject<Bool, Never>(false)
    private let recordingTimeSubject = CurrentValueSubject<TimeInterval, Never>(0)
    private let permissionStatusSubject = CurrentValueSubject<MicrophonePermissionStatus, Never>(.notDetermined)
    private let countdownSubject = CurrentValueSubject<(Bool, TimeInterval), Never>((false, 0))
    private let audioLevelSubject = CurrentValueSubject<Double, Never>(0)
    private let isPausedSubject = CurrentValueSubject<Bool, Never>(false)

    // MARK: - AudioRepository Publishers
    var isRecordingPublisher: AnyPublisher<Bool, Never> { isRecordingSubject.eraseToAnyPublisher() }
    var recordingTimePublisher: AnyPublisher<TimeInterval, Never> { recordingTimeSubject.eraseToAnyPublisher() }
    var permissionStatusPublisher: AnyPublisher<MicrophonePermissionStatus, Never> { permissionStatusSubject.eraseToAnyPublisher() }
    var countdownPublisher: AnyPublisher<(Bool, TimeInterval), Never> { countdownSubject.eraseToAnyPublisher() }
    var audioLevelPublisher: AnyPublisher<Double, Never> { audioLevelSubject.eraseToAnyPublisher() }
    var isPausedPublisher: AnyPublisher<Bool, Never> { isPausedSubject.eraseToAnyPublisher() }

    init(backgroundAudioService: BackgroundAudioService) {
        self.backgroundAudioService = backgroundAudioService
        setupAudioPlayerProxy()
        setupBackgroundAudioService()
        setupPolling()
        print("🎵 AudioRepositoryImpl: Initialized with BackgroundAudioService integration")
    }

    deinit {
        print("🎵 AudioRepositoryImpl: Deinitialized")
    }

    private func setupAudioPlayerProxy() {
        audioPlayerProxy.onFinish = { [weak self] in
            DispatchQueue.main.async {
                self?.stopAudio()
            }
        }
    }

    /// Setup BackgroundAudioService integration for recording functionality
    private func setupBackgroundAudioService() {
        // Configure BackgroundAudioService callbacks
        backgroundAudioService.onRecordingFinished = { [weak self] url in
            Task { @MainActor in
                self?.handleRecordingFinished(at: url)
            }
        }

        backgroundAudioService.onRecordingFailed = { [weak self] error in
            Task { @MainActor in
                self?.handleRecordingFailed(error)
            }
        }

        backgroundAudioService.onBackgroundTaskExpired = { [weak self] in
            Task { @MainActor in
                self?.handleBackgroundTaskExpired()
            }
        }

        // Observe background audio service state
        backgroundAudioService.$isRecording
            .sink { [weak self] isRecording in
                self?.isRecordingSubject.send(isRecording)
                // Additional state management if needed
                print("🎵 AudioRepositoryImpl: Recording state changed: \(isRecording)")
            }
            .store(in: &cancellables)

        backgroundAudioService.$audioLevel
            .sink { [weak self] level in
                self?.audioLevelSubject.send(level)
            }
            .store(in: &cancellables)

        backgroundAudioService.$isPaused
            .sink { [weak self] paused in
                self?.isPausedSubject.send(paused)
            }
            .store(in: &cancellables)

        print("🎵 AudioRepositoryImpl: BackgroundAudioService configured")
    }

    // MARK: - Internal Polling for UI Streams
    private func setupPolling() {
        // 0.1s polling to expose stable UI publishers; service also updates internally
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                // Recording time
                self.recordingTimeSubject.send(self.backgroundAudioService.recordingTime)
                // Permission status
                self.permissionStatusSubject.send(MicrophonePermissionStatus.current())
                // Countdown
                self.countdownSubject.send((self.backgroundAudioService.isInCountdown, self.backgroundAudioService.remainingTime))
            }
            .store(in: &cancellables)

        // Seed initial values
        isRecordingSubject.send(backgroundAudioService.isRecording)
        recordingTimeSubject.send(backgroundAudioService.recordingTime)
        permissionStatusSubject.send(MicrophonePermissionStatus.current())
        countdownSubject.send((backgroundAudioService.isInCountdown, backgroundAudioService.remainingTime))
        audioLevelSubject.send(backgroundAudioService.audioLevel)
        isPausedSubject.send(backgroundAudioService.isPaused)
    }

    func playAudio(at url: URL) throws {
        // Stop any active recording before playing
        if backgroundAudioService.isRecording {
            backgroundAudioService.stopRecording()
        }

        // If the same memo is playing, pause it
        if let memo = playingMemo, memo.fileURL == url, isPlaying {
            audioPlayer?.pause()
            isPlaying = false
            return
        }

        // Configure audio session for playback
        do {
            try configureAudioSessionForPlayback()
        } catch {
            throw mapToRecordingError(error)
        }

        // Create and configure audio player
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
        } catch {
            throw SonoraError.audioRecordingFailed(error.localizedDescription)
        }
        audioPlayer?.delegate = audioPlayerProxy
        audioPlayer?.play()

        let playingMemoForURL = Memo(
            filename: url.lastPathComponent,
            fileURL: url,
            creationDate: Date()
        )

        playingMemo = playingMemoForURL
        isPlaying = true

        print("🎵 AudioRepositoryImpl: Started playing \(url.lastPathComponent)")
    }

    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
    }

    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        playingMemo = nil
        isPlaying = false

        // Only deactivate audio session if not recording
        if !backgroundAudioService.isRecording {
            let audioSession = AVAudioSession.sharedInstance()
            try? audioSession.setActive(false)
        }

        print("🎵 AudioRepositoryImpl: Stopped audio playback")
    }

    func isAudioPlaying(for memo: Memo) -> Bool {
        playingMemo?.id == memo.id && isPlaying
    }

    // MARK: - Recording Functionality (BackgroundAudioService Integration)

    /// Start recording with proper background support and return memo ID
    func startRecording(allowedCap: TimeInterval?) async throws -> UUID {
        // Generate memo ID for this recording session
        let memoId = UUID()

        // Stop any playing audio before recording
        if isPlaying {
            stopAudio()
        }

        print("🎵 AudioRepositoryImpl: Starting background recording for memo: \(memoId)")
        do {
            try backgroundAudioService.startRecording(capOverride: allowedCap)
        } catch {
            throw mapToRecordingError(error)
        }

        return memoId
    }

    /// Backward-compatible start method
    func startRecording() async throws -> UUID {
        try await startRecording(allowedCap: nil)
    }

    /// Stop the current recording
    func stopRecording() {
        print("🎵 AudioRepositoryImpl: Stopping background recording")
        backgroundAudioService.stopRecording()
    }

    func pauseRecording() {
        print("🎵 AudioRepositoryImpl: Pausing background recording")
        backgroundAudioService.pauseRecording()
    }

    func resumeRecording() {
        print("🎵 AudioRepositoryImpl: Resuming background recording")
        backgroundAudioService.resumeRecording()
    }

    /// Check if currently recording
    var isRecording: Bool {
        backgroundAudioService.isRecording
    }

    /// Get current recording time
    var recordingTime: TimeInterval {
        backgroundAudioService.recordingTime
    }

    /// Pause state
    var isPaused: Bool { backgroundAudioService.isPaused }

    /// Check microphone permissions
    func checkMicrophonePermissions() {
        backgroundAudioService.checkMicrophonePermissions()
    }

    /// Check if microphone permission is granted
    var hasMicrophonePermission: Bool {
        backgroundAudioService.hasPermission
    }

    /// Check if background task is active
    var isBackgroundTaskActive: Bool {
        backgroundAudioService.backgroundTaskActive
    }

    /// Whether the recording was stopped automatically (e.g., by a limit)
    var recordingStoppedAutomatically: Bool {
        backgroundAudioService.recordingStoppedAutomatically
    }

    /// Message describing why the recording stopped automatically
    var autoStopMessage: String? {
        backgroundAudioService.autoStopMessage
    }

    /// Whether a countdown is active before auto-stop
    var isInCountdown: Bool {
        backgroundAudioService.isInCountdown
    }

    /// Remaining time in countdown (if any)
    var remainingTime: TimeInterval {
        backgroundAudioService.remainingTime
    }

    // MARK: - Recording Callbacks

    /// Set handler for when recording finishes successfully
    func setRecordingFinishedHandler(_ handler: @escaping (URL) -> Void) {
        backgroundAudioService.onRecordingFinished = handler
    }

    /// Set handler for when recording fails
    func setRecordingFailedHandler(_ handler: @escaping (Error) -> Void) {
        backgroundAudioService.onRecordingFailed = handler
    }

    // MARK: - Audio Session Management

    /// Configure audio session specifically for playback
    private func configureAudioSessionForPlayback() throws {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            // If recording is active, don't change the session
            if backgroundAudioService.isRecording {
                print("🎵 AudioRepositoryImpl: Recording active, keeping current session configuration")
                return
            }

            // Configure for playback only
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true)

            print("🎵 AudioRepositoryImpl: Audio session configured for playback")

        } catch {
            print("❌ AudioRepositoryImpl: Failed to configure audio session for playback: \(error)")
            throw RecordingError.audioSessionFailed(error.localizedDescription)
        }
    }

    // MARK: - Error Mapping

    private func mapToRecordingError(_ error: Error) -> RecordingError {
        if let svc = error as? AudioServiceError {
            switch svc {
            case .permissionDenied:
                return .permissionDenied
            case .alreadyRecording:
                return .alreadyRecording
            case .notRecording:
                return .notRecording
            case .sessionConfigurationFailed(let underlying):
                return .audioSessionFailed(underlying.localizedDescription)
            case .recordingStartFailed:
                return .recordingFailed("Failed to start recording")
            case .recordingFailed(let message):
                return .recordingFailed(message)
            case .encodingError(let underlying):
                return .recordingFailed("Encoding error: \(underlying?.localizedDescription ?? "Unknown")")
            case .backgroundTaskFailed:
                return .backgroundTaskFailed
            }
        }
        return .recordingFailed(error.localizedDescription)
    }

    // MARK: - BackgroundAudioService Callbacks

    /// Handle successful recording completion
    private func handleRecordingFinished(at url: URL) {
        print("🎵 AudioRepositoryImpl: Recording finished at \(url.lastPathComponent)")

        // Save the recording to the documents directory if needed
        // This would typically trigger memo creation in the repository layer

        // Notify observers if needed
        objectWillChange.send()
    }

    /// Handle recording failure
    private func handleRecordingFailed(_ error: Error) {
        print("❌ AudioRepositoryImpl: Recording failed: \(error.localizedDescription)")

        // Handle error appropriately - could show user notification
        // For now, just log the error
    }

    /// Handle background task expiration
    private func handleBackgroundTaskExpired() {
        print("⏰ AudioRepositoryImpl: Background task expired during recording")

        // Could show user notification that recording was stopped due to background limits
        // For now, just log the event
    }

    // MARK: - Debug Information

    /// Get comprehensive debug information about audio state
    var debugInfo: String {
        """
        AudioRepositoryImpl Debug Info:
        Playback:
        - Playing Memo: \(playingMemo?.filename ?? "None")
        - Is Playing: \(isPlaying)

        Recording (BackgroundAudioService):
        - Is Recording: \(backgroundAudioService.isRecording)
        - Recording Time: \(backgroundAudioService.recordingTime)
        - Has Permission: \(backgroundAudioService.hasPermission)
        - Session Active: \(backgroundAudioService.isSessionActive)
        - Background Task Active: \(backgroundAudioService.backgroundTaskActive)
        """
    }

    // Testing helper removed as unused
}

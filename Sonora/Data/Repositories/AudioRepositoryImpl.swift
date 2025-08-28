import Foundation
import AVFoundation
import Combine

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
    private let backgroundAudioService = BackgroundAudioService()
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    
    // MARK: - Combine
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupAudioPlayerProxy()
        setupBackgroundAudioService()
        print("🎵 AudioRepositoryImpl: Initialized with BackgroundAudioService integration")
    }
    
    deinit {
        cancellables.removeAll()
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
                // Can be used for additional state management if needed
                print("🎵 AudioRepositoryImpl: Recording state changed: \(isRecording)")
            }
            .store(in: &cancellables)
        
        print("🎵 AudioRepositoryImpl: BackgroundAudioService configured")
    }
    
    func loadAudioFiles() -> [Memo] {
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: documentsPath, 
                includingPropertiesForKeys: [.creationDateKey], 
                options: []
            )
            
            let audioFiles = files.filter { $0.pathExtension == "m4a" }
            var loadedMemos: [Memo] = []
            
            for file in audioFiles {
                let resourceValues = try file.resourceValues(forKeys: [.creationDateKey])
                let creationDate = resourceValues.creationDate ?? Date()
                
                let memo = Memo(
                    filename: file.lastPathComponent,
                    url: file,
                    createdAt: creationDate
                )
                loadedMemos.append(memo)
            }
            
            return loadedMemos.sorted { $0.createdAt > $1.createdAt }
        } catch {
            print("❌ AudioRepository: Error loading audio files: \(error)")
            return []
        }
    }
    
    func deleteAudioFile(at url: URL) throws {
        try FileManager.default.removeItem(at: url)
        
        if playingMemo?.url == url {
            stopAudio()
        }
    }
    
    func saveAudioFile(from sourceURL: URL, to destinationURL: URL) throws {
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }
    
    func getAudioMetadata(for url: URL) throws -> (duration: TimeInterval, creationDate: Date) {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        
        let resourceValues = try url.resourceValues(forKeys: [.creationDateKey])
        let creationDate = resourceValues.creationDate ?? Date()
        
        return (duration: duration, creationDate: creationDate)
    }
    
    func playAudio(at url: URL) throws {
        // Stop any active recording before playing
        if backgroundAudioService.isRecording {
            backgroundAudioService.stopRecording()
        }
        
        // If the same memo is playing, pause it
        if let memo = playingMemo, memo.url == url, isPlaying {
            audioPlayer?.pause()
            isPlaying = false
            return
        }
        
        // Configure audio session for playback
        try configureAudioSessionForPlayback()
        
        // Create and configure audio player
        audioPlayer = try AVAudioPlayer(contentsOf: url)
        audioPlayer?.delegate = audioPlayerProxy
        audioPlayer?.play()
        
        let playingMemoForURL = Memo(
            filename: url.lastPathComponent,
            url: url,
            createdAt: Date()
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
        return playingMemo?.id == memo.id && isPlaying
    }
    
    func getDocumentsDirectory() -> URL {
        return documentsPath
    }
    
    // MARK: - Recording Functionality (BackgroundAudioService Integration)
    
    /// Start recording with proper background support and return memo ID
    func startRecording() async throws -> UUID {
        // Generate memo ID for this recording session
        let memoId = UUID()
        
        // Stop any playing audio before recording
        if isPlaying {
            stopAudio()
        }
        
        print("🎵 AudioRepositoryImpl: Starting background recording for memo: \(memoId)")
        try backgroundAudioService.startRecording()
        
        return memoId
    }
    
    /// Start recording synchronously (for use case compatibility)
    func startRecordingSync() throws {
        // Stop any playing audio before recording
        if isPlaying {
            stopAudio()
        }
        
        print("🎵 AudioRepositoryImpl: Starting background recording (sync)")
        
        do {
            try backgroundAudioService.startRecording()
            print("🎵 AudioRepositoryImpl: Background recording started successfully (sync)")
        } catch {
            print("❌ AudioRepositoryImpl: Failed to start recording (sync): \(error)")
            throw error
        }
    }
    
    /// Stop the current recording
    func stopRecording() {
        print("🎵 AudioRepositoryImpl: Stopping background recording")
        backgroundAudioService.stopRecording()
    }
    
    /// Check if currently recording
    var isRecording: Bool {
        return backgroundAudioService.isRecording
    }
    
    /// Get current recording time
    var recordingTime: TimeInterval {
        return backgroundAudioService.recordingTime
    }
    
    /// Check microphone permissions
    func checkMicrophonePermissions() {
        backgroundAudioService.checkMicrophonePermissions()
    }
    
    /// Check if microphone permission is granted
    var hasMicrophonePermission: Bool {
        return backgroundAudioService.hasPermission
    }
    
    /// Check if background task is active
    var isBackgroundTaskActive: Bool {
        return backgroundAudioService.backgroundTaskActive
    }
    
    /// Whether the recording was stopped automatically (e.g., by a limit)
    var recordingStoppedAutomatically: Bool {
        return backgroundAudioService.recordingStoppedAutomatically
    }
    
    /// Message describing why the recording stopped automatically
    var autoStopMessage: String? {
        return backgroundAudioService.autoStopMessage
    }
    
    /// Whether a countdown is active before auto-stop
    var isInCountdown: Bool {
        return backgroundAudioService.isInCountdown
    }
    
    /// Remaining time in countdown (if any)
    var remainingTime: TimeInterval {
        return backgroundAudioService.remainingTime
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
            throw error
        }
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
        return """
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
    
    // MARK: - Testing Functionality
    
    /// Test background recording functionality
    /// This method helps verify that recording continues when the device is locked
    func testBackgroundRecording() async {
        print("🧪 AudioRepositoryImpl: Starting background recording test")
        
        do {
            // Start recording
            try await startRecording()
            print("🧪 AudioRepositoryImpl: Recording started successfully")
            print("🧪 Background task active: \(isBackgroundTaskActive)")
            
            // Log state every 2 seconds for 10 seconds
            for i in 1...5 {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                print("🧪 AudioRepositoryImpl: Test \(i * 2)s - Recording: \(isRecording), Time: \(recordingTime)s, Background: \(isBackgroundTaskActive)")
            }
            
            // Stop recording
            stopRecording()
            print("🧪 AudioRepositoryImpl: Recording stopped")
            print("🧪 AudioRepositoryImpl: Background recording test completed")
            print("🧪 Instructions: To test background recording:")
            print("🧪   1. Call this method")
            print("🧪   2. Lock your phone during the 10-second recording")
            print("🧪   3. Check logs to verify recording continued in background")
            
        } catch {
            print("❌ AudioRepositoryImpl: Background recording test failed: \(error)")
        }
    }
}

import Foundation
import AVFoundation
import Combine

@MainActor
protocol AudioRepository: ObservableObject {
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
    
    // MARK: - File Management
    func loadAudioFiles() -> [Memo]
    func deleteAudioFile(at url: URL) throws
    func saveAudioFile(from sourceURL: URL, to destinationURL: URL) throws
    func getAudioMetadata(for url: URL) throws -> (duration: TimeInterval, creationDate: Date)
    func getDocumentsDirectory() -> URL
    
    // MARK: - Playback Control
    func playAudio(at url: URL) throws
    func pauseAudio()
    func stopAudio()
    func isAudioPlaying(for memo: Memo) -> Bool
    
    // MARK: - Recording Control
    func startRecording() async throws -> UUID
    func stopRecording()
    func checkMicrophonePermissions()
    
    // MARK: - Recording Callbacks
    func setRecordingFinishedHandler(_ handler: @escaping (URL) -> Void)
    func setRecordingFailedHandler(_ handler: @escaping (Error) -> Void)
}

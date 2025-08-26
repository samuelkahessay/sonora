import Foundation
import Combine
import SwiftUI

/// ViewModel for handling audio recording functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class RecordingViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let audioRecordingService: AudioRecordingService
    private let memoRepository: MemoRepository
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasPermission: Bool = false
    @Published var recordingStoppedAutomatically: Bool = false
    @Published var autoStopMessage: String?
    @Published var isInCountdown: Bool = false
    @Published var remainingTime: TimeInterval = 0
    @Published var showAutoStopAlert: Bool = false
    
    // MARK: - Computed Properties
    
    /// Status text for the current recording state
    var recordingStatusText: String {
        if !hasPermission {
            return "Microphone Permission Required"
        } else if isRecording {
            if isInCountdown {
                return "Recording ends in"
            } else {
                return "Recording..."
            }
        } else {
            return "Ready to Record"
        }
    }
    
    /// Formatted recording time string
    var formattedRecordingTime: String {
        formatTime(recordingTime)
    }
    
    /// Formatted remaining time for countdown
    var formattedRemainingTime: String {
        return "\(Int(ceil(remainingTime)))"
    }
    
    /// Recording button color based on state
    var recordingButtonColor: Color {
        isRecording ? .red : .blue
    }
    
    /// Whether to show the recording indicator
    var shouldShowRecordingIndicator: Bool {
        isRecording
    }
    
    // MARK: - Initialization
    
    init(
        audioRecordingService: AudioRecordingService,
        memoRepository: MemoRepository
    ) {
        self.audioRecordingService = audioRecordingService
        self.memoRepository = memoRepository
        
        setupBindings()
        setupRecordingCallback()
        
        print("🎬 RecordingViewModel: Initialized with dependency injection")
    }
    
    /// Convenience initializer using DIContainer
    convenience init() {
        let container = DIContainer.shared
        self.init(
            audioRecordingService: container.audioRecordingService(),
            memoRepository: container.memoRepository()
        )
    }
    
    // MARK: - Setup Methods
    
    private func setupBindings() {
        // Use a timer to periodically sync with the service
        // This avoids the objectWillChange type compatibility issue
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateFromService()
            }
            .store(in: &cancellables)
        
        // Initial update
        updateFromService()
    }
    
    private func updateFromService() {
        isRecording = audioRecordingService.isRecording
        recordingTime = audioRecordingService.recordingTime
        hasPermission = audioRecordingService.hasPermission
        recordingStoppedAutomatically = audioRecordingService.recordingStoppedAutomatically
        autoStopMessage = audioRecordingService.autoStopMessage
        isInCountdown = audioRecordingService.isInCountdown
        remainingTime = audioRecordingService.remainingTime
        
        // Update alert state
        showAutoStopAlert = recordingStoppedAutomatically
    }
    
    private func setupRecordingCallback() {
        print("🔧 RecordingViewModel: Setting up callback function")
        audioRecordingService.onRecordingFinished = { [weak self] url in
            Task { @MainActor in
                print("🎤 RecordingViewModel: Recording finished callback triggered for \(url.lastPathComponent)")
                self?.handleRecordingFinished(at: url)
            }
        }
        print("🔧 RecordingViewModel: Callback function set successfully")
    }
    
    // MARK: - Public Methods
    
    /// Start audio recording
    func startRecording() {
        print("▶️ RecordingViewModel: Starting recording")
        audioRecordingService.startRecording()
    }
    
    /// Stop audio recording
    func stopRecording() {
        print("🛑 RecordingViewModel: Stopping recording")
        audioRecordingService.stopRecording()
    }
    
    /// Toggle recording state (start if stopped, stop if recording)
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    /// Request microphone permission
    func requestPermission() {
        print("🎤 RecordingViewModel: Requesting microphone permission")
        audioRecordingService.checkPermissions()
    }
    
    /// Dismiss auto-stop alert
    func dismissAutoStopAlert() {
        showAutoStopAlert = false
        recordingStoppedAutomatically = false
        autoStopMessage = nil
    }
    
    /// Format time interval to MM:SS string
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    // MARK: - Private Methods
    
    private func handleRecordingFinished(at url: URL) {
        print("🎤 RecordingViewModel: Handling recording finished for \(url.lastPathComponent)")
        print("🎤 RecordingViewModel: Calling memoRepository.handleNewRecording")
        memoRepository.handleNewRecording(at: url)
    }
    
    // MARK: - Lifecycle
    
    func onViewAppear() {
        print("🎬 RecordingViewModel: View appeared, ensuring callback is set")
        setupRecordingCallback()
    }
    
    func onViewDisappear() {
        print("🎬 RecordingViewModel: View disappeared")
        // Stop recording if in progress to prevent issues
        if isRecording {
            stopRecording()
        }
    }
}

// MARK: - View State Helpers

extension RecordingViewModel {
    
    /// Get recording button icon name
    var recordingButtonIconName: String {
        isRecording ? "" : "mic.fill" // Empty for stop state (shows square)
    }
    
    /// Get recording button scale effect
    var recordingButtonScale: Double {
        isRecording ? 0.9 : 1.0
    }
    
    /// Get countdown scale effect for animation
    var countdownScale: Double {
        remainingTime.truncatingRemainder(dividingBy: 1.0) < 0.5 ? 1.1 : 1.0
    }
    
    /// Get status text color
    var statusTextColor: Color {
        if !hasPermission {
            return .red
        } else if isInCountdown {
            return .orange
        } else if isRecording {
            return .red
        } else {
            return .primary
        }
    }
    
    /// Get countdown text color
    var countdownTextColor: Color {
        .red
    }
}

// MARK: - Debug Helpers

extension RecordingViewModel {
    
    /// Get debug information about the current state
    var debugInfo: String {
        return """
        RecordingViewModel State:
        - isRecording: \(isRecording)
        - recordingTime: \(formattedRecordingTime)
        - hasPermission: \(hasPermission)
        - isInCountdown: \(isInCountdown)
        - remainingTime: \(formattedRemainingTime)
        - recordingStoppedAutomatically: \(recordingStoppedAutomatically)
        """
    }
}
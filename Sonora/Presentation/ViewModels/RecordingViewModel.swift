import Foundation
import Combine
import SwiftUI

/// ViewModel for handling audio recording functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class RecordingViewModel: ObservableObject {
    
    // MARK: - Dependencies
    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let requestPermissionUseCase: RequestMicrophonePermissionUseCaseProtocol
    private let handleNewRecordingUseCase: HandleNewRecordingUseCaseProtocol
    private let audioRecordingService: AudioRecordingService // Still needed for state updates
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Debounce Management
    private var recordButtonDebounceTask: Task<Void, Never>?
    
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
        startRecordingUseCase: StartRecordingUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        requestPermissionUseCase: RequestMicrophonePermissionUseCaseProtocol,
        handleNewRecordingUseCase: HandleNewRecordingUseCaseProtocol,
        audioRecordingService: AudioRecordingService
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.requestPermissionUseCase = requestPermissionUseCase
        self.handleNewRecordingUseCase = handleNewRecordingUseCase
        self.audioRecordingService = audioRecordingService
        
        setupBindings()
        setupRecordingCallback()
        
        print("🎬 RecordingViewModel: Initialized with dependency injection")
    }
    
    deinit {
        // Cancel any pending debounce task
        recordButtonDebounceTask?.cancel()
        print("🎬 RecordingViewModel: Deinitialized and cleaned up debounce task")
    }
    
    /// Convenience initializer using DIContainer
    convenience init() {
        let container = DIContainer.shared
        let audioService = container.audioRecordingService()
        let memoRepository = container.memoRepository()
        
        self.init(
            startRecordingUseCase: StartRecordingUseCase(audioRecordingService: audioService),
            stopRecordingUseCase: StopRecordingUseCase(audioRecordingService: audioService),
            requestPermissionUseCase: RequestMicrophonePermissionUseCase(audioRecordingService: audioService),
            handleNewRecordingUseCase: HandleNewRecordingUseCase(memoRepository: memoRepository),
            audioRecordingService: audioService
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
        do {
            try startRecordingUseCase.execute()
        } catch {
            print("❌ RecordingViewModel: Failed to start recording: \(error)")
        }
    }
    
    /// Stop audio recording
    func stopRecording() {
        print("🛑 RecordingViewModel: Stopping recording")
        do {
            try stopRecordingUseCase.execute()
        } catch {
            print("❌ RecordingViewModel: Failed to stop recording: \(error)")
        }
    }
    
    /// Toggle recording state (start if stopped, stop if recording)
    /// Implements 300ms debouncing to prevent rapid button tapping issues
    func toggleRecording() {
        print("🎛️ RecordingViewModel: Toggle recording requested")
        
        // Cancel any pending debounce task
        recordButtonDebounceTask?.cancel()
        
        // Create new debounced task
        recordButtonDebounceTask = Task {
            do {
                // 300ms debounce delay
                try await Task.sleep(nanoseconds: 300_000_000) // 300ms
                
                // Check if task was cancelled during sleep
                guard !Task.isCancelled else {
                    print("🎛️ RecordingViewModel: Toggle recording cancelled during debounce")
                    return
                }
                
                // Execute the actual toggle operation
                print("🎛️ RecordingViewModel: Executing debounced toggle recording")
                
                if isRecording {
                    stopRecording()
                } else {
                    startRecording()
                }
                
                // Clear the task reference
                recordButtonDebounceTask = nil
                
            } catch {
                // Task was cancelled or failed
                print("🎛️ RecordingViewModel: Toggle recording debounce interrupted: \(error)")
                recordButtonDebounceTask = nil
            }
        }
    }
    
    /// Request microphone permission
    func requestPermission() {
        print("🎤 RecordingViewModel: Requesting microphone permission")
        let hasPermission = requestPermissionUseCase.execute()
        print("🎤 RecordingViewModel: Permission result: \(hasPermission)")
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
        Task {
            do {
                try await handleNewRecordingUseCase.execute(at: url)
            } catch {
                print("❌ RecordingViewModel: Failed to handle new recording: \(error)")
            }
        }
    }
    
    // MARK: - Lifecycle
    
    func onViewAppear() {
        print("🎬 RecordingViewModel: View appeared, ensuring callback is set")
        setupRecordingCallback()
    }
    
    func onViewDisappear() {
        print("🎬 RecordingViewModel: View disappeared")
        
        // Cancel any pending debounce task
        recordButtonDebounceTask?.cancel()
        
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
        - debounceTaskActive: \(recordButtonDebounceTask != nil)
        """
    }
    
    /// Test rapid button tapping to verify debouncing works correctly
    /// This method simulates rapid button presses to ensure only the last one executes
    func testRapidButtonTapping() {
        print("🧪 RecordingViewModel: Testing rapid button tapping (5 quick taps)")
        
        // Simulate 5 rapid button taps with 50ms intervals
        for i in 1...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.05) {
                print("🧪 RecordingViewModel: Rapid tap #\(i)")
                self.toggleRecording()
            }
        }
        
        // Check result after debounce period
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            print("🧪 RecordingViewModel: Rapid tap test completed")
            print("🧪 Result: isRecording = \(self.isRecording)")
            print("🧪 Expected: Only one toggle should have executed")
        }
    }
}
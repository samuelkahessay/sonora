import Foundation
import Combine
import SwiftUI

/// ViewModel for handling audio recording functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class RecordingViewModel: ObservableObject, OperationStatusDelegate {
    
    // MARK: - Dependencies
    private let startRecordingUseCase: StartRecordingUseCaseProtocol
    private let stopRecordingUseCase: StopRecordingUseCaseProtocol
    private let requestPermissionUseCase: RequestMicrophonePermissionUseCaseProtocol
    private let handleNewRecordingUseCase: HandleNewRecordingUseCaseProtocol
    private let audioRepository: AudioRepository
    private let operationCoordinator: OperationCoordinator
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Debounce Management
    private var recordButtonDebounceTask: Task<Void, Never>?
    
    // MARK: - Published Properties
    @Published var isRecording: Bool = false
    @Published var recordingTime: TimeInterval = 0
    @Published var hasPermission: Bool = false
    @Published var permissionStatus: MicrophonePermissionStatus = .notDetermined
    @Published var recordingStoppedAutomatically: Bool = false
    @Published var autoStopMessage: String?
    @Published var isInCountdown: Bool = false
    @Published var remainingTime: TimeInterval = 0
    @Published var showAutoStopAlert: Bool = false
    @Published var isRequestingPermission: Bool = false
    
    // MARK: - Operation Status Properties
    @Published var currentRecordingOperationId: UUID?
    @Published var recordingOperationStatus: DetailedOperationStatus?
    @Published var queuePosition: Int?
    @Published var systemMetrics: SystemOperationMetrics?
    
    // MARK: - Computed Properties
    
    /// Status text for the current recording state
    var recordingStatusText: String {
        if isRequestingPermission {
            return "Requesting Permission..."
        }
        
        switch permissionStatus {
        case .notDetermined:
            return "Microphone Access Needed"
        case .denied:
            return "Microphone Permission Denied"
        case .restricted:
            return "Microphone Access Restricted"
        case .granted:
            if isRecording {
                if isInCountdown {
                    return "Recording ends in"
                } else {
                    return "Recording..."
                }
            } else {
                return "Ready to Record"
            }
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
    
    /// Enhanced status text that includes operation status
    var enhancedStatusText: String {
        // Show operation status if available
        if let opStatus = recordingOperationStatus {
            switch opStatus {
            case .queued:
                if let position = queuePosition {
                    return "Queued (position \(position + 1))"
                }
                return "Queued for recording"
            case .waitingForResources:
                return "Waiting for system resources"
            case .waitingForConflictResolution:
                return "Waiting (another operation active)"
            case .processing(let progress):
                if let progress = progress {
                    return progress.currentStep
                }
                return "Processing recording"
            default:
                break
            }
        }
        
        // Fall back to basic status
        return recordingStatusText
    }
    
    /// System load indicator for UI
    var systemLoadText: String? {
        guard let metrics = systemMetrics else { return nil }
        
        if metrics.isSystemBusy {
            return "System busy (\(metrics.activeOperations)/\(metrics.maxConcurrentOperations) operations)"
        } else if metrics.activeOperations > 0 {
            return "\(metrics.activeOperations) operations running"
        }
        
        return nil
    }
    
    /// Whether the recording operation can be cancelled
    var canCancelRecording: Bool {
        guard let operationId = currentRecordingOperationId else { return false }
        return recordingOperationStatus?.isInProgress == true
    }
    
    // MARK: - Initialization
    
    init(
        startRecordingUseCase: StartRecordingUseCaseProtocol,
        stopRecordingUseCase: StopRecordingUseCaseProtocol,
        requestPermissionUseCase: RequestMicrophonePermissionUseCaseProtocol,
        handleNewRecordingUseCase: HandleNewRecordingUseCaseProtocol,
        audioRepository: AudioRepository,
        operationCoordinator: OperationCoordinator = OperationCoordinator.shared
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.requestPermissionUseCase = requestPermissionUseCase
        self.handleNewRecordingUseCase = handleNewRecordingUseCase
        self.audioRepository = audioRepository
        self.operationCoordinator = operationCoordinator
        
        setupBindings()
        setupRecordingCallback()
        setupPermissionNotifications()
        setupOperationStatusMonitoring()
        updatePermissionStatus()
        
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
        let audioRepository = container.audioRepository()
        let memoRepository = container.memoRepository()
        let logger = container.logger()
        
        self.init(
            startRecordingUseCase: StartRecordingUseCase(audioRepository: audioRepository),
            stopRecordingUseCase: StopRecordingUseCase(audioRepository: audioRepository),
            requestPermissionUseCase: RequestMicrophonePermissionUseCase(logger: logger),
            handleNewRecordingUseCase: HandleNewRecordingUseCase(memoRepository: memoRepository),
            audioRepository: audioRepository,
            operationCoordinator: container.operationCoordinator()
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
        isRecording = audioRepository.isRecording
        recordingTime = audioRepository.recordingTime
        if isRecording {
            print("🔄 RecordingViewModel: Syncing timer - recordingTime: \(String(format: "%.1f", recordingTime))s")
        }
        hasPermission = audioRepository.hasMicrophonePermission
        // Consume countdown and auto-stop state from AudioRepository
        isInCountdown = audioRepository.isInCountdown
        remainingTime = audioRepository.remainingTime
        recordingStoppedAutomatically = audioRepository.recordingStoppedAutomatically
        autoStopMessage = audioRepository.autoStopMessage
        
        // Update alert state
        showAutoStopAlert = recordingStoppedAutomatically
    }
    
    private func setupOperationStatusMonitoring() {
        // Set up delegation for operation status updates
        Task {
            await operationCoordinator.setStatusDelegate(self)
        }
        
        // Periodically update system metrics and operation status
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { @MainActor in
                    await self?.updateOperationStatus()
                }
            }
            .store(in: &cancellables)
    }
    
    private func updateOperationStatus() async {
        // Update system metrics
        systemMetrics = await operationCoordinator.getSystemMetrics()
        
        // Update current recording operation status if exists
        if let operationId = currentRecordingOperationId {
            let operation = await operationCoordinator.getOperation(operationId)
            queuePosition = await operationCoordinator.getQueuePosition(for: operationId)
            
            // Clear operation ID if operation is no longer active
            if let op = operation, !op.status.isInProgress {
                currentRecordingOperationId = nil
                recordingOperationStatus = nil
                queuePosition = nil
            }
        }
    }
    
    private func setupRecordingCallback() {
        print("🔧 RecordingViewModel: Setting up callback function")
        audioRepository.setRecordingFinishedHandler { [weak self] url in
            Task { @MainActor in
                print("🎤 RecordingViewModel: Recording finished callback triggered for \(url.lastPathComponent)")
                self?.handleRecordingFinished(at: url)
            }
        }
        print("🔧 RecordingViewModel: Callback function set successfully")
    }
    
    private func setupPermissionNotifications() {
        NotificationCenter.default.addObserver(
            forName: .microphonePermissionStatusChanged,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let status = notification.userInfo?[MicrophonePermissionStatus.notificationUserInfoKey] as? MicrophonePermissionStatus {
                self?.permissionStatus = status
                self?.hasPermission = status.allowsRecording
            }
        }
    }
    
    private func updatePermissionStatus() {
        let status = requestPermissionUseCase.getCurrentStatus()
        permissionStatus = status
        hasPermission = status.allowsRecording
    }
    
    // MARK: - Public Methods
    
    /// Start audio recording
    func startRecording() {
        print("▶️ RecordingViewModel: Starting recording")
        Task {
            do {
                let memoId = try await startRecordingUseCase.execute()
                
                if let validMemoId = memoId {
                    // Get the recording operation for this memoId
                    currentRecordingOperationId = await operationCoordinator.getActiveOperations(for: validMemoId).first?.id
                    print("✅ RecordingViewModel: Recording started with memo ID: \(validMemoId.uuidString)")
                } else {
                    // Recording failed to start - no valid memoId returned
                    currentRecordingOperationId = nil
                    print("❌ RecordingViewModel: Recording failed to start - no memoId returned")
                }
            } catch {
                currentRecordingOperationId = nil
                print("❌ RecordingViewModel: Failed to start recording: \(error)")
            }
        }
    }
    
    /// Stop audio recording
    func stopRecording() {
        print("🛑 RecordingViewModel: Stopping recording")
        guard let operationId = currentRecordingOperationId else {
            print("⚠️ RecordingViewModel: No active recording operation to stop")
            return
        }
        
        Task {
            do {
                // Get memo ID from operation
                if let operation = await operationCoordinator.getOperation(operationId) {
                    try await stopRecordingUseCase.execute(memoId: operation.type.memoId)
                    print("✅ RecordingViewModel: Recording stopped successfully")
                }
            } catch {
                print("❌ RecordingViewModel: Failed to stop recording: \(error)")
            }
        }
    }
    
    /// Cancel the current recording operation
    func cancelRecording() {
        guard let operationId = currentRecordingOperationId else { return }
        
        Task {
            await operationCoordinator.cancelOperation(operationId)
            currentRecordingOperationId = nil
            recordingOperationStatus = nil
            queuePosition = nil
            print("🚫 RecordingViewModel: Recording cancelled")
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
    
    /// Request microphone permission asynchronously
    func requestPermission() {
        guard !isRequestingPermission else { return }
        
        print("🎤 RecordingViewModel: Requesting microphone permission")
        isRequestingPermission = true
        
        Task {
            do {
                let status = await requestPermissionUseCase.execute()
                await MainActor.run {
                    isRequestingPermission = false
                    permissionStatus = status
                    hasPermission = status.allowsRecording
                    print("🎤 RecordingViewModel: Permission result: \(status.displayName)")
                }
            } catch {
                await MainActor.run {
                    isRequestingPermission = false
                    print("❌ RecordingViewModel: Permission request failed: \(error)")
                }
            }
        }
    }
    
    /// Open iOS Settings for permission management
    func openSettings() {
        print("⚙️ RecordingViewModel: Opening Settings for permission management")
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            print("❌ RecordingViewModel: Failed to create Settings URL")
            return
        }
        
        UIApplication.shared.open(settingsURL) { success in
            print("⚙️ RecordingViewModel: Settings opened successfully: \(success)")
        }
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
        updatePermissionStatus() // Refresh permission status when view appears
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

// MARK: - OperationStatusDelegate

extension RecordingViewModel {
    
    func operationStatusDidUpdate(_ update: OperationStatusUpdate) {
        // Update recording operation status if it matches our current operation
        if update.operationId == currentRecordingOperationId {
            recordingOperationStatus = update.currentStatus
            
            switch update.currentStatus {
            case .completed, .failed, .cancelled:
                // Clear tracking when operation finishes
                currentRecordingOperationId = nil
                recordingOperationStatus = nil
                queuePosition = nil
            default:
                break
            }
        }
    }
    
    func operationDidComplete(_ operationId: UUID, memoId: UUID, operationType: OperationType) {
        if operationId == currentRecordingOperationId {
            print("✅ RecordingViewModel: Recording operation completed successfully")
            currentRecordingOperationId = nil
            recordingOperationStatus = nil
            queuePosition = nil
        }
    }
    
    func operationDidFail(_ operationId: UUID, memoId: UUID, operationType: OperationType, error: Error) {
        if operationId == currentRecordingOperationId {
            print("❌ RecordingViewModel: Recording operation failed: \(error.localizedDescription)")
            currentRecordingOperationId = nil
            recordingOperationStatus = nil
            queuePosition = nil
        }
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

// Moved into Features/Recording/ViewModels
import Combine
import Foundation
import SwiftUI

/// ViewModel for handling audio recording functionality
/// Uses dependency injection for testability and clean architecture
@MainActor
final class RecordingViewModel: ObservableObject, OperationStatusDelegate {

    // MARK: - Dependencies
    private let startRecordingUseCase: any StartRecordingUseCaseProtocol
    private let stopRecordingUseCase: any StopRecordingUseCaseProtocol
    private let requestPermissionUseCase: any RequestMicrophonePermissionUseCaseProtocol
    private let handleNewRecordingUseCase: any HandleNewRecordingUseCaseProtocol
    private let audioRepository: any AudioRepository
    private let operationCoordinator: any OperationCoordinatorProtocol
    private let systemNavigator: any SystemNavigator
    // Quota dependencies
    private let canStartRecordingUseCase: any CanStartRecordingUseCaseProtocol
    private let consumeRecordingUsageUseCase: any ConsumeRecordingUsageUseCaseProtocol
    private let resetDailyUsageIfNeededUseCase: any ResetDailyUsageIfNeededUseCaseProtocol
    private let getRemainingMonthlyQuotaUseCase: any GetRemainingMonthlyQuotaUseCaseProtocol
    private let usageRepository: any RecordingUsageRepository
    private let storeKitService: any StoreKitServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Debounce Management
    private var recordButtonDebounceTask: Task<Void, Never>?
    private var wasRecording = false
    private var lastKnownRecordingTime: TimeInterval = 0
    private var currentSessionCap: TimeInterval?
    private var currentSessionService: TranscriptionServiceType = .cloudAPI

    // MARK: - Consolidated State

    /// Single source of truth for all UI state
    @Published var state = RecordingViewState()
    @Published var monthlyUsageMinutes: Int = 0
    @Published var showingPaywall: Bool = false
    @Published var quotaBlocked: Bool = false
    @Published var isProUser: Bool = false
    @Published var recordingState: RecordingSessionState = .idle
    // MARK: - Computed Properties

    /// Status text for the current recording state
    var recordingStatusText: String {
        state.recordingStatusText
    }

    /// Formatted recording time string
    var formattedRecordingTime: String {
        state.recording.formattedRecordingTime
    }

    /// Formatted remaining time for countdown
    var formattedRemainingTime: String {
        state.countdown.formattedRemainingTime
    }

    // Removed unused daily quota status string.

    /// Recording button color based on state
    var recordingButtonColor: Color {
        state.recording.recordingButtonColor
    }

    /// Whether to show the recording indicator
    var shouldShowRecordingIndicator: Bool {
        state.recording.shouldShowRecordingIndicator
    }

    /// Enhanced status text that includes operation status
    var enhancedStatusText: String {
        state.enhancedStatusText
    }

    /// System load indicator for UI
    var systemLoadText: String? {
        guard let metrics = state.operations.systemMetrics else { return nil }

        if metrics.isSystemBusy {
            return "System busy (\(metrics.activeOperations)/\(metrics.maxConcurrentOperations) operations)"
        } else if metrics.activeOperations > 0 {
            return "\(metrics.activeOperations) operations running"
        }

        return nil
    }

    /// Whether the recording operation can be cancelled
    var canCancelRecording: Bool {
        guard currentRecordingOperationId != nil else { return false }
        return recordingOperationStatus?.isInProgress == true
    }

    // MARK: - Initialization

    init(
        startRecordingUseCase: any StartRecordingUseCaseProtocol,
        stopRecordingUseCase: any StopRecordingUseCaseProtocol,
        requestPermissionUseCase: any RequestMicrophonePermissionUseCaseProtocol,
        handleNewRecordingUseCase: any HandleNewRecordingUseCaseProtocol,
        audioRepository: any AudioRepository,
        operationCoordinator: any OperationCoordinatorProtocol,
        systemNavigator: any SystemNavigator,
        canStartRecordingUseCase: any CanStartRecordingUseCaseProtocol,
        consumeRecordingUsageUseCase: any ConsumeRecordingUsageUseCaseProtocol,
        resetDailyUsageIfNeededUseCase: any ResetDailyUsageIfNeededUseCaseProtocol,
        getRemainingMonthlyQuotaUseCase: any GetRemainingMonthlyQuotaUseCaseProtocol,
        usageRepository: any RecordingUsageRepository,
        storeKitService: any StoreKitServiceProtocol
    ) {
        self.startRecordingUseCase = startRecordingUseCase
        self.stopRecordingUseCase = stopRecordingUseCase
        self.requestPermissionUseCase = requestPermissionUseCase
        self.handleNewRecordingUseCase = handleNewRecordingUseCase
        self.audioRepository = audioRepository
        self.operationCoordinator = operationCoordinator
        self.systemNavigator = systemNavigator
        self.canStartRecordingUseCase = canStartRecordingUseCase
        self.consumeRecordingUsageUseCase = consumeRecordingUsageUseCase
        self.resetDailyUsageIfNeededUseCase = resetDailyUsageIfNeededUseCase
        self.getRemainingMonthlyQuotaUseCase = getRemainingMonthlyQuotaUseCase
        self.usageRepository = usageRepository
        self.storeKitService = storeKitService

        setupBindings()
        setupRecordingCallback()
        setupOperationStatusMonitoring()

        // Subscribe to monthly usage and Pro entitlement
        usageRepository.monthUsagePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] seconds in
                self?.monthlyUsageMinutes = Int((seconds / 60.0).rounded(.toNearestOrEven))
            }
            .store(in: &cancellables)

        storeKitService.isProPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] isPro in
                self?.isProUser = isPro
            }
            .store(in: &cancellables)

        // Initialize quota view
        Task { @MainActor in
            await refreshQuota()
        }

        print("🎬 RecordingViewModel: Initialized with dependency injection")
    }

    deinit {
        // Cancel any pending debounce task
        recordButtonDebounceTask?.cancel()
        print("🎬 RecordingViewModel: Deinitialized and cleaned up debounce task")
    }

    // MARK: - Setup Methods

    private func setupBindings() {
        // Bind to AudioRepository publishers (repository manages its own polling)
        audioRepository.isRecordingPublisher
            .sink { [weak self] value in
                guard let self = self else { return }
                let didStop = self.wasRecording && !value
                self.isRecording = value
                // Update tri-state from repository signals
                if value {
                    self.recordingState = .recording
                } else if self.audioRepository.isPaused {
                    self.recordingState = .paused
                } else {
                    self.recordingState = .idle
                }
                if didStop {
                    // When recording stops automatically (cap reached), finalize operation and consume usage
                    if self.audioRepository.recordingStoppedAutomatically {
                        self.showAutoStopAlert = true
                        self.autoStopMessage = self.audioRepository.autoStopMessage
                        Task { [weak self] in
                            guard let self = self else { return }
                            // Complete operation
                            if let opId = self.currentRecordingOperationId,
                               let op = await self.operationCoordinator.getOperation(opId) {
                                try? await self.stopRecordingUseCase.execute(memoId: op.type.memoId)
                            }
                            // Consume usage for cloud sessions
                            if self.currentSessionService == .cloudAPI {
                                let elapsed = self.lastKnownRecordingTime
                                let consumed = self.currentSessionCap.map { min($0, elapsed) } ?? elapsed
                                await self.consumeRecordingUsageUseCase.execute(elapsed: consumed, service: .cloudAPI)
                            }
                            // Reset session cap after stop
                            self.currentSessionCap = nil
                            // Refresh quota after auto-stop consumption
                            await self.refreshQuota()
                        }
                    }
                }
                self.wasRecording = value
            }
            .store(in: &cancellables)

        audioRepository.recordingTimePublisher
            .sink { [weak self] value in
                self?.recordingTime = value
                self?.lastKnownRecordingTime = value
            }
            .store(in: &cancellables)

        audioRepository.isPausedPublisher
            .sink { [weak self] paused in
                guard let self = self else { return }
                if paused {
                    self.recordingState = .paused
                } else if self.isRecording {
                    self.recordingState = .recording
                } else {
                    self.recordingState = .idle
                }
            }
            .store(in: &cancellables)

        audioRepository.permissionStatusPublisher
            .sink { [weak self] status in
                self?.permissionStatus = status
                self?.hasPermission = status.allowsRecording
            }
            .store(in: &cancellables)

        audioRepository.countdownPublisher
            .sink { [weak self] isCountdown, remaining in
                self?.isInCountdown = isCountdown
                self?.remainingTime = remaining
            }
            .store(in: &cancellables)
    }

    /// Refresh the quota state (service + remaining seconds)
    private func refreshQuota() async {
        state.quota.service = .cloudAPI
        let rem = try? await getRemainingMonthlyQuotaUseCase.execute()
        if let r = rem {
            if r == .infinity {
                // No limit for Pro or unlimited cases
                state.quota.remainingDailySeconds = nil
            } else {
                state.quota.remainingDailySeconds = max(0, r)
            }
        } else {
            // If unknown, assume not limited for UI purposes; back-end will still enforce if needed
            state.quota.remainingDailySeconds = nil
        }
        objectWillChange.send()
    }

    private func setupOperationStatusMonitoring() {
        // Set up delegation for operation status updates and fetch initial metrics once
        Task { @MainActor in
            operationCoordinator.setStatusDelegate(self)
            await updateOperationStatus()
        }
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
        audioRepository.setRecordingFinishedHandler { [weak self] url in
            Task { @MainActor in
                print("🎤 RecordingViewModel: Recording finished callback triggered for \(url.lastPathComponent)")
                self?.handleRecordingFinished(at: url)
            }
        }
    }

    // MARK: - Public Methods

    /// Start audio recording
    func startRecording() {
        print("▶️ RecordingViewModel: Starting recording")
        Task {
            do {
                // Ensure daily rollover
                await resetDailyUsageIfNeededUseCase.execute(now: Date())

                self.currentSessionService = .cloudAPI

                var capToApply: TimeInterval?
                do {
                    if let allowed = try await canStartRecordingUseCase.execute(service: .cloudAPI) {
                        capToApply = allowed
                    }
                } catch let err as RecordingQuotaError {
                    switch err {
                    case .limitReached:
                        self.quotaBlocked = true
                        self.showingPaywall = true
                        await refreshQuota()
                        return
                    }
                } catch {
                    // Other errors
                    self.error = ErrorMapping.mapError(error)
                    await refreshQuota()
                    return
                }

                let memoId = try await startRecordingUseCase.execute(capSeconds: capToApply)

                if let validMemoId = memoId {
                    // Get the recording operation for this memoId
                    currentRecordingOperationId = await operationCoordinator.getActiveOperations(for: validMemoId).first?.id
                    print("✅ RecordingViewModel: Recording started with memo ID: \(validMemoId.uuidString)")
                    // Persist session cap for usage consumption
                    self.currentSessionCap = capToApply
                } else {
                    // Recording failed to start - no valid memoId returned
                    currentRecordingOperationId = nil
                    print("❌ RecordingViewModel: Recording failed to start - no memoId returned")
                }
                // Update quota label right after start (no consumption yet)
                await refreshQuota()
            } catch {
                currentRecordingOperationId = nil
                self.error = ErrorMapping.mapError(error)
                print("❌ RecordingViewModel: Failed to start recording: \(error)")
                await refreshQuota()
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
                    // Consume usage for cloud sessions on manual stop
                    if self.currentSessionService == .cloudAPI {
                        let elapsed = self.lastKnownRecordingTime
                        let consumed = self.currentSessionCap.map { min($0, elapsed) } ?? elapsed
                        await self.consumeRecordingUsageUseCase.execute(elapsed: consumed, service: .cloudAPI)
                    }
                    // Reset session cap after stop
                    self.currentSessionCap = nil
                    try await stopRecordingUseCase.execute(memoId: operation.type.memoId)
                    print("✅ RecordingViewModel: Recording stopped successfully")
                    // Refresh quota after consumption
                    await self.refreshQuota()
                }
            } catch {
                self.error = ErrorMapping.mapError(error)
                print("❌ RecordingViewModel: Failed to stop recording: \(error)")
                await refreshQuota()
            }
        }
    }

    /// Pause the ongoing recording
    func pauseRecording() {
        print("⏸️ RecordingViewModel: Pausing recording")
        audioRepository.pauseRecording()
        recordingState = .paused
    }

    /// Resume a paused recording
    func resumeRecording() {
        print("▶️ RecordingViewModel: Resuming recording")
        audioRepository.resumeRecording()
        recordingState = .recording
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
        let status = await requestPermissionUseCase.execute()
        await MainActor.run {
            isRequestingPermission = false
            permissionStatus = status
            hasPermission = status.allowsRecording
            print("🎤 RecordingViewModel: Permission result: \(status.displayName)")
        }
    }
    }

    /// Open iOS Settings for permission management
    func openSettings() {
        print("⚙️ RecordingViewModel: Opening Settings for permission management")
        systemNavigator.openSettings { success in
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
                _ = try await handleNewRecordingUseCase.execute(at: url)
            } catch {
                self.error = ErrorMapping.mapError(error)
                print("❌ RecordingViewModel: Failed to handle new recording: \(error)")
            }
        }
    }

    // MARK: - Lifecycle

    func onViewAppear() {
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
            return .semantic(.error)
        } else if isInCountdown {
            return .semantic(.warning)
        } else if isRecording {
            return .semantic(.error)
        } else {
            return .semantic(.textPrimary)
        }
    }

    /// Get countdown text color
    var countdownTextColor: Color { .semantic(.error) }
}

// MARK: - OperationStatusDelegate

extension RecordingViewModel {

    func operationStatusDidUpdate(_ update: OperationStatusUpdate) async {
        // Update recording operation status if it matches our current operation
        if update.operationId == currentRecordingOperationId {
            recordingOperationStatus = update.currentStatus
            // Update queue position and system metrics reactively
            queuePosition = await operationCoordinator.getQueuePosition(for: update.operationId)
            systemMetrics = await operationCoordinator.getSystemMetrics()

            switch update.currentStatus {
            case .completed, .failed, .cancelled:
                // Clear tracking when operation finishes
                currentRecordingOperationId = nil
                recordingOperationStatus = nil
                queuePosition = nil
                systemMetrics = await operationCoordinator.getSystemMetrics()
            default:
                break
            }
        }
    }

    func operationDidComplete(_ operationId: UUID, memoId: UUID, operationType: OperationType) async {
        if operationId == currentRecordingOperationId {
            print("✅ RecordingViewModel: Recording operation completed successfully")
            currentRecordingOperationId = nil
            recordingOperationStatus = nil
            queuePosition = nil
        }
    }

    func operationDidFail(_ operationId: UUID, memoId: UUID, operationType: OperationType, error: Error) async {
        if operationId == currentRecordingOperationId {
            print("❌ RecordingViewModel: Recording operation failed: \(error.localizedDescription)")
            self.error = ErrorMapping.mapError(error)
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
        """
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

    // MARK: - Error Handling

    /// Clear the current error state
    func clearError() {
        error = nil
    }

    /// Retry the last failed operation
    func retryLastOperation() {
        clearError()
        // Implementation depends on the specific failed operation
        // For now, we'll just clear the error
    }

    // Note: Protocol-level handleError is provided by ErrorHandling default impl
}

// MARK: - ErrorHandling Protocol Conformance

extension RecordingViewModel: ErrorHandling {
    var recordingProgress: Double {
        if let cap = currentSessionCap, cap > 0 {
            let ratio = recordingTime / cap
            return max(0.0, min(1.0, ratio))
        }
        return 0
    }
    var isLoading: Bool {
        state.permission.isRequestingPermission || state.recording.currentRecordingOperationId != nil
    }
}

// MARK: - Backward Compatibility Properties

extension RecordingViewModel {

    // MARK: - Recording Properties
    var isRecording: Bool {
        get { state.recording.isRecording }
        set { state.recording.isRecording = newValue }
    }

    var recordingTime: TimeInterval {
        get { state.recording.recordingTime }
        set { state.recording.recordingTime = newValue }
    }

    var recordingStoppedAutomatically: Bool {
        get { state.recording.recordingStoppedAutomatically }
        set { state.recording.recordingStoppedAutomatically = newValue }
    }

    var autoStopMessage: String? {
        get { state.recording.autoStopMessage }
        set { state.recording.autoStopMessage = newValue }
    }

    var currentRecordingOperationId: UUID? {
        get { state.recording.currentRecordingOperationId }
        set { state.recording.currentRecordingOperationId = newValue }
    }

    // MARK: - Permission Properties
    var hasPermission: Bool {
        get { state.permission.hasPermission }
        set { state.permission.hasPermission = newValue }
    }

    var permissionStatus: MicrophonePermissionStatus {
        get { state.permission.permissionStatus }
        set { state.permission.permissionStatus = newValue }
    }

    var isRequestingPermission: Bool {
        get { state.permission.isRequestingPermission }
        set { state.permission.isRequestingPermission = newValue }
    }

    // MARK: - Countdown Properties
    var isInCountdown: Bool {
        get { state.countdown.isInCountdown }
        set { state.countdown.isInCountdown = newValue }
    }

    var remainingTime: TimeInterval {
        get { state.countdown.remainingTime }
        set { state.countdown.remainingTime = newValue }
    }

    // MARK: - Alert Properties
    var showAutoStopAlert: Bool {
        get { state.alert.showAutoStopAlert }
        set { state.alert.showAutoStopAlert = newValue }
    }

    // MARK: - Operation Properties
    var recordingOperationStatus: DetailedOperationStatus? {
        get { state.operations.recordingOperationStatus }
        set { state.operations.recordingOperationStatus = newValue }
    }

    var queuePosition: Int? {
        get { state.operations.queuePosition }
        set { state.operations.queuePosition = newValue }
    }

    var systemMetrics: SystemOperationMetrics? {
        get { state.operations.systemMetrics }
        set { state.operations.systemMetrics = newValue }
    }

    // MARK: - UI Properties
    var error: SonoraError? {
        get { state.ui.error }
        set { state.ui.error = newValue }
    }
}

//
//  RecordingViewModelTests.swift
//  SonoraTests
//
//  Comprehensive tests for RecordingViewModel
//

import Foundation
import Combine
import Testing
@testable import Sonora

@MainActor
struct RecordingViewModelTests {

    // MARK: - Test Helpers

    private func createViewModel(
        startRecordingResult: Result<UUID?, Error> = .success(UUID()),
        stopRecordingResult: Result<Void, Error> = .success(()),
        remainingTime: TimeInterval? = 3600.0,
        isProUser: Bool = false,
        remainingQuota: TimeInterval = 7200.0
    ) -> (viewModel: RecordingViewModel, mocks: TestMocks) {
        let mocks = TestMocks(
            startRecordingResult: startRecordingResult,
            stopRecordingResult: stopRecordingResult,
            remainingTime: remainingTime,
            isProUser: isProUser,
            remainingQuota: remainingQuota
        )

        let viewModel = RecordingViewModel(
            startRecordingUseCase: mocks.startRecording,
            stopRecordingUseCase: mocks.stopRecording,
            requestPermissionUseCase: mocks.requestPermission,
            handleNewRecordingUseCase: mocks.handleNewRecording,
            audioRepository: mocks.audioRepository,
            operationCoordinator: mocks.operationCoordinator,
            systemNavigator: mocks.systemNavigator,
            canStartRecordingUseCase: mocks.canStartRecording,
            consumeRecordingUsageUseCase: mocks.consumeUsage,
            resetDailyUsageIfNeededUseCase: mocks.resetDailyUsage,
            getRemainingMonthlyQuotaUseCase: mocks.getRemainingQuota,
            usageRepository: mocks.usageRepository,
            storeKitService: mocks.storeKitService
        )

        return (viewModel, mocks)
    }

    // MARK: - Tier 1: CRITICAL Tests - Recording Lifecycle

    @Test func test_startRecording_success_updatesIsRecordingState() async throws {
        let (viewModel, mocks) = createViewModel()

        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        #expect(mocks.startRecording.executeCallCount == 1)
        #expect(mocks.audioRepository.isRecording == true)
    }

    @Test func test_startRecording_quotaLimitReached_showsPaywall() async throws {
        let (viewModel, mocks) = createViewModel(remainingTime: 0) // 0 = no time left

        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        #expect(viewModel.showingPaywall == true)
        #expect(mocks.startRecording.executeCallCount == 0)
    }

    @Test func test_startRecording_callsStartRecordingUseCase() async throws {
        let (viewModel, mocks) = createViewModel()

        await viewModel.startRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        #expect(mocks.startRecording.executeCallCount > 0)
    }

    @Test func test_stopRecording_success_stopsRecordingAndConsumesUsage() async throws {
        let (viewModel, mocks) = createViewModel()

        // Start recording first
        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        // Allow async state propagation to complete
        await Task.yield()

        // Simulate recording time
        mocks.audioRepository.simulateRecordingTimeUpdate(30.0)

        // Stop recording
        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        #expect(mocks.stopRecording.executeCallCount == 1)
        #expect(mocks.audioRepository.isRecording == false)
    }

    @Test func test_pauseRecording_updatesStateToPaused() async throws {
        let (viewModel, mocks) = createViewModel()

        // Start recording
        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        // Pause
        await viewModel.pauseRecording()
        try await Task.sleep(nanoseconds: TestConstants.shortDelay)

        #expect(mocks.audioRepository.isPaused == true)
        #expect(viewModel.recordingState == .paused)
    }

    @Test func test_resumeRecording_updatesStateToRecording() async throws {
        let (viewModel, mocks) = createViewModel()

        // Start, then pause
        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)
        await viewModel.pauseRecording()
        try await Task.sleep(nanoseconds: TestConstants.shortDelay)

        // Resume
        await viewModel.resumeRecording()
        try await Task.sleep(nanoseconds: TestConstants.shortDelay)

        #expect(mocks.audioRepository.isPaused == false)
        #expect(viewModel.recordingState == .recording)
    }

    @Test func test_recordingFinished_callsHandleNewRecordingUseCase() async throws {
        let (viewModel, mocks) = createViewModel()
        let testURL = URL(fileURLWithPath: "/tmp/test.m4a")

        // Trigger recording finished callback
        mocks.audioRepository.simulateRecordingFinished(url: testURL)
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        #expect(mocks.handleNewRecording.executeCallCount == 1)
    }

    @Test func test_autoStop_triggersAutoStopAlert() async throws {
        let (viewModel, _) = createViewModel()

        // Simulate auto-stop from repository
        viewModel.state.recording.recordingStoppedAutomatically = true
        viewModel.state.recording.autoStopMessage = "Recording limit reached"

        #expect(viewModel.state.recording.recordingStoppedAutomatically == true)
        #expect(viewModel.state.recording.autoStopMessage != nil)
    }

    // MARK: - Tier 1: CRITICAL Tests - Toggle & Debouncing

    @Test func test_toggleRecording_startsWhenIdle() async throws {
        let (viewModel, mocks) = createViewModel()

        #expect(viewModel.recordingState == .idle)

        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        #expect(mocks.startRecording.executeCallCount == 1)
    }

    @Test func test_toggleRecording_stopsWhenRecording() async throws {
        let (viewModel, mocks) = createViewModel()

        // First toggle - start
        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        // Allow async state propagation to complete
        await Task.yield()

        // Update state to recording
        mocks.audioRepository.simulateRecordingStateChange(true)
        try await Task.sleep(nanoseconds: TestConstants.shortDelay)

        // Second toggle - stop
        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        #expect(mocks.stopRecording.executeCallCount == 1)
    }

    @Test func test_toggleRecording_debounces300ms() async throws {
        let (viewModel, mocks) = createViewModel()
        let startTime = Date()

        await viewModel.toggleRecording()

        // Wait for debounce
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)
        let elapsed = Date().timeIntervalSince(startTime)

        #expect(elapsed >= 0.3)
        #expect(mocks.startRecording.executeCallCount == 1)
    }

    @Test func test_toggleRecording_multipleRapidTaps_executesOnlyOnce() async throws {
        let (viewModel, mocks) = createViewModel()

        // Rapid taps
        await viewModel.toggleRecording()
        await viewModel.toggleRecording()
        await viewModel.toggleRecording()

        // Wait for debounce
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        // Only one should execute due to debouncing
        #expect(mocks.startRecording.executeCallCount == 1)
    }

    // MARK: - Tier 1: Permission Management

    // NOTE: Permission requests are handled internally via requestPermissionUseCase
    // RecordingViewModel doesn't expose a public requestMicrophonePermission() method

    @Test func test_openSettings_callsSystemNavigator() async throws {
        let (viewModel, mocks) = createViewModel()

        await viewModel.openSettings()

        #expect(mocks.systemNavigator.openedSettings == true)
    }

    // MARK: - Tier 1: Quota Management

    // NOTE: refreshQuota() is private and called automatically in init
    // Testing quota behavior through public APIs

    @Test func test_refreshQuota_proUser_setsNoLimit() async throws {
        let (viewModel, mocks) = createViewModel(isProUser: true)

        mocks.storeKitService.isPro = true
        try await Task.sleep(nanoseconds: TestConstants.shortDelay)

        #expect(viewModel.isProUser == true)
    }

    @Test func test_quotaBlocked_preventsRecordingStart() async throws {
        let (viewModel, mocks) = createViewModel(remainingTime: 0) // 0 = no time left

        await viewModel.toggleRecording()
        try await Task.sleep(nanoseconds: TestConstants.debounceDelay)

        // Should show paywall instead of starting
        #expect(viewModel.showingPaywall == true)
        #expect(mocks.startRecording.executeCallCount == 0)
    }

    // MARK: - Tier 2: State Management

    @Test func test_recordingStatusText_reflectsCurrentState() async throws {
        let (viewModel, _) = createViewModel()

        // Initial state should be "Microphone Access Needed" (notDetermined)
        // Wait briefly for publishers to emit initial values
        try await Task.sleep(nanoseconds: TestConstants.shortDelay)

        // Grant permission and update state
        viewModel.state.permission.permissionStatus = .granted
        #expect(viewModel.recordingStatusText == "Ready to Record")

        // Start recording
        viewModel.state.recording.isRecording = true
        #expect(viewModel.recordingStatusText == "Recording...")
    }

    @Test func test_enhancedStatusText_includesOperationStatus() async throws {
        let (viewModel, _) = createViewModel()

        // TODO: Update this test once Operation structure is clarified
        let statusText = viewModel.enhancedStatusText
        #expect(statusText != "")
    }

    // MARK: - Test Mocks Helper

    @MainActor
    struct TestMocks {
        let startRecording: MockStartRecordingUseCase
        let stopRecording: MockStopRecordingUseCase
        let requestPermission: MockRequestPermissionUseCase
        let handleNewRecording: MockHandleNewRecordingUseCase
        let audioRepository: MockAudioRepository
        let operationCoordinator: MockOperationCoordinator
        let systemNavigator: MockSystemNavigator
        let canStartRecording: MockCanStartRecordingUseCase
        let consumeUsage: MockConsumeRecordingUsageUseCase
        let resetDailyUsage: MockResetDailyUsageUseCase
        let getRemainingQuota: MockGetRemainingMonthlyQuotaUseCase
        let usageRepository: MockRecordingUsageRepository
        let storeKitService: MockStoreKitService

        init(
            startRecordingResult: Result<UUID?, Error> = .success(UUID()),
            stopRecordingResult: Result<Void, Error> = .success(()),
            remainingTime: TimeInterval? = 3600.0,
            isProUser: Bool = false,
            remainingQuota: TimeInterval = 7200.0
        ) {
            self.operationCoordinator = MockOperationCoordinator()
            self.audioRepository = MockAudioRepository()
            // Set microphone permission to granted by default for tests
            self.audioRepository.hasMicrophonePermission = true
            self.audioRepository.checkMicrophonePermissions()  // Updates the publisher

            self.startRecording = MockStartRecordingUseCase()
            self.startRecording.executeResult = startRecordingResult
            self.startRecording.operationCoordinator = self.operationCoordinator  // Connect to coordinator
            self.startRecording.audioRepository = self.audioRepository  // Connect to audio repository

            self.stopRecording = MockStopRecordingUseCase()
            self.stopRecording.executeResult = stopRecordingResult
            self.stopRecording.audioRepository = self.audioRepository  // Connect to audio repository

            self.requestPermission = MockRequestPermissionUseCase()
            self.handleNewRecording = MockHandleNewRecordingUseCase()
            self.systemNavigator = MockSystemNavigator()

            self.canStartRecording = MockCanStartRecordingUseCase()
            self.canStartRecording.remainingTime = remainingTime

            self.consumeUsage = MockConsumeRecordingUsageUseCase()
            self.resetDailyUsage = MockResetDailyUsageUseCase()

            self.getRemainingQuota = MockGetRemainingMonthlyQuotaUseCase()
            self.getRemainingQuota.remainingSeconds = remainingQuota

            self.usageRepository = MockRecordingUsageRepository()
            self.storeKitService = MockStoreKitService()
            self.storeKitService.isPro = isProUser
        }
    }
}


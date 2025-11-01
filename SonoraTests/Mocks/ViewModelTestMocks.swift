//
//  ViewModelTestMocks.swift
//  SonoraTests
//
//  Mock implementations for ViewModel testing
//

import Foundation
import Combine
@testable import Sonora

// MARK: - Mock Use Cases for MemoListViewModel

@MainActor
final class MockLoadMemosUseCase: LoadMemosUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<[Memo], Error> = .success([])

    func execute() async throws -> [Memo] {
        executeCallCount += 1
        return try executeResult.get()
    }
}

@MainActor
final class MockDeleteMemoUseCase: DeleteMemoUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<Void, Error> = .success(())
    var deletedMemos: [Memo] = []

    func execute(memo: Memo) async throws {
        executeCallCount += 1
        deletedMemos.append(memo)
        try executeResult.get()
    }
}

@MainActor
final class MockPlayMemoUseCase: PlayMemoUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<Void, Error> = .success(())
    var lastPlayedMemo: Memo?

    func execute(memo: Memo) async throws {
        executeCallCount += 1
        lastPlayedMemo = memo
        try executeResult.get()
    }
}

@MainActor
final class MockStartTranscriptionUseCase: StartTranscriptionUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<Void, Error> = .success(())
    var lastTranscribedMemo: Memo?

    func execute(memo: Memo) async throws {
        executeCallCount += 1
        lastTranscribedMemo = memo
        try executeResult.get()
    }
}

@MainActor
final class MockRetryTranscriptionUseCase: RetryTranscriptionUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<Void, Error> = .success(())
    var lastRetriedMemo: Memo?

    func execute(memo: Memo) async throws {
        executeCallCount += 1
        lastRetriedMemo = memo
        try executeResult.get()
    }
}

@MainActor
final class MockGetTranscriptionStateUseCase: GetTranscriptionStateUseCaseProtocol {
    var statesByMemo: [UUID: TranscriptionState] = [:]

    func execute(memo: Memo) -> TranscriptionState {
        return statesByMemo[memo.id] ?? .notStarted
    }
}

@MainActor
final class MockRenameMemoUseCase: RenameMemoUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<Void, Error> = .success(())
    var lastRenamedMemo: Memo?
    var lastNewTitle: String?

    func execute(memo: Memo, newTitle: String) async throws {
        executeCallCount += 1
        lastRenamedMemo = memo
        lastNewTitle = newTitle
        try executeResult.get()
    }
}

@MainActor
final class MockHandleNewRecordingUseCase: HandleNewRecordingUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<Memo, Error> = .success(MemoBuilder.make())
    var lastRecordingURL: URL?

    func execute(at url: URL) async throws -> Memo {
        executeCallCount += 1
        lastRecordingURL = url
        return try executeResult.get()
    }
}

// MARK: - Mock Use Cases for RecordingViewModel

@MainActor
final class MockStartRecordingUseCase: StartRecordingUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<UUID?, Error> = .success(UUID())
    var capturedCapSeconds: TimeInterval?
    weak var operationCoordinator: MockOperationCoordinator? // Link to operation coordinator
    weak var audioRepository: MockAudioRepository? // Link to audio repository

    func execute(capSeconds: TimeInterval?) async throws -> UUID? {
        executeCallCount += 1
        capturedCapSeconds = capSeconds
        let memoId = try executeResult.get()

        // CRITICAL: Register operation FIRST before updating audio repository
        // This ensures the operation is queryable when ViewModel checks for it
        if let memoId = memoId, let coordinator = operationCoordinator {
            let opId = await coordinator.registerOperation(.recording(memoId: memoId))
            if let opId = opId {
                _ = await coordinator.startOperation(opId)
            }
        }

        // Update audio repository state AFTER operation is registered
        // This ensures currentRecordingOperationId is set before publisher fires
        if let audioRepo = audioRepository, memoId != nil {
            audioRepo.isRecording = true
            audioRepo.simulateRecordingStateChange(true)
        }

        return memoId
    }
}

@MainActor
final class MockStopRecordingUseCase: StopRecordingUseCaseProtocol {
    var executeCallCount = 0
    var executeResult: Result<Void, Error> = .success(())
    weak var audioRepository: MockAudioRepository? // Link to audio repository

    nonisolated func execute(memoId: UUID) async throws {
        let result = await MainActor.run {
            executeCallCount += 1

            // Update audio repository state to match real behavior
            if let audioRepo = audioRepository {
                audioRepo.isRecording = false
                audioRepo.simulateRecordingStateChange(false)
            }

            return executeResult
        }
        try result.get()
    }
}

@MainActor
final class MockCanStartRecordingUseCase: CanStartRecordingUseCaseProtocol {
    var executeCallCount = 0
    var remainingTime: TimeInterval? = 3600.0 // 1 hour default
    var lastService: TranscriptionServiceType?

    func execute(service: TranscriptionServiceType) async throws -> TimeInterval? {
        executeCallCount += 1
        lastService = service

        // Match real implementation behavior:
        // - nil means unlimited (Pro user)
        // - 0 or negative throws limitReached error
        // - positive value returns that value as cap
        if let time = remainingTime {
            if time <= 0 {
                throw RecordingQuotaError.limitReached(remaining: time)
            }
            return time
        }
        return nil // Unlimited (Pro user)
    }
}

@MainActor
final class MockConsumeRecordingUsageUseCase: ConsumeRecordingUsageUseCaseProtocol {
    var executeCallCount = 0
    var lastConsumedSeconds: TimeInterval?
    var lastService: TranscriptionServiceType?

    func execute(elapsed: TimeInterval, service: TranscriptionServiceType) async {
        executeCallCount += 1
        lastConsumedSeconds = elapsed
        lastService = service
    }
}

@MainActor
final class MockGetRemainingMonthlyQuotaUseCase: GetRemainingMonthlyQuotaUseCaseProtocol {
    var remainingSeconds: TimeInterval = 7200.0 // 2 hours default

    func execute() async throws -> TimeInterval {
        return remainingSeconds
    }
}

// MARK: - Mock Repositories

@MainActor
final class MockMemoRepository: MemoRepository {
    var memos: [Memo] = []
    var playingMemo: Memo?
    var isPlaying: Bool = false

    var memosPublisher: AnyPublisher<[Memo], Never> {
        _memosPublisher.eraseToAnyPublisher()
    }
    var playbackProgressPublisher: AnyPublisher<PlaybackProgress, Never> {
        _playbackProgressPublisher.eraseToAnyPublisher()
    }

    private let _memosPublisher = PassthroughSubject<[Memo], Never>()
    private let _playbackProgressPublisher = PassthroughSubject<PlaybackProgress, Never>()

    func loadMemos() {
        _memosPublisher.send(memos)
    }

    func searchMemos(query: String) -> [Memo] {
        guard !query.isEmpty else { return memos }
        return memos.filter { memo in
            return memo.displayName.localizedCaseInsensitiveContains(query) ||
                memo.filename.localizedCaseInsensitiveContains(query)
        }
    }

    func saveMemo(_ memo: Memo) {
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            memos[index] = memo
        } else {
            memos.append(memo)
        }
        _memosPublisher.send(memos)
    }

    func deleteMemo(_ memo: Memo) {
        memos.removeAll { $0.id == memo.id }
        _memosPublisher.send(memos)
    }

    func getMemo(by id: UUID) -> Memo? {
        return memos.first { $0.id == id }
    }

    func getMemo(by url: URL) -> Memo? {
        return memos.first { $0.fileURL == url }
    }

    @discardableResult
    func handleNewRecording(at url: URL) -> Memo {
        let memo = MemoBuilder.make(fileURL: url)
        memos.append(memo)
        _memosPublisher.send(memos)
        return memo
    }

    func updateMemoMetadata(_ memo: Memo, metadata: [String: Any]) {
        // Mock implementation - just update the memo in array
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            memos[index] = memo
            _memosPublisher.send(memos)
        }
    }

    func renameMemo(_ memo: Memo, newTitle: String) {
        if let index = memos.firstIndex(where: { $0.id == memo.id }) {
            let updated = Memo(
                id: memo.id,
                filename: memo.filename,
                fileURL: memo.fileURL,
                creationDate: memo.creationDate,
                durationSeconds: memo.durationSeconds,
                transcriptionStatus: memo.transcriptionStatus,
                analysisResults: memo.analysisResults,
                customTitle: newTitle,
                shareableFileName: memo.shareableFileName,
                autoTitleState: memo.autoTitleState
            )
            memos[index] = updated
            _memosPublisher.send(memos)
        }
    }

    func playMemo(_ memo: Memo) {
        playingMemo = memo
        isPlaying = true
    }

    func stopPlaying() {
        playingMemo = nil
        isPlaying = false
    }

    func seek(to time: TimeInterval, for memo: Memo) {
        if playingMemo?.id == memo.id {
            _playbackProgressPublisher.send(PlaybackProgress(
                memoId: memo.id,
                currentTime: time,
                duration: memo.duration,
                isPlaying: isPlaying
            ))
        }
    }
}

@MainActor
final class MockTranscriptionRepository: TranscriptionRepository {
    var transcriptionStates: [String: TranscriptionState] = [:]
    var stateChangesPublisher: AnyPublisher<TranscriptionStateChange, Never> {
        _stateChangesPublisher.eraseToAnyPublisher()
    }

    private let _stateChangesPublisher = PassthroughSubject<TranscriptionStateChange, Never>()
    private var textByMemoId: [UUID: String] = [:]
    private var metadataByMemoId: [UUID: TranscriptionMetadata] = [:]

    func saveTranscriptionState(_ state: TranscriptionState, for memoId: UUID) {
        let previousState = transcriptionStates[memoId.uuidString]
        transcriptionStates[memoId.uuidString] = state
        _stateChangesPublisher.send(TranscriptionStateChange(
            memoId: memoId,
            previousState: previousState,
            currentState: state
        ))
    }

    func getTranscriptionState(for memoId: UUID) -> TranscriptionState {
        return transcriptionStates[memoId.uuidString] ?? .notStarted
    }

    func deleteTranscriptionData(for memoId: UUID) {
        transcriptionStates.removeValue(forKey: memoId.uuidString)
        textByMemoId.removeValue(forKey: memoId)
        metadataByMemoId.removeValue(forKey: memoId)
    }

    func getTranscriptionText(for memoId: UUID) -> String? {
        return textByMemoId[memoId]
    }

    func saveTranscriptionText(_ text: String, for memoId: UUID) {
        textByMemoId[memoId] = text
    }

    func getTranscriptionMetadata(for memoId: UUID) -> TranscriptionMetadata? {
        return metadataByMemoId[memoId]
    }

    func saveTranscriptionMetadata(_ metadata: TranscriptionMetadata, for memoId: UUID) {
        metadataByMemoId[memoId] = metadata
    }

    func clearTranscriptionCache() {
        transcriptionStates.removeAll()
        textByMemoId.removeAll()
        metadataByMemoId.removeAll()
    }

    func getTranscriptionStates(for memoIds: [UUID]) -> [UUID: TranscriptionState] {
        var result: [UUID: TranscriptionState] = [:]
        for memoId in memoIds {
            result[memoId] = getTranscriptionState(for: memoId)
        }
        return result
    }

    func stateChangesPublisher(for memoId: UUID) -> AnyPublisher<TranscriptionStateChange, Never> {
        return _stateChangesPublisher
            .filter { $0.memoId == memoId }
            .eraseToAnyPublisher()
    }
}

@MainActor
final class MockAudioRepository: AudioRepository {
    // MARK: - Properties
    var isRecording: Bool = false
    var recordingTime: TimeInterval = 0
    var hasMicrophonePermission: Bool = false
    var isBackgroundTaskActive: Bool = false
    var recordingStoppedAutomatically: Bool = false
    var autoStopMessage: String?
    var isInCountdown: Bool = false
    var remainingTime: TimeInterval = 0
    var playingMemo: Memo?
    var isPlaying: Bool = false
    var isPaused: Bool = false

    // MARK: - Publishers
    private let _isRecordingPublisher = CurrentValueSubject<Bool, Never>(false)
    private let _recordingTimePublisher = CurrentValueSubject<TimeInterval, Never>(0)
    private let _permissionStatusPublisher = CurrentValueSubject<MicrophonePermissionStatus, Never>(.notDetermined)
    private let _countdownPublisher = PassthroughSubject<(Bool, TimeInterval), Never>()
    private let _audioLevelPublisher = PassthroughSubject<Double, Never>()
    private let _peakLevelPublisher = PassthroughSubject<Double, Never>()
    private let _voiceActivityPublisher = PassthroughSubject<Double, Never>()
    private let _frequencyBandsPublisher = PassthroughSubject<FrequencyBands, Never>()
    private let _isPausedPublisher = CurrentValueSubject<Bool, Never>(false)

    var isRecordingPublisher: AnyPublisher<Bool, Never> {
        _isRecordingPublisher.eraseToAnyPublisher()
    }

    var recordingTimePublisher: AnyPublisher<TimeInterval, Never> {
        _recordingTimePublisher.eraseToAnyPublisher()
    }

    var permissionStatusPublisher: AnyPublisher<MicrophonePermissionStatus, Never> {
        _permissionStatusPublisher.eraseToAnyPublisher()
    }

    var countdownPublisher: AnyPublisher<(Bool, TimeInterval), Never> {
        _countdownPublisher.eraseToAnyPublisher()
    }

    var audioLevelPublisher: AnyPublisher<Double, Never> {
        _audioLevelPublisher.eraseToAnyPublisher()
    }

    var peakLevelPublisher: AnyPublisher<Double, Never> {
        _peakLevelPublisher.eraseToAnyPublisher()
    }

    var voiceActivityPublisher: AnyPublisher<Double, Never> {
        _voiceActivityPublisher.eraseToAnyPublisher()
    }

    var frequencyBandsPublisher: AnyPublisher<FrequencyBands, Never> {
        _frequencyBandsPublisher.eraseToAnyPublisher()
    }

    var isPausedPublisher: AnyPublisher<Bool, Never> {
        _isPausedPublisher.eraseToAnyPublisher()
    }

    // MARK: - Test Helpers
    /// Simulate recording time update (for tests)
    func simulateRecordingTimeUpdate(_ time: TimeInterval) {
        recordingTime = time
        _recordingTimePublisher.send(time)
    }

    /// Simulate recording state change (for tests)
    func simulateRecordingStateChange(_ isRecording: Bool) {
        self.isRecording = isRecording
        _isRecordingPublisher.send(isRecording)
    }

    // MARK: - Handlers
    private var recordingFinishedHandler: ((URL) -> Void)?
    private var recordingFailedHandler: ((Error) -> Void)?

    // MARK: - Methods
    func startRecording(allowedCap: TimeInterval?) async throws -> UUID {
        isRecording = true
        _isRecordingPublisher.send(true)
        return UUID()
    }

    func startRecording() async throws -> UUID {
        return try await startRecording(allowedCap: nil)
    }

    func stopRecording() {
        isRecording = false
        _isRecordingPublisher.send(false)
    }

    func pauseRecording() {
        isPaused = true
        _isPausedPublisher.send(true)
    }

    func resumeRecording() {
        isPaused = false
        _isPausedPublisher.send(false)
    }

    func playAudio(at url: URL) throws {
        isPlaying = true
    }

    func pauseAudio() {
        isPlaying = false
    }

    func stopAudio() {
        isPlaying = false
        playingMemo = nil
    }

    func isAudioPlaying(for memo: Memo) -> Bool {
        return playingMemo?.id == memo.id && isPlaying
    }

    func checkMicrophonePermissions() {
        _permissionStatusPublisher.send(hasMicrophonePermission ? .granted : .denied)
    }

    func setRecordingFinishedHandler(_ handler: @escaping (URL) -> Void) {
        recordingFinishedHandler = handler
    }

    func setRecordingFailedHandler(_ handler: @escaping (Error) -> Void) {
        recordingFailedHandler = handler
    }

    // Helper methods for testing
    func simulateRecordingFinished(url: URL) {
        recordingFinishedHandler?(url)
    }

    func simulateRecordingFailed(error: Error) {
        recordingFailedHandler?(error)
    }
}

@MainActor
final class MockOperationCoordinator: OperationCoordinatorProtocol {
    private var operations: [UUID: Sonora.Operation] = [:]
    private var operationsByMemoId: [UUID: [UUID]] = [:] // Track operations by memo ID
    var statusDelegate: (any OperationStatusDelegate)?

    func setStatusDelegate(_ delegate: (any OperationStatusDelegate)?) {
        statusDelegate = delegate
    }

    func registerOperation(_ operationType: OperationType) async -> UUID? {
        // CRITICAL: Use the operation's own id, not a separate UUID
        let operation = Sonora.Operation(type: operationType, priority: .medium, status: .pending)
        let id = operation.id  // Use the operation's auto-generated ID
        operations[id] = operation

        // Track by memo ID
        let memoId = operationType.memoId
        if operationsByMemoId[memoId] == nil {
            operationsByMemoId[memoId] = []
        }
        operationsByMemoId[memoId]?.append(id)

        return id
    }

    func startOperation(_ operationId: UUID) async -> Bool {
        guard var operation = operations[operationId] else { return false }
        operation.status = .active
        operations[operationId] = operation
        return true
    }

    func completeOperation(_ operationId: UUID) async {
        guard var operation = operations[operationId] else { return }
        operation.status = .completed
        operations[operationId] = operation
    }

    func failOperation(_ operationId: UUID, errorDescription: String) async {
        guard var operation = operations[operationId] else { return }
        operation.status = .failed
        operation.errorDescription = errorDescription
        operations[operationId] = operation
    }

    func cancelOperation(_ operationId: UUID) async {
        guard var operation = operations[operationId] else { return }
        operation.status = .cancelled
        operations[operationId] = operation
    }

    func updateProgress(operationId: UUID, progress: OperationProgress) async {
        guard var operation = operations[operationId] else { return }
        operation.progress = progress
        operations[operationId] = operation
    }

    func cancelAllOperations(for memoId: UUID) async -> Int {
        // Cancel all operations for this memo ID
        guard let operationIds = operationsByMemoId[memoId] else { return 0 }
        var count = 0
        for id in operationIds {
            if var operation = operations[id], operation.status.isInProgress {
                operation.status = .cancelled
                operations[id] = operation
                count += 1
            }
        }
        return count
    }

    func cancelOperations(ofType category: OperationCategory) async -> Int {
        var count = 0
        for (id, operation) in operations {
            if operation.type.category == category && operation.status.isInProgress {
                var updated = operation
                updated.status = .cancelled
                operations[id] = updated
                count += 1
            }
        }
        return count
    }

    func cancelAllOperations() async -> Int {
        var count = 0
        for (id, operation) in operations {
            if operation.status.isInProgress {
                var updated = operation
                updated.status = .cancelled
                operations[id] = updated
                count += 1
            }
        }
        return count
    }

    func isRecordingActive(for memoId: UUID) async -> Bool {
        // Check if there's an active recording operation for this memo ID
        guard let operationIds = operationsByMemoId[memoId] else { return false }
        return operationIds.contains { id in
            if let operation = operations[id],
               case .recording = operation.type,
               operation.status.isInProgress {
                return true
            }
            return false
        }
    }

    func canStartTranscription(for memoId: UUID) async -> Bool {
        // Mock implementation
        return true
    }

    func getActiveOperations(for memoId: UUID) async -> [Sonora.Operation] {
        // Return operations for this specific memo ID
        guard let operationIds = operationsByMemoId[memoId] else { return [] }
        return operationIds.compactMap { operations[$0] }
            .filter { $0.status.isInProgress }
    }

    func getAllActiveOperations() async -> [Sonora.Operation] {
        return operations.values.filter { $0.status.isInProgress }
    }

    func getSystemMetrics() async -> SystemOperationMetrics {
        let allOps = operations.values
        return SystemOperationMetrics(
            totalOperations: allOps.count,
            activeOperations: allOps.filter { $0.status.isInProgress }.count,
            queuedOperations: allOps.filter { $0.status == .pending }.count,
            maxConcurrentOperations: 10,
            averageOperationDuration: 0.0
        )
    }

    func getOperationSummaries(group: OperationGroup, filter: OperationFilter, for memoId: UUID?) async -> [OperationSummary] {
        // Mock implementation
        return []
    }

    func getQueuePosition(for operationId: UUID) async -> Int? {
        // Mock implementation
        return nil
    }

    func getDebugInfo() async -> String {
        return "Mock Operation Coordinator - \(operations.count) operations"
    }

    func getOperation(_ operationId: UUID) async -> Sonora.Operation? {
        return operations[operationId]
    }
}

@MainActor
final class MockSystemNavigator: SystemNavigator {
    var openedURL: URL?
    var openedSettings = false
    var lastCompletion: ((Bool) -> Void)?

    func open(_ url: URL, completion: ((Bool) -> Void)?) {
        openedURL = url
        lastCompletion = completion
        completion?(true)
    }

    func openSettings(completion: ((Bool) -> Void)?) {
        openedSettings = true
        lastCompletion = completion
        completion?(true)
    }
}

@MainActor
final class MockStoreKitService: StoreKitServiceProtocol {
    private var _isPro: Bool = false
    private let _isProPublisher = CurrentValueSubject<Bool, Never>(false)

    var isPro: Bool {
        get { _isPro }
        set {
            _isPro = newValue
            _isProPublisher.send(newValue)
        }
    }

    var isProPublisher: AnyPublisher<Bool, Never> {
        _isProPublisher.eraseToAnyPublisher()
    }

    func purchase(productId: String) async throws -> Bool {
        isPro = true
        return true
    }

    func restorePurchases() async throws -> Bool {
        return isPro
    }

    func refreshEntitlements(force: Bool) async {
        // Mock implementation - no-op
    }
}

@MainActor
final class MockTitleGenerationCoordinator {
    var generateCallCount = 0
    var lastMemoId: UUID?

    func requestTitleGeneration(for memoId: UUID) async {
        generateCallCount += 1
        lastMemoId = memoId
    }
}

// MARK: - Additional Mocks for Recording Tests

@MainActor
final class MockRequestPermissionUseCase: RequestMicrophonePermissionUseCaseProtocol {
    var executeCallCount = 0
    var permissionResult: MicrophonePermissionStatus = .granted

    nonisolated func execute() async -> MicrophonePermissionStatus {
        await MainActor.run {
            executeCallCount += 1
            return permissionResult
        }
    }

    nonisolated func getCurrentStatus() -> MicrophonePermissionStatus {
        MainActor.assumeIsolated {
            return permissionResult
        }
    }
}

@MainActor
final class MockResetDailyUsageUseCase: ResetDailyUsageIfNeededUseCaseProtocol {
    var executeCallCount = 0
    var lastDate: Date?

    nonisolated func execute(now: Date) async {
        await MainActor.run {
            executeCallCount += 1
            lastDate = now
        }
    }
}

@MainActor
final class MockRecordingUsageRepository: RecordingUsageRepository {
    // Daily usage tracking
    private var dailyUsage: [Date: TimeInterval] = [:]
    private let todayUsageSubject = CurrentValueSubject<TimeInterval, Never>(0)

    nonisolated var todayUsagePublisher: AnyPublisher<TimeInterval, Never> {
        MainActor.assumeIsolated {
            todayUsageSubject.eraseToAnyPublisher()
        }
    }

    // Monthly usage tracking
    private var monthlyUsage: [Date: TimeInterval] = [:]
    private let monthUsageSubject = CurrentValueSubject<TimeInterval, Never>(0)

    nonisolated var monthUsagePublisher: AnyPublisher<TimeInterval, Never> {
        MainActor.assumeIsolated {
            monthUsageSubject.eraseToAnyPublisher()
        }
    }

    // Test helpers
    var addUsageCallCount = 0
    var resetCallCount = 0
    var resetMonthCallCount = 0

    // MARK: - Daily Usage

    nonisolated func usage(for day: Date) async -> TimeInterval {
        await MainActor.run {
            dailyUsage[day] ?? 0
        }
    }

    nonisolated func addUsage(_ seconds: TimeInterval, for day: Date) async {
        await MainActor.run {
            addUsageCallCount += 1
            let current = dailyUsage[day] ?? 0
            dailyUsage[day] = current + seconds
            todayUsageSubject.send(current + seconds)
        }
    }

    nonisolated func resetIfDayChanged(now: Date) async {
        await MainActor.run {
            resetCallCount += 1
            // In tests, we can just clear all daily usage
            dailyUsage.removeAll()
            todayUsageSubject.send(0)
        }
    }

    // MARK: - Monthly Usage

    nonisolated func monthToDateUsage(for monthStart: Date) async -> TimeInterval {
        await MainActor.run {
            monthlyUsage[monthStart] ?? 0
        }
    }

    nonisolated func addMonthlyUsage(_ seconds: TimeInterval, for day: Date) async {
        await MainActor.run {
            let current = monthlyUsage[day] ?? 0
            monthlyUsage[day] = current + seconds
            monthUsageSubject.send(current + seconds)
        }
    }

    nonisolated func resetIfMonthChanged(now: Date) async {
        await MainActor.run {
            resetMonthCallCount += 1
            // In tests, we can just clear all monthly usage
            monthlyUsage.removeAll()
            monthUsageSubject.send(0)
        }
    }
}

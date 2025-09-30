import Foundation

/// OperationCoordinator
/// ---------------------
/// Actor‑backed, process‑wide coordinator for Sonora’s long‑running operations
/// (Recording, Transcription, Analysis). It centralizes:
/// - Conflict detection (e.g. recording vs. transcription on the same memo)
/// - Lightweight priority queueing (pending → active)
/// - Global status + metrics for the UI and diagnostics
/// - Delivery of detailed updates to a weak @MainActor delegate and coarse AppEvents
///
/// Concurrency & safety:
/// - All mutable state is actor‑isolated (no locks).
/// - `statusDelegate` is weak and @MainActor; we bridge via a setter and always call back on main.
/// - AppEvent publications that affect UI are dispatched on the main actor.
///
/// Design notes:
/// - Capacity is enforced at registration time to keep `start()` cheap and predictable.
/// - Queue ordering: by priority (high first) then FIFO by creation time.
/// - This is not a general job system; it solves Sonora‑specific UX needs. See ADR for trade‑offs.
public actor OperationCoordinator {

    // MARK: - Nested Types (Subtypes)
    /// Memory management configuration
    internal struct MemoryManagementConfig {
        internal static let maxOperationHistory = 100        // Count-based limit
        internal static let standardRetentionTime: TimeInterval = 300  // 5 minutes normal
        internal static let memoryPressureRetentionTime: TimeInterval = 60  // 1 minute under pressure
        internal static let cleanupInterval: TimeInterval = 30  // Check every 30 seconds
        internal static let memoryPressureThreshold: Double = 0.8  // 80% of max operations

        // Sliding window tiers
        internal static let recentOperationLimit = 20     // Keep last 20 operations always
        internal static let completedOperationLimit = 50  // Keep up to 50 completed operations
        internal static let errorOperationLimit = 30      // Keep up to 30 failed operations for debugging
    }

    // MARK: - Singleton
    public static let shared = OperationCoordinator()

    // MARK: - State Management

    /// All operations indexed by unique ID (lifecycle source of truth)
    private var operations: [UUID: Operation] = [:]

    /// IDs of active operations per memo for O(1) conflict checks
    private var activeOperationsByMemo: [UUID: Set<UUID>] = [:]

    /// Pending operation IDs waiting for conflicts/resources (metadata lives in `operations`)
    private var queuedOperations: [UUID] = []

    /// Global concurrency cap (checked at registration time)
    private let maxConcurrentOperations = 10

    // MARK: - Sliding Window Memory Management

    /// Memory pressure detection
    private var isUnderMemoryPressure = false
    private var lastCleanupTime = Date()
    private var cleanupTimer: Task<Void, Never>?

    /// Logger for diagnostics and debugging
    private let logger: any LoggerProtocol

    /// Weak, @MainActor delegate for UI status updates
    public weak var statusDelegate: (any OperationStatusDelegate)?

    // MARK: - Internal state proxies for extensions
    internal var opsProxy: [UUID: Operation] {
        get { operations }
        set { operations = newValue }
    }
    internal var queuedProxy: [UUID] {
        get { queuedOperations }
        set { queuedOperations = newValue }
    }
    internal var activeByMemoProxy: [UUID: Set<UUID>] {
        get { activeOperationsByMemo }
        set { activeOperationsByMemo = newValue }
    }
    internal var isUnderPressureProxy: Bool {
        get { isUnderMemoryPressure }
        set { isUnderMemoryPressure = newValue }
    }
    internal var lastCleanupTimeProxy: Date {
        get { lastCleanupTime }
        set { lastCleanupTime = newValue }
    }
    internal var cleanupTimerProxy: Task<Void, Never>? {
        get { cleanupTimer }
        set { cleanupTimer = newValue }
    }
    internal var loggerProxy: any LoggerProtocol { logger }

    // MARK: - Initialization
    private init(
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.logger = logger

        // Start the sliding window cleanup timer after initialization
        Task { await self.startCleanupTimer() }

        logger.debug(
            "OperationCoordinator initialized with sliding window memory management",
            category: .system,
            context: LogContext()
        )

        // Observe system memory pressure to adapt cleanup aggressiveness
        NotificationCenter.default.addObserver(
            forName: .memoryPressureStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self = self else { return }
            let under = (note.userInfo?["isUnderPressure"] as? Bool) ?? false
            Task { await self.setMemoryPressureState(under) }
        }
    }

    deinit {
        cleanupTimer?.cancel()
    }

    // MARK: - Internal snapshots for extensions
    internal func snapshotOperations() -> [Operation] { Array(operations.values) }
    internal func snapshotQueuedIds() -> [UUID] { queuedOperations }
    internal func snapshotActiveByMemo() -> [UUID: Set<UUID>] { activeOperationsByMemo }
    internal func snapshotMaxConcurrentOps() -> Int { maxConcurrentOperations }

    /// Set the status delegate (called from MainActor; bridge into actor)
    @MainActor
    public func setStatusDelegate(_ delegate: (any OperationStatusDelegate)?) {
        Task { [weak self] in
            await self?._setStatusDelegate(delegate)
        }
    }

    private func _setStatusDelegate(_ delegate: (any OperationStatusDelegate)?) {
        statusDelegate = delegate
    }

    // MARK: - Operation Registration

    // Registration moved to OperationCoordinator+Queue.swift

    // Start moved to OperationCoordinator+Queue.swift

    /// Complete an operation (success)
    public func completeOperation(_ operationId: UUID) async {
        await finishOperation(operationId, status: .completed, errorDescription: nil)
    }

    /// Fail an operation
    public func failOperation(_ operationId: UUID, errorDescription: String) async {
        await finishOperation(operationId, status: .failed, errorDescription: errorDescription)
    }

    /// Cancel an operation
    public func cancelOperation(_ operationId: UUID) async {
        await finishOperation(operationId, status: .cancelled, errorDescription: nil)
    }

    /// Update progress for a running operation
    public func updateProgress(operationId: UUID, progress: OperationProgress) async {
        guard var operation = operations[operationId] else {
            logger.warning("updateProgress: operation not found", category: .system, context: LogContext(additionalInfo: ["operationId": operationId.uuidString]), error: nil)
            return
        }

        let previous = operation.progress
        operation.progress = progress
        operations[operationId] = operation

        // Notify status delegate with a detailed progress update
        await notifyProgressDelegate(operation: operation, previousProgress: previous)

        // Also publish progress via the event bus for UI layers that consume AppEvents
        if operation.type.category == .transcription {
            let memoId = operation.type.memoId
            let fraction = max(0.0, min(1.0, progress.percentage))
            await MainActor.run {
                EventBus.shared.publish(.transcriptionProgress(memoId: memoId, fraction: fraction, step: progress.currentStep))
            }
        }
    }

    /// Cancel all operations for a specific memo
    public func cancelAllOperations(for memoId: UUID) async -> Int {
        let allOps = await getAllOperations(for: memoId)
        let cancellableOps = allOps.filter { $0.status.isInProgress }

        for operation in cancellableOps {
            await cancelOperation(operation.id)
        }

        logger.info(
            "Cancelled \(cancellableOps.count) operations for memo: \(memoId)",
            category: .system,
            context: LogContext(additionalInfo: ["memoId": memoId.uuidString])
        )

        return cancellableOps.count
    }

    /// Cancel all operations of a specific type system-wide
    public func cancelOperations(ofType category: OperationCategory) async -> Int {
        let activeOps = await getOperations(ofType: category, withStatus: .active)
        let pendingOps = await getOperations(ofType: category, withStatus: .pending)
        let cancellableOps = activeOps + pendingOps

        for operation in cancellableOps {
            await cancelOperation(operation.id)
        }

        logger.info(
            "Cancelled \(cancellableOps.count) operations of type: \(category.rawValue)",
            category: .system,
            context: LogContext()
        )

        return cancellableOps.count
    }

    /// Cancel all operations system-wide (emergency stop)
    public func cancelAllOperations() async -> Int {
        let allActiveOps = await getAllActiveOperations()
        let allPendingOps = await getOperationsByStatus(.pending)
        let cancellableOps = allActiveOps + allPendingOps

        for operation in cancellableOps {
            await cancelOperation(operation.id)
        }

        logger.warning(
            "Emergency cancellation of all operations: \(cancellableOps.count) operations cancelled",
            category: .system,
            context: LogContext(),
            error: nil
        )

        return cancellableOps.count
    }

    // MARK: - Private Implementation

    /// Transition to a terminal state (completed/failed/cancelled), notify, and cleanup
    private func finishOperation(_ operationId: UUID, status: OperationStatus, errorDescription: String?) async {
        guard var operation = operations[operationId] else {
            logger.error(
                "Cannot finish operation: not found",
                category: .system,
                context: LogContext(additionalInfo: ["operationId": operationId.uuidString]),
                error: errorDescription.map { NSError(domain: "OperationError", code: -1, userInfo: [NSLocalizedDescriptionKey: $0]) }
            )
            return
        }

        // Get previous status for delegate notification
        let previousStatus = operation.status

        // Update operation state
        operation.status = status
        operation.completedAt = Date()
        operation.errorDescription = errorDescription
        operations[operationId] = operation

        // Remove from active tracking
        let memoId = operation.type.memoId
        activeOperationsByMemo[memoId]?.remove(operationId)
        if activeOperationsByMemo[memoId]?.isEmpty == true {
            activeOperationsByMemo[memoId] = nil
        }

        let context = LogContext(additionalInfo: [
            "operationId": operationId.uuidString,
            "operationType": operation.type.description,
            "status": status.displayName,
            "duration": operation.executionDuration.map { String(format: "%.2fs", $0) } ?? "unknown"
        ])

        let logLevel: LogLevel = status == .completed ? .info : .warning
        logger.log(level: logLevel,
                  category: .system,
                  message: "Operation finished: \(operation.type.description) - \(status.displayName)",
                  context: context,
                  error: errorDescription.map { NSError(domain: "OperationError", code: -1, userInfo: [NSLocalizedDescriptionKey: $0]) })

        // Notify via event bus
        await notifyOperationStateChange(operation)

        // Notify status delegate
        await notifyStatusDelegate(operation: operation, previousStatus: previousStatus)

        // Try to start any queued operations that might now be able to run
        await processQueuedOperations()

        // Clean up old completed operations to prevent memory growth
        await cleanupCompletedOperations()
    }

    // Conflict detection moved to OperationCoordinator+Queue.swift

    // Conflict handling moved to OperationCoordinator+Queue.swift

    // tryStartOperation moved to OperationCoordinator+Queue.swift

    // getOperation moved to OperationCoordinator+Queue.swift

    // Queue processing moved to OperationCoordinator+Queue.swift

    // Notifications moved to OperationCoordinator+Notifications.swift

    // Cleanup moved to OperationCoordinator+Cleanup.swift

    // Event bus notifications moved to OperationCoordinator+Notifications.swift

    // MARK: - Public Query Interface

    /// Get all active operations for a memo
    public func getActiveOperations(for memoId: UUID) async -> [Operation] {
        guard let operationIds = activeOperationsByMemo[memoId] else {
            return []
        }

        return operationIds.compactMap { operations[$0] }
    }

    /// Get all operations (active and completed) for a memo
    public func getAllOperations(for memoId: UUID) async -> [Operation] {
        operations.values.filter { $0.type.memoId == memoId }
    }

    /// Get all active operations system-wide
    public func getAllActiveOperations() async -> [Operation] {
        operations.values.filter { $0.status == .active }
    }

    /// Get all operations with specified status system-wide
    public func getOperationsByStatus(_ status: OperationStatus) async -> [Operation] {
        operations.values.filter { $0.status == status }
    }

    /// Get operations filtered by type and optionally by status
    public func getOperations(
        ofType category: OperationCategory,
        withStatus status: OperationStatus? = nil
    ) async -> [Operation] {
        var filtered = operations.values.filter { $0.type.category == category }
        if let status = status {
            filtered = filtered.filter { $0.status == status }
        }
        return filtered.sorted { $0.createdAt < $1.createdAt }
    }

    /// Get all queued operations in priority order
    public func getQueuedOperations() async -> [Operation] {
        let queuedOps = queuedOperations.compactMap { operations[$0] }
        return queuedOps.sorted { operation1, operation2 in
            if operation1.priority != operation2.priority {
                return operation1.priority > operation2.priority
            }
            return operation1.createdAt < operation2.createdAt
        }
    }

    /// Check if a specific operation type is active for a memo
    public func isOperationActive(_ operationType: OperationType) async -> Bool {
        let activeOps = await getActiveOperations(for: operationType.memoId)
        return activeOps.contains { $0.type == operationType }
    }

    /// Check if any recording is active for a memo
    public func isRecordingActive(for memoId: UUID) async -> Bool {
        await isOperationActive(.recording(memoId: memoId))
    }

    /// Check if transcription is active for a memo
    public func isTranscriptionActive(for memoId: UUID) async -> Bool {
        await isOperationActive(.transcription(memoId: memoId))
    }

    // Metrics and summaries are defined in OperationCoordinator+Metrics.swift
}

extension OperationCoordinator: OperationCoordinatorProtocol {}

// MARK: - Convenience Extensions

public extension OperationCoordinator {

    /// Register and start a recording operation
    func startRecording(for memoId: UUID) async -> UUID? {
        await registerOperation(.recording(memoId: memoId))
    }

    /// Register and start a transcription operation
    func startTranscription(for memoId: UUID) async -> UUID? {
        await registerOperation(.transcription(memoId: memoId))
    }

    /// Register and start an analysis operation
    func startAnalysis(for memoId: UUID, type: AnalysisMode) async -> UUID? {
        await registerOperation(.analysis(memoId: memoId, analysisType: type))
    }

    /// Check if a memo can start transcription (no recording active)
    func canStartTranscription(for memoId: UUID) async -> Bool {
        let activeOps = await getActiveOperations(for: memoId)
        return !activeOps.contains { $0.type.category == .recording }
    }

    /// Check if a memo can start recording (no conflicting operations)
    func canStartRecording(for memoId: UUID) async -> Bool {
        let activeOps = await getActiveOperations(for: memoId)
        return !activeOps.contains { $0.type.category.conflictsWith.contains(.recording) }
    }
}

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
    
    /// EventBus for coarse operation events (e.g. recording started/completed, transcription progress)
    private let eventBus: any EventBusProtocol
    
    /// Logger for diagnostics and debugging
    private let logger: any LoggerProtocol
    
    /// Weak, @MainActor delegate for UI status updates
    public weak var statusDelegate: (any OperationStatusDelegate)?
    
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
    
    // MARK: - Initialization
    private init(
        eventBus: any EventBusProtocol = EventBus.shared,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.eventBus = eventBus
        self.logger = logger
        
        logger.debug("OperationCoordinator initialized", 
                    category: .system, 
                    context: LogContext())
    }
    
    // MARK: - Operation Registration
    
    /// Register a new operation and check for conflicts
    /// Returns operation ID if registered, nil if rejected
    public func registerOperation(_ operationType: OperationType) async -> UUID? {
        let operation = Operation(type: operationType)
        let context = LogContext(additionalInfo: [
            "operationId": operation.id.uuidString,
            "operationType": operationType.description,
            "memoId": operationType.memoId.uuidString
        ])
        
        logger.debug("Registering operation: \(operationType.description)", 
                    category: .system, 
                    context: context)
        
        // Capacity gate (enforced here; `start()` does not re-check)
        let activeCount = operations.values.filter { $0.status == .active }.count
        if activeCount >= maxConcurrentOperations {
            logger.warning("Operation registration rejected: at capacity (\(activeCount)/\(maxConcurrentOperations))", 
                          category: .system, 
                          context: context, 
                          error: nil)
            return nil
        }
        
        // Check conflicts against active ops on the same memo
        if let conflict = await detectConflicts(for: operationType) {
            return await handleConflict(operation, conflict: conflict, context: context)
        }
        
        // No conflicts - register and potentially start immediately
        operations[operation.id] = operation
        
        logger.info("Operation registered successfully: \(operationType.description)", 
                   category: .system, 
                   context: context)
        
        // Try to start immediately if no conflicts
        await tryStartOperation(operation.id)
        
        return operation.id
    }
    
    /// Start an operation (transition pending → active)
    public func startOperation(_ operationId: UUID) async -> Bool {
        guard var operation = operations[operationId] else {
            logger.error("Cannot start operation: not found", 
                        category: .system, 
                        context: LogContext(additionalInfo: ["operationId": operationId.uuidString]), 
                        error: nil)
            return false
        }
        
        guard operation.status == .pending else {
            logger.warning("Cannot start operation: not in pending state (current: \(operation.status.displayName))", 
                          category: .system, 
                          context: LogContext(additionalInfo: ["operationId": operationId.uuidString]), 
                          error: nil)
            return false
        }
        
        // Defensive conflict check (another op may have become active)
        if let conflict = await detectConflicts(for: operation.type) {
            logger.debug("Operation start delayed due to conflict with \(conflict.conflictingOperation.type.description)", 
                        category: .system, 
                        context: LogContext(additionalInfo: ["operationId": operationId.uuidString]))
            return false
        }
        
        // Update operation state
        operation.status = .active
        operation.startedAt = Date()
        operations[operationId] = operation
        
        // Index active operation by memo for conflict checks
        let memoId = operation.type.memoId
        if activeOperationsByMemo[memoId] == nil {
            activeOperationsByMemo[memoId] = Set()
        }
        activeOperationsByMemo[memoId]?.insert(operationId)
        
        let context = LogContext(additionalInfo: [
            "operationId": operationId.uuidString,
            "operationType": operation.type.description,
            "memoId": memoId.uuidString
        ])
        
        logger.info("Operation started: \(operation.type.description)", 
                   category: .system, 
                   context: context)
        
        // Publish coarse app events for UI consumers
        await notifyOperationStateChange(operation)
        
        return true
    }
    
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
        
        logger.info("Cancelled \(cancellableOps.count) operations for memo: \(memoId)", 
                   category: .system, 
                   context: LogContext(additionalInfo: ["memoId": memoId.uuidString]))
        
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
        
        logger.info("Cancelled \(cancellableOps.count) operations of type: \(category.rawValue)", 
                   category: .system, 
                   context: LogContext())
        
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
        
        logger.warning("Emergency cancellation of all operations: \(cancellableOps.count) operations cancelled", 
                      category: .system, 
                      context: LogContext(), 
                      error: nil)
        
        return cancellableOps.count
    }
    
    // MARK: - Private Implementation
    
    /// Transition to a terminal state (completed/failed/cancelled), notify, and cleanup
    private func finishOperation(_ operationId: UUID, status: OperationStatus, errorDescription: String?) async {
        guard var operation = operations[operationId] else {
            logger.error("Cannot finish operation: not found", 
                        category: .system, 
                        context: LogContext(additionalInfo: ["operationId": operationId.uuidString]), 
                        error: errorDescription.map { NSError(domain: "OperationError", code: -1, userInfo: [NSLocalizedDescriptionKey: $0]) })
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
    
    /// Detect conflicts against currently active operations on the same memo
    private func detectConflicts(for operationType: OperationType) async -> OperationConflict? {
        let memoId = operationType.memoId
        
        // Get active operations for this memo
        guard let activeOperationIds = activeOperationsByMemo[memoId] else {
            return nil // No active operations for this memo
        }
        
        // Check each active operation for conflicts
        for operationId in activeOperationIds {
            guard let existingOperation = operations[operationId] else { continue }
            
            if let conflict = OperationConflict.detectConflict(
                existing: existingOperation, 
                proposed: operationType
            ) {
                return conflict
            }
        }
        
        return nil
    }
    
    private func handleConflict(
        _ operation: Operation, 
        conflict: OperationConflict, 
        context: LogContext
    ) async -> UUID? {
        switch conflict.resolutionStrategy {
        case .queue:
            // Add to queue
            operations[operation.id] = operation
            queuedOperations.append(operation.id)
            
            logger.info("Operation queued due to conflict with \(conflict.conflictingOperation.type.description)", 
                       category: .system, 
                       context: context)
            return operation.id
            
        case .cancel:
            logger.warning("Operation cancelled due to unresolvable conflict", 
                          category: .system, 
                          context: context, 
                          error: nil)
            return nil
            
        case .replace:
            // Cancel existing operation and start new one
            await cancelOperation(conflict.conflictingOperation.id)
            operations[operation.id] = operation
            
            logger.info("Replacing lower priority operation \(conflict.conflictingOperation.type.description)", 
                       category: .system, 
                       context: context)
            
            await tryStartOperation(operation.id)
            return operation.id
            
        case .allow:
            // No actual conflict - proceed normally
            operations[operation.id] = operation
            await tryStartOperation(operation.id)
            return operation.id
        }
    }
    
    /// Best‑effort start helper
    private func tryStartOperation(_ operationId: UUID) async {
        // Attempt to start operation if no conflicts
        let _ = await startOperation(operationId)
    }

    public func getOperation(_ operationId: UUID) async -> Operation? {
        return operations[operationId]
    }
    
    /// Start queued operations in priority order when capacity/conflicts allow
    private func processQueuedOperations() async {
        // Try to start queued operations in priority order
        let sortedQueue = queuedOperations.compactMap { id in
            operations[id]
        }.sorted { operation1, operation2 in
            // Sort by priority (high first), then by creation time (older first)
            if operation1.priority != operation2.priority {
                return operation1.priority > operation2.priority
            }
            return operation1.createdAt < operation2.createdAt
        }
        
        for operation in sortedQueue {
            if await startOperation(operation.id) {
                // Remove from queue if successfully started
                queuedOperations.removeAll { $0 == operation.id }
            }
        }
    }
    
    /// Deliver lifecycle updates to the @MainActor delegate
    private func notifyStatusDelegate(operation: Operation, previousStatus: OperationStatus) async {
        guard let delegate = statusDelegate else { return }
        
        let detailedPrevious = mapToDetailedStatus(previousStatus)
        let detailedCurrent = mapToDetailedStatus(operation.status)
        
        let update = OperationStatusUpdate(
            operationId: operation.id,
            memoId: operation.type.memoId,
            operationType: operation.type,
            previousStatus: detailedPrevious,
            currentStatus: detailedCurrent
        )
        
        // Async delegate callbacks on main actor (delegate is @MainActor)
        await delegate.operationStatusDidUpdate(update)
        
        switch operation.status {
        case .completed:
            await delegate.operationDidComplete(operation.id, memoId: operation.type.memoId, operationType: operation.type)
        case .failed:
            let err = NSError(domain: "OperationError", code: -1, userInfo: [NSLocalizedDescriptionKey: operation.errorDescription ?? "Unknown error"])
            await delegate.operationDidFail(operation.id, memoId: operation.type.memoId, operationType: operation.type, error: err)
        default:
            break
        }
    }

    /// Deliver progress updates to the @MainActor delegate
    private func notifyProgressDelegate(operation: Operation, previousProgress: OperationProgress?) async {
        guard let delegate = statusDelegate else { return }

        let previousStatus: DetailedOperationStatus? = previousProgress.map { .processing($0) } ?? .processing(nil)
        let currentStatus: DetailedOperationStatus = .processing(operation.progress)

        let update = OperationStatusUpdate(
            operationId: operation.id,
            memoId: operation.type.memoId,
            operationType: operation.type,
            previousStatus: previousStatus,
            currentStatus: currentStatus
        )

        await delegate.operationStatusDidUpdate(update)
    }
    
    private func mapToDetailedStatus(_ status: OperationStatus) -> DetailedOperationStatus {
        switch status {
        case .pending:
            return .queued
        case .active:
            return .processing(nil)
        case .completed:
            return .completed(Date())
        case .failed:
            return .failed("Operation failed", Date())
        case .cancelled:
            return .cancelled(Date())
        }
    }
    
    private func cleanupCompletedOperations() async {
        let now = Date()
        let cleanupThreshold: TimeInterval = 300 // Keep completed operations for 5 minutes
        
        let operationsToRemove = operations.values.filter { operation in
            operation.status.isFinished && 
            now.timeIntervalSince(operation.completedAt ?? operation.createdAt) > cleanupThreshold
        }
        
        for operation in operationsToRemove {
            operations.removeValue(forKey: operation.id)
            queuedOperations.removeAll { $0 == operation.id }
        }
        
        if !operationsToRemove.isEmpty {
            logger.debug("Cleaned up \(operationsToRemove.count) old operations", 
                        category: .system, 
                        context: LogContext())
        }
    }
    
    private func notifyOperationStateChange(_ operation: Operation) async {
        // Convert operation state changes to AppEvents for integration with existing event system
        // This allows Live Activities to react to operation state changes
        
        switch (operation.type, operation.status) {
        case (.recording(let memoId), .active):
            await MainActor.run {
                EventBus.shared.publish(.recordingStarted(memoId: memoId))
            }
            
        case (.recording(let memoId), .completed):
            await MainActor.run {
                EventBus.shared.publish(.recordingCompleted(memoId: memoId))
            }
            
        default:
            // Other operation state changes don't currently map to AppEvents
            // This can be expanded as needed
            break
        }
    }
    
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
        return operations.values.filter { $0.type.memoId == memoId }
    }
    
    /// Get all active operations system-wide
    public func getAllActiveOperations() async -> [Operation] {
        return operations.values.filter { $0.status == .active }
    }
    
    /// Get all operations with specified status system-wide
    public func getOperationsByStatus(_ status: OperationStatus) async -> [Operation] {
        return operations.values.filter { $0.status == status }
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
        return await isOperationActive(.recording(memoId: memoId))
    }
    
    /// Check if transcription is active for a memo
    public func isTranscriptionActive(for memoId: UUID) async -> Bool {
        return await isOperationActive(.transcription(memoId: memoId))
    }
    
    /// Get current system metrics
    public func getMetrics() async -> OperationMetrics {
        let allOps = operations.values
        let activeOps = allOps.filter { $0.status == .active }
        let queuedOps = allOps.filter { $0.status == .pending }
        let completedOps = allOps.filter { $0.status == .completed }
        let failedOps = allOps.filter { $0.status == .failed }
        
        // Calculate average execution time for completed operations
        let completedExecutionTimes = completedOps.compactMap { $0.executionDuration }
        let averageExecutionTime = completedExecutionTimes.isEmpty ? 
            nil : completedExecutionTimes.reduce(0, +) / Double(completedExecutionTimes.count)
        
        // Count operations by type
        var operationsByType: [OperationCategory: Int] = [:]
        for category in OperationCategory.allCases {
            operationsByType[category] = allOps.filter { $0.type.category == category }.count
        }
        
        return OperationMetrics(
            totalOperations: allOps.count,
            activeOperations: activeOps.count,
            queuedOperations: queuedOps.count,
            completedOperations: completedOps.count,
            failedOperations: failedOps.count,
            averageExecutionTime: averageExecutionTime,
            operationsByType: operationsByType
        )
    }
    
    /// Get enhanced system metrics for UI display
    public func getSystemMetrics() async -> SystemOperationMetrics {
        let metrics = await getMetrics()
        return SystemOperationMetrics(
            totalOperations: metrics.totalOperations,
            activeOperations: metrics.activeOperations,
            queuedOperations: metrics.queuedOperations,
            maxConcurrentOperations: maxConcurrentOperations,
            averageOperationDuration: metrics.averageExecutionTime
        )
    }
    
    /// Get operation summaries for UI display
    public func getOperationSummaries(
        group: OperationGroup = .all,
        filter: OperationFilter = .all,
        for memoId: UUID? = nil
    ) async -> [OperationSummary] {
        var ops = Array(operations.values)
        
        // Filter by memo if specified
        if let memoId = memoId {
            ops = ops.filter { $0.type.memoId == memoId }
        }
        
        // Filter by group (operation type)
        if group != .all {
            ops = ops.filter { group.operationCategories.contains($0.type.category) }
        }
        
        // Filter by status
        if filter != .all {
            ops = ops.filter { filter.statusFilter.contains($0.status) }
        }
        
        return Array(ops)
            .sorted { $0.createdAt > $1.createdAt } // Most recent first
            .map { OperationSummary(operation: $0) }
    }
    
    /// Get queue position for a pending operation
    public func getQueuePosition(for operationId: UUID) async -> Int? {
        guard let operation = operations[operationId],
              operation.status == .pending else {
            return nil
        }
        
        let queuedOps = await getQueuedOperations()
        return queuedOps.firstIndex { $0.id == operationId }
    }
    
    /// Get debug information
    public func getDebugInfo() async -> String {
        let metrics = await getMetrics()
        let queueInfo = queuedOperations.isEmpty ? "empty" : "\(queuedOperations.count) operations"
        let memoInfo = activeOperationsByMemo.isEmpty ? "none" : 
            activeOperationsByMemo.map { memoId, ops in 
                "\(memoId): \(ops.count) ops" 
            }.joined(separator: ", ")
        
        return """
        OperationCoordinator Debug Info:
        \(metrics.description)
        
        Queue: \(queueInfo)
        Active by memo: \(memoInfo)
        Max concurrent: \(maxConcurrentOperations)
        """
    }
}

extension OperationCoordinator: OperationCoordinatorProtocol {}

// MARK: - Convenience Extensions

public extension OperationCoordinator {
    
    /// Register and start a recording operation
    func startRecording(for memoId: UUID) async -> UUID? {
        return await registerOperation(.recording(memoId: memoId))
    }
    
    /// Register and start a transcription operation
    func startTranscription(for memoId: UUID) async -> UUID? {
        return await registerOperation(.transcription(memoId: memoId))
    }
    
    /// Register and start an analysis operation
    func startAnalysis(for memoId: UUID, type: AnalysisMode) async -> UUID? {
        return await registerOperation(.analysis(memoId: memoId, analysisType: type))
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

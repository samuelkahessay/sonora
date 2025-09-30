import Foundation

extension OperationCoordinator {
    // MARK: - Registration & Start
    public func registerOperation(_ operationType: OperationType) async -> UUID? {
        let operation = Operation(type: operationType)
        let context = LogContext(additionalInfo: [
            "operationId": operation.id.uuidString,
            "operationType": operationType.description,
            "memoId": operationType.memoId.uuidString
        ])

        loggerProxy.debug("Registering operation: \(operationType.description)", category: .system, context: context)

        // Capacity gate
        let activeCount = opsProxy.values.filter { $0.status == .active }.count
        if activeCount >= snapshotMaxConcurrentOps() {
            loggerProxy.warning("Operation registration rejected: at capacity (\(activeCount)/\(snapshotMaxConcurrentOps()))", category: .system, context: context, error: nil)
            return nil
        }

        // Conflicts
        if let conflict = await detectConflicts(for: operationType) {
            return await handleConflict(operation, conflict: conflict, context: context)
        }

        // No conflicts - register and attempt start
        opsProxy[operation.id] = operation

        loggerProxy.info("Operation registered successfully: \(operationType.description)", category: .system, context: context)
        await tryStartOperation(operation.id)
        return operation.id
    }

    public func startOperation(_ operationId: UUID) async -> Bool {
        guard var operation = opsProxy[operationId] else {
            loggerProxy.error("Cannot start operation: not found", category: .system, context: LogContext(additionalInfo: ["operationId": operationId.uuidString]), error: nil)
            return false
        }

        guard operation.status == .pending else {
            loggerProxy.warning("Cannot start operation: not in pending state (current: \(operation.status.displayName))", category: .system, context: LogContext(additionalInfo: ["operationId": operationId.uuidString]), error: nil)
            return false
        }

        // Defensive conflict check
        if let conflict = await detectConflicts(for: operation.type) {
            loggerProxy.debug("Operation start delayed due to conflict with \(conflict.conflictingOperation.type.description)", category: .system, context: LogContext(additionalInfo: ["operationId": operationId.uuidString]))
            return false
        }

        // Update state
        operation.status = .active
        operation.startedAt = Date()
        opsProxy[operationId] = operation

        // Index active by memo
        let memoId = operation.type.memoId
        var byMemo = activeByMemoProxy
        if byMemo[memoId] == nil { byMemo[memoId] = Set() }
        byMemo[memoId]?.insert(operationId)
        activeByMemoProxy = byMemo

        let context = LogContext(additionalInfo: [
            "operationId": operationId.uuidString,
            "operationType": operation.type.description,
            "memoId": memoId.uuidString
        ])
        loggerProxy.info("Operation started: \(operation.type.description)", category: .system, context: context)

        await notifyOperationStateChange(operation)
        return true
    }

    private func tryStartOperation(_ operationId: UUID) async {
        _ = await startOperation(operationId)
    }

    // MARK: - Queue Management
    internal func processQueuedOperations() async {
        let sortedQueue = snapshotQueuedIds().compactMap { id in
            opsProxy[id]
        }.sorted { o1, o2 in
            if o1.priority != o2.priority { return o1.priority > o2.priority }
            return o1.createdAt < o2.createdAt
        }

        for op in sortedQueue {
            if await startOperation(op.id) {
                var q = queuedProxy
                q.removeAll { $0 == op.id }
                queuedProxy = q
            }
        }
    }

    // MARK: - Conflict Detection
    private func detectConflicts(for operationType: OperationType) async -> OperationConflict? {
        let memoId = operationType.memoId
        guard let activeIds = activeByMemoProxy[memoId] else { return nil }
        for id in activeIds {
            guard let existing = opsProxy[id] else { continue }
            if let conflict = OperationConflict.detectConflict(existing: existing, proposed: operationType) {
                return conflict
            }
        }
        return nil
    }

    private func handleConflict(_ operation: Operation, conflict: OperationConflict, context: LogContext) async -> UUID? {
        switch conflict.resolutionStrategy {
        case .queue:
            opsProxy[operation.id] = operation
            var q = queuedProxy
            q.append(operation.id)
            queuedProxy = q
            loggerProxy.info("Operation queued due to conflict with \(conflict.conflictingOperation.type.description)", category: .system, context: context)
            return operation.id
        case .cancel:
            loggerProxy.warning("Operation cancelled due to unresolvable conflict", category: .system, context: context, error: nil)
            return nil
        case .replace:
            await cancelOperation(conflict.conflictingOperation.id)
            opsProxy[operation.id] = operation
            loggerProxy.info("Replacing lower priority operation \(conflict.conflictingOperation.type.description)", category: .system, context: context)
            await tryStartOperation(operation.id)
            return operation.id
        case .allow:
            opsProxy[operation.id] = operation
            await tryStartOperation(operation.id)
            return operation.id
        }
    }

    // MARK: - Accessors
    public func getOperation(_ operationId: UUID) async -> Operation? { opsProxy[operationId] }
}

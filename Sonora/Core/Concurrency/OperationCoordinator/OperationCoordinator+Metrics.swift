import Foundation

extension OperationCoordinator {

    // MARK: - Metrics
    public func getMetrics() async -> OperationMetrics {
        let allOps = snapshotOperations()
        let activeOps = allOps.filter { $0.status == .active }
        let queuedOps = allOps.filter { $0.status == .pending }
        let completedOps = allOps.filter { $0.status == .completed }
        let failedOps = allOps.filter { $0.status == .failed }

        let completedExecutionTimes = completedOps.compactMap { $0.executionDuration }
        let averageExecutionTime = completedExecutionTimes.isEmpty ?
            nil : completedExecutionTimes.reduce(0, +) / Double(completedExecutionTimes.count)

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

    public func getSystemMetrics() async -> SystemOperationMetrics {
        let metrics = await getMetrics()
        return SystemOperationMetrics(
            totalOperations: metrics.totalOperations,
            activeOperations: metrics.activeOperations,
            queuedOperations: metrics.queuedOperations,
            maxConcurrentOperations: snapshotMaxConcurrentOps(),
            averageOperationDuration: metrics.averageExecutionTime
        )
    }

    public func getOperationSummaries(
        group: OperationGroup = .all,
        filter: OperationFilter = .all,
        for memoId: UUID? = nil
    ) async -> [OperationSummary] {
        var ops = snapshotOperations()

        if let memoId = memoId {
            ops = ops.filter { $0.type.memoId == memoId }
        }

        if group != .all {
            ops = ops.filter { group.operationCategories.contains($0.type.category) }
        }

        if filter != .all {
            ops = ops.filter { filter.statusFilter.contains($0.status) }
        }

        return ops
            .sorted { $0.createdAt > $1.createdAt }
            .map { OperationSummary(operation: $0) }
    }

    public func getQueuePosition(for operationId: UUID) async -> Int? {
        let ops = snapshotOperations()
        let queuedIds = snapshotQueuedIds()
        guard let op = ops.first(where: { $0.id == operationId }), op.status == .pending else {
            return nil
        }
        let queuedOps = queuedIds.compactMap { id in ops.first(where: { $0.id == id }) }
        return queuedOps.firstIndex { $0.id == operationId }
    }

    public func getDebugInfo() async -> String {
        let metrics = await getMetrics()
        let queuedIds = snapshotQueuedIds()
        let activeByMemo = snapshotActiveByMemo()
        let queueInfo = queuedIds.isEmpty ? "empty" : "\(queuedIds.count) operations"
        let memoInfo = activeByMemo.isEmpty ? "none" :
            activeByMemo.map { memoId, ops in
                "\(memoId): \(ops.count) ops"
            }.joined(separator: ", ")

        return """
        OperationCoordinator Debug Info:
        \(metrics.description)

        Queue: \(queueInfo)
        Active by memo: \(memoInfo)
        Max concurrent: \(snapshotMaxConcurrentOps())
        """
    }
}

import Foundation

extension OperationCoordinator {
    // MARK: - Cleanup lifecycle
    internal func startCleanupTimer() {
        cleanupTimerProxy = Task { [weak self] in
            while !Task.isCancelled {
                let under = await self?.isUnderPressureProxy ?? false
                let interval = under ? 10.0 : MemoryManagementConfig.cleanupInterval
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if !Task.isCancelled {
                    await self?.performIntelligentCleanup()
                }
            }
        }
    }

    internal func setMemoryPressureState(_ underPressure: Bool) async {
        let was = isUnderPressureProxy
        isUnderPressureProxy = underPressure
        if underPressure && !was {
            await emergencyMemoryCleanup()
        }
    }

    internal func performIntelligentCleanup() async {
        let now = Date()
        let timeSinceLastCleanup = now.timeIntervalSince(lastCleanupTimeProxy)

        await detectMemoryPressure()

        let retentionTime = isUnderPressureProxy ?
            MemoryManagementConfig.memoryPressureRetentionTime :
            MemoryManagementConfig.standardRetentionTime

        let initialCount = opsProxy.count

        await cleanupByTime(threshold: retentionTime)
        await enforceCountLimits()
        if isUnderPressureProxy { await emergencyMemoryCleanup() }

        let finalCount = opsProxy.count
        let cleanedCount = initialCount - finalCount
        if cleanedCount > 0 || isUnderPressureProxy {
            loggerProxy.info("Sliding window cleanup: removed \(cleanedCount) operations, \(finalCount) remaining, memory pressure: \(isUnderPressureProxy)",
                       category: .system,
                       context: LogContext(additionalInfo: [
                           "retentionTime": "\(retentionTime)s",
                           "timeSinceLastCleanup": "\(timeSinceLastCleanup)s"
                       ]))
        }

        lastCleanupTimeProxy = now
    }

    internal func cleanupByTime(threshold: TimeInterval) async {
        let now = Date()
        let operationsToRemove = opsProxy.values.filter { operation in
            let referenceTime = operation.completedAt ?? operation.createdAt
            return operation.status.isFinished && now.timeIntervalSince(referenceTime) > threshold
        }
        for operation in operationsToRemove {
            opsProxy.removeValue(forKey: operation.id)
            queuedProxy.removeAll { $0 == operation.id }
        }
    }

    internal func enforceCountLimits() async {
        guard opsProxy.count > MemoryManagementConfig.maxOperationHistory else { return }
        let allOps = opsProxy.values.sorted { $0.createdAt > $1.createdAt }
        let recentOps = Array(allOps.prefix(MemoryManagementConfig.recentOperationLimit))
        let completedOps = allOps.filter { $0.status == .completed }
        let errorOps = allOps.filter { $0.status == .failed || $0.status == .cancelled }
        let activeOps = allOps.filter { !$0.status.isFinished }
        var keepSet = Set<UUID>()
        activeOps.forEach { keepSet.insert($0.id) }
        recentOps.forEach { keepSet.insert($0.id) }
        completedOps.prefix(MemoryManagementConfig.completedOperationLimit).forEach { keepSet.insert($0.id) }
        errorOps.prefix(MemoryManagementConfig.errorOperationLimit).forEach { keepSet.insert($0.id) }
        let operationsToRemove = opsProxy.keys.filter { !keepSet.contains($0) }
        for operationId in operationsToRemove {
            opsProxy.removeValue(forKey: operationId)
            queuedProxy.removeAll { $0 == operationId }
        }
    }

    internal func emergencyMemoryCleanup() async {
        loggerProxy.warning("Emergency memory cleanup triggered", category: .system, context: LogContext(), error: nil)
        let allOps = opsProxy.values.sorted { $0.createdAt > $1.createdAt }
        let activeOps = allOps.filter { !$0.status.isFinished }
        let recentOps = Array(allOps.prefix(10))
        let criticalErrorOps = allOps.filter { $0.status == .failed && Date().timeIntervalSince($0.createdAt) < 300 }
        var keepSet = Set<UUID>()
        activeOps.forEach { keepSet.insert($0.id) }
        recentOps.forEach { keepSet.insert($0.id) }
        criticalErrorOps.forEach { keepSet.insert($0.id) }
        let operationsToRemove = opsProxy.keys.filter { !keepSet.contains($0) }
        for operationId in operationsToRemove {
            opsProxy.removeValue(forKey: operationId)
            queuedProxy.removeAll { $0 == operationId }
        }
        loggerProxy.info("Emergency cleanup completed: kept \(keepSet.count) operations", category: .system, context: LogContext())
    }

    internal func detectMemoryPressure() async {
        let operationCount = opsProxy.count
        let maxOperations = MemoryManagementConfig.maxOperationHistory
        let operationPressure = Double(operationCount) / Double(maxOperations)
        let thermalState = ProcessInfo.processInfo.thermalState
        let thermalPressure = thermalState.rawValue >= 2
        let previousPressure = isUnderPressureProxy
        isUnderPressureProxy = operationPressure > MemoryManagementConfig.memoryPressureThreshold || thermalPressure
        if isUnderPressureProxy && !previousPressure {
            loggerProxy.warning("Memory pressure detected - switching to aggressive cleanup",
                          category: .system,
                          context: LogContext(additionalInfo: [
                              "operationCount": "\(operationCount)",
                              "operationPressure": "\(operationPressure)",
                              "thermalState": "\(thermalState)",
                              "thermalPressure": "\(thermalPressure)"
                          ]),
                          error: nil)
        } else if !isUnderPressureProxy && previousPressure {
            loggerProxy.info("Memory pressure relieved - returning to standard cleanup", category: .system, context: LogContext())
        }
    }

    internal func cleanupCompletedOperations() async {
        await performIntelligentCleanup()
    }
}

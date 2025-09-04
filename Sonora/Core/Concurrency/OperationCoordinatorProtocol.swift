import Foundation

public protocol OperationCoordinatorProtocol: AnyObject, Sendable {
    // Delegate (set from MainActor only)
    @MainActor func setStatusDelegate(_ delegate: (any OperationStatusDelegate)?)

    // Registration & lifecycle
    func registerOperation(_ operationType: OperationType) async -> UUID?
    func startOperation(_ operationId: UUID) async -> Bool
    func completeOperation(_ operationId: UUID) async
    func failOperation(_ operationId: UUID, errorDescription: String) async
    func cancelOperation(_ operationId: UUID) async
    // Progress updates
    func updateProgress(operationId: UUID, progress: OperationProgress) async

    // Cancellation helpers
    func cancelAllOperations(for memoId: UUID) async -> Int
    func cancelOperations(ofType category: OperationCategory) async -> Int
    func cancelAllOperations() async -> Int

    // Queries & metrics
    func isRecordingActive(for memoId: UUID) async -> Bool
    func canStartTranscription(for memoId: UUID) async -> Bool
    func getActiveOperations(for memoId: UUID) async -> [Operation]
    func getAllActiveOperations() async -> [Operation]
    func getSystemMetrics() async -> SystemOperationMetrics
    func getOperationSummaries(group: OperationGroup, filter: OperationFilter, for memoId: UUID?) async -> [OperationSummary]
    func getQueuePosition(for operationId: UUID) async -> Int?
    func getDebugInfo() async -> String
    func getOperation(_ operationId: UUID) async -> Operation?
}

import Foundation

public protocol OperationCoordinatorProtocol: AnyObject {
    // Delegate
    func setStatusDelegate(_ delegate: (any OperationStatusDelegate)?) async

    // Registration & lifecycle
    func registerOperation(_ operationType: OperationType) async -> UUID?
    func startOperation(_ operationId: UUID) async -> Bool
    func completeOperation(_ operationId: UUID) async
    func failOperation(_ operationId: UUID, error: Error) async
    func cancelOperation(_ operationId: UUID) async

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

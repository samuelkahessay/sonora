import Foundation

extension OperationCoordinator {
    // MARK: - Delegate Notifications
    internal func notifyStatusDelegate(operation: Operation, previousStatus: OperationStatus) async {
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

    internal func notifyProgressDelegate(operation: Operation, previousProgress: OperationProgress?) async {
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

    internal func mapToDetailedStatus(_ status: OperationStatus) -> DetailedOperationStatus {
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

    // MARK: - Event Bus Notifications
    internal func notifyOperationStateChange(_ operation: Operation) async {
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
            break
        }
    }
}


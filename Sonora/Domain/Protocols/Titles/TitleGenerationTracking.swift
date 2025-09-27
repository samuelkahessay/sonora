import Foundation

@MainActor
public protocol TitleGenerationTracking: AnyObject, Sendable {
    func setInProgress(_ memoId: UUID)
    func setSuccess(_ memoId: UUID, title: String)
    func setFailed(_ memoId: UUID)
    func state(for memoId: UUID) -> TitleGenerationState
}


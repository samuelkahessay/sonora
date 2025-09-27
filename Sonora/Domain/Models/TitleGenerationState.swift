import Foundation

public enum TitleGenerationState: Equatable, Sendable {
    case idle
    case inProgress
    case success(String)
    case failed
}


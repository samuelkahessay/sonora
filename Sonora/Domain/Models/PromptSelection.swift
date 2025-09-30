import Foundation

// MARK: - Prompt Selection Policy

public enum PromptSelectionPolicy: Sendable, Equatable {
    /// Context-aware selection honoring time/day filters; relaxed only when empty
    case contextAware
    /// Exploration mode for "Inspire Me": broaden filters to guarantee variety
    case exploration
}

// MARK: - Rotation Token

/// Ephemeral rotation token used to provide stable, non-repeating order
/// across consecutive prompt requests within a session.
public struct PromptRotationToken: Sendable, Equatable, Hashable {
    public let createdAt: Date
    public let candidateIds: [String]
    public let nextIndex: Int

    public init(createdAt: Date, candidateIds: [String], nextIndex: Int) {
        self.createdAt = createdAt
        self.candidateIds = candidateIds
        self.nextIndex = nextIndex
    }

    public func advancing() -> PromptRotationToken {
        guard !candidateIds.isEmpty else { return self }
        let idx = (nextIndex + 1) % candidateIds.count
        return PromptRotationToken(createdAt: createdAt, candidateIds: candidateIds, nextIndex: idx)
    }
}

// MARK: - Selection Request/Response

public struct SelectPromptRequest: Sendable, Equatable {
    public let userName: String?
    public let policy: PromptSelectionPolicy
    public let currentPromptId: String?
    public let rotationToken: PromptRotationToken?

    public init(userName: String?, policy: PromptSelectionPolicy, currentPromptId: String? = nil, rotationToken: PromptRotationToken? = nil) {
        self.userName = userName
        self.policy = policy
        self.currentPromptId = currentPromptId
        self.rotationToken = rotationToken
    }
}

public struct NextPromptResponse: Sendable, Equatable {
    public let prompt: InterpolatedPrompt
    public let rotationToken: PromptRotationToken?
    /// Source for analytics: "dynamic" | "inspire"
    public let source: String

    public init(prompt: InterpolatedPrompt, rotationToken: PromptRotationToken?, source: String) {
        self.prompt = prompt
        self.rotationToken = rotationToken
        self.source = source
    }
}

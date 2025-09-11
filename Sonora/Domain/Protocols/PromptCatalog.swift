import Foundation

/// Provides access to the static catalog of recording prompts.
/// Implementations in Data layer (e.g., static in-memory seed).
public protocol PromptCatalog: Sendable {
    func allPrompts() -> [RecordingPrompt]
    func prompts(in category: PromptCategory?) -> [RecordingPrompt]
}

public extension PromptCatalog {
    func prompts(in category: PromptCategory?) -> [RecordingPrompt] {
        guard let category else { return allPrompts() }
        return allPrompts().filter { $0.category == category }
    }
}


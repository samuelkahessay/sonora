import Foundation

/// Protocol for services that remove filler words from transcription text.
/// Kept in the domain layer so use cases can depend on abstractions rather than concrete implementations.
@MainActor
public protocol FillerWordFiltering {
    /// Enable or disable filler word removal without dropping the service reference.
    var isEnabled: Bool { get set }

    /// Replace filler words in the supplied text with cleaner phrasing.
    /// - Parameter text: The original transcription text.
    /// - Returns: The processed text with filler words removed when the service is enabled.
    func removeFillerWords(from text: String) -> String

    /// Provide an updated custom filler word list that augments the default tokens.
    /// Implementations should rebuild internal caches or regex state when this changes.
    /// - Parameter words: Case-insensitive filler words or phrases (e.g., "you know").
    func updateCustomWords(_ words: Set<String>)
}

import Foundation

/// Protocol for accessing audio file metadata without framework dependencies in Domain layer
/// Implementation will use AVFoundation in Data layer
public protocol AudioMetadataServiceProtocol: Sendable {
    /// Get the duration of an audio file in seconds
    /// - Parameter url: URL to the audio file
    /// - Returns: Duration in seconds
    /// - Throws: Error if unable to load audio file or extract duration
    func getAudioDuration(url: URL) async throws -> TimeInterval
}

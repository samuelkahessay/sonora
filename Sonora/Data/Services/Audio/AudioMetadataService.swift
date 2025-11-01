import Foundation
import AVFoundation

/// Implementation of AudioMetadataServiceProtocol using AVFoundation
/// Provides audio file metadata extraction isolated to Data layer
final class AudioMetadataService: AudioMetadataServiceProtocol {

    func getAudioDuration(url: URL) async throws -> TimeInterval {
        let asset = AVURLAsset(url: url)
        let durationTime = try await asset.load(.duration)
        let totalDurationSec = CMTimeGetSeconds(durationTime)
        return totalDurationSec
    }
}

import Foundation
import AVFoundation

extension Memo {
    /// Duration of the memo's audio file in seconds.
    var duration: TimeInterval {
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }

    /// Human-readable duration string in mm:ss format.
    var durationString: String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


import Foundation
import AVFoundation

extension Memo {
    /// Duration of the memo's audio file in seconds.
    var duration: TimeInterval {
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            let frames = Double(audioFile.length)
            let sampleRate = audioFile.fileFormat.sampleRate
            let seconds = frames / sampleRate
            return seconds.isFinite ? seconds : 0
        } catch {
            return 0
        }
    }

    /// Human-readable duration string in mm:ss format.
    var durationString: String {
        let totalSeconds = max(0, Int(duration.rounded()))
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

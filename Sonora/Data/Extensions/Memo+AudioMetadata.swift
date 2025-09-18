import Foundation
import AVFoundation

extension Memo {
    /// Duration of the memo's audio file in seconds.
    var duration: TimeInterval {
        if let stored = durationSeconds, stored.isFinite, stored > 0 {
            return stored
        }
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

    /// Estimated end time for the recording, derived from creation date plus duration.
    /// Falls back to creation date if duration is unavailable.
    var recordingEndDate: Date {
        let duration = max(0, self.duration)
        return creationDate.addingTimeInterval(duration)
    }
}

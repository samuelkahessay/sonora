// Shared ActivityKit attributes used by both the app and the Live Activity widget target.
// IMPORTANT: In Xcode, add this file to BOTH targets' Target Membership:
// - Sonora (app)
// - SonoraLiveActivity (widget extension)

import Foundation
#if canImport(ActivityKit)
import ActivityKit

@available(iOS 16.1, *)
public struct SonoraLiveActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var memoTitle: String
        public var startTime: Date
        public var duration: TimeInterval
        public var isCountdown: Bool
        public var remainingTime: TimeInterval?
        public var emoji: String

        // MARK: - Audio Visualization Data
        // Backward compatible: keep original `level` field
        public var level: Double? // 0.0 ... 1.0 (backward compatible, average power)

        // Enhanced audio data for richer waveform visualization
        public var peakLevel: Double? // 0.0 ... 1.0 (transient detection)
        public var voiceActivity: Double? // 0.0 ... 1.0 (speech vs silence indicator)

        // Frequency band energy for voice-centric visualization
        public var frequencyLow: Double? // 0.0 ... 1.0 (80-500 Hz: fundamental voice)
        public var frequencyMid: Double? // 0.0 ... 1.0 (500-2000 Hz: vowels, main energy)
        public var frequencyHigh: Double? // 0.0 ... 1.0 (2000-8000 Hz: consonants)

        public init(
            memoTitle: String,
            startTime: Date,
            duration: TimeInterval,
            isCountdown: Bool,
            remainingTime: TimeInterval?,
            emoji: String,
            level: Double? = nil,
            peakLevel: Double? = nil,
            voiceActivity: Double? = nil,
            frequencyLow: Double? = nil,
            frequencyMid: Double? = nil,
            frequencyHigh: Double? = nil
        ) {
            self.memoTitle = memoTitle
            self.startTime = startTime
            self.duration = duration
            self.isCountdown = isCountdown
            self.remainingTime = remainingTime
            self.emoji = emoji
            self.level = level
            self.peakLevel = peakLevel
            self.voiceActivity = voiceActivity
            self.frequencyLow = frequencyLow
            self.frequencyMid = frequencyMid
            self.frequencyHigh = frequencyHigh
        }
    }

    public var memoId: String

    public init(memoId: String) {
        self.memoId = memoId
    }
}
#endif

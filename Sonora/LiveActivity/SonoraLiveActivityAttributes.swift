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
        public var level: Double? // 0.0 ... 1.0 (optional, for calm waveform)
        
        public init(
            memoTitle: String,
            startTime: Date,
            duration: TimeInterval,
            isCountdown: Bool,
            remainingTime: TimeInterval?,
            emoji: String,
            level: Double? = nil
        ) {
            self.memoTitle = memoTitle
            self.startTime = startTime
            self.duration = duration
            self.isCountdown = isCountdown
            self.remainingTime = remainingTime
            self.emoji = emoji
            self.level = level
        }
    }

    public var memoId: String
    
    public init(memoId: String) {
        self.memoId = memoId
    }
}
#endif

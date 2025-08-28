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
        
        public init(
            memoTitle: String,
            startTime: Date,
            duration: TimeInterval,
            isCountdown: Bool,
            remainingTime: TimeInterval?,
            emoji: String
        ) {
            self.memoTitle = memoTitle
            self.startTime = startTime
            self.duration = duration
            self.isCountdown = isCountdown
            self.remainingTime = remainingTime
            self.emoji = emoji
        }
    }

    public var memoId: String
    
    public init(memoId: String) {
        self.memoId = memoId
    }
}
#endif


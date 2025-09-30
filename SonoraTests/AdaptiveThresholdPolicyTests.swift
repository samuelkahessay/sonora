import XCTest
@testable import Sonora

final class AdaptiveThresholdPolicyTests: XCTestCase {
    func testShortSimpleContentRaisesThresholds() {
        let ctx = DetectionContext(memoId: UUID(), transcriptLength: 40, sentenceCount: 1, hasDatesOrTimes: false, hasCalendarPhrases: false, imperativeVerbDensity: 0.0, localeIdentifier: "en_US", avgSentenceLength: 40)
        let policy = DefaultAdaptiveThresholdPolicy()
        let t = policy.thresholds(for: ctx)
        XCTAssertGreaterThanOrEqual(t.event, 0.75)
        XCTAssertGreaterThanOrEqual(t.reminder, 0.75)
    }

    func testCalendarSignalsLowerReminderThreshold() {
        let ctx = DetectionContext(memoId: UUID(), transcriptLength: 300, sentenceCount: 5, hasDatesOrTimes: true, hasCalendarPhrases: true, imperativeVerbDensity: 0.03, localeIdentifier: "en_US", avgSentenceLength: 60)
        let policy = DefaultAdaptiveThresholdPolicy()
        let t = policy.thresholds(for: ctx)
        XCTAssertLessThan(t.reminder, 0.7)
    }
}

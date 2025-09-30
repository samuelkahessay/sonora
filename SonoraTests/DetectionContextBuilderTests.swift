@testable import Sonora
import XCTest

final class DetectionContextBuilderTests: XCTestCase {
    func testContextExtractionSimple() {
        let text = "Let's meet tomorrow at 3pm."
        let ctx = DetectionContextBuilder.build(memoId: UUID(), transcript: text)
        XCTAssertTrue(ctx.hasDatesOrTimes)
        XCTAssertTrue(ctx.hasCalendarPhrases)
        XCTAssertGreaterThan(ctx.sentenceCount, 0)
    }

    func testImperativeDensity() {
        let text = "Remind me to email Sam. Send the deck. Prepare notes."
        let ctx = DetectionContextBuilder.build(memoId: UUID(), transcript: text)
        XCTAssertGreaterThan(ctx.imperativeVerbDensity, 0.0)
    }

    func testDetectsRelativeDatePhrases() {
        let text = "Let's regroup next weekend and wrap it up in a few days."
        let ctx = DetectionContextBuilder.build(memoId: UUID(), transcript: text)
        XCTAssertTrue(ctx.hasRelativeDatePhrases)
        XCTAssertTrue(ctx.hasWeekendReferences)
    }
}

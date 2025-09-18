import XCTest
@testable import Sonora

@MainActor
final class DefaultFillerWordFilterTests: XCTestCase {
    func testRemovesSimpleFillers() {
        let filter = DefaultFillerWordFilter()
        let input = "Um, I think we should start."
        let output = filter.removeFillerWords(from: input)
        XCTAssertEqual(output, "I think we should start.")
    }

    func testKeepsNonFillers() {
        let filter = DefaultFillerWordFilter()
        let input = "The umbrella is under the table."
        let output = filter.removeFillerWords(from: input)
        XCTAssertEqual(output, input)
    }

    func testRemovesMultiWordPhrase() {
        let filter = DefaultFillerWordFilter()
        let input = "You know, this is actually a good idea."
        let output = filter.removeFillerWords(from: input)
        XCTAssertEqual(output, "this is actually a good idea.")
    }

    func testPreservesMeaningWhenOnlyFillers() {
        let filter = DefaultFillerWordFilter()
        let input = "Uh... um..."
        let output = filter.removeFillerWords(from: input)
        XCTAssertEqual(output, "Uh... um...")
    }

    func testCustomWordsAugmentDefaultList() {
        let filter = DefaultFillerWordFilter()
        filter.updateCustomWords(["essentially"])
        let input = "Essentially, we should leave."
        let output = filter.removeFillerWords(from: input)
        XCTAssertEqual(output, "we should leave.")
    }
}

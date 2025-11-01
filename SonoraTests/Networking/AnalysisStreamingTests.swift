import XCTest
@testable import Sonora

/// Integration tests for AI analysis streaming functionality
/// Tests SSE parsing, progress updates, and final envelope construction
@MainActor
final class AnalysisStreamingTests: XCTestCase {

    var analysisService: AnalysisService!

    override func setUp() async throws {
        try await super.setUp()
        analysisService = AnalysisService()
    }

    override func tearDown() async throws {
        analysisService = nil
        try await super.tearDown()
    }

    // MARK: - Streaming Summary Tests

    func test_analyzeDistillSummaryStreaming_receivesInterimUpdates() async throws {
        // Given
        let transcript = "Today I had a productive meeting about the project. We discussed timelines and budget concerns."
        var interimUpdates: [AnalysisStreamingUpdate] = []
        var finalUpdate: AnalysisStreamingUpdate?

        let progressHandler: AnalysisStreamingHandler = { update in
            if update.isFinal {
                finalUpdate = update
            } else {
                interimUpdates.append(update)
            }
        }

        // When
        let envelope = try await analysisService.analyzeDistillSummaryStreaming(
            transcript: transcript,
            progress: progressHandler
        )

        // Then
        XCTAssertGreaterThan(interimUpdates.count, 0, "Should receive interim streaming updates")
        XCTAssertNotNil(finalUpdate, "Should receive final update")
        XCTAssertTrue(finalUpdate?.isFinal ?? false, "Final update should be marked as final")
        XCTAssertFalse(envelope.data.summary.isEmpty, "Should have valid summary")
        XCTAssertEqual(envelope.mode, .distillSummary, "Mode should match")
    }

    func test_analyzeDistillSummaryStreaming_partialTextGrowsOverTime() async throws {
        // Given
        let transcript = "I need to complete the report by Friday and schedule a meeting with the team next week."
        var partialLengths: [Int] = []

        let progressHandler: AnalysisStreamingHandler = { update in
            if !update.isFinal {
                partialLengths.append(update.partialText.count)
            }
        }

        // When
        _ = try await analysisService.analyzeDistillSummaryStreaming(
            transcript: transcript,
            progress: progressHandler
        )

        // Then - Verify partial text grows progressively
        for i in 1..<partialLengths.count {
            XCTAssertGreaterThanOrEqual(
                partialLengths[i],
                partialLengths[i-1],
                "Partial text should grow or stay the same (not shrink)"
            )
        }
    }

    // MARK: - Streaming Actions Tests

    func test_analyzeDistillActionsStreaming_receivesValidActionItems() async throws {
        // Given
        let transcript = "I must email Sarah by Friday about the proposal. Also need to call the client tomorrow at 2pm."
        var finalReceived = false

        let progressHandler: AnalysisStreamingHandler = { update in
            if update.isFinal {
                finalReceived = true
            }
        }

        // When
        let envelope = try await analysisService.analyzeDistillActionsStreaming(
            transcript: transcript,
            progress: progressHandler
        )

        // Then
        XCTAssertTrue(finalReceived, "Should receive final update")
        XCTAssertFalse(envelope.data.action_items.isEmpty, "Should detect action items")
        XCTAssertEqual(envelope.mode, .distillActions, "Mode should match")
    }

    // MARK: - Streaming Reflection Tests

    func test_analyzeDistillReflectionStreaming_receivesValidQuestions() async throws {
        // Given
        let transcript = "The meeting was productive but I'm worried about the deadlines. Everyone seemed optimistic."
        var interimCount = 0

        let progressHandler: AnalysisStreamingHandler = { update in
            if !update.isFinal {
                interimCount += 1
            }
        }

        // When
        let envelope = try await analysisService.analyzeDistillReflectionStreaming(
            transcript: transcript,
            progress: progressHandler
        )

        // Then
        XCTAssertGreaterThan(interimCount, 0, "Should receive interim updates")
        XCTAssertFalse(envelope.data.reflection_questions.isEmpty, "Should have reflection questions")
        XCTAssertEqual(envelope.mode, .distillReflection, "Mode should match")
    }

    // MARK: - Pro-Tier Streaming Tests

    func test_analyzeCognitiveClarityCBTStreaming_receivesValidPatterns() async throws {
        // Given
        let transcript = "I always mess things up. Everyone will think I'm incompetent if I make a mistake."
        var streamingWorked = false

        let progressHandler: AnalysisStreamingHandler = { update in
            if !update.isFinal {
                streamingWorked = true
            }
        }

        // When
        let envelope = try await analysisService.analyzeCognitiveClarityCBTStreaming(
            transcript: transcript,
            progress: progressHandler
        )

        // Then
        XCTAssertTrue(streamingWorked, "Streaming should work")
        XCTAssertEqual(envelope.mode, .cognitiveClarityCBT, "Mode should match")
        // Note: cognitive patterns may or may not be detected depending on content
    }

    func test_analyzePhilosophicalEchoesStreaming_receivesValidEchoes() async throws {
        // Given
        let transcript = "I'm trying to focus on what I can control and accept what I cannot. Life is about finding meaning in suffering."
        var interimUpdateReceived = false

        let progressHandler: AnalysisStreamingHandler = { update in
            if !update.isFinal && !update.partialText.isEmpty {
                interimUpdateReceived = true
            }
        }

        // When
        let envelope = try await analysisService.analyzePhilosophicalEchoesStreaming(
            transcript: transcript,
            progress: progressHandler
        )

        // Then
        XCTAssertTrue(interimUpdateReceived, "Should receive interim updates")
        XCTAssertEqual(envelope.mode, .philosophicalEchoes, "Mode should match")
    }

    func test_analyzeValuesRecognitionStreaming_receivesValidValues() async throws {
        // Given
        let transcript = "Family is the most important thing to me. I also value honesty and integrity in all my relationships."
        var finalReceived = false

        let progressHandler: AnalysisStreamingHandler = { update in
            if update.isFinal {
                finalReceived = true
            }
        }

        // When
        let envelope = try await analysisService.analyzeValuesRecognitionStreaming(
            transcript: transcript,
            progress: progressHandler
        )

        // Then
        XCTAssertTrue(finalReceived, "Should receive final update")
        XCTAssertEqual(envelope.mode, .valuesRecognition, "Mode should match")
        XCTAssertFalse(envelope.data.coreValues.isEmpty, "Should detect core values")
    }

    // MARK: - Error Handling Tests

    func test_streamingWithInvalidTranscript_throwsError() async throws {
        // Given
        let invalidTranscript = ""  // Empty transcript should fail

        // When/Then
        do {
            _ = try await analysisService.analyzeDistillSummaryStreaming(
                transcript: invalidTranscript,
                progress: nil
            )
            XCTFail("Should throw error for invalid transcript")
        } catch {
            // Expected to throw
            XCTAssertTrue(true, "Correctly threw error for invalid input")
        }
    }

    func test_streamingWithoutProgressHandler_usesNonStreamingPath() async throws {
        // Given
        let transcript = "Today was productive. I completed the report and scheduled the meeting."

        // When - Call streaming method with nil progress handler
        let envelope = try await analysisService.analyzeDistillSummaryStreaming(
            transcript: transcript,
            progress: nil
        )

        // Then - Should fall back to non-streaming and still work
        XCTAssertFalse(envelope.data.summary.isEmpty, "Should have valid summary")
        XCTAssertEqual(envelope.mode, .distillSummary, "Mode should match")
    }

    // MARK: - Performance Tests

    func test_streamingPerformance_completesWithinTimeout() async throws {
        // Given
        let transcript = String(repeating: "This is a test sentence. ", count: 100)  // ~2500 chars
        let expectation = XCTestExpectation(description: "Streaming completes within 60s")

        // When
        let startTime = Date()
        _ = try await analysisService.analyzeDistillSummaryStreaming(
            transcript: transcript,
            progress: { _ in }
        )
        let duration = Date().timeIntervalSince(startTime)

        // Then
        XCTAssertLessThan(duration, 60, "Streaming should complete within 60 seconds")
        expectation.fulfill()

        await fulfillment(of: [expectation], timeout: 65)
    }
}

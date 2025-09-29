import XCTest
@testable import Sonora

final class TitleServiceTests: XCTestCase {
    override func tearDown() {
        URLProtocolStub.reset()
        super.tearDown()
    }

    func testGenerateTitleRetriesOnServerError() async throws {
        URLProtocolStub.enqueueJSON(
            statusCode: 500,
            json: ["error": "internal"],
            headers: ["Content-Type": "application/json"]
        )
        URLProtocolStub.enqueueJSON(
            statusCode: 200,
            json: ["title": "Weekly Recap Notes"],
            headers: ["Content-Type": "application/json"]
        )

        let service = makeService(maxAttempts: 3)

        let title = try await service.generateTitle(
            transcript: "example transcript for testing",
            languageHint: nil,
            progress: nil
        )

        XCTAssertEqual(title, "Weekly Recap Notes")
        XCTAssertEqual(URLProtocolStub.recordedRequests.count, 2, "Expected a retry after server error")
    }

    func testGenerateTitleStopsOnValidationError() async {
        URLProtocolStub.enqueueJSON(
            statusCode: 422,
            json: ["error": "validation"],
            headers: ["Content-Type": "application/json"]
        )

        let service = makeService(maxAttempts: 3)

        do {
            _ = try await service.generateTitle(
                transcript: "short transcript",
                languageHint: nil,
                progress: nil
            )
            XCTFail("Expected validation error")
        } catch let error as TitleServiceError {
            guard case .unexpectedStatus(let status, _) = error else {
                return XCTFail("Unexpected error: \(error)")
            }
            XCTAssertEqual(status, 422)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }

        XCTAssertEqual(URLProtocolStub.recordedRequests.count, 1, "Validation errors should not retry")
    }

    func testStreamingEmitsInterimUpdatesAndFinalTitle() async throws {
        let stream = [
            URLProtocolStub.StreamChunk(string: "data: {\"choices\":[{\"delta\":{\"content\":\"Weekly\"}}]}\n\n", delay: 0.0),
            URLProtocolStub.StreamChunk(string: "data: {\"choices\":[{\"delta\":{\"content\":\" Recap\"}}]}\n\n", delay: 0.05),
            URLProtocolStub.StreamChunk(string: "data: {\"choices\":[{\"delta\":{\"content\":\" Notes\"}}]}\n\n", delay: 0.05),
            URLProtocolStub.StreamChunk(string: "data: [DONE]\n\n", delay: 0.02)
        ]

        URLProtocolStub.enqueueStream(statusCode: 200, chunks: stream)

        let service = makeService(maxAttempts: 1)

        let finalExpectation = expectation(description: "final update")
        var updates: [TitleStreamingUpdate] = []

        let title = try await service.generateTitle(
            transcript: "example transcript for testing",
            languageHint: nil,
            progress: { update in
                updates.append(update)
                if update.isFinal {
                    finalExpectation.fulfill()
                }
            }
        )

        await fulfillment(of: [finalExpectation], timeout: 1.0)
        XCTAssertEqual(title, "Weekly Recap Notes")
        XCTAssertTrue(updates.contains(where: { !$0.isFinal }), "Expected at least one interim update")
        XCTAssertEqual(updates.last?.text, "Weekly Recap Notes")
    }

    func testStreamingFallbacksToLegacyWhenUnsupported() async throws {
        URLProtocolStub.enqueueStream(
            statusCode: 406,
            chunks: [],
            headers: ["Content-Type": "text/event-stream"]
        )
        URLProtocolStub.enqueueJSON(
            statusCode: 200,
            json: ["title": "Weekly Recap Notes"],
            headers: ["Content-Type": "application/json"]
        )

        let service = makeService(maxAttempts: 2)

        let title = try await service.generateTitle(
            transcript: "fallback transcript",
            languageHint: nil,
            progress: { _ in }
        )

        XCTAssertEqual(title, "Weekly Recap Notes")
        XCTAssertEqual(URLProtocolStub.recordedRequests.count, 2, "Expected fallback request after streaming unsupported")
    }

    // MARK: - Helpers

    private func makeService(maxAttempts: Int) -> TitleService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        configuration.protocolClasses = [URLProtocolStub.self]
        let session = URLSession(configuration: configuration)

        return TitleService(
            config: AppConfiguration.shared,
            session: session,
            maxAttempts: maxAttempts,
            baseBackoff: 0.01,
            maxJitter: 0
        )
    }
}

// MARK: - URLProtocol Stub

private final class URLProtocolStub: URLProtocol {
    struct StreamChunk {
        let data: Data
        let delay: TimeInterval

        init(data: Data, delay: TimeInterval) {
            self.data = data
            self.delay = delay
        }

        init(string: String, delay: TimeInterval) {
            self.init(data: Data(string.utf8), delay: delay)
        }
    }

    enum Payload {
        case data(Data)
        case stream([StreamChunk])
    }

    struct Response {
        let response: HTTPURLResponse
        let payload: Payload
        let error: Error?
    }

    private static var stubs: [Response] = []
    private static let queue = DispatchQueue(label: "URLProtocolStub.queue")

    static var recordedRequests: [URLRequest] = []

    static func enqueueJSON(statusCode: Int, json: [String: Any], headers: [String: String] = [:]) {
        let url = URL(string: "https://stubbed.local/title")!
        var allHeaders = headers
        allHeaders["Content-Type"] = allHeaders["Content-Type"] ?? "application/json"
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: allHeaders)!
        let data = try! JSONSerialization.data(withJSONObject: json, options: [])
        enqueue(Response(response: response, payload: .data(data), error: nil))
    }

    static func enqueueStream(statusCode: Int, chunks: [StreamChunk], headers: [String: String] = [:]) {
        let url = URL(string: "https://stubbed.local/title")!
        var allHeaders = headers
        allHeaders["Content-Type"] = allHeaders["Content-Type"] ?? "text/event-stream"
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: allHeaders)!
        enqueue(Response(response: response, payload: .stream(chunks), error: nil))
    }

    static func enqueue(_ response: Response) {
        queue.sync {
            stubs.append(response)
        }
    }

    static func reset() {
        queue.sync {
            stubs.removeAll()
            recordedRequests.removeAll()
        }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let stub: Response? = URLProtocolStub.queue.sync {
            guard !URLProtocolStub.stubs.isEmpty else { return nil }
            return URLProtocolStub.stubs.removeFirst()
        }

        URLProtocolStub.queue.sync {
            URLProtocolStub.recordedRequests.append(request)
        }

        guard let stub else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        if let error = stub.error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        client?.urlProtocol(self, didReceive: stub.response, cacheStoragePolicy: .notAllowed)

        switch stub.payload {
        case .data(let data):
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        case .stream(let chunks):
            guard !chunks.isEmpty else {
                client?.urlProtocolDidFinishLoading(self)
                return
            }

            let queue = DispatchQueue.global()
            var accumulatedDelay: TimeInterval = 0
            for (index, chunk) in chunks.enumerated() {
                accumulatedDelay += chunk.delay
                queue.asyncAfter(deadline: .now() + accumulatedDelay) { [weak self] in
                    guard let self else { return }
                    self.client?.urlProtocol(self, didLoad: chunk.data)
                    if index == chunks.count - 1 {
                        self.client?.urlProtocolDidFinishLoading(self)
                    }
                }
            }
        }
    }

    override func stopLoading() {}
}

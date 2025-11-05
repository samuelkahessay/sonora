import Foundation
import UIKit

final class AnalysisService: AnalysisServiceProtocol, @unchecked Sendable {
    private let config = AppConfiguration.shared
    private let logger: any LoggerProtocol = Logger.shared
    private let analysisTracker: AnalysisTracker
    private lazy var backgroundDelegate: AnalysisSessionDelegate = {
        AnalysisSessionDelegate(tracker: analysisTracker, logger: logger)
    }()
    private lazy var backgroundSession: URLSession = {
        let identifier: String
        if let bundleId = Bundle.main.bundleIdentifier {
            identifier = "\(bundleId).analysis.background"
        } else {
            identifier = "com.sonora.analysis.background"
        }
        let configuration = URLSessionConfiguration.background(withIdentifier: identifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.allowsCellularAccess = true
        configuration.shouldUseExtendedBackgroundIdleMode = true
        configuration.networkServiceType = .responsiveData
        return URLSession(configuration: configuration, delegate: backgroundDelegate, delegateQueue: nil)
    }()

    // Dedicated session for analysis with extended timeouts (better for large JSON responses than background session)
    private lazy var analysisSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 180.0  // 3 minutes for Pro mode with 4 parallel calls
        configuration.timeoutIntervalForResource = 240.0 // 4 minutes resource timeout
        configuration.allowsCellularAccess = true
        configuration.networkServiceType = .responsiveData
        configuration.waitsForConnectivity = true
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    init() {
        self.analysisTracker = AnalysisTracker(logger: Logger.shared)
    }

    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]? = nil,
        isPro: Bool = false
    ) async throws -> AnalyzeEnvelope<T> {
        let analyzeURL = config.apiBaseURL.appendingPathComponent("analyze")
        print("🔧 AnalysisService: Using API URL: \(analyzeURL.absoluteString)")

        // Sanitize transcript to reduce prompt injection surface area on server
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)

        var requestBody: [String: Any] = [
            "mode": mode.rawValue,
            "transcript": safeTranscript
        ]

        // Include isPro flag for pro modes aggregation on server
        requestBody["isPro"] = isPro
        if isPro {
            print("🔧 AnalysisService: Pro subscription active - server will include pro modes")
        } else {
            print("⚠️ AnalysisService: Free tier - Pro modes will NOT be included")
        }

        // Include historical context if provided (for pattern detection)
        if let historicalContext = historicalContext, !historicalContext.isEmpty {
            // Encode historical context to JSON-compatible array
            if let encoded = try? JSONEncoder().encode(historicalContext),
               let jsonArray = try? JSONSerialization.jsonObject(with: encoded) as? [[String: Any]] {
                requestBody["historicalContext"] = jsonArray
                print("🔧 AnalysisService: Including \(historicalContext.count) historical memos for pattern detection")
            }
        }

        var request = URLRequest(url: analyzeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeoutInterval(for: mode)

        print("🔧 AnalysisService: Using timeout: \(request.timeoutInterval)s for \(mode.displayName)")
        print("🔧 AnalysisService: Transcript length: \(transcript.count) characters (sanitized: \(safeTranscript.count))")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            // Log the actual JSON being sent for debugging
            if let jsonString = String(data: request.httpBody!, encoding: .utf8) {
                print("🔍 [DEBUG] Request JSON being sent:")
                print(jsonString)
            }
        } catch {
            throw AnalysisError.networkError("Failed to encode request: \(error.localizedDescription)")
        }

        // Use dedicated analysis session with proper timeout configuration
        // Note: Regular URLSession with extended timeouts is better for large JSON responses than background sessions
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await analysisSession.data(for: request)
        } catch {
            throw AnalysisError.networkError("Request failed: \(error.localizedDescription)")
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ AnalysisService: Server error \(httpResponse.statusCode)")
            if let body = String(data: data, encoding: .utf8) {
                print("❌ AnalysisService: Response body: \(body)")
            }
            throw AnalysisError.serverError(httpResponse.statusCode)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(AnalyzeEnvelope<T>.self, from: data)
            print("✅ AnalysisService: Analysis completed")
            print("✅ AnalysisService: Model: \(envelope.model)")
            print("✅ AnalysisService: Tokens: \(envelope.tokens.input) in, \(envelope.tokens.output) out")
            print("✅ AnalysisService: Latency: \(envelope.latency_ms)ms")
            return envelope
        } catch {
            print("❌ AnalysisService: JSON decode error: \(error)")

            // Enhanced error debugging
            print("❌ AnalysisService: Data size received: \(data.count) bytes")

            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("❌ AnalysisService: Type mismatch - expected \(type), path: \(context.codingPath)")
                    print("❌ AnalysisService: Context: \(context.debugDescription)")
                case .valueNotFound(let type, let context):
                    print("❌ AnalysisService: Value not found - \(type), path: \(context.codingPath)")
                    print("❌ AnalysisService: Context: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("❌ AnalysisService: Key not found - \(key.stringValue), path: \(context.codingPath)")
                    print("❌ AnalysisService: Context: \(context.debugDescription)")
                case .dataCorrupted(let context):
                    print("❌ AnalysisService: Data corrupted at path: \(context.codingPath)")
                    print("❌ AnalysisService: Context: \(context.debugDescription)")
                @unknown default:
                    print("❌ AnalysisService: Unknown decoding error")
                }
            }

            if let body = String(data: data, encoding: .utf8) {
                print("❌ AnalysisService: Raw response (first 500 chars): \(String(body.prefix(500)))")
                if body.count > 500 {
                    print("❌ AnalysisService: Response truncated - total length: \(body.count)")
                }
            } else {
                print("❌ AnalysisService: Unable to decode response data as UTF-8 string")
            }

            throw AnalysisError.decodingError(error.localizedDescription)
        }
    }

    // MARK: - SSE Streaming Support

    /// Analyze with Server-Sent Events (SSE) streaming for progressive updates
    func analyzeWithStreaming<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]? = nil,
        isPro: Bool = false,
        onProgress: @escaping @Sendable (AnalysisStreamingUpdate) -> Void
    ) async throws -> AnalyzeEnvelope<T> {
        let analyzeURL = config.apiBaseURL.appendingPathComponent("analyze")
        print("📡 AnalysisService (SSE): Using API URL: \(analyzeURL.absoluteString)")

        // Sanitize transcript
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)

        var requestBody: [String: Any] = [
            "mode": mode.rawValue,
            "transcript": safeTranscript,
            "isPro": isPro,
            "stream": true  // Request SSE streaming
        ]

        // Include historical context if provided
        if let historicalContext = historicalContext, !historicalContext.isEmpty {
            if let encoded = try? JSONEncoder().encode(historicalContext),
               let jsonArray = try? JSONSerialization.jsonObject(with: encoded) as? [[String: Any]] {
                requestBody["historicalContext"] = jsonArray
                print("📡 AnalysisService (SSE): Including \(historicalContext.count) historical memos")
            }
        }

        var request = URLRequest(url: analyzeURL)
        request.httpMethod = "POST"
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")  // Request SSE
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeoutInterval(for: mode)

        print("📡 AnalysisService (SSE): Timeout: \(request.timeoutInterval)s, isPro: \(isPro)")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AnalysisError.networkError("Failed to encode request: \(error.localizedDescription)")
        }

        // Use URLSession.shared for streaming (not background session)
        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            print("❌ AnalysisService (SSE): Stream connection failed, attempting fallback to non-streaming")
            // Graceful fallback: retry without streaming
            return try await analyze(
                mode: mode,
                transcript: transcript,
                responseType: responseType,
                historicalContext: historicalContext,
                isPro: isPro
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ AnalysisService (SSE): Server error \(httpResponse.statusCode)")
            throw AnalysisError.serverError(httpResponse.statusCode)
        }

        // Check if response is actually SSE
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""
        if !contentType.contains("text/event-stream") {
            print("⚠️ AnalysisService (SSE): Server didn't return SSE stream, falling back to non-streaming")
            // Server didn't support streaming - fall back
            return try await analyze(
                mode: mode,
                transcript: transcript,
                responseType: responseType,
                historicalContext: historicalContext,
                isPro: isPro
            )
        }

        print("📡 AnalysisService (SSE): Streaming started, parsing events...")

        // Parse SSE events
        var buffer = ""
        var finalEnvelope: AnalyzeEnvelope<T>?
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            for try await byte in bytes {
                buffer.append(String(decoding: [byte], as: UTF8.self))

                // Process complete events (terminated by \n\n)
                while let range = buffer.range(of: "\n\n") {
                    let rawEvent = String(buffer[..<range.lowerBound])
                    buffer.removeSubrange(..<range.upperBound)

                    // Parse event
                    var eventType: String?
                    var eventData: String?

                    for line in rawEvent.split(separator: "\n") {
                        if line.hasPrefix("event:") {
                            eventType = String(line.dropFirst("event:".count)).trimmingCharacters(in: .whitespaces)
                        } else if line.hasPrefix("data:") {
                            eventData = String(line.dropFirst("data:".count)).trimmingCharacters(in: .whitespaces)
                        }
                    }

                    guard let type = eventType, let data = eventData else {
                        continue
                    }

                    print("📡 AnalysisService (SSE): Received event: \(type)")

                    switch type {
                    case "interim":
                        // Parse interim progress update
                        if let jsonData = data.data(using: .utf8),
                           let interimData = try? decoder.decode(InterimEventData.self, from: jsonData) {

                            // Convert server's partialData to PartialDistillData
                            let partialData = interimData.partialData.map { serverData -> PartialDistillData in
                                PartialDistillData(
                                    summary: serverData.summary,
                                    actionItems: serverData.actionItems,
                                    reflectionQuestions: serverData.reflectionQuestions,
                                    thinkingPatterns: serverData.thinkingPatterns,
                                    philosophicalEchoes: serverData.philosophicalEchoes,
                                    valuesInsights: serverData.valuesInsights
                                )
                            }

                            let update = AnalysisStreamingUpdate(
                                component: interimData.component,
                                completedCount: interimData.completedCount,
                                totalCount: interimData.totalCount,
                                partialData: partialData,
                                isFinal: false
                            )
                            onProgress(update)
                            print("📡 AnalysisService (SSE): Progress: \(interimData.completedCount)/\(interimData.totalCount) - \(interimData.component ?? "unknown")")
                        }

                    case "final":
                        // Parse final complete response
                        if let jsonData = data.data(using: .utf8) {
                            finalEnvelope = try decoder.decode(AnalyzeEnvelope<T>.self, from: jsonData)
                            print("📡 AnalysisService (SSE): Final event received")

                            // Send final progress update
                            onProgress(AnalysisStreamingUpdate(isFinal: true))
                        }

                    case "error":
                        print("❌ AnalysisService (SSE): Server sent error event: \(data)")
                        throw AnalysisError.serverError(500)

                    default:
                        print("⚠️ AnalysisService (SSE): Unknown event type: \(type)")
                    }
                }
            }
        } catch {
            print("❌ AnalysisService (SSE): Stream parsing error: \(error)")
            throw AnalysisError.networkError("Stream parsing failed: \(error.localizedDescription)")
        }

        guard let envelope = finalEnvelope else {
            print("❌ AnalysisService (SSE): Stream ended without final event")
            throw AnalysisError.networkError("Stream ended without final event")
        }

        print("✅ AnalysisService (SSE): Streaming completed")
        print("✅ AnalysisService (SSE): Model: \(envelope.model), Tokens: \(envelope.tokens.input) in, \(envelope.tokens.output) out")
        return envelope
    }

    // MARK: - Convenience Methods

    /// Analyze distill with historical context and pro flag
    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?,
        isPro: Bool
    ) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyze(
            mode: .distill,
            transcript: transcript,
            responseType: DistillData.self,
            historicalContext: historicalContext,
            isPro: isPro
        )
    }

    /// Analyze distill without historical context
    func analyzeDistill(transcript: String, isPro: Bool) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeDistill(transcript: transcript, historicalContext: nil, isPro: isPro)
    }

    /// Free tier lite distill analysis
    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        try await analyze(mode: .liteDistill, transcript: transcript, responseType: LiteDistillData.self, historicalContext: nil, isPro: false)
    }

    // MARK: - SSE Streaming Convenience Methods

    /// Analyze distill with SSE streaming for progressive updates
    func analyzeDistillStreaming(
        transcript: String,
        historicalContext: [HistoricalMemoContext]? = nil,
        isPro: Bool,
        onProgress: @escaping @Sendable (AnalysisStreamingUpdate) -> Void
    ) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeWithStreaming(
            mode: .distill,
            transcript: transcript,
            responseType: DistillData.self,
            historicalContext: historicalContext,
            isPro: isPro,
            onProgress: onProgress
        )
    }
}

// MARK: - Background Session Support

/// Actor that tracks analysis data tasks and their continuations
///
/// This enables background URLSession tasks to communicate their results back to the async/await world.
/// Similar to UploadTracker but for data tasks instead of upload tasks.
private actor AnalysisTracker {
    enum AnalysisTrackerError: Error {
        case missingResponse
    }

    private var continuations: [Int: CheckedContinuation<(Data, URLResponse), Error>] = [:]
    private var buffers: [Int: Data] = [:]
    private let logger: any LoggerProtocol

    init(logger: any LoggerProtocol) {
        self.logger = logger
    }

    func register(task: URLSessionTask, continuation: CheckedContinuation<(Data, URLResponse), Error>) {
        continuations[task.taskIdentifier] = continuation
        buffers[task.taskIdentifier] = Data()
    }

    func appendData(taskIdentifier: Int, data: Data) {
        if buffers[taskIdentifier] != nil {
            buffers[taskIdentifier]?.append(data)
        } else {
            buffers[taskIdentifier] = data
        }
    }

    func complete(task: URLSessionTask, error: Error?) {
        let identifier = task.taskIdentifier
        let continuation = continuations.removeValue(forKey: identifier)
        let collectedData = buffers.removeValue(forKey: identifier) ?? Data()

        guard let continuation else {
            logger.debug("AnalysisTracker: No continuation for task \(identifier)", category: .network, context: nil)
            return
        }

        if let error {
            continuation.resume(throwing: error)
            return
        }

        guard let response = task.response else {
            continuation.resume(throwing: AnalysisTrackerError.missingResponse)
            return
        }

        continuation.resume(returning: (collectedData, response))
    }
}

extension AnalysisTracker.AnalysisTrackerError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .missingResponse:
            return "Analysis request finished without a server response"
        }
    }
}

/// URLSession delegate for handling background analysis requests
///
/// This delegate is critical for background analysis to work when the phone is locked.
/// It receives data chunks, handles task completion, and notifies AppDelegate when done.
private final class AnalysisSessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let tracker: AnalysisTracker
    private let logger: any LoggerProtocol

    init(tracker: AnalysisTracker, logger: any LoggerProtocol) {
        self.tracker = tracker
        self.logger = logger
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        Task {
            await tracker.appendData(taskIdentifier: dataTask.taskIdentifier, data: data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task {
            await tracker.complete(task: task, error: error)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.debug("AnalysisSessionDelegate: finished events for background session", category: .network, context: nil)

        // Notify iOS that we're done processing background URLSession events
        // This is critical for background analysis to work when the phone is locked
        DispatchQueue.main.async { [logger] in
            guard let appDelegate = UIApplication.shared.delegate as? AppDelegate else {
                logger.warning("AnalysisSessionDelegate: Could not get AppDelegate to call completion handler", category: .network, context: nil, error: nil)
                return
            }

            // Look up completion handler for this specific session
            guard let identifier = session.configuration.identifier else {
                logger.warning("AnalysisSessionDelegate: Session has no identifier", category: .network, context: nil, error: nil)
                return
            }

            if let completionHandler = appDelegate.backgroundSessionCompletionHandlers[identifier] {
                logger.info("AnalysisSessionDelegate: Calling completion handler for session: \(identifier)", category: .network, context: nil)
                completionHandler()
                appDelegate.backgroundSessionCompletionHandlers.removeValue(forKey: identifier)
            } else {
                logger.debug("AnalysisSessionDelegate: No completion handler for session \(identifier) (app may have been in foreground)", category: .network, context: nil)
            }
        }
    }

    func urlSession(_ session: URLSession, didBecomeInvalidWithError error: Error?) {
        if let error {
            logger.error("AnalysisSessionDelegate: session invalidated", category: .network, context: nil, error: error)
        } else {
            logger.debug("AnalysisSessionDelegate: session invalidated without error", category: .network, context: nil)
        }
    }
}

// MARK: - SSE Event Data Models

/// Server interim event data structure (matches server's SSE interim event format)
private struct InterimEventData: Codable {
    let component: String?
    let completedCount: Int
    let totalCount: Int
    let partialData: ServerPartialData?
}

/// Server's partial data structure (matches server's interim event partialData field)
private struct ServerPartialData: Codable {
    let summary: String?
    let actionItems: [DistillData.ActionItem]?
    let reflectionQuestions: [String]?
    let thinkingPatterns: [ThinkingPattern]?
    let philosophicalEchoes: [PhilosophicalEcho]?
    let valuesInsights: ValuesInsight?
}

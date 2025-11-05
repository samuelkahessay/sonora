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

        // Use background URLSession for reliability when phone is locked
        let dataTask = backgroundSession.dataTask(with: request)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                Task {
                    await analysisTracker.register(task: dataTask, continuation: continuation)
                    dataTask.resume()
                }
            }
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
            if let body = String(data: data, encoding: .utf8) {
                print("❌ AnalysisService: Raw response: \(body)")
            }
            throw AnalysisError.decodingError(error.localizedDescription)
        }
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

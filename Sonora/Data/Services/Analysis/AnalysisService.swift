import Foundation
import UIKit

final class AnalysisService: AnalysisServiceProtocol, Sendable {
    private let config = AppConfiguration.shared
    private let logger: any LoggerProtocol = Logger.shared
    private let analysisTracker: AnalysisTracker
    private let backgroundDelegate: AnalysisSessionDelegate
    private let backgroundSession: URLSession

    init() {
        let logger = Logger.shared
        self.analysisTracker = AnalysisTracker(logger: logger)
        self.backgroundDelegate = AnalysisSessionDelegate(tracker: analysisTracker, logger: logger)

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
        self.backgroundSession = URLSession(configuration: configuration, delegate: backgroundDelegate, delegateQueue: nil)
    }

    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type,
        historicalContext: [HistoricalMemoContext]? = nil
    ) async throws -> AnalyzeEnvelope<T> {
        let analyzeURL = config.apiBaseURL.appendingPathComponent("analyze")

        // Sanitize transcript to reduce prompt injection surface area on server
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)

        var requestBody: [String: Any] = [
            "mode": mode.rawValue,
            "transcript": safeTranscript
        ]

        // Include historical context if provided (for pattern detection)
        if let historicalContext = historicalContext, !historicalContext.isEmpty {
            // Encode historical context to JSON-compatible array
            if let encoded = try? JSONEncoder().encode(historicalContext),
               let jsonArray = try? JSONSerialization.jsonObject(with: encoded) as? [[String: Any]] {
                requestBody["historicalContext"] = jsonArray
                logger.debug("📝 Including \(historicalContext.count) historical memos for pattern detection", category: .analysis, context: nil)
            }
        }

        var request = URLRequest(url: analyzeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeoutInterval(for: mode)

        // Add Pro entitlement header for Pro-tier features
        // Parallel distill components (.distillSummary, .distillActions, .distillReflection, etc.)
        // and detection modes (.events, .reminders) require Pro subscription
        let isProMode = mode == .events || mode == .reminders ||
                        mode == .distill || mode == .distillSummary || mode == .distillActions ||
                        mode == .distillThemes || mode == .distillPersonalInsight ||
                        mode == .distillClosingNote || mode == .distillReflection
        if isProMode {
            request.setValue("1", forHTTPHeaderField: "X-Entitlement-Pro")
        }

        // Comprehensive request logging
        logger.debug("━━━━━━━━━━ ANALYSIS REQUEST START ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("🌐 Method: \(request.httpMethod ?? "UNKNOWN")", category: .network, context: nil)
        logger.debug("🌐 URL: \(analyzeURL.absoluteString)", category: .network, context: nil)
        logger.debug("🌐 Mode: \(mode.rawValue) (\(mode.displayName))", category: .network, context: nil)
        logger.debug("🌐 Timeout: \(request.timeoutInterval)s", category: .network, context: nil)
        logger.debug("🌐 Transcript Length: \(transcript.count) chars (sanitized: \(safeTranscript.count))", category: .network, context: nil)
        logger.debug("🌐 Pro Mode: \(isProMode ? "YES" : "NO")", category: .network, context: nil)
        logger.debug("━━━━━━━━━━ REQUEST HEADERS ━━━━━━━━━━", category: .network, context: nil)
        if let headers = request.allHTTPHeaderFields {
            for (key, value) in headers {
                logger.debug("  \(key): \(value)", category: .network, context: nil)
            }
        }
        logger.debug("━━━━━━━━━━ REQUEST BODY ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("📝 Mode: \(mode.rawValue)", category: .network, context: nil)
        logger.debug("📝 Transcript preview: \(String(safeTranscript.prefix(100)))...", category: .network, context: nil)
        if let historicalContext = historicalContext, !historicalContext.isEmpty {
            logger.debug("📝 Historical context items: \(historicalContext.count)", category: .network, context: nil)
        }

        // Write request body to temporary file (required for background URLSession)
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: requestBody)
            logger.debug("📝 Request body size: \(bodyData.count) bytes", category: .network, context: nil)
        } catch {
            logger.error("❌ Failed to encode request body", category: .network, context: nil, error: error)
            throw AnalysisError.networkError("Failed to encode request: \(error.localizedDescription)")
        }

        let tempDir = FileManager.default.temporaryDirectory
        let bodyFileURL = tempDir.appendingPathComponent(UUID().uuidString)
        do {
            try bodyData.write(to: bodyFileURL)
            logger.debug("📁 Wrote request body to temporary file: \(bodyFileURL.lastPathComponent)", category: .network, context: nil)
        } catch {
            logger.error("❌ Failed to write request body to file", category: .network, context: nil, error: error)
            throw AnalysisError.networkError("Failed to write request body to file: \(error.localizedDescription)")
        }
        defer {
            try? FileManager.default.removeItem(at: bodyFileURL)
        }

        // Use background URLSession with uploadTask
        let uploadTask = backgroundSession.uploadTask(with: request, fromFile: bodyFileURL)
        logger.debug("🚀 Starting analysis upload task (ID: \(uploadTask.taskIdentifier))...", category: .network, context: nil)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                Task {
                    await analysisTracker.register(task: uploadTask, continuation: continuation)
                    uploadTask.resume()
                }
            }
        } catch {
            logger.error("❌ Analysis upload task failed", category: .network, context: nil, error: error)
            logger.debug("❌ Error details: \(error.localizedDescription)", category: .network, context: nil)
            if let urlError = error as? URLError {
                logger.debug("❌ URLError code: \(urlError.code.rawValue)", category: .network, context: nil)
                logger.debug("❌ URLError domain: \(urlError.errorCode)", category: .network, context: nil)
            }
            throw AnalysisError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("❌ Invalid response type: \(type(of: response))", category: .network, context: nil, error: AnalysisError.networkError("Invalid response"))
            throw AnalysisError.networkError("Invalid response")
        }

        // Comprehensive response logging
        logger.debug("━━━━━━━━━━ ANALYSIS RESPONSE START ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("📥 Status Code: \(httpResponse.statusCode)", category: .network, context: nil)
        logger.debug("📥 Status Description: \(HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode))", category: .network, context: nil)
        logger.debug("📥 Response URL: \(httpResponse.url?.absoluteString ?? "unknown")", category: .network, context: nil)
        logger.debug("━━━━━━━━━━ RESPONSE HEADERS ━━━━━━━━━━", category: .network, context: nil)
        for (key, value) in httpResponse.allHeaderFields {
            logger.debug("  \(key): \(value)", category: .network, context: nil)
        }
        logger.debug("━━━━━━━━━━ RESPONSE BODY ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("📥 Body Size: \(data.count) bytes", category: .network, context: nil)

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("━━━━━━━━━━ ANALYSIS SERVER ERROR ━━━━━━━━━━", category: .network, context: nil, error: AnalysisError.serverError(httpResponse.statusCode))
            logger.error("❌ Status Code: \(httpResponse.statusCode)", category: .network, context: nil, error: nil)
            logger.error("❌ Mode: \(mode.rawValue) (\(mode.displayName))", category: .network, context: nil, error: nil)
            logger.error("❌ Response Body: \(body)", category: .network, context: nil, error: nil)
            logger.error("❌ Full URL: \(analyzeURL.absoluteString)", category: .network, context: nil, error: nil)
            logger.error("❌ Transcript Length: \(transcript.count) chars", category: .network, context: nil, error: nil)

            // Handle 402 Payment Required specifically
            if httpResponse.statusCode == 402 {
                logger.error("❌ Payment Required (402) - Pro subscription needed", category: .network, context: nil, error: nil)
                logger.error("━━━━━━━━━━ ANALYSIS SERVER ERROR END ━━━━━━━━━━", category: .network, context: nil, error: nil)
                throw AnalysisError.paymentRequired
            }

            logger.error("━━━━━━━━━━ ANALYSIS SERVER ERROR END ━━━━━━━━━━", category: .network, context: nil, error: nil)
            throw AnalysisError.serverError(httpResponse.statusCode)
        }

        logger.debug("✅ Analysis request succeeded", category: .network, context: nil)

        // Log raw response body for debugging
        if let bodyString = String(data: data, encoding: .utf8) {
            let preview = String(bodyString.prefix(500))
            logger.debug("📥 Response Body Preview: \(preview)", category: .network, context: nil)
        }

        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let envelope = try decoder.decode(AnalyzeEnvelope<T>.self, from: data)
            logger.info("✅ Analysis completed successfully", category: .analysis, context: LogContext(additionalInfo: [
                "mode": mode.rawValue,
                "model": envelope.model,
                "inputTokens": String(envelope.tokens.input),
                "outputTokens": String(envelope.tokens.output),
                "latency": String(envelope.latency_ms) + "ms"
            ]))
            logger.debug("━━━━━━━━━━ ANALYSIS RESPONSE END ━━━━━━━━━━", category: .network, context: nil)
            return envelope
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("❌ JSON decode error for mode \(mode.rawValue)", category: .analysis, context: nil, error: error)
            logger.debug("❌ Decode error details: \(error.localizedDescription)", category: .analysis, context: nil)
            logger.debug("❌ Raw response body: \(body)", category: .analysis, context: nil)
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    logger.debug("❌ Missing key: \(key.stringValue) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .analysis, context: nil)
                case .typeMismatch(let type, let context):
                    logger.debug("❌ Type mismatch: expected \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .analysis, context: nil)
                case .valueNotFound(let type, let context):
                    logger.debug("❌ Value not found: \(type) at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .analysis, context: nil)
                case .dataCorrupted(let context):
                    logger.debug("❌ Data corrupted at path: \(context.codingPath.map { $0.stringValue }.joined(separator: "."))", category: .analysis, context: nil)
                @unknown default:
                    logger.debug("❌ Unknown decoding error", category: .analysis, context: nil)
                }
            }
            logger.debug("━━━━━━━━━━ ANALYSIS RESPONSE END ━━━━━━━━━━", category: .network, context: nil)
            throw AnalysisError.decodingError(error.localizedDescription)
        }
    }

    // Convenience methods for each analysis type
    func analyzeDistill(
        transcript: String,
        historicalContext: [HistoricalMemoContext]?
    ) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyze(
            mode: .distill,
            transcript: transcript,
            responseType: DistillData.self,
            historicalContext: historicalContext
        )
    }

    // Backward-compatible method without historical context
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyzeDistill(transcript: transcript, historicalContext: nil)
    }

    // MARK: - Distill Component Methods for Parallel Processing

    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        try await analyze(mode: .distillSummary, transcript: transcript, responseType: DistillSummaryData.self, historicalContext: nil)
    }

    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self, historicalContext: nil)
    }

    func analyzeDistillPersonalInsight(transcript: String) async throws -> AnalyzeEnvelope<DistillPersonalInsightData> {
        try await analyze(mode: .distillPersonalInsight, transcript: transcript, responseType: DistillPersonalInsightData.self, historicalContext: nil)
    }

    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self, historicalContext: nil)
    }

    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self, historicalContext: nil)
    }

    func analyzeDistillClosingNote(transcript: String) async throws -> AnalyzeEnvelope<DistillClosingNoteData> {
        try await analyze(mode: .distillClosingNote, transcript: transcript, responseType: DistillClosingNoteData.self, historicalContext: nil)
    }

    // MARK: - Free Tier Analysis

    func analyzeLiteDistill(transcript: String) async throws -> AnalyzeEnvelope<LiteDistillData> {
        try await analyze(mode: .liteDistill, transcript: transcript, responseType: LiteDistillData.self, historicalContext: nil)
    }
}

// MARK: - Background URLSession Support

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

private final class AnalysisSessionDelegate: NSObject, URLSessionDataDelegate, URLSessionTaskDelegate, @unchecked Sendable {
    private let tracker: AnalysisTracker
    private let logger: any LoggerProtocol

    init(tracker: AnalysisTracker, logger: any LoggerProtocol) {
        self.tracker = tracker
        self.logger = logger
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        logger.debug("📦 AnalysisSessionDelegate: Received \(data.count) bytes for task \(dataTask.taskIdentifier)", category: .network, context: nil)
        Task {
            await tracker.appendData(taskIdentifier: dataTask.taskIdentifier, data: data)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error {
            logger.error("❌ AnalysisSessionDelegate: Task \(task.taskIdentifier) completed with error", category: .network, context: nil, error: error)
            logger.debug("❌ Error details: \(error.localizedDescription)", category: .network, context: nil)
            if let urlError = error as? URLError {
                logger.debug("❌ URLError code: \(urlError.code.rawValue)", category: .network, context: nil)
            }
        } else {
            logger.debug("✅ AnalysisSessionDelegate: Task \(task.taskIdentifier) completed successfully", category: .network, context: nil)
            if let httpResponse = task.response as? HTTPURLResponse {
                logger.debug("✅ Final status code: \(httpResponse.statusCode)", category: .network, context: nil)
            }
        }
        Task {
            await tracker.complete(task: task, error: error)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        logger.debug("AnalysisSessionDelegate: finished events for background session", category: .network, context: nil)

        // Notify AppDelegate that this session has completed
        if let identifier = session.configuration.identifier {
            Task { @MainActor in
                if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                    appDelegate.notifyBackgroundSessionCompleted(identifier: identifier)
                }
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

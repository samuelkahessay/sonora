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
        print("🔧 AnalysisService: Using API URL: \(analyzeURL.absoluteString)")

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
                print("🔧 AnalysisService: Including \(historicalContext.count) historical memos for pattern detection")
            }
        }

        var request = URLRequest(url: analyzeURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = config.timeoutInterval(for: mode)

        // Add Pro entitlement header for Pro-tier features
        // Parallel distill components (.distillSummary, .distillActions, .distillReflection)
        // and detection modes (.events, .reminders) require Pro subscription
        if mode == .events || mode == .reminders ||
           mode == .distill || mode == .distillSummary || mode == .distillActions ||
           mode == .distillThemes || mode == .distillReflection {
            request.setValue("1", forHTTPHeaderField: "X-Entitlement-Pro")
        }

        print("🔧 AnalysisService: Using timeout: \(request.timeoutInterval)s for \(mode.displayName)")
        print("🔧 AnalysisService: Transcript length: \(transcript.count) characters (sanitized: \(safeTranscript.count))")

        // Write request body to temporary file (required for background URLSession)
        let bodyData: Data
        do {
            bodyData = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            throw AnalysisError.networkError("Failed to encode request: \(error.localizedDescription)")
        }

        let tempDir = FileManager.default.temporaryDirectory
        let bodyFileURL = tempDir.appendingPathComponent(UUID().uuidString)
        do {
            try bodyData.write(to: bodyFileURL)
        } catch {
            throw AnalysisError.networkError("Failed to write request body to file: \(error.localizedDescription)")
        }
        defer {
            try? FileManager.default.removeItem(at: bodyFileURL)
        }

        // Use background URLSession with uploadTask
        let uploadTask = backgroundSession.uploadTask(with: request, fromFile: bodyFileURL)
        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await withCheckedThrowingContinuation { continuation in
                Task {
                    await analysisTracker.register(task: uploadTask, continuation: continuation)
                    uploadTask.resume()
                }
            }
        } catch {
            throw AnalysisError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AnalysisError.networkError("Invalid response")
        }

        guard httpResponse.statusCode == 200 else {
            print("❌ AnalysisService: Server error \(httpResponse.statusCode)")
            if let body = String(data: data, encoding: .utf8) {
                print("❌ AnalysisService: Response body: \(body)")
            }
            // Handle 402 Payment Required specifically
            if httpResponse.statusCode == 402 {
                throw AnalysisError.paymentRequired
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

    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self, historicalContext: nil)
    }

    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self, historicalContext: nil)
    }

    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self, historicalContext: nil)
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

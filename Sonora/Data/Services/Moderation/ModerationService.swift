import Foundation

@MainActor
final class ModerationService: ObservableObject, ModerationServiceProtocol {
    private let config = AppConfiguration.shared
    private let logger: any LoggerProtocol = Logger.shared

    func moderate(text: String) async throws -> ModerationResult {
        let url = config.apiBaseURL.appendingPathComponent("moderate")

        // Comprehensive request logging
        logger.debug("━━━━━━━━━━ MODERATION REQUEST START ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("🌐 Method: POST", category: .network, context: nil)
        logger.debug("🌐 URL: \(url.absoluteString)", category: .network, context: nil)
        logger.debug("🌐 Timeout: 10s", category: .network, context: nil)
        logger.debug("🌐 Text Length: \(text.count) characters", category: .network, context: nil)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let body: [String: Any] = ["text": text]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            logger.debug("━━━━━━━━━━ REQUEST HEADERS ━━━━━━━━━━", category: .network, context: nil)
            if let headers = request.allHTTPHeaderFields {
                for (key, value) in headers {
                    logger.debug("  \(key): \(value)", category: .network, context: nil)
                }
            }
            logger.debug("━━━━━━━━━━ REQUEST BODY ━━━━━━━━━━", category: .network, context: nil)
            if let bodySize = request.httpBody?.count {
                logger.debug("📝 Body size: \(bodySize) bytes", category: .network, context: nil)
            }
            logger.debug("📝 Text preview: \(String(text.prefix(100)))...", category: .network, context: nil)
        } catch {
            logger.error("❌ Failed to encode moderation request body", category: .network, context: nil, error: error)
            throw error
        }

        logger.debug("🚀 Sending moderation request...", category: .network, context: nil)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            logger.error("❌ Moderation request failed", category: .network, context: nil, error: error)
            logger.debug("❌ Error details: \(error.localizedDescription)", category: .network, context: nil)
            if let urlError = error as? URLError {
                logger.debug("❌ URLError code: \(urlError.code.rawValue)", category: .network, context: nil)
            }
            throw error
        }

        guard let http = response as? HTTPURLResponse else {
            logger.error("❌ Invalid response type: \(type(of: response))", category: .network, context: nil, error: AnalysisError.serverError(-1))
            throw AnalysisError.serverError(-1)
        }

        // Comprehensive response logging
        logger.debug("━━━━━━━━━━ MODERATION RESPONSE START ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("📥 Status Code: \(http.statusCode)", category: .network, context: nil)
        logger.debug("📥 Status Description: \(HTTPURLResponse.localizedString(forStatusCode: http.statusCode))", category: .network, context: nil)
        logger.debug("━━━━━━━━━━ RESPONSE HEADERS ━━━━━━━━━━", category: .network, context: nil)
        for (key, value) in http.allHeaderFields {
            logger.debug("  \(key): \(value)", category: .network, context: nil)
        }
        logger.debug("━━━━━━━━━━ RESPONSE BODY ━━━━━━━━━━", category: .network, context: nil)
        logger.debug("📥 Body Size: \(data.count) bytes", category: .network, context: nil)

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("━━━━━━━━━━ MODERATION SERVER ERROR ━━━━━━━━━━", category: .network, context: nil, error: AnalysisError.serverError(http.statusCode))
            logger.error("❌ Status Code: \(http.statusCode)", category: .network, context: nil, error: nil)
            logger.error("❌ Response Body: \(body)", category: .network, context: nil, error: nil)
            logger.error("❌ Full URL: \(url.absoluteString)", category: .network, context: nil, error: nil)
            logger.error("❌ Text Length: \(text.count) chars", category: .network, context: nil, error: nil)
            logger.error("━━━━━━━━━━ MODERATION SERVER ERROR END ━━━━━━━━━━", category: .network, context: nil, error: nil)
            throw AnalysisError.serverError(http.statusCode)
        }

        logger.debug("✅ Moderation request succeeded", category: .network, context: nil)

        // Log raw response body for debugging
        if let bodyString = String(data: data, encoding: .utf8) {
            logger.debug("📥 Response Body: \(bodyString)", category: .network, context: nil)
        }

        do {
            let result = try JSONDecoder().decode(ModerationResult.self, from: data)
            logger.info("✅ Moderation completed successfully", category: .network, context: LogContext(additionalInfo: [
                "flagged": String(result.flagged),
                "categories": result.categories?.filter { $0.value }.keys.joined(separator: ", ") ?? "none"
            ]))
            logger.debug("━━━━━━━━━━ MODERATION RESPONSE END ━━━━━━━━━━", category: .network, context: nil)
            return result
        } catch {
            let body = String(data: data, encoding: .utf8) ?? ""
            logger.error("❌ Failed to decode moderation response", category: .network, context: nil, error: error)
            logger.debug("❌ Decode error details: \(error.localizedDescription)", category: .network, context: nil)
            logger.debug("❌ Raw response body: \(body)", category: .network, context: nil)
            logger.debug("━━━━━━━━━━ MODERATION RESPONSE END ━━━━━━━━━━", category: .network, context: nil)
            throw error
        }
    }
}

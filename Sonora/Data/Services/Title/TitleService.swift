import Foundation

protocol TitleServiceProtocol: Sendable {
    func generateTitle(transcript: String, languageHint: String?) async throws -> String?
}

final class TitleService: TitleServiceProtocol, @unchecked Sendable {
    private let config = AppConfiguration.shared

    struct TitleResponse: Codable { let title: String }

    func generateTitle(transcript: String, languageHint: String?) async throws -> String? {
        let url = config.apiBaseURL.appendingPathComponent("title")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = min(8.0, config.analysisTimeoutInterval)

        // Keep payload minimal; server performs tiny-model prompt + validation.
        let safeTranscript = AnalysisGuardrails.sanitizeTranscriptForLLM(transcript)
        var body: [String: Any] = [
            "transcript": safeTranscript,
            "rules": [
                "words": "3-5",
                "titleCase": true,
                "noPunctuation": true,
                "maxChars": 32
            ]
        ]
        if let lang = languageHint, !lang.isEmpty { body["language"] = lang }

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        print("🧠 TitleService: POST /title lang=\(languageHint ?? "auto") url=\(url.absoluteString)")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            if let http = response as? HTTPURLResponse {
                print("🧠 TitleService: /title non-200 status=\(http.statusCode) body=\(String(data: data, encoding: .utf8) ?? "<nil>")")
            } else {
                print("🧠 TitleService: /title no HTTPURLResponse")
            }
            return nil
        }
        if let decoded = try? JSONDecoder().decode(TitleResponse.self, from: data) {
            print("🧠 TitleService: /title decoded=\(decoded.title)")
            return Self.validate(decoded.title)
        }
        print("🧠 TitleService: /title decode failed")
        return nil
    }

    private static func validate(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let words = trimmed.split(separator: " ").map(String.init)
        guard (3...5).contains(words.count) else { return nil }
        guard trimmed.count <= 32 else { return nil }
        // Reject outputs with obvious punctuation/emojis
        if trimmed.range(of: #"[\p{P}\p{Emoji_Presentation}]"#, options: .regularExpression) != nil { return nil }
        // Basic pass
        return trimmed
    }
}

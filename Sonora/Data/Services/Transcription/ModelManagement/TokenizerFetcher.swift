import Foundation

/// Fetches tokenizer assets for WhisperKit models from canonical HF sources.
/// Order of attempts per model:
/// 1) argmaxinc/whisperkit-coreml/<model_id>/tokenizer.json (and tokenizer_config.json)
/// 2) argmaxinc/whisperkit-coreml/<model_id>/tokenizer/tokenizer.json
/// 3) Fallback: openai/whisper-<size>[/tokenizer]/tokenizer.json (+ tokenizer_config.json)
///
/// Writes assets into `<modelFolder>/tokenizer/`.
@MainActor
final class TokenizerFetcher {
    struct Metrics { var successArgmax: Int = 0; var successOpenAI: Int = 0; var failures: Int = 0 }
    static private(set) var metrics = Metrics()
    private static let logger = Logger.shared

    func fetch(for modelId: String, into modelFolder: URL, timeout: TimeInterval = 10.0) async -> Bool {
        let destDir = modelFolder.appendingPathComponent("tokenizer", isDirectory: true)
        do { try FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true) } catch {}

        // Build candidate URLs
        let argmaxBase = "https://huggingface.co/argmaxinc/whisperkit-coreml/resolve/main/\(modelId)"
        var candidates: [URL] = []
        // Prefer tokenizer.json in root, then in tokenizer/
        candidates.append(URL(string: "\(argmaxBase)/tokenizer.json")!)
        candidates.append(URL(string: "\(argmaxBase)/tokenizer/tokenizer.json")!)
        // Config variants
        let argmaxConfigRoot = URL(string: "\(argmaxBase)/tokenizer_config.json")!
        let argmaxConfigSub = URL(string: "\(argmaxBase)/tokenizer/tokenizer_config.json")!

        // OpenAI fallback mapping: openai_whisper-<size>(.en) -> openai/whisper-<size>
        if let openAIRepo = mapToOpenAIRepo(modelId: modelId) {
            let openAIBase = "https://huggingface.co/\(openAIRepo)/resolve/main"
            candidates.append(URL(string: "\(openAIBase)/tokenizer.json")!)
            candidates.append(URL(string: "\(openAIBase)/tokenizer/tokenizer.json")!)
        }

        // Attempt tokenizer.json first
        if let tokenizerURL = await firstReachable(candidates, timeout: timeout) {
            if await download(url: tokenizerURL, to: destDir.appendingPathComponent("tokenizer.json"), timeout: timeout) {
                // Try optional tokenizer_config.json from the same repo base (best-effort)
                if tokenizerURL.absoluteString.contains("argmaxinc/whisperkit-coreml") {
                    _ = await download(url: argmaxConfigRoot, to: destDir.appendingPathComponent("tokenizer_config.json"), timeout: timeout)
                    _ = await download(url: argmaxConfigSub, to: destDir.appendingPathComponent("tokenizer/tokenizer_config.json"), timeout: timeout)
                    Self.metrics.successArgmax += 1
                } else {
                    Self.metrics.successOpenAI += 1
                }
                return true
            }
        }

        Self.metrics.failures += 1
        return false
    }

    func currentMetrics() -> Metrics { Self.metrics }

    // MARK: - Helpers
    private func mapToOpenAIRepo(modelId: String) -> String? {
        // openai_whisper-base(.en) -> openai/whisper-base
        guard modelId.hasPrefix("openai_whisper-") else { return nil }
        var size = String(modelId.dropFirst("openai_whisper-".count))
        if size.hasSuffix(".en") { size.removeLast(3) }
        return "openai/whisper-\(size)"
    }

    private func firstReachable(_ urls: [URL], timeout: TimeInterval) async -> URL? {
        for url in urls {
            if await checkHEAD(url: url, timeout: timeout) { return url }
        }
        return nil
    }

    private func checkHEAD(url: URL, timeout: TimeInterval) async -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = timeout
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse { return (200..<300).contains(http.statusCode) }
        } catch { Self.logger.debug("TokenizerFetcher HEAD failed: \(error.localizedDescription)") }
        return false
    }

    private func download(url: URL, to dest: URL, timeout: TimeInterval) async -> Bool {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = timeout
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), data.count > 0 {
                let dir = dest.deletingLastPathComponent()
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                try data.write(to: dest, options: .atomic)
                Self.logger.info("TokenizerFetcher: Downloaded \(url.lastPathComponent) from \(url.host ?? "")")
                return true
            }
        } catch {
            Self.logger.debug("TokenizerFetcher GET failed: \(error.localizedDescription)")
        }
        return false
    }
}


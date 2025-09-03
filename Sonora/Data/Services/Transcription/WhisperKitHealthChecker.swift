import Foundation
#if canImport(WhisperKit)
import WhisperKit
#endif

@MainActor
final class WhisperKitHealthChecker {
    private let modelProvider: WhisperKitModelProvider
    private let logger: any LoggerProtocol
    
    init(modelProvider: WhisperKitModelProvider? = nil,
         logger: any LoggerProtocol = Logger.shared) {
        self.modelProvider = modelProvider ?? DIContainer.shared.whisperKitModelProvider()
        self.logger = logger
    }
    
    struct Report {
        let ok: Bool
        let details: String
    }
    
    func checkSelectedModel() async -> Report {
        let selectedId = UserDefaults.standard.selectedWhisperModel
        logger.info("HealthCheck: Checking WhisperKit model \(selectedId)", category: .system, context: LogContext())
        guard let folder = modelProvider.installedModelFolder(id: selectedId) else {
            return Report(ok: false, details: "Model folder not found for \(selectedId). Install the model and retry.")
        }
        do {
            #if canImport(WhisperKit)
            let timeout = AppConfiguration.shared.healthCheckTimeoutInterval
            let result = try await withThrowingTaskGroup(of: Report.self) { group -> Report in
                group.addTask { [logger] in
                    let urls = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
                    // Validate compiled models exist
                    guard urls.contains(where: { $0.pathExtension == "mlmodelc" }) else {
                        return Report(ok: false, details: "No compiled models (.mlmodelc) found at \(folder.path)")
                    }
                    // Validate tokenizer assets with a broader recursive heuristic
                    var hasAssets = false
                    if let enumerator = FileManager.default.enumerator(at: folder, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                        while let obj = enumerator.nextObject() as? URL {
                            let n = obj.lastPathComponent.lowercased()
                            if n == "tokenizer.json" || n == "tokenizer.model" || n == "vocabulary.json" || n.contains("merges") || n.contains("vocab") || n.contains("tokenizer") {
                                hasAssets = true
                                break
                            }
                        }
                    }
                    guard hasAssets else {
                        return Report(ok: false, details: "Tokenizer assets missing (merges/tokenizer/vocab) in \(folder.lastPathComponent). Re-download the model.")
                    }
                    let wk = try await WhisperKit(prewarm: false, load: false, download: false)
                    wk.modelFolder = folder
                    do { try await wk.prewarmModels() } catch { return Report(ok: false, details: "Prewarm failed: \(error.localizedDescription)") }
                    do { try await wk.loadModels() } catch { return Report(ok: false, details: "Load failed: \(error.localizedDescription)") }

                    // Perform a tiny transcription to fully exercise tokenizer/decoder
                    do {
                        let sampleRate = 16_000
                        // 0.5s of silence to keep it fast
                        let audio = Array<Float>(repeating: 0.0, count: sampleRate / 2)
                        #if canImport(WhisperKit)
                        let options = DecodingOptions(task: .transcribe, language: nil, wordTimestamps: false, chunkingStrategy: ChunkingStrategy.none)
                        _ = try await wk.transcribe(audioArray: audio, decodeOptions: options)
                        #else
                        _ = try await wk.transcribe(audioArray: audio)
                        #endif
                    } catch {
                        return Report(ok: false, details: "Tiny transcription failed: \(error.localizedDescription)")
                    }

                    await wk.unloadModels()
                    logger.info("HealthCheck: Successfully prewarmed, loaded, and transcribed with model \(selectedId)", category: .system, context: LogContext())
                    return Report(ok: true, details: "Model is healthy and decodes correctly.")
                }
                group.addTask {
                    try await Task.sleep(nanoseconds: UInt64(max(1.0, timeout) * 1_000_000_000))
                    return Report(ok: false, details: "Health check timed out after \(timeout)s")
                }
                let report = try await group.next()!
                group.cancelAll()
                return report
            }
            return result
            #else
            return Report(ok: false, details: "WhisperKit SDK not available in this build.")
            #endif
        } catch {
            return Report(ok: false, details: "Health check failed: \(error.localizedDescription)")
        }
    }
}

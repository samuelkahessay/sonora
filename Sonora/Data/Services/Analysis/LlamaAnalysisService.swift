import Foundation
import UIKit
@preconcurrency import LLM

@MainActor
final class LlamaAnalysisService: ObservableObject, AnalysisServiceProtocol {
    
    private var llm: LLM?
    private var currentLoadedModel: LocalModel?
    private let logger = Logger.shared
    
    /// Currently selected model from user settings
    private var selectedModel: LocalModel {
        let modelId = AppConfiguration.shared.selectedLocalModel
        return LocalModel(rawValue: modelId) ?? LocalModel.defaultModel
    }
    
    // Keep model loaded until app backgrounds
    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        // Free memory when app backgrounds
        llm = nil
        currentLoadedModel = nil
        logger.debug("Model unloaded on background")
    }
    
    private func ensureModelLoaded() async throws {
        let targetModel = selectedModel

        // If already loaded for this model, keep using it
        if llm != nil && currentLoadedModel == targetModel { return }

        // If model is likely too large for this device, skip loading and fall back preemptively
        if !isModelViableOnDevice(targetModel) {
            logger.warning("Selected model appears too large for device memory; will try smaller models")
        } else {
            // Try to load target model; if it fails (e.g., memory), fall back
            if try await tryLoadModel(targetModel) { return }
        }

        // Fallback chain: prefer downloaded, compatible models from higher to lower tiers
        // Prefer smaller models first to avoid memory pressure on mobile devices
        let fallbackOrder: [LocalModel] = [
            .llama32_3B, .gemma2_2B, .qwen25_3B, .llama32_1B, .phi4_mini, .tinyllama_1B
        ]
        for candidate in fallbackOrder {
            if candidate == targetModel { continue }
            if try await tryLoadModel(candidate) {
                logger.warning("Falling back to \(candidate.displayName) after load failure of \(targetModel.displayName)")
                return
            }
        }

        // No viable model could be loaded
        throw AnalysisError.modelLoadFailed
    }

    private func tryLoadModel(_ model: LocalModel) async throws -> Bool {
        // Validate device + file present
        guard model.isDeviceCompatible else { return false }
        guard model.isDownloaded else { return false }

        // Unload any previous
        if currentLoadedModel != model { llm = nil; currentLoadedModel = nil }

        // Log file info prior to load
        let path = model.localPath.path
        var sizeInfo = "unknown"
        if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
           let size = attrs[.size] as? NSNumber {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            sizeInfo = formatter.string(fromByteCount: size.int64Value)
        }
        logger.info("Loading \(model.displayName) model (\(sizeInfo))...")
        llm = LLM(
            from: model.localPath,
            topP: 0.95,
            temp: 0.7,
            historyLimit: 2,
            maxTokenCount: 512
        )
        guard llm != nil else { return false }
        currentLoadedModel = model
        logger.info("\(model.displayName) model loaded successfully")
        return true
    }
    
    // MARK: - Memory Viability Heuristic
    
    /// Estimate whether a model's on-disk footprint is likely to exceed practical memory limits for the current device.
    private func isModelViableOnDevice(_ model: LocalModel) -> Bool {
        let estRAM = ProcessInfo.processInfo.physicalMemory // bytes (approx)
        // Heuristic memory budget for weights + runtime (KV cache, context): ~45% of total RAM
        // Debugger attached reduces headroom; be conservative.
        let budget = UInt64(Double(estRAM) * 0.45)
        let modelBytes = totalModelBytesOnDisk(model)
        logger.debug("Memory check: estRAM=\(ByteCountFormatter.string(fromByteCount: Int64(estRAM), countStyle: .memory)), budget=\(ByteCountFormatter.string(fromByteCount: Int64(budget), countStyle: .memory)), model=\(ByteCountFormatter.string(fromByteCount: Int64(modelBytes), countStyle: .memory))")
        return modelBytes <= budget
    }
    
    /// Sum sizes of model GGUF files (handles shards when primary is 00001-of-NN)
    private func totalModelBytesOnDisk(_ model: LocalModel) -> UInt64 {
        let primary = model.localPath.lastPathComponent.lowercased()
        let dir = model.localPath.deletingLastPathComponent()
        do {
            if primary.contains("-00001-of-") {
                // Sum all parts by pattern prefix
                let prefix = primary.replacingOccurrences(of: "-00001-of-", with: "-")
                let files = try FileManager.default.contentsOfDirectory(atPath: dir.path)
                let ggufs = files.filter { $0.lowercased().hasSuffix(".gguf") && $0.lowercased().contains(prefix.split(separator: "-gguf").first ?? "") }
                var total: UInt64 = 0
                for f in ggufs {
                    let p = dir.appendingPathComponent(f).path
                    if let attrs = try? FileManager.default.attributesOfItem(atPath: p), let s = attrs[.size] as? UInt64 { total += s }
                }
                return total
            } else {
                let attrs = try FileManager.default.attributesOfItem(atPath: model.localPath.path)
                return (attrs[.size] as? UInt64) ?? 0
            }
        } catch {
            return 0
        }
    }
    
    func analyze<T: Codable & Sendable>(
        mode: AnalysisMode,
        transcript: String,
        responseType: T.Type
    ) async throws -> AnalyzeEnvelope<T> {
        
        let startTime = Date()
        
        // Basic input validation
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AnalysisError.invalidInput("Empty transcript")
        }
        
        // Ensure model is loaded (cached after first use)
        try await ensureModelLoaded()
        
        guard let llmInstance = llm else {
            throw AnalysisError.modelNotAvailable
        }
        
        // Simple prompt
        let prompt = buildSimplePrompt(mode: mode, transcript: transcript)
        
        // Get completion - call directly, preconcurrency import handles Sendable warnings
        let output = await llmInstance.getCompletion(from: prompt)
        
        // Parse output
        let parsedData = try parseSimpleOutput(output, mode: mode, responseType: responseType)
        
        let duration = Date().timeIntervalSince(startTime)
        
        return AnalyzeEnvelope(
            mode: mode,
            data: parsedData,
            model: currentLoadedModel?.rawValue ?? "local-llm",
            tokens: TokenUsage(input: 0, output: 0),
            latency_ms: Int(duration * 1000),
            moderation: nil
        )
    }
    
    // Required protocol methods
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        return try await analyze(mode: .distill, transcript: transcript, responseType: DistillData.self)
    }
    
    func analyzeAnalysis(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData> {
        return try await analyze(mode: .analysis, transcript: transcript, responseType: AnalysisData.self)
    }
    
    func analyzeThemes(transcript: String) async throws -> AnalyzeEnvelope<ThemesData> {
        return try await analyze(mode: .themes, transcript: transcript, responseType: ThemesData.self)
    }
    
    func analyzeTodos(transcript: String) async throws -> AnalyzeEnvelope<TodosData> {
        return try await analyze(mode: .todos, transcript: transcript, responseType: TodosData.self)
    }
    
    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        return try await analyze(mode: .distillSummary, transcript: transcript, responseType: DistillSummaryData.self)
    }
    
    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        return try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self)
    }
    
    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        return try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self)
    }
    
    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        return try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self)
    }
    
    // MARK: - Helpers
    
    private func buildSimplePrompt(mode: AnalysisMode, transcript: String) -> String {
        // Truncate if too long
        let maxLength = 1500
        let truncated = transcript.count > maxLength 
            ? String(transcript.prefix(maxLength)) + "..."
            : transcript
        
        switch mode {
        case .distill, .distillSummary:
            return "Summarize in 2-3 sentences: \(truncated)"
        case .analysis:
            return "List 3 key points: \(truncated)"
        case .themes, .distillThemes:
            return "List main themes: \(truncated)"
        case .todos, .distillActions:
            return "List action items: \(truncated)"
        case .distillReflection:
            return "Brief reflection: \(truncated)"
        }
    }
    
    private func parseSimpleOutput<T: Codable>(_ output: String, mode: AnalysisMode, responseType: T.Type) throws -> T {
        let cleaned = output.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Simple parsing based on type
        if responseType == DistillData.self {
            // Best-effort simple mapping to structured fields
            let bullets = cleaned
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            let themes = Array(bullets.prefix(3))
            let actions = Array(bullets.dropFirst(3).prefix(3)).map { text in
                DistillData.ActionItem(text: text, priority: .medium)
            }
            let reflections = Array(bullets.suffix(2))

            let data = DistillData(
                summary: cleaned,
                action_items: actions.isEmpty ? nil : actions,
                key_themes: themes,
                reflection_questions: reflections
            )
            return data as! T
        }
        
        if responseType == AnalysisData.self {
            // Create simple summary and key points from lines
            let lines = cleaned
                .components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let summary = lines.first ?? cleaned
            let keyPoints = Array(lines.prefix(5))
            let data = AnalysisData(
                summary: summary,
                key_points: keyPoints
            )
            return data as! T
        }
        
        if responseType == ThemesData.self {
            let names = cleaned.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(5)
            let themeObjects: [ThemesData.Theme] = names.map { name in
                ThemesData.Theme(name: name, evidence: [])
            }
            // Default neutral sentiment when unknown
            let data = ThemesData(themes: themeObjects, sentiment: "neutral")
            return data as! T
        }
        
        if responseType == TodosData.self {
            let items = cleaned.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let todos = items.map { TodosData.Todo(text: $0, due: nil) }
            let data = TodosData(todos: todos)
            return data as! T
        }
        
        if responseType == DistillSummaryData.self {
            return DistillSummaryData(summary: cleaned) as! T
        }
        
        if responseType == DistillActionsData.self {
            let actions = cleaned.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let items = actions.map { DistillData.ActionItem(text: $0, priority: .medium) }
            return DistillActionsData(action_items: items) as! T
        }
        
        if responseType == DistillThemesData.self {
            let themes = cleaned.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(5)
            return DistillThemesData(key_themes: Array(themes)) as! T
        }
        
        if responseType == DistillReflectionData.self {
            let qs = cleaned.isEmpty ? [] : [cleaned]
            return DistillReflectionData(reflection_questions: qs) as! T
        }
        
        throw AnalysisError.parsingFailed("Unsupported type")
    }
}

// MARK: - Errors

extension AnalysisError {
    static let modelNotDownloaded = AnalysisError.networkError("Model not downloaded")
    static let modelLoadFailed = AnalysisError.networkError("Failed to load model")
    static let modelNotAvailable = AnalysisError.networkError("Model not available")
    
    static func deviceIncompatible(_ reason: String) -> AnalysisError {
        return .networkError("Device incompatible: \(reason)")
    }
    
    static func invalidInput(_ msg: String) -> AnalysisError {
        return .decodingError(msg)
    }
    
    static func parsingFailed(_ msg: String) -> AnalysisError {
        return .decodingError(msg)
    }
}

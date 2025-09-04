import Foundation
import UIKit
import LLM

@MainActor
final class LlamaAnalysisService: ObservableObject, AnalysisServiceProtocol {
    
    private var llm: LLM?
    private let logger = Logger.shared
    
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
        logger.debug("Model unloaded on background")
    }
    
    private func ensureModelLoaded() async throws {
        // Return if already loaded
        if llm != nil { return }
        
        // Check model exists
        guard let modelPath = SimpleModelDownloader.shared.modelPath else {
            throw AnalysisError.modelNotDownloaded
        }
        
        // Load model (one-time cost)
        logger.info("Loading LLaMA model...")
        
        // Initialize LLM with sensible defaults. Some SDK versions
        // may not support a specific template enum case; omit template.
        llm = LLM(
            from: modelPath,
            topP: 0.95,
            temp: 0.7,
            historyLimit: 2,
            maxTokenCount: 1024
        )
        
        guard llm != nil else {
            throw AnalysisError.modelLoadFailed
        }
        
        logger.info("Model loaded successfully")
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
        
        guard let llm = llm else {
            throw AnalysisError.modelNotAvailable
        }
        
        // Simple prompt
        let prompt = buildSimplePrompt(mode: mode, transcript: transcript)
        
        // Get completion
        let output = await llm.getCompletion(from: prompt)
        
        // Parse output
        let parsedData = try parseSimpleOutput(output, mode: mode, responseType: responseType)
        
        let duration = Date().timeIntervalSince(startTime)
        
        return AnalyzeEnvelope(
            mode: mode,
            data: parsedData,
            model: "llama-3.2-3b",
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
    static func invalidInput(_ msg: String) -> AnalysisError {
        return .decodingError(msg)
    }
    static func parsingFailed(_ msg: String) -> AnalysisError {
        return .decodingError(msg)
    }
}

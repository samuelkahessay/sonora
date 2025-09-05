import Foundation

/// Multi-tier AnalysisService that can short-circuit for simple content.
/// Uses injected tiered services to minimize cost while preserving quality.
@MainActor
final class ProgressiveAnalysisService: ObservableObject, AnalysisServiceProtocol {
    private let tiny: any AnalysisServiceProtocol
    private let base: any AnalysisServiceProtocol
    private let logger: any LoggerProtocol

    /// Optional: a second local or medium tier. For now we alias to tiny if not provided.
    private let small: (any AnalysisServiceProtocol)?

    init(tiny: any AnalysisServiceProtocol,
         small: (any AnalysisServiceProtocol)? = nil,
         base: any AnalysisServiceProtocol,
         logger: any LoggerProtocol = Logger.shared) {
        self.tiny = tiny
        self.small = small
        self.base = base
        self.logger = logger
    }

    func analyze<T: Codable & Sendable>(mode: AnalysisMode, transcript: String, responseType: T.Type) async throws -> AnalyzeEnvelope<T> {
        let start = Date()
        let ctx = DetectionContextBuilder.build(memoId: UUID(), transcript: transcript)
        logger.debug("Progressive analysis: starting tiny tier", category: .analysis, context: LogContext(additionalInfo: ["mode": mode.rawValue]))

        var previous: AnalyzeEnvelope<T>? = nil

        // Tier 1: tiny (local)
        do {
            let tinyEnv: AnalyzeEnvelope<T> = try await tiny.analyze(mode: mode, transcript: transcript, responseType: responseType)
            logTierTelemetry(tier: "tiny", envelope: tinyEnv, startedAt: start)
            previous = tinyEnv
            if shouldEarlyTerminate(context: ctx, mode: mode, envelope: tinyEnv) {
                logger.info("Progressive analysis: early terminated at tiny tier", category: .analysis, context: LogContext(additionalInfo: [
                    "latency_ms": Int(Date().timeIntervalSince(start) * 1000)
                ]))
                return tinyEnv
            }
        } catch {
            logger.warning("Progressive analysis: tiny tier failed, escalating — \(error.localizedDescription)", category: .analysis, context: LogContext(), error: error)
        }

        // Tier 2: small (if provided)
        if let smallSvc = small {
            do {
                let smallEnv: AnalyzeEnvelope<T> = try await smallSvc.analyze(mode: mode, transcript: transcript, responseType: responseType)
                logTierTelemetry(tier: "small", envelope: smallEnv, startedAt: start)
                if let prev = previous, isDisagreement(prev, smallEnv) {
                    logger.info("Progressive analysis: tiny↔︎small disagreement detected; escalating", category: .analysis, context: LogContext())
                } else if shouldEarlyTerminate(context: ctx, mode: mode, envelope: smallEnv) {
                    logger.info("Progressive analysis: terminated at small tier", category: .analysis, context: LogContext(additionalInfo: [
                        "latency_ms": Int(Date().timeIntervalSince(start) * 1000)
                    ]))
                    return smallEnv
                }
                previous = smallEnv
            } catch {
                logger.warning("Progressive analysis: small tier failed, escalating — \(error.localizedDescription)", category: .analysis, context: LogContext(), error: error)
            }
        }

        // Tier 3: base (cloud)
        logger.debug("Progressive analysis: escalating to base tier", category: .analysis, context: LogContext())
        let baseEnv: AnalyzeEnvelope<T> = try await base.analyze(mode: mode, transcript: transcript, responseType: responseType)
        logTierTelemetry(tier: "base", envelope: baseEnv, startedAt: start)
        return baseEnv
    }

    // MARK: - Convenience passthroughs for component methods
    func analyzeDistill(transcript: String) async throws -> AnalyzeEnvelope<DistillData> {
        try await analyze(mode: .distill, transcript: transcript, responseType: DistillData.self)
    }
    func analyzeAnalysis(transcript: String) async throws -> AnalyzeEnvelope<AnalysisData> {
        try await analyze(mode: .analysis, transcript: transcript, responseType: AnalysisData.self)
    }
    func analyzeThemes(transcript: String) async throws -> AnalyzeEnvelope<ThemesData> {
        try await analyze(mode: .themes, transcript: transcript, responseType: ThemesData.self)
    }
    func analyzeTodos(transcript: String) async throws -> AnalyzeEnvelope<TodosData> {
        try await analyze(mode: .todos, transcript: transcript, responseType: TodosData.self)
    }
    func analyzeDistillSummary(transcript: String) async throws -> AnalyzeEnvelope<DistillSummaryData> {
        try await analyze(mode: .distillSummary, transcript: transcript, responseType: DistillSummaryData.self)
    }
    func analyzeDistillActions(transcript: String) async throws -> AnalyzeEnvelope<DistillActionsData> {
        try await analyze(mode: .distillActions, transcript: transcript, responseType: DistillActionsData.self)
    }
    func analyzeDistillThemes(transcript: String) async throws -> AnalyzeEnvelope<DistillThemesData> {
        try await analyze(mode: .distillThemes, transcript: transcript, responseType: DistillThemesData.self)
    }
    func analyzeDistillReflection(transcript: String) async throws -> AnalyzeEnvelope<DistillReflectionData> {
        try await analyze(mode: .distillReflection, transcript: transcript, responseType: DistillReflectionData.self)
    }

    // MARK: - Early termination heuristic
    private func shouldEarlyTerminate<T: Codable & Sendable>(context: DetectionContext, mode: AnalysisMode, envelope: AnalyzeEnvelope<T>) -> Bool {
        // Confidence gating: if high-confidence on tiny/small, allow termination; on disagreement, escalate
        // 1) Generic simplicity heuristic
        var score = 0
        if context.transcriptLength < 200 { score += 1 }
        if !context.hasDatesOrTimes { score += 1 }
        if !context.hasCalendarPhrases { score += 1 }
        if context.imperativeVerbDensity < 0.01 { score += 1 }
        if mode == .distill || mode == .themes { score += 1 }

        // 2) Content-specific: if envelope contains EventsData/RemindersData, use average confidence
        if let events = envelope.data as? EventsData {
            let avg = events.events.map { $0.confidence }.reduce(0, +) / Float(max(events.events.count, 1))
            if avg >= 0.80 && !events.events.isEmpty { score += 1 }
        }
        if let reminders = envelope.data as? RemindersData {
            let avg = reminders.reminders.map { $0.confidence }.reduce(0, +) / Float(max(reminders.reminders.count, 1))
            if avg >= 0.80 && !reminders.reminders.isEmpty { score += 1 }
        }

        return score >= 3
    }

    // Compare tiers for disagreement if we have previous tier data with confidences (simple heuristic hook)
    private func isDisagreement<T: Codable & Sendable>(_ a: AnalyzeEnvelope<T>, _ b: AnalyzeEnvelope<T>) -> Bool {
        // Only handle events/reminders where we can infer overlap roughly by title text
        if let ea = a.data as? EventsData, let eb = b.data as? EventsData {
            let setA = Set(ea.events.map { $0.title.lowercased() })
            let setB = Set(eb.events.map { $0.title.lowercased() })
            // Significant symmetric difference implies disagreement
            let inter = setA.intersection(setB).count
            let maxCount = max(setA.count, setB.count)
            return maxCount > 0 && Double(inter) / Double(maxCount) < 0.5
        }
        if let ra = a.data as? RemindersData, let rb = b.data as? RemindersData {
            let setA = Set(ra.reminders.map { $0.title.lowercased() })
            let setB = Set(rb.reminders.map { $0.title.lowercased() })
            let inter = setA.intersection(setB).count
            let maxCount = max(setA.count, setB.count)
            return maxCount > 0 && Double(inter) / Double(maxCount) < 0.5
        }
        return false
    }

    private func logTierTelemetry<T: Codable & Sendable>(tier: String, envelope: AnalyzeEnvelope<T>, startedAt: Date) {
        logger.analysis("Progressive tier \(tier): model=\(envelope.model), tokens_in=\(envelope.tokens.input), tokens_out=\(envelope.tokens.output), latency_ms=\(envelope.latency_ms)", level: .info, context: LogContext(additionalInfo: [
            "elapsed_ms": Int(Date().timeIntervalSince(startedAt) * 1000)
        ]))
    }
}

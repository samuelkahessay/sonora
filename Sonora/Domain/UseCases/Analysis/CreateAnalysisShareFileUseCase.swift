import Foundation

protocol CreateAnalysisShareFileUseCaseProtocol: Sendable {
    /// Creates a shareable text file containing AI analysis for the memo.
    /// - Parameters:
    ///   - memo: The memo to gather analysis for.
    ///   - includeTypes: Optional filter of domain analysis types to include. If nil, include all completed.
    /// - Returns: URL to the created temporary `.txt` file.
    func execute(memo: Memo, includeTypes: Set<DomainAnalysisType>?) async throws -> URL
}

final class CreateAnalysisShareFileUseCase: CreateAnalysisShareFileUseCaseProtocol, @unchecked Sendable {
    // MARK: - Dependencies
    private let analysisRepository: any AnalysisRepository
    private let exporter: any AnalysisExporting
    private let logger: any LoggerProtocol

    init(
        analysisRepository: any AnalysisRepository,
        exporter: any AnalysisExporting,
        logger: any LoggerProtocol = Logger.shared
    ) {
        self.analysisRepository = analysisRepository
        self.exporter = exporter
        self.logger = logger
    }

    @MainActor
    func execute(memo: Memo, includeTypes: Set<DomainAnalysisType>?) async throws -> URL {
        let corr = UUID().uuidString
        let context = LogContext(correlationId: corr, additionalInfo: [
            "memoId": memo.id.uuidString,
            "filename": memo.filename
        ])
        logger.useCase("Preparing analysis share file", level: .info, context: context)

        do {
            // Map DomainAnalysisType filter to AnalysisMode filter
            let modeFilter: Set<AnalysisMode>? = includeTypes.map { types in
                var set = Set<AnalysisMode>()
                for t in types {
                    switch t {
                    case .distill: set.insert(.distill)
                    case .summary: set.insert(.analysis) // summaries available in AnalysisData
                    case .themes: set.insert(.themes)
                    case .actionItems: set.insert(.todos)
                    case .keyPoints: set.insert(.analysis)
                    }
                }
                return set
            }

            // Determine latest timestamps from repository history (MainActor-isolated)
            let history = await MainActor.run(resultType: [(mode: AnalysisMode, timestamp: Date)].self) {
                analysisRepository.getAnalysisHistory(for: memo.id)
            }
            var timestampByMode: [AnalysisMode: Date] = [:]
            for (mode, ts) in history { timestampByMode[mode] = ts }

            // Collect available envelopes per mode
            struct Section { let mode: AnalysisMode; let timestamp: Date; let text: String }
            var sections: [Section] = []

            func addIfAvailable<M: Codable>(_ mode: AnalysisMode, _ type: M.Type, builder: (AnalyzeEnvelope<M>) -> String?) async {
                if let filter = modeFilter, !filter.contains(mode) { return }
                let env: AnalyzeEnvelope<M>? = await MainActor.run { analysisRepository.getAnalysisResult(for: memo.id, mode: mode, responseType: M.self) }
                guard let env = env else { return }
                let ts = timestampByMode[mode] ?? Date()
                if let txt = builder(env), !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sections.append(Section(mode: mode, timestamp: ts, text: txt))
                }
            }

            // Distill section: prefer full DistillData; otherwise consolidate component modes
            let includeDistill = (includeTypes == nil) || (includeTypes?.contains(.distill) == true)
            if includeDistill {
                let fullDistill: AnalyzeEnvelope<DistillData>? = await MainActor.run {
                    analysisRepository.getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self)
                }
                if let env = fullDistill {
                    let ts = timestampByMode[.distill] ?? Date()
                    var s = "📝 DISTILL (Updated: \(Self.fmtDate(ts)))\n\n"
                    s += env.data.summary + "\n\n"
                    // Themes removed from Distill export; use Themes mode section below if available.
                    if let actions = env.data.action_items, !actions.isEmpty {
                        s += "✅ Action Items\n"
                        actions.forEach { s += "• \($0.text) [\($0.priority.rawValue)]\n" }
                        s += "\n"
                    }
                    sections.append(Section(mode: .distill, timestamp: ts, text: s))
                } else {
                    // Consolidate component modes: summary, themes, actions, reflection
                    let sumEnv: AnalyzeEnvelope<DistillSummaryData>? = await MainActor.run(resultType: AnalyzeEnvelope<DistillSummaryData>?.self) {
                        analysisRepository.getAnalysisResult(for: memo.id, mode: .distillSummary, responseType: DistillSummaryData.self)
                    }
                    let actEnv: AnalyzeEnvelope<DistillActionsData>? = await MainActor.run(resultType: AnalyzeEnvelope<DistillActionsData>?.self) {
                        analysisRepository.getAnalysisResult(for: memo.id, mode: .distillActions, responseType: DistillActionsData.self)
                    }
                    let refEnv: AnalyzeEnvelope<DistillReflectionData>? = await MainActor.run(resultType: AnalyzeEnvelope<DistillReflectionData>?.self) {
                        analysisRepository.getAnalysisResult(for: memo.id, mode: .distillReflection, responseType: DistillReflectionData.self)
                    }

                    if sumEnv != nil || actEnv != nil || refEnv != nil {
                        // Determine latest timestamp among components
                        let compTs: [Date] = [
                            timestampByMode[.distillSummary],
                            timestampByMode[.distillActions],
                            timestampByMode[.distillReflection]
                        ].compactMap { $0 }
                        let ts = compTs.max() ?? Date()
                        var s = "📝 DISTILL (Updated: \(Self.fmtDate(ts)))\n\n"
                        if let sum = sumEnv?.data.summary {
                            s += sum + "\n\n"
                        }
                        if let actions = actEnv?.data.action_items, !actions.isEmpty {
                            s += "✅ Action Items\n"
                            actions.forEach { s += "• \($0.text) [\($0.priority.rawValue)]\n" }
                            s += "\n"
                        }
                        if let questions = refEnv?.data.reflection_questions, !questions.isEmpty {
                            s += "💭 Reflection Questions\n"
                            questions.forEach { s += "• \($0)\n" }
                            s += "\n"
                        }
                        sections.append(Section(mode: .distill, timestamp: ts, text: s))
                    }
                }
            }

            // Analysis: summary + key points
            await addIfAvailable(.analysis, AnalysisData.self) { env in
                var s = "🔍 ANALYSIS (Updated: \(Self.fmt(env)))\n\n"
                s += (env.data.summary) + "\n\n"
                if !env.data.key_points.isEmpty {
                    s += "🔑 Key Points\n"
                    env.data.key_points.forEach { s += "• \($0)\n" }
                    s += "\n"
                }
                return s
            }

            // Themes: themes list
            await addIfAvailable(.themes, ThemesData.self) { env in
                var s = "🏷️ THEMES (Updated: \(Self.fmt(env)))\n\n"
                if !env.data.themes.isEmpty {
                    env.data.themes.forEach { s += "• \($0.name)\n" }
                    s += "\n"
                }
                return s
            }

            // Todos: action items
            await addIfAvailable(.todos, TodosData.self) { env in
                var s = "✅ TO-DO (Updated: \(Self.fmt(env)))\n\n"
                let todos = env.data.todos
                if !todos.isEmpty {
                    todos.forEach { todo in
                        if let due = todo.due { s += "• \(todo.text) (due: \(due))\n" } else { s += "• \(todo.text)\n" }
                    }
                    s += "\n"
                }
                return s
            }

            guard !sections.isEmpty else {
                logger.useCase("No completed analysis to export", level: .info, context: context)
                throw SonoraError.analysisInsufficientContent
            }

            // Sort by timestamp descending (newest first)
            sections.sort { $0.timestamp > $1.timestamp }

            // Build file content
            let header: String = {
                let df = DateFormatter()
                df.dateStyle = .medium
                df.timeStyle = .short
                return """
                \(memo.displayName)
                Generated: \(df.string(from: Date()))

                --- AI ANALYSIS ---

                """
            }()
            let body = sections.map { $0.text }.joined()
            let content = header + body

            // Export to file
            let url = try exporter.makeAnalysisFile(memo: memo, text: content)
            logger.useCase("Analysis file created: \(url.lastPathComponent)", level: .info, context: context)
            return url

        } catch let repoErr as RepositoryError {
            logger.error("CreateAnalysisShareFileUseCase repository error", category: .useCase, context: context, error: repoErr)
            throw repoErr.asSonoraError
        } catch let svcErr as ServiceError {
            logger.error("CreateAnalysisShareFileUseCase service error", category: .useCase, context: context, error: svcErr)
            throw svcErr.asSonoraError
        } catch let nsErr as NSError {
            logger.error("CreateAnalysisShareFileUseCase system error", category: .useCase, context: context, error: nsErr)
            throw ErrorMapping.mapError(nsErr)
        } catch {
            logger.error("CreateAnalysisShareFileUseCase unknown error", category: .useCase, context: context, error: error)
            throw SonoraError.storageWriteFailed("Failed to create analysis file: \(error.localizedDescription)")
        }
    }

    private static func fmt<T>(_ env: AnalyzeEnvelope<T>) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        // We don't have exact timestamp on envelope; caller sorts via repo history.
        return df.string(from: Date())
    }

    private static func fmtDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }
}

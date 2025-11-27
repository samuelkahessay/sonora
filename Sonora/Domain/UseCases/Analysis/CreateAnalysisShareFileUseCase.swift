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
                    case .distill, .summary, .actionItems, .keyPoints:
                        set.insert(.distill)
                    case .themes:
                        set.insert(.distillThemes)
                    }
                }
                return set
            }

            // Determine latest timestamps from repository history
            let history = await analysisRepository.getAnalysisHistory(for: memo.id)
            var timestampByMode: [AnalysisMode: Date] = [:]
            for (mode, ts) in history { timestampByMode[mode] = ts }

            // Collect available envelopes per mode
            struct Section { let mode: AnalysisMode; let timestamp: Date; let text: String }
            var sections: [Section] = []

            func addIfAvailable<M: Codable & Sendable>(_ mode: AnalysisMode, _ type: M.Type, builder: (AnalyzeEnvelope<M>) -> String?) async {
                if let filter = modeFilter, !filter.contains(mode) { return }
                let env: AnalyzeEnvelope<M>? = await analysisRepository.getAnalysisResult(for: memo.id, mode: mode, responseType: M.self)
                guard let env = env else { return }
                let ts = timestampByMode[mode] ?? Date()
                if let txt = builder(env), !txt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    sections.append(Section(mode: mode, timestamp: ts, text: txt))
                }
            }

            // Distill section: prefer full DistillData; otherwise consolidate component modes
            let includeDistill = (includeTypes == nil) || (includeTypes?.contains(.distill) == true)
            if includeDistill {
                let fullDistill: AnalyzeEnvelope<DistillData>? = await analysisRepository.getAnalysisResult(for: memo.id, mode: .distill, responseType: DistillData.self)
                if let env = fullDistill {
                    let ts = timestampByMode[.distill] ?? Date()
                    var s = "📝 DISTILL (Updated: \(Self.fmtDate(ts)))\n\n"

                    // Summary
                    s += env.data.summary + "\n\n"

                    // Key Themes
                    if let keyThemes = env.data.keyThemes, !keyThemes.isEmpty {
                        s += "🏷️ Key Themes\n"
                        keyThemes.forEach { s += "• \($0)\n" }
                        s += "\n"
                    }

                    // Personal Insight
                    if let personalInsight = env.data.personalInsight {
                        s += "💡 Personal Insight (\(personalInsight.type.displayName))\n"
                        s += personalInsight.observation + "\n"
                        if let invitation = personalInsight.invitation {
                            s += invitation + "\n"
                        }
                        s += "\n"
                    }

                    // Patterns & Connections
                    if let patterns = env.data.patterns, !patterns.isEmpty {
                        s += "🔗 Patterns & Connections\n"
                        for (index, pattern) in patterns.enumerated() {
                            s += "\(index + 1). \(pattern.theme)\n"
                            s += "   \(pattern.description)\n"
                            if let relatedMemos = pattern.relatedMemos, !relatedMemos.isEmpty {
                                s += "   Related memos:\n"
                                for memo in relatedMemos.prefix(3) {
                                    let timeStr = memo.daysAgo.map { "(\($0) days ago)" } ?? ""
                                    s += "   • \(memo.title) \(timeStr)\n"
                                }
                            }
                        }
                        s += "\n"
                    }

                    // Action Items
                    if let actions = env.data.action_items, !actions.isEmpty {
                        s += "✅ Action Items\n"
                        actions.forEach { s += "• \($0.text) [\($0.priority.rawValue)]\n" }
                        s += "\n"
                    }

                    // Events
                    if let events = env.data.events, !events.isEmpty {
                        s += "📅 Events\n"
                        for event in events {
                            s += "• \(event.title)"
                            if let start = event.startDate {
                                let df = DateFormatter()
                                df.dateStyle = .medium
                                df.timeStyle = .short
                                s += " (\(df.string(from: start)))"
                            }
                            if let location = event.location {
                                s += " at \(location)"
                            }
                            s += "\n"
                        }
                        s += "\n"
                    }

                    // Reminders
                    if let reminders = env.data.reminders, !reminders.isEmpty {
                        s += "⏰ Reminders\n"
                        for reminder in reminders {
                            s += "• \(reminder.title) [\(reminder.priority.rawValue)]"
                            if let due = reminder.dueDate {
                                let df = DateFormatter()
                                df.dateStyle = .medium
                                df.timeStyle = .short
                                s += " (Due: \(df.string(from: due)))"
                            }
                            s += "\n"
                        }
                        s += "\n"
                    }

                    // Reflection Questions
                    if !env.data.reflection_questions.isEmpty {
                        s += "💭 Reflection Questions\n"
                        env.data.reflection_questions.forEach { s += "• \($0)\n" }
                        s += "\n"
                    }

                    // Closing Note
                    if let closingNote = env.data.closingNote {
                        s += "📝 Note\n\(closingNote)\n\n"
                    }

                    sections.append(Section(mode: .distill, timestamp: ts, text: s))
                } else {
                    // Consolidate component modes: summary, themes, actions, reflection
                    let sumEnv: AnalyzeEnvelope<DistillSummaryData>? = await analysisRepository.getAnalysisResult(for: memo.id, mode: .distillSummary, responseType: DistillSummaryData.self)
                    let actEnv: AnalyzeEnvelope<DistillActionsData>? = await analysisRepository.getAnalysisResult(for: memo.id, mode: .distillActions, responseType: DistillActionsData.self)
                    let themesEnv: AnalyzeEnvelope<DistillThemesData>? = await analysisRepository.getAnalysisResult(for: memo.id, mode: .distillThemes, responseType: DistillThemesData.self)
                    let insightEnv: AnalyzeEnvelope<DistillPersonalInsightData>? = await analysisRepository.getAnalysisResult(for: memo.id, mode: .distillPersonalInsight, responseType: DistillPersonalInsightData.self)
                    let closingEnv: AnalyzeEnvelope<DistillClosingNoteData>? = await analysisRepository.getAnalysisResult(for: memo.id, mode: .distillClosingNote, responseType: DistillClosingNoteData.self)
                    let refEnv: AnalyzeEnvelope<DistillReflectionData>? = await analysisRepository.getAnalysisResult(for: memo.id, mode: .distillReflection, responseType: DistillReflectionData.self)

                    if sumEnv != nil || actEnv != nil || themesEnv != nil || insightEnv != nil || closingEnv != nil || refEnv != nil {
                        // Determine latest timestamp among components
                        let compTs: [Date] = [
                            timestampByMode[.distillSummary],
                            timestampByMode[.distillActions],
                            timestampByMode[.distillThemes],
                            timestampByMode[.distillPersonalInsight],
                            timestampByMode[.distillClosingNote],
                            timestampByMode[.distillReflection]
                        ].compactMap { $0 }
                        let ts = compTs.max() ?? Date()
                        var s = "📝 DISTILL (Updated: \(Self.fmtDate(ts)))\n\n"

                        // Summary
                        if let sum = sumEnv?.data.summary {
                            s += sum + "\n\n"
                        }

                        // Key Themes
                        if let keyThemes = themesEnv?.data.keyThemes, !keyThemes.isEmpty {
                            s += "🏷️ Key Themes\n"
                            keyThemes.forEach { s += "• \($0)\n" }
                            s += "\n"
                        }

                        // Personal Insight
                        if let personalInsight = insightEnv?.data.personalInsight {
                            s += "💡 Personal Insight (\(personalInsight.type.displayName))\n"
                            s += personalInsight.observation + "\n"
                            if let invitation = personalInsight.invitation {
                                s += invitation + "\n"
                            }
                            s += "\n"
                        }

                        // Action Items
                        if let actions = actEnv?.data.action_items, !actions.isEmpty {
                            s += "✅ Action Items\n"
                            actions.forEach { s += "• \($0.text) [\($0.priority.rawValue)]\n" }
                            s += "\n"
                        }

                        // Reflection Questions
                        if let questions = refEnv?.data.reflection_questions, !questions.isEmpty {
                            s += "💭 Reflection Questions\n"
                            questions.forEach { s += "• \($0)\n" }
                            s += "\n"
                        }

                        // Closing Note
                        if let closingNote = closingEnv?.data.closingNote {
                            s += "📝 Note\n\(closingNote)\n\n"
                        }

                        sections.append(Section(mode: .distill, timestamp: ts, text: s))
                    }
                }
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

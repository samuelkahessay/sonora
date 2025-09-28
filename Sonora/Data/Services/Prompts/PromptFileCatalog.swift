import Foundation

/// Loader for NDJSON (JSON Lines) prompt file in the app bundle.
/// One JSON object per line, comments starting with `#` or `//` are ignored.
/// Missing optional fields fall back to sensible defaults.
final class PromptFileLoader {
    struct FilePrompt: Codable {
        let id: String
        let text: String
        let category: String?
        let depth: String?
        let dayParts: [String]?
        let weekParts: [String]?
        let weight: Int?
    }

    private let logger: any LoggerProtocol

    init(logger: any LoggerProtocol = Logger.shared) {
        self.logger = logger
    }

    func loadPrompts(fromResource name: String = "prompts", ext: String = "ndjson") -> [RecordingPrompt] {
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            logger.debug("PromptFileLoader: prompts file not found — falling back to static catalog", category: .system, context: LogContext())
            return []
        }

        guard let data = try? Data(contentsOf: url), let content = String(data: data, encoding: .utf8) else {
            logger.warning("PromptFileLoader: failed to read prompts file", category: .system, context: LogContext(), error: nil)
            return []
        }

        var results: [RecordingPrompt] = []
        let decoder = JSONDecoder()
        let lines = content.split(whereSeparator: { $0.isNewline })
        for (idx, rawLine) in lines.enumerated() {
            let lineNum = idx + 1
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            if line.hasPrefix("#") || line.hasPrefix("//") { continue }
            guard let jsonData = line.data(using: .utf8) else { continue }
            do {
                let fp = try decoder.decode(FilePrompt.self, from: jsonData)
                let prompt = mapFilePrompt(fp)
                results.append(prompt)
            } catch {
                logger.warning("PromptFileLoader: failed to parse line \(lineNum): \(error.localizedDescription)", category: .system, context: LogContext(), error: error)
                continue
            }
        }
        if results.isEmpty {
            logger.warning("PromptFileLoader: no valid prompts parsed — falling back to static catalog", category: .system, context: LogContext(), error: nil)
        } else {
            logger.info("PromptFileLoader: loaded \(results.count) prompts from file", category: .system, context: LogContext())
        }
        return results
    }

    private func mapFilePrompt(_ fp: FilePrompt) -> RecordingPrompt {
        // Category
        let category: PromptCategory = {
            switch (fp.category ?? "goals").lowercased() {
            case "growth": return .growth
            case "work": return .work
            case "relationships": return .relationships
            case "creative": return .creative
            case "goals": return .goals
            case "mindfulness": return .mindfulness
            default: return .goals
            }
        }()

        // Depth
        let depth: EmotionalDepth = {
            switch (fp.depth ?? "light").lowercased() {
            case "light": return .light
            case "medium": return .medium
            case "deep": return .deep
            default: return .light
            }
        }()

        // Day parts
        let dayParts: Set<DayPart> = {
            guard let arr = fp.dayParts, !arr.isEmpty else { return DayPart.any }
            if arr.contains(where: { $0.lowercased() == "any" }) { return DayPart.any }
            var set: Set<DayPart> = []
            for v in arr {
                switch v.lowercased() {
                case "morning": set.insert(.morning)
                case "afternoon": set.insert(.afternoon)
                case "evening": set.insert(.evening)
                case "night": set.insert(.night)
                default: break
                }
            }
            return set.isEmpty ? DayPart.any : set
        }()

        // Week parts
        let weekParts: Set<WeekPart> = {
            guard let arr = fp.weekParts, !arr.isEmpty else { return WeekPart.any }
            if arr.contains(where: { $0.lowercased() == "any" }) { return WeekPart.any }
            var set: Set<WeekPart> = []
            for v in arr {
                switch v.lowercased() {
                case "startofweek", "start": set.insert(.startOfWeek)
                case "midweek", "mid": set.insert(.midWeek)
                case "endofweek", "end": set.insert(.endOfWeek)
                default: break
                }
            }
            return set.isEmpty ? WeekPart.any : set
        }()

        let weight = max(1, fp.weight ?? 1)

        // Use the template text as the localization key. If Localizable.strings lacks a translation,
        // DefaultLocalizationProvider returns the key unchanged, which is the text itself.
        return RecordingPrompt(
            id: fp.id,
            localizationKey: fp.text,
            category: category,
            emotionalDepth: depth,
            allowedDayParts: dayParts,
            allowedWeekParts: weekParts,
            weight: weight
        )
    }
}

/// File-backed PromptCatalog that loads prompts once from the bundled NDJSON file.
final class PromptCatalogFile: PromptCatalog, @unchecked Sendable {
    private let prompts: [RecordingPrompt]

    init(logger: any LoggerProtocol = Logger.shared) {
        let loader = PromptFileLoader(logger: logger)
        self.prompts = loader.loadPrompts()
    }

    func allPrompts() -> [RecordingPrompt] { prompts }
}

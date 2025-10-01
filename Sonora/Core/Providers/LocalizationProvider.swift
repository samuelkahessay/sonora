import Foundation

public protocol LocalizationProvider: Sendable {
    func localizedString(_ key: String, locale: Locale) -> String
}

public struct DefaultLocalizationProvider: LocalizationProvider, Sendable {
    // Cache of prompt localization keys -> source text
    // Built once to avoid repeatedly reloading the NDJSON file.
    private let promptTextByKey: [String: String]

    public init() {
        // Build dictionary once from the file-backed catalog
        let loader = PromptFileLoader(logger: Logger.shared)
        let prompts = loader.loadPrompts()
        var map: [String: String] = [:]
        map.reserveCapacity(prompts.count)
        for p in prompts {
            if let text = p.metadata["text"], !text.isEmpty {
                map[p.localizationKey] = text
            }
        }
        self.promptTextByKey = map
    }

    public func localizedString(_ key: String, locale: Locale) -> String {
        // Locale not used for bundle selection currently; keep to satisfy protocol.
        _ = locale

        // 1) Prompts: map "prompt.*" keys to ndjson text (source of truth)
        if key.hasPrefix("prompt.") {
            return promptTextByKey[key] ?? key
        }

        // 2) Built-in daypart/weekpart defaults (English)
        switch key {
        case "daypart.morning": return "morning"
        case "daypart.afternoon": return "afternoon"
        case "daypart.evening": return "evening"
        case "daypart.night": return "night"
        case "weekpart.start": return "start of the week"
        case "weekpart.mid": return "mid-week"
        case "weekpart.end": return "end of the week"
        case "prompt.fallback.tap": return "Tap the lightbulb for ideas"
        default:
            break
        }

        // 3) Fallback to bundle lookup; if missing, return key itself
        return NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
    }
}

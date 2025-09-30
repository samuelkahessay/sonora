import Foundation

public protocol LocalizationProvider: Sendable {
    func localizedString(_ key: String, locale: Locale) -> String
}

public struct DefaultLocalizationProvider: LocalizationProvider, Sendable {
    public init() {}

    public func localizedString(_ key: String, locale: Locale) -> String {
        // Locale not used for bundle selection currently; keep to satisfy protocol.
        _ = locale

        // 1) Prompts: map "prompt.*" keys to ndjson text (source of truth)
        if key.hasPrefix("prompt.") {
            let catalog = PromptCatalogFile(logger: Logger.shared)
            if let prompt = catalog.allPrompts().first(where: { $0.localizationKey == key }),
               let text = prompt.metadata["text"], !text.isEmpty {
                return text
            }
            return key
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

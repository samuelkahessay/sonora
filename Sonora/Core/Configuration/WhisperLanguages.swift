import Foundation

struct WhisperLanguages {
    // Curated set of languages exposed in the app UI.
    static let codeToName: [String: String] = [
        "en": "english",
        "es": "spanish",
        "fr": "french",
        "de": "german",
        "it": "italian",
        "pt": "portuguese",
        "ru": "russian",
        "zh": "mandarin chinese",
        "ja": "japanese",
        "ko": "korean",
        "ar": "arabic",
        "hi": "hindi",
        "ur": "urdu"
    ]

    static let supportedCodes: Set<String> = Set(codeToName.keys)

    static func localizedDisplayName(for code: String) -> String {
        let lc = code.lowercased()
        // Try Locale for ISO 639-1 codes; fallback to Whisper name capitalized
        if lc.count == 2, let name = Locale.current.localizedString(forLanguageCode: lc) {
            return name.capitalized
        }
        if let english = codeToName[lc] {
            return english.capitalized
        }
        return lc.uppercased()
    }
}

import Foundation

struct WhisperLanguages {
    // Source: https://github.com/openai/whisper (tokenizer.py LANGUAGES)
    static let codeToName: [String: String] = [
        "en": "english", "zh": "chinese", "de": "german", "es": "spanish", "ru": "russian",
        "ko": "korean", "fr": "french", "ja": "japanese", "pt": "portuguese", "tr": "turkish",
        "pl": "polish", "ca": "catalan", "nl": "dutch", "ar": "arabic", "sv": "swedish",
        "it": "italian", "id": "indonesian", "hi": "hindi", "fi": "finnish", "vi": "vietnamese",
        "he": "hebrew", "uk": "ukrainian", "el": "greek", "ms": "malay", "cs": "czech",
        "ro": "romanian", "da": "danish", "hu": "hungarian", "ta": "tamil", "no": "norwegian",
        "th": "thai", "ur": "urdu", "hr": "croatian", "bg": "bulgarian", "lt": "lithuanian",
        "la": "latin", "mi": "maori", "ml": "malayalam", "cy": "welsh", "sk": "slovak",
        "te": "telugu", "fa": "persian", "lv": "latvian", "bn": "bengali", "sr": "serbian",
        "az": "azerbaijani", "sl": "slovenian", "kn": "kannada", "et": "estonian", "mk": "macedonian",
        "br": "breton", "eu": "basque", "is": "icelandic", "hy": "armenian", "ne": "nepali",
        "mn": "mongolian", "bs": "bosnian", "kk": "kazakh", "sq": "albanian", "sw": "swahili",
        "gl": "galician", "mr": "marathi", "pa": "punjabi", "si": "sinhala", "km": "khmer",
        "sn": "shona", "yo": "yoruba", "so": "somali", "af": "afrikaans", "oc": "occitan",
        "ka": "georgian", "be": "belarusian", "tg": "tajik", "sd": "sindhi", "gu": "gujarati",
        "am": "amharic", "yi": "yiddish", "lo": "lao", "uz": "uzbek", "fo": "faroese",
        "ht": "haitian creole", "ps": "pashto", "tk": "turkmen", "nn": "nynorsk", "mt": "maltese",
        "sa": "sanskrit", "lb": "luxembourgish", "my": "myanmar", "bo": "tibetan", "tl": "tagalog",
        "mg": "malagasy", "as": "assamese", "tt": "tatar", "haw": "hawaiian", "ln": "lingala",
        "ha": "hausa", "ba": "bashkir", "jw": "javanese", "su": "sundanese", "yue": "cantonese",
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

    static func pickerItems() -> [(code: String, name: String)] {
        let items: [(code: String, name: String)] = supportedCodes.map { code in (code, localizedDisplayName(for: code)) }
        return items.sorted(by: { (a: (code: String, name: String), b: (code: String, name: String)) -> Bool in
            a.name.localizedCaseInsensitiveCompare(b.name) == .orderedAscending
        })
    }
}

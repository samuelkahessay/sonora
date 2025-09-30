import Foundation
import NaturalLanguage

// MARK: - Models

struct LanguageDetectionResult {
    let language: String              // ISO 639-1 code or "unknown"
    let confidence: Double            // 0.0 to 1.0
    let isEnglish: Bool
    let wordCount: Int
    let hasNonAsciiCharacters: Bool
}

enum LanguageSource: String {
    case server
    case client
}

// MARK: - Protocol

protocol ClientLanguageDetectionService {
    func detectLanguage(from text: String) -> LanguageDetectionResult
    func computeQualityScore(for result: LanguageDetectionResult, textLength: Int) -> Double
}

// MARK: - Implementation

final class DefaultClientLanguageDetectionService: ClientLanguageDetectionService {
    private let recognizer = NLLanguageRecognizer()

    func detectLanguage(from text: String) -> LanguageDetectionResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return LanguageDetectionResult(
                language: "unknown",
                confidence: 0.0,
                isEnglish: false,
                wordCount: 0,
                hasNonAsciiCharacters: false
            )
        }

        if #available(iOS 12.0, *) {
            recognizer.reset()
            recognizer.processString(text)

            // Get dominant language and its confidence when possible
            let dominantLanguage = recognizer.dominantLanguage
            let topHypothesis = recognizer.languageHypotheses(withMaximum: 1).first

            let code = Self.iso639_1(fromBCP47: dominantLanguage?.rawValue)
            let conf = topHypothesis?.value ?? 0.0

            return LanguageDetectionResult(
                language: code ?? "unknown",
                confidence: conf,
                isEnglish: dominantLanguage == .english,
                wordCount: Self.wordCount(in: text),
                hasNonAsciiCharacters: Self.hasNonASCII(text)
            )
        } else {
            // Fallback for iOS versions earlier than 12 (unlikely for current targets)
            return LanguageDetectionResult(
                language: "unknown",
                confidence: 0.0,
                isEnglish: false,
                wordCount: Self.wordCount(in: text),
                hasNonAsciiCharacters: Self.hasNonASCII(text)
            )
        }
    }

    func computeQualityScore(for result: LanguageDetectionResult, textLength: Int) -> Double {
        var score = result.confidence

        // Boost score for reasonable text length
        if textLength > 50 { score += 0.1 }

        // Reduce score for very short text (less reliable detection)
        if textLength < 20 { score *= 0.7 }

        // Slight boost for English (assumed primary use case)
        if result.isEnglish { score += 0.05 }

        return min(1.0, max(0.0, score))
    }

    // MARK: - Helpers

    static func iso639_1(fromBCP47 code: String?) -> String? {
        guard let code = code, !code.isEmpty else { return nil }
        // NLLanguage uses BCP-47 such as "en", "es", "pt-BR", "zh-Hans"
        let lower = code.lowercased()
        if lower == "und" { return nil }
        // Extract first two alphabetic characters as ISO 639-1 when present
        let prefix2 = lower.prefix(2)
        if prefix2.count == 2, prefix2.allSatisfy({ $0.isLetter }) {
            return String(prefix2)
        }
        return nil
    }

    private static func wordCount(in text: String) -> Int {
        // Simple whitespace-based word count; performant for large text
        var count = 0
        var inWord = false
        for ch in text.unicodeScalars {
            if CharacterSet.whitespacesAndNewlines.contains(ch) {
                if inWord { count += 1; inWord = false }
            } else {
                inWord = true
            }
        }
        if inWord { count += 1 }
        return count
    }

    private static func hasNonASCII(_ text: String) -> Bool {
        for s in text.unicodeScalars { if !s.isASCII { return true } }
        return false
    }
}

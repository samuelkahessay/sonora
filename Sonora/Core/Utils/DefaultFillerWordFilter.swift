import Foundation

/// Default implementation that removes common filler words from transcriptions using a pre-built regular expression.
/// The filter is intentionally conservative so the cleaned transcript preserves meaning while improving readability.
@MainActor
final class DefaultFillerWordFilter: FillerWordFiltering {
    private static let baseWords: Set<String> = [
        "um",
        "uh",
        "er",
        "ah",
        "eh",
        "hmm",
        "you know",
        "i mean",
        "sort of",
        "kind of",
        "actually",
        "basically",
        "literally",
        "anyway"
    ]

    private var customWords: Set<String>
    private let defaultWords: Set<String>
    private var regex: NSRegularExpression?

    var isEnabled: Bool

    init(defaultWords: Set<String> = DefaultFillerWordFilter.baseWords, customWords: Set<String> = [], isEnabled: Bool = true) {
        self.defaultWords = defaultWords
        self.customWords = customWords
        self.isEnabled = isEnabled
        rebuildRegex()
    }

    func removeFillerWords(from text: String) -> String {
        guard isEnabled, !text.isEmpty, let regex else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let replaced = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")

        var normalized = replaced.replacingOccurrences(of: " {2,}", with: " ", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: " ([,\.!?;:])", with: "$1", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: " \n", with: "\n", options: .regularExpression)
        normalized = normalized.replacingOccurrences(of: "\n ", with: "\n", options: .regularExpression)
        normalized = normalized.trimmingCharacters(in: .whitespaces)
        return normalized
    }

    func updateCustomWords(_ words: Set<String>) {
        customWords = words
        rebuildRegex()
    }

    // MARK: - Regex Construction

    private func rebuildRegex() {
        let combined = defaultWords.union(customWords).map { $0.lowercased() }.filter { !$0.isEmpty }
        guard let pattern = Self.buildPattern(from: combined) else {
            regex = nil
            return
        }

        do {
            regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        } catch {
            regex = nil
        }
    }

    private static func buildPattern(from phrases: [String]) -> String? {
        guard !phrases.isEmpty else { return nil }
        let components = phrases
            .map { regexComponent(for: $0) }
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
            .joined(separator: "|")
        guard !components.isEmpty else { return nil }
        // (?<!\S) ensures the match begins at the start or after whitespace.
        // The trailing look-ahead keeps the following whitespace/newline intact so we can normalise spacing afterwards.
        return "(?<!\\S)(?:" + components + ")[\\,\\.!?;:]*?(?=(?:\\s|$))"
    }

    private static func regexComponent(for phrase: String) -> String {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        switch trimmed {
        case "um":
            return "u+m+"
        case "uh":
            return "u+h+"
        default:
            return trimmed
                .split(separator: " ")
                .map { NSRegularExpression.escapedPattern(for: String($0)) }
                .joined(separator: "\\s+")
        }
    }
}

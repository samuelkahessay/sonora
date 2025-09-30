import Foundation

enum PromptInterpolation {
    /// Builds final localized text by replacing known tokens. Unknown tokens are removed and whitespace collapsed.
    static func build(
        key: String,
        tokens: [String: String],
        localization: LocalizationProvider,
        locale: Locale
    ) -> String {
        var text = localization.localizedString(key, locale: locale)

        // Replace provided tokens (e.g., [Name], [DayPart], [WeekPart])
        for (token, value) in tokens {
            text = text.replacingOccurrences(of: "[\(token)]", with: value)
        }

        // Remove any remaining [Token] patterns and collapse whitespace
        text = removeUnresolvedTokens(text)
        text = collapseWhitespace(text)
        return text
    }

    private static func removeUnresolvedTokens(_ s: String) -> String {
        // Simple scan to remove bracketed words like [Something]
        var result = ""
        var i = s.startIndex
        while i < s.endIndex {
            if s[i] == "[" {
                if let close = s[i...].firstIndex(of: "]") {
                    i = s.index(after: close)
                    continue
                }
            }
            result.append(s[i])
            i = s.index(after: i)
        }
        return result
    }

    private static func collapseWhitespace(_ s: String) -> String {
        let comps = s.split(whereSeparator: { $0.isWhitespace })
        return comps.joined(separator: " ")
    }
}

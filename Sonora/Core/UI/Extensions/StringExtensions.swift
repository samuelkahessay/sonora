import Foundation

extension String {
    /// Normalizes Unicode smart quotes and apostrophes to their ASCII equivalents
    /// to prevent encoding display issues (� characters) in the UI.
    ///
    /// This is commonly needed when displaying AI-generated text which often includes:
    /// - Left/right single quotes (' ') → straight apostrophe (')
    /// - Left/right double quotes (" ") → straight double quote (")
    /// - Em dash (—) → double hyphen (--)
    /// - En dash (–) → single hyphen (-)
    /// - Ellipsis (…) → three dots (...)
    func normalizingSmartPunctuation() -> String {
        var result = self

        // Normalize single quotes and apostrophes
        result = result.replacingOccurrences(of: "\u{2018}", with: "'") // '
        result = result.replacingOccurrences(of: "\u{2019}", with: "'") // '
        result = result.replacingOccurrences(of: "\u{201A}", with: "'") // ‚
        result = result.replacingOccurrences(of: "\u{201B}", with: "'") // ‛

        // Normalize double quotes
        result = result.replacingOccurrences(of: "\u{201C}", with: "\"") // "
        result = result.replacingOccurrences(of: "\u{201D}", with: "\"") // "
        result = result.replacingOccurrences(of: "\u{201E}", with: "\"") // „
        result = result.replacingOccurrences(of: "\u{201F}", with: "\"") // ‟

        // Normalize dashes
        result = result.replacingOccurrences(of: "\u{2013}", with: "-")  // – (en dash)
        result = result.replacingOccurrences(of: "\u{2014}", with: "--") // — (em dash)
        result = result.replacingOccurrences(of: "\u{2015}", with: "--") // ― (horizontal bar)

        // Normalize ellipsis
        result = result.replacingOccurrences(of: "\u{2026}", with: "...") // …

        return result
    }
}

//
//  FileNameSanitizer.swift
//  Sonora
//
//  Utility for sanitizing user input into safe filenames
//

import Foundation

/// Utility for converting user input into safe, filesystem-compatible filenames
struct FileNameSanitizer {

    // MARK: - Constants

    /// Maximum length for generated filenames (excluding extension)
    private static let maxFileNameLength = 100

    /// Characters that are invalid in filenames on most filesystems
    private static let invalidCharacters: CharacterSet = {
        var set = CharacterSet()
        set.insert(charactersIn: "<>:\"|?*\\/")
        set.formUnion(.newlines)
        set.formUnion(.controlCharacters)
        return set
    }()

    /// Reserved filename components that should be avoided
    private static let reservedNames = [
        "CON", "PRN", "AUX", "NUL",
        "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7", "COM8", "COM9",
        "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9"
    ]

    // MARK: - Public Methods

    /// Converts a user-provided string into a safe filename
    /// - Parameters:
    ///   - input: The user input to sanitize
    ///   - fileExtension: The file extension to append (with dot, e.g., ".m4a")
    /// - Returns: A sanitized filename safe for filesystem use
    static func sanitize(_ input: String, withExtension fileExtension: String = ".m4a") -> String {
        guard !input.isEmpty else {
            return "untitled\(fileExtension)"
        }

        // Step 1: Trim whitespace
        var sanitized = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Step 2: Convert emojis to text equivalents for filesystem compatibility
        sanitized = convertEmojisToText(sanitized)

        // Step 3: Replace spaces with underscores
        sanitized = sanitized.replacingOccurrences(of: " ", with: "_")

        // Step 4: Remove invalid characters
        sanitized = String(sanitized.unicodeScalars.filter { scalar in
            !Self.invalidCharacters.contains(scalar)
        })

        // Step 5: Handle multiple consecutive underscores
        sanitized = sanitized.replacingOccurrences(of: "_+", with: "_", options: .regularExpression)

        // Step 6: Remove leading/trailing underscores
        sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))

        // Step 7: Handle empty result after sanitization
        if sanitized.isEmpty {
            sanitized = "untitled"
        }

        // Step 8: Check for reserved names
        if Self.reservedNames.contains(sanitized.uppercased()) {
            sanitized = "memo_\(sanitized)"
        }

        // Step 9: Truncate if too long
        if sanitized.count > Self.maxFileNameLength {
            let endIndex = sanitized.index(sanitized.startIndex, offsetBy: Self.maxFileNameLength)
            sanitized = String(sanitized[..<endIndex])
            // Remove trailing underscore if truncation created one
            sanitized = sanitized.trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        }

        // Step 10: Final fallback check
        if sanitized.isEmpty {
            sanitized = "untitled"
        }

        // Step 11: Add file extension
        return "\(sanitized)\(fileExtension)"
    }

    // MARK: - Private Methods

    /// Converts common emojis to text equivalents for filename compatibility
    /// - Parameter input: String that may contain emojis
    /// - Returns: String with emojis converted to text
    private static func convertEmojisToText(_ input: String) -> String {
        let emojiMappings: [String: String] = [
            "📝": "memo",
            "🎤": "audio",
            "🎵": "music",
            "🎶": "music",
            "💼": "business",
            "📅": "calendar",
            "📞": "call",
            "✅": "done",
            "❌": "cancel",
            "⭐": "star",
            "❤️": "heart",
            "👍": "thumbs_up",
            "👎": "thumbs_down",
            "🔥": "fire",
            "💡": "idea",
            "📈": "chart",
            "🏠": "home",
            "🚗": "car",
            "✈️": "airplane",
            "🌟": "star",
            "💯": "100",
            "🎯": "target"
        ]

        var intermediate = input
        for (emoji, text) in emojiMappings {
            intermediate = intermediate.replacingOccurrences(of: emoji, with: text)
        }

        // Replace remaining emoji grapheme clusters with a generic placeholder,
        // but do NOT replace ASCII digits or characters that can participate in
        // keycap sequences unless they form an actual emoji presentation.
        var output = String()
        output.reserveCapacity(intermediate.count)

        for ch in intermediate { // iterate by grapheme cluster
            let scalars = ch.unicodeScalars
            let hasEmojiScalar = scalars.contains { scalar in
                let props = scalar.properties
                // Replace only true emoji presentations or emoji scalars that are not ASCII
                return props.isEmojiPresentation || (props.isEmoji && scalar.value >= 0x80)
            }
            if hasEmojiScalar {
                output.append("emoji")
            } else {
                output.append(ch)
            }
        }

        return output
    }
}

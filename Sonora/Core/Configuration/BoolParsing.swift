import Foundation

// Robust String → Bool parsing used across env var handling.
// Accepts common truthy/falsey tokens (case-insensitive, trims whitespace).
extension Bool {
    public init?(_ string: String) {
        let s = string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch s {
        case "1", "true", "yes", "y", "on":
            self = true
        case "0", "false", "no", "n", "off":
            self = false
        default:
            return nil
        }
    }
}


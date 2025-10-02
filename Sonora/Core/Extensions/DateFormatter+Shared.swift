import Foundation

/// Shared DateFormatter instances to avoid expensive repeated initialization.
/// DateFormatter creation is expensive (~1ms per instance), so we reuse configured formatters.
extension DateFormatter {
    /// Medium date and short time format (e.g., "Mar 15, 2025 at 2:00 PM")
    static let mediumDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    /// Short date only format (e.g., "3/15/25")
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()

    /// Long date and short time format (e.g., "March 15, 2025 at 2:00 PM")
    static let longDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter
    }()
}

// MARK: - Date Convenience Extensions

extension Date {
    /// Returns a medium date and short time string (e.g., "Mar 15, 2025 at 2:00 PM")
    var mediumDateTimeString: String {
        DateFormatter.mediumDateTime.string(from: self)
    }

    /// Returns a short date string (e.g., "3/15/25")
    var shortDateString: String {
        DateFormatter.shortDate.string(from: self)
    }

    /// Returns a long date and short time string (e.g., "March 15, 2025 at 2:00 PM")
    var longDateTimeString: String {
        DateFormatter.longDateTime.string(from: self)
    }
}

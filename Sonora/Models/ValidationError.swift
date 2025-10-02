import Foundation

/// Validation errors for user input in edit forms
enum ValidationError: LocalizedError, Equatable, Hashable {
    case emptyTitle
    case pastDueDate
    case invalidDateRange
    case titleTooLong(maxLength: Int)
    case locationTooLong(maxLength: Int)

    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Title cannot be empty"
        case .pastDueDate:
            return "Due date must be in the future"
        case .invalidDateRange:
            return "End date must be after start date"
        case .titleTooLong(let maxLength):
            return "Title must be \(maxLength) characters or less"
        case .locationTooLong(let maxLength):
            return "Location must be \(maxLength) characters or less"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .emptyTitle:
            return "Enter a title for this item"
        case .pastDueDate:
            return "Select a date in the future or leave empty"
        case .invalidDateRange:
            return "Adjust the start or end time"
        case .titleTooLong, .locationTooLong:
            return "Shorten the text"
        }
    }
}

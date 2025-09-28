import Foundation

public enum CalendarEntityType: String, Sendable, Codable, Hashable {
    case event
    case reminder
}

public struct CalendarDTO: Sendable, Identifiable, Codable, Equatable, Hashable {
    public let id: String           // Stable identifier (EKCalendar.calendarIdentifier)
    public let title: String
    public let colorHex: String?    // sRGB hex like "#RRGGBB" or "#RRGGBBAA"
    public let entityType: CalendarEntityType
    public let allowsModifications: Bool
    public let isDefault: Bool

    public init(
        id: String,
        title: String,
        colorHex: String?,
        entityType: CalendarEntityType,
        allowsModifications: Bool,
        isDefault: Bool
    ) {
        self.id = id
        self.title = title
        self.colorHex = colorHex
        self.entityType = entityType
        self.allowsModifications = allowsModifications
        self.isDefault = isDefault
    }
}

public struct ExistingEventDTO: Sendable, Codable, Equatable {
    public let identifier: String?
    public let title: String?
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool

    public init(
        identifier: String?,
        title: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool
    ) {
        self.identifier = identifier
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
    }
}

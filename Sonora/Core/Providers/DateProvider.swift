import Foundation

public protocol DateProvider: Sendable {
    var now: Date { get }
    var calendar: Calendar { get }
    var timeZone: TimeZone { get }
    var locale: Locale { get }
    func dayPart(for date: Date) -> DayPart
    func weekPart(for date: Date) -> WeekPart
}

public struct DefaultDateProvider: DateProvider, Sendable {
    public let calendar: Calendar
    public let timeZone: TimeZone
    public let locale: Locale

    public init(
        calendar: Calendar = .autoupdatingCurrent,
        timeZone: TimeZone = .autoupdatingCurrent,
        locale: Locale = .autoupdatingCurrent
    ) {
        var cal = calendar
        cal.timeZone = timeZone
        self.calendar = cal
        self.timeZone = timeZone
        self.locale = locale
    }

    public var now: Date { Date() }

    public func dayPart(for date: Date) -> DayPart {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5...11: return .morning
        case 12...16: return .afternoon
        case 17...20: return .evening
        default: return .night
        }
    }

    public func weekPart(for date: Date) -> WeekPart {
        // Determine offset since the local start of week
        var cal = calendar
        cal.locale = locale
        cal.timeZone = timeZone

        let weekday = cal.component(.weekday, from: date)
        // Convert to zero-based offset from firstWeekday
        let first = cal.firstWeekday
        let offset = (weekday - first + 7) % 7
        switch offset {
        case 0, 1: return .startOfWeek
        case 2, 3: return .midWeek
        default: return .endOfWeek
        }
    }
}

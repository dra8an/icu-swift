/// Error thrown when constructing a date with invalid field values.
public enum DateNewError: Error, Sendable, Hashable {
    /// The day is out of range for the given month.
    /// `max` is the maximum valid day for that month.
    case invalidDay(max: UInt8)

    /// The month does not exist in this calendar system at all.
    /// For example, month 14 in Gregorian.
    case monthNotInCalendar

    /// The month does not exist in this particular year.
    /// For example, a leap month in a non-leap year of the Hebrew calendar.
    case monthNotInYear

    /// The era code is not recognized by the calendar.
    case invalidEra

    /// The year is out of the supported range.
    case invalidYear

    /// The resulting date would be outside the valid `RataDie` range.
    case overflow
}

extension DateNewError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .invalidDay(let max):
            "Invalid day: maximum is \(max)"
        case .monthNotInCalendar:
            "Month does not exist in this calendar"
        case .monthNotInYear:
            "Month does not exist in this year"
        case .invalidEra:
            "Unknown era code"
        case .invalidYear:
            "Year is out of supported range"
        case .overflow:
            "Date would be outside the valid range"
        }
    }
}

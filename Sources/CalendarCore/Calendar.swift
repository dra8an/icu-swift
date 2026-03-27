/// A calendar system that can convert dates to and from `RataDie`.
///
/// This is the core protocol that all calendar implementations conform to.
/// Users typically interact with `Date<C>` rather than calling these methods directly.
///
/// Calendar types should be lightweight — most are zero-size value types
/// (e.g., `Gregorian`, `Buddhist`) that exist purely as type-level markers.
/// Calendars that need runtime data (e.g., `Japanese` with era data) may be larger.
public protocol CalendarProtocol: Sendable {
    /// The internal representation of a date in this calendar.
    associatedtype DateInner: Equatable & Comparable & Sendable

    /// The CLDR calendar identifier (e.g., "gregorian", "hebrew", "japanese").
    static var calendarIdentifier: String { get }

    /// Construct a date from year, month, and day.
    ///
    /// - Parameters:
    ///   - year: The year, specified as either an extended year or era+year.
    ///   - month: The month (number + leap flag).
    ///   - day: The day of the month (1-based).
    /// - Throws: `DateNewError` if any field is out of range.
    func newDate(year: YearInput, month: Month, day: UInt8) throws -> DateInner

    /// Convert a calendar-specific date to its `RataDie` representation.
    func toRataDie(_ date: DateInner) -> RataDie

    /// Convert a `RataDie` to a calendar-specific date.
    ///
    /// The `RataDie` is assumed to be within `RataDie.validRange`.
    func fromRataDie(_ rd: RataDie) -> DateInner

    /// Year information for the given date.
    func yearInfo(_ date: DateInner) -> YearInfo

    /// Month information for the given date.
    func monthInfo(_ date: DateInner) -> MonthInfo

    /// The day of the month (1-based).
    func dayOfMonth(_ date: DateInner) -> UInt8

    /// The day of the year (1-based).
    func dayOfYear(_ date: DateInner) -> UInt16

    /// The number of days in the month containing the given date.
    func daysInMonth(_ date: DateInner) -> UInt8

    /// The number of days in the year containing the given date.
    func daysInYear(_ date: DateInner) -> UInt16

    /// The number of months in the year containing the given date.
    func monthsInYear(_ date: DateInner) -> UInt8

    /// Whether the year containing the given date is a leap year.
    func isInLeapYear(_ date: DateInner) -> Bool
}

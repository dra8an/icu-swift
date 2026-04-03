/// A calendar system that can convert dates to and from `RataDie`.
///
/// This is the core protocol that all calendar implementations conform to.
/// Users typically interact with `Date<C>` rather than calling these methods directly.
///
/// Calendar types should be lightweight — most are zero-size value types
/// (e.g., `Gregorian`, `Buddhist`) that exist purely as type-level markers.
/// Calendars that need runtime data (e.g., `Japanese` with era data,
/// Hindu calendars with a location) may be larger.
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

    // MARK: - Location-Dependent Calendars

    /// The geographic location used for astronomical calculations, if this calendar
    /// is location-dependent (e.g., Hindu calendars that depend on sunrise time).
    ///
    /// Returns `nil` for location-independent calendars (the default).
    var location: Location? { get }

    // MARK: - Non-Bijective Date Mapping

    /// The status of this date on its civil day.
    ///
    /// Most calendars have a 1:1 mapping between civil days and calendar dates.
    /// Hindu lunisolar calendars can have:
    /// - `.repeated`: this tithi also occurred on the previous civil day (adhika tithi)
    /// - `.skipped`: this civil day consumed an additional date; see `alternativeDate`
    func dateStatus(_ date: DateInner) -> DateStatus

    /// An alternative date assigned to the same civil day, if any.
    ///
    /// In Hindu lunisolar calendars, a kshaya (skipped) tithi starts and ends
    /// entirely within one sunrise-to-sunrise period. The civil day has two
    /// Hindu dates: the primary date (from `fromRataDie`) and the alternative
    /// (the kshaya tithi that was consumed during that day).
    ///
    /// Returns `nil` for most calendars and most dates.
    func alternativeDate(_ date: DateInner) -> DateInner?
}

// MARK: - Default Implementations

extension CalendarProtocol {
    /// Default: no location dependency.
    public var location: Location? { nil }

    /// Default: normal 1:1 mapping.
    public func dateStatus(_ date: DateInner) -> DateStatus { .normal }

    /// Default: no alternative date.
    public func alternativeDate(_ date: DateInner) -> DateInner? { nil }
}

/// The status of a calendar date on its civil day.
public enum DateStatus: Sendable {
    /// Normal 1:1 mapping between civil day and calendar date.
    case normal
    /// This date also occurred on the previous civil day (e.g., adhika tithi in Hindu calendar).
    case repeated
    /// This civil day consumed an additional date that was skipped (e.g., kshaya tithi).
    /// Use `alternativeDate` to get the skipped date.
    case skipped
}

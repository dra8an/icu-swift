/// A date in a specific calendar system.
///
/// `Date` is generic over a `CalendarProtocol` conforming type, giving you
/// compile-time type safety:
///
/// ```swift
/// let greg = Date<Gregorian>(...)   // only accepts Gregorian operations
/// let hebrew = Date<Hebrew>(...)    // only accepts Hebrew operations
/// ```
///
/// For runtime-selected calendars, use `Date<AnyCalendar>` (defined in CalendarAll).
///
/// Dates are immutable value types. Operations that change a date return a new `Date`.
public struct Date<C: CalendarProtocol>: Sendable {
    /// The calendar-specific internal representation.
    public let inner: C.DateInner

    /// The calendar instance used for this date.
    public let calendar: C

    /// Creates a date from a pre-computed inner value and calendar.
    ///
    /// This is intended for use by `CalendarProtocol` implementations.
    /// Prefer `try_new` or calendar-specific factory methods instead.
    public init(inner: C.DateInner, calendar: C) {
        self.inner = inner
        self.calendar = calendar
    }

    /// Creates a date from year, month, and day.
    ///
    /// - Parameters:
    ///   - year: The year as extended year or era+year.
    ///   - month: The month.
    ///   - day: The day of the month (1-based).
    ///   - calendar: The calendar instance.
    /// - Throws: `DateNewError` if any field is invalid.
    public init(
        year: YearInput,
        month: Month,
        day: UInt8,
        calendar: C
    ) throws {
        let inner = try calendar.newDate(year: year, month: month, day: day)
        self.inner = inner
        self.calendar = calendar
    }

    // MARK: - Field Accessors

    /// Year information (era-based or cyclic).
    public var year: YearInfo {
        calendar.yearInfo(inner)
    }

    /// The extended year — a single comparable number.
    public var extendedYear: Int32 {
        year.extendedYear
    }

    /// Month information (ordinal, number, leap status, code).
    public var month: MonthInfo {
        calendar.monthInfo(inner)
    }

    /// The day of the month (1-based).
    public var dayOfMonth: UInt8 {
        calendar.dayOfMonth(inner)
    }

    /// The day of the year (1-based).
    public var dayOfYear: UInt16 {
        calendar.dayOfYear(inner)
    }

    /// The day of the week.
    public var weekday: Weekday {
        Weekday.from(rataDie: rataDie)
    }

    // MARK: - Calendar Queries

    /// The number of days in the month containing this date.
    public var daysInMonth: UInt8 {
        calendar.daysInMonth(inner)
    }

    /// The number of days in the year containing this date.
    public var daysInYear: UInt16 {
        calendar.daysInYear(inner)
    }

    /// The number of months in the year containing this date.
    public var monthsInYear: UInt8 {
        calendar.monthsInYear(inner)
    }

    /// Whether the year containing this date is a leap year.
    public var isInLeapYear: Bool {
        calendar.isInLeapYear(inner)
    }

    // MARK: - RataDie Conversion

    /// The `RataDie` (fixed day number) for this date.
    public var rataDie: RataDie {
        calendar.toRataDie(inner)
    }

    /// Creates a date from a `RataDie` value.
    public static func fromRataDie(_ rd: RataDie, calendar: C) -> Date<C> {
        let inner = calendar.fromRataDie(rd)
        return Date(inner: inner, calendar: calendar)
    }

    // MARK: - Calendar Conversion

    /// Converts this date to a different calendar system.
    ///
    /// The conversion goes through `RataDie` — no direct calendar-to-calendar
    /// path is needed.
    public func converting<T: CalendarProtocol>(to targetCalendar: T) -> Date<T> {
        let rd = calendar.toRataDie(inner)
        let targetInner = targetCalendar.fromRataDie(rd)
        return Date<T>(inner: targetInner, calendar: targetCalendar)
    }
}

// MARK: - Equatable

extension Date: Equatable where C.DateInner: Equatable {
    public static func == (lhs: Date<C>, rhs: Date<C>) -> Bool {
        lhs.inner == rhs.inner
    }
}

// MARK: - Comparable

extension Date: Comparable where C.DateInner: Comparable {
    public static func < (lhs: Date<C>, rhs: Date<C>) -> Bool {
        lhs.inner < rhs.inner
    }
}

// MARK: - Hashable

extension Date: Hashable where C.DateInner: Hashable {
    public func hash(into hasher: inout Hasher) {
        inner.hash(into: &hasher)
    }
}

// MARK: - CustomStringConvertible

extension Date: CustomStringConvertible {
    public var description: String {
        let y = year
        let m = month
        let d = dayOfMonth
        return "\(C.calendarIdentifier): \(y.extendedYear)-\(m.code)-\(d)"
    }
}

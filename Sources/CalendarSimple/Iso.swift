// ISO 8601 calendar — the pivot calendar for all inter-calendar conversions.
//
// Identical arithmetic to Gregorian, but uses a single "default" era.
// Extended year = display year (year 0 exists, negative years for BCE).

import CalendarCore

/// The ISO 8601 calendar.
///
/// This calendar is identical to the Gregorian calendar in its arithmetic,
/// but uses a single `default` era instead of `ce`/`bce`. Year 0 exists
/// and corresponds to 1 BCE Gregorian.
///
/// This is the pivot calendar — all inter-calendar conversion goes through
/// ISO RataDie.
public struct Iso: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "iso8601"

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IsoDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return IsoDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: IsoDateInner) -> RataDie {
        GregorianArithmetic.fixedFromGregorian(year: date.year, month: date.month, day: date.day)
    }

    public func fromRataDie(_ rd: RataDie) -> IsoDateInner {
        let (y, m, d) = GregorianArithmetic.gregorianFromFixed(rd)
        return IsoDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: IsoDateInner) -> YearInfo {
        .era(EraYear(
            era: "default",
            year: date.year,
            extendedYear: date.year,
            ambiguity: .unambiguous
        ))
    }

    public func monthInfo(_ date: IsoDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: IsoDateInner) -> UInt8 {
        date.day
    }

    public func dayOfYear(_ date: IsoDateInner) -> UInt16 {
        GregorianArithmetic.daysBeforeMonth(year: date.year, month: date.month) + UInt16(date.day)
    }

    public func daysInMonth(_ date: IsoDateInner) -> UInt8 {
        GregorianArithmetic.daysInMonth(year: date.year, month: date.month)
    }

    public func daysInYear(_ date: IsoDateInner) -> UInt16 {
        GregorianArithmetic.isLeapYear(date.year) ? 366 : 365
    }

    public func monthsInYear(_ date: IsoDateInner) -> UInt8 {
        12
    }

    public func isInLeapYear(_ date: IsoDateInner) -> Bool {
        GregorianArithmetic.isLeapYear(date.year)
    }

    // MARK: - Private Helpers

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y):
            return y
        case .eraYear(let era, let year):
            switch era {
            case "default":
                return year
            default:
                throw DateNewError.invalidEra
            }
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else {
            throw DateNewError.monthNotInCalendar
        }
        guard month.number >= 1, month.number <= 12 else {
            throw DateNewError.monthNotInCalendar
        }
        let maxDay = GregorianArithmetic.daysInMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else {
            throw DateNewError.invalidDay(max: maxDay)
        }
    }
}

// MARK: - IsoDateInner

/// Internal representation of an ISO/Gregorian-family date.
///
/// Stores year as extended year (year 0 = 1 BCE). Used by ISO, Gregorian,
/// Buddhist, and ROC calendars since they all share Gregorian arithmetic.
public struct IsoDateInner: Equatable, Comparable, Hashable, Sendable {
    /// Extended year (year 0 exists, negative = BCE).
    let year: Int32
    /// Month (1-12).
    let month: UInt8
    /// Day of month (1-31).
    let day: UInt8

    public static func < (lhs: IsoDateInner, rhs: IsoDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

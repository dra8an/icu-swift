// Julian calendar — simpler leap year rule, different epoch.
//
// Ported from ICU4X components/calendar/src/cal/julian.rs (Unicode License).

import CalendarCore

/// The proleptic Julian calendar.
///
/// Uses a simpler leap year rule than Gregorian: every year divisible by 4
/// is a leap year, with no century exceptions.
///
/// Important for historical dates before October 15, 1582.
///
/// Uses two eras:
/// - `ce`: extended year > 0
/// - `bce`: extended year ≤ 0, where year 0 = 1 BCE
public struct Julian: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "julian"

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> JulianDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return JulianDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: JulianDateInner) -> RataDie {
        JulianArithmetic.fixedFromJulian(year: date.year, month: date.month, day: date.day)
    }

    public func fromRataDie(_ rd: RataDie) -> JulianDateInner {
        let (y, m, d) = JulianArithmetic.julianFromFixed(rd)
        return JulianDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: JulianDateInner) -> YearInfo {
        if date.year > 0 {
            return .era(EraYear(
                era: "ce",
                year: date.year,
                extendedYear: date.year,
                ambiguity: .centuryRequired
            ))
        } else {
            return .era(EraYear(
                era: "bce",
                year: 1 - date.year,
                extendedYear: date.year,
                ambiguity: .eraAndCenturyRequired
            ))
        }
    }

    public func monthInfo(_ date: JulianDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: JulianDateInner) -> UInt8 {
        date.day
    }

    public func dayOfYear(_ date: JulianDateInner) -> UInt16 {
        JulianArithmetic.daysBeforeMonth(year: date.year, month: date.month) + UInt16(date.day)
    }

    public func daysInMonth(_ date: JulianDateInner) -> UInt8 {
        JulianArithmetic.daysInMonth(year: date.year, month: date.month)
    }

    public func daysInYear(_ date: JulianDateInner) -> UInt16 {
        JulianArithmetic.isLeapYear(date.year) ? 366 : 365
    }

    public func monthsInYear(_ date: JulianDateInner) -> UInt8 {
        12
    }

    public func isInLeapYear(_ date: JulianDateInner) -> Bool {
        JulianArithmetic.isLeapYear(date.year)
    }

    // MARK: - Private Helpers

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y):
            return y
        case .eraYear(let era, let year):
            switch era {
            case "ce", "ad":
                return year
            case "bce", "bc":
                return 1 - year
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
        let maxDay = JulianArithmetic.daysInMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else {
            throw DateNewError.invalidDay(max: maxDay)
        }
    }
}

// MARK: - JulianDateInner

/// Internal representation of a Julian calendar date.
public struct JulianDateInner: Equatable, Comparable, Hashable, Sendable {
    /// Extended year (year 0 exists, negative = BCE).
    let year: Int32
    /// Month (1-12).
    let month: UInt8
    /// Day of month (1-31).
    let day: UInt8

    public static func < (lhs: JulianDateInner, rhs: JulianDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

// Persian (Solar Hijri) calendar.
//
// Algorithms from "Calendrical Calculations" by Reingold & Dershowitz (4th ed., 2018),
// ported from ICU4X calendrical_calculations/src/persian.rs (Apache-2.0).
// Uses the fast 33-year rule with NON_LEAP_CORRECTION table.

import CalendarCore
import CalendarSimple

/// The Persian (Solar Hijri / Jalali) calendar.
///
/// Months 1-6 have 31 days, months 7-11 have 30 days, month 12 has 29 (30 in leap years).
/// Leap years are determined by the 33-year rule with correction table.
/// Epoch: March 19, 622 CE (Julian) = Farvardin 1, 1 AP.
///
/// Single era: `ap` (Anno Persico).
public struct Persian: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "persian"

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> PersianDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return PersianDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: PersianDateInner) -> RataDie {
        PersianArithmetic.fixedFromPersian(year: date.year, month: date.month, day: date.day)
    }

    public func fromRataDie(_ rd: RataDie) -> PersianDateInner {
        let (y, m, d) = PersianArithmetic.persianFromFixed(rd)
        return PersianDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: PersianDateInner) -> YearInfo {
        .era(EraYear(
            era: "ap",
            year: date.year,
            extendedYear: date.year,
            ambiguity: .centuryRequired
        ))
    }

    public func monthInfo(_ date: PersianDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: PersianDateInner) -> UInt8 {
        date.day
    }

    public func dayOfYear(_ date: PersianDateInner) -> UInt16 {
        PersianArithmetic.daysBeforeMonth(date.month) + UInt16(date.day)
    }

    public func daysInMonth(_ date: PersianDateInner) -> UInt8 {
        PersianArithmetic.daysInMonth(year: date.year, month: date.month)
    }

    public func daysInYear(_ date: PersianDateInner) -> UInt16 {
        PersianArithmetic.isLeapYear(date.year) ? 366 : 365
    }

    public func monthsInYear(_ date: PersianDateInner) -> UInt8 {
        12
    }

    public func isInLeapYear(_ date: PersianDateInner) -> Bool {
        PersianArithmetic.isLeapYear(date.year)
    }

    // MARK: - Private

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(let era, let year):
            guard era == "ap" else { throw DateNewError.invalidEra }
            return year
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else { throw DateNewError.monthNotInCalendar }
        guard month.number >= 1, month.number <= 12 else { throw DateNewError.monthNotInCalendar }
        let maxDay = PersianArithmetic.daysInMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }
    }
}

// MARK: - PersianDateInner

public struct PersianDateInner: Equatable, Comparable, Hashable, Sendable {
    let year: Int32
    let month: UInt8  // 1-12
    let day: UInt8

    public static func < (lhs: PersianDateInner, rhs: PersianDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

// MARK: - PersianArithmetic

enum PersianArithmetic {

    /// Persian epoch: March 19, 622 CE (Julian).
    static let epoch: RataDie = JulianArithmetic.fixedFromJulian(year: 622, month: 3, day: 19)

    /// Years that violate the 33-year leap rule. The year following each is the actual leap year.
    private static let nonLeapCorrection: [Int32] = [
        1502, 1601, 1634, 1667, 1700, 1733, 1766, 1799, 1832, 1865, 1898, 1931, 1964, 1997, 2030, 2059,
        2063, 2096, 2129, 2158, 2162, 2191, 2195, 2224, 2228, 2257, 2261, 2290, 2294, 2323, 2327, 2356,
        2360, 2389, 2393, 2422, 2426, 2455, 2459, 2488, 2492, 2521, 2525, 2554, 2558, 2587, 2591, 2620,
        2624, 2653, 2657, 2686, 2690, 2719, 2723, 2748, 2752, 2756, 2781, 2785, 2789, 2818, 2822, 2847,
        2851, 2855, 2880, 2884, 2888, 2913, 2917, 2921, 2946, 2950, 2954, 2979, 2983, 2987,
    ]

    private static let minNonLeapCorrection: Int32 = 1502

    /// Whether a Persian year is a leap year (33-year rule with corrections).
    static func isLeapYear(_ year: Int32) -> Bool {
        if year >= minNonLeapCorrection && nonLeapCorrection.contains(year) {
            return false
        } else if year > minNonLeapCorrection && nonLeapCorrection.contains(year - 1) {
            return true
        } else {
            var r = (25 * Int64(year) + 11) % 33
            if r < 0 { r += 33 }
            return r < 8
        }
    }

    /// Days in a Persian month.
    static func daysInMonth(year: Int32, month: UInt8) -> UInt8 {
        if month <= 6 {
            return 31
        } else if month <= 11 {
            return 30
        } else {
            return isLeapYear(year) ? 30 : 29
        }
    }

    /// Days before the given month starts (0-indexed).
    static func daysBeforeMonth(_ month: UInt8) -> UInt16 {
        if month <= 7 {
            return 31 * UInt16(month - 1)
        } else {
            return 30 * UInt16(month - 1) + 6
        }
    }

    /// Convert Persian (year, month, day) to RataDie using the fast 33-year rule.
    static func fixedFromPersian(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        let y = Int64(year)
        var newYear = epoch.dayNumber - 1
            + 365 * (y - 1)
            + floorDiv(8 * y + 21, 33)

        if year > minNonLeapCorrection && nonLeapCorrection.contains(year - 1) {
            newYear -= 1
        }

        let monthDays: Int64 = month <= 7
            ? 31 * Int64(month - 1)
            : 30 * Int64(month - 1) + 6

        return RataDie(newYear - 1 + monthDays + Int64(day))
    }

    /// Convert RataDie to Persian (year, month, day).
    static func persianFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        var year = yearFromFixed(date)

        var dayOfYear = 1 + (date.dayNumber - fixedFromPersian(year: year, month: 1, day: 1).dayNumber)

        // Handle correction table edge case
        if dayOfYear == 366
            && year >= minNonLeapCorrection
            && nonLeapCorrection.contains(year) {
            year += 1
            dayOfYear = 1
        }

        let month: UInt8
        if dayOfYear <= 186 {
            month = UInt8(ceilDiv(dayOfYear, 31))
        } else {
            month = UInt8(ceilDiv(dayOfYear - 6, 30))
        }

        let day = UInt8(date.dayNumber - fixedFromPersian(year: year, month: month, day: 1).dayNumber + 1)

        return (year, month, day)
    }

    private static func yearFromFixed(_ date: RataDie) -> Int32 {
        let daysSinceEpoch = date.dayNumber - epoch.dayNumber + 1
        let year = 1 + floorDiv(33 * daysSinceEpoch + 3, 12053)
        return Int32(year)
    }

    private static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 {
        if (a >= 0) == (b > 0) {
            return a / b
        } else {
            return (a - b + 1) / b
        }
    }

    private static func ceilDiv(_ a: Int64, _ b: Int64) -> Int64 {
        (a + b - 1) / b
    }
}

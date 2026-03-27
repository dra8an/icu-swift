// Julian calendar arithmetic.
//
// Algorithms from "Calendrical Calculations" by Reingold & Dershowitz (4th ed., 2018),
// ported from ICU4X calendrical_calculations/src/julian.rs (Apache-2.0).

import CalendarCore

/// Arithmetic for the Julian calendar.
///
/// The Julian calendar uses a simpler leap year rule than the Gregorian calendar:
/// every year divisible by 4 is a leap year, with no century exceptions.
public enum JulianArithmetic {

    // MARK: - Constants

    /// The Julian epoch: January 1, year 1 Julian = December 30, year 0 Gregorian = R.D. -1.
    public static let epoch: RataDie = GregorianArithmetic.fixedFromGregorian(year: 0, month: 12, day: 30)

    private static let daysInYear: Int64 = 365
    private static let daysIn4YearCycle: Int64 = 365 * 4 + 1  // 1461

    // MARK: - Leap Year

    /// Whether `year` is a Julian leap year (every 4th year).
    public static func isLeapYear(_ year: Int32) -> Bool {
        year % 4 == 0
    }

    // MARK: - Days in Month

    /// The number of days in the given month of the given Julian year.
    public static func daysInMonth(year: Int32, month: UInt8) -> UInt8 {
        if month == 2 {
            return isLeapYear(year) ? 29 : 28
        } else {
            return 30 | (month ^ (month >> 3))
        }
    }

    // MARK: - Days Before Month

    /// The number of days in this year before the given month starts.
    public static func daysBeforeMonth(year: Int32, month: UInt8) -> UInt16 {
        if month < 3 {
            return month == 1 ? 0 : 31
        } else {
            let leap: UInt16 = isLeapYear(year) ? 1 : 0
            return 31 + 28 + leap + UInt16((979 * UInt32(month) - 2919) >> 5)
        }
    }

    // MARK: - Day Before Year

    /// The RataDie of the day before January 1 of `year` (Julian).
    public static func dayBeforeYear(_ year: Int32) -> RataDie {
        let prevYear = Int64(year) - 1
        var fixed = daysInYear * prevYear

        // Shift to ensure positive division for leap year count.
        let yearShift: Int64 = 4 * ((Int64(Int32.max) / 4) + 1)
        fixed += (prevYear + yearShift) / 4 - yearShift / 4

        return epoch + (fixed - 1)
    }

    // MARK: - Fixed from Julian

    /// Converts a Julian (year, month, day) to a `RataDie`.
    public static func fixedFromJulian(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        dayBeforeYear(year) + Int64(daysBeforeMonth(year: year, month: month)) + Int64(day)
    }

    // MARK: - Year from Fixed

    /// Determines the Julian year containing the given `RataDie`.
    public static func yearFromFixed(_ date: RataDie) -> Int32 {
        let d = date.dayNumber - epoch.dayNumber

        // Euclidean division by 4-year cycle
        var n4 = d / daysIn4YearCycle
        var rem4 = d % daysIn4YearCycle
        if rem4 < 0 {
            n4 -= 1
            rem4 += daysIn4YearCycle
        }

        let n1 = rem4 / daysInYear

        let year = 4 * n4 + n1 + (n1 != 4 ? 1 : 0)

        return Int32(year)
    }

    // MARK: - Year Day

    /// Converts a 1-based day-of-year to (month, day) for a Julian year.
    public static func yearDay(year: Int32, dayOfYear: UInt16) -> (month: UInt8, day: UInt8) {
        let leapOffset: UInt16 = isLeapYear(year) ? 1 : 0
        let correction: Int32
        if dayOfYear < 31 + 28 + leapOffset {
            correction = -1
        } else {
            correction = isLeapYear(year) ? 0 : 1
        }
        let month = UInt8((12 * (Int32(dayOfYear) + correction) + 373) / 367)
        let day = UInt8(dayOfYear - daysBeforeMonth(year: year, month: month))
        return (month, day)
    }

    // MARK: - Julian from Fixed

    /// Converts a `RataDie` to Julian (year, month, day).
    public static func julianFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        let year = yearFromFixed(date)
        let dayOfYear = date.dayNumber - dayBeforeYear(year).dayNumber
        let (month, day) = yearDay(year: year, dayOfYear: UInt16(dayOfYear))
        return (year, month, day)
    }
}

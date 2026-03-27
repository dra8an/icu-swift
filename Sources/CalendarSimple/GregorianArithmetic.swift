// Gregorian calendar arithmetic.
//
// Algorithms from "Calendrical Calculations" by Reingold & Dershowitz (4th ed., 2018),
// ported from ICU4X calendrical_calculations/src/gregorian.rs (Apache-2.0).

import CalendarCore

/// Shared arithmetic for all Gregorian-based calendars (ISO, Gregorian, Buddhist, ROC).
public enum GregorianArithmetic {

    // MARK: - Constants

    /// The Gregorian epoch: R.D. 1 = January 1, year 1.
    public static let epoch = RataDie(1)

    private static let daysInYear: Int64 = 365
    private static let daysIn4YearCycle: Int64 = 365 * 4 + 1          // 1461
    private static let daysIn100YearCycle: Int64 = 25 * 1461 - 1       // 36524
    public static let daysIn400YearCycle: Int64 = 4 * 36524 + 1               // 146097

    // MARK: - Leap Year

    /// Whether `year` is a Gregorian leap year.
    ///
    /// Uses the Neri-Schneider branch-free formulation:
    /// divisible by 4, except centuries not divisible by 400.
    public static func isLeapYear(_ year: Int32) -> Bool {
        if year % 25 != 0 {
            return year % 4 == 0
        } else {
            return year % 16 == 0
        }
    }

    // MARK: - Days in Month

    /// The number of days in the given month of the given year.
    public static func daysInMonth(year: Int32, month: UInt8) -> UInt8 {
        if month == 2 {
            return isLeapYear(year) ? 29 : 28
        } else {
            // Bit trick: yields 31 for months 1,3,5,7,8,10,12 and 30 for 4,6,9,11.
            return 30 | (month ^ (month >> 3))
        }
    }

    // MARK: - Days Before Month

    /// The number of days in this year before the given month starts (0-indexed).
    ///
    /// Inspired by Neri-Schneider.
    public static func daysBeforeMonth(year: Int32, month: UInt8) -> UInt16 {
        if month < 3 {
            return month == 1 ? 0 : 31
        } else {
            let leap: UInt16 = isLeapYear(year) ? 1 : 0
            // Formula from ICU4X: 31 + 28 + leap + ((979 * month - 2919) >> 5)
            return 31 + 28 + leap + UInt16((979 * UInt32(month) - 2919) >> 5)
        }
    }

    // MARK: - Day Before Year

    /// The RataDie of the day before January 1 of `year`.
    public static func dayBeforeYear(_ year: Int32) -> RataDie {
        let prevYear = Int64(year) - 1
        var fixed = daysInYear * prevYear

        // Leap year adjustment. We shift prevYear positive to avoid
        // negative-division issues. The shift is divisible by 400, so it
        // distributes correctly over the leap year formula.
        let yearShift: Int64 = 400 * ((Int64(Int32.max) / 400) + 1)
        let shifted = prevYear + yearShift
        let shiftCorrection = yearShift / 4 - yearShift / 100 + yearShift / 400
        fixed += shifted / 4 - shifted / 100 + shifted / 400 - shiftCorrection

        return epoch + (fixed - 1)
    }

    // MARK: - Fixed from Gregorian

    /// Converts a Gregorian (year, month, day) to a `RataDie`.
    public static func fixedFromGregorian(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        dayBeforeYear(year) + Int64(daysBeforeMonth(year: year, month: month)) + Int64(day)
    }

    // MARK: - Year from Fixed

    /// Determines the Gregorian year containing the given `RataDie`.
    public static func yearFromFixed(_ date: RataDie) -> Int32 {
        let d = date - epoch

        let n400 = d.quotientAndRemainder(dividingBy: daysIn400YearCycle)
        let rem400 = n400.remainder
        let q400 = n400.quotient

        let n100 = rem400 / daysIn100YearCycle
        let rem100 = rem400 % daysIn100YearCycle

        let n4 = rem100 / daysIn4YearCycle
        let rem4 = rem100 % daysIn4YearCycle

        let n1 = rem4 / daysInYear

        let year = 400 * q400 + 100 * n100 + 4 * n4 + n1
            + ((n100 != 4 && n1 != 4) ? 1 : 0)

        return Int32(year)
    }

    // MARK: - Year Day

    /// Converts a 1-based day-of-year to (month, day).
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

    // MARK: - Gregorian from Fixed

    /// Converts a `RataDie` to Gregorian (year, month, day).
    public static func gregorianFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        let year = yearFromFixed(date)
        let dayOfYear = date - dayBeforeYear(year)
        let (month, day) = yearDay(year: year, dayOfYear: UInt16(dayOfYear))
        return (year, month, day)
    }
}

// MARK: - Int64 Euclidean Division Helper

private extension Int64 {
    /// Returns (quotient, remainder) using Euclidean division (remainder always non-negative).
    func quotientAndRemainder(dividingBy divisor: Int64) -> (quotient: Int64, remainder: Int64) {
        var quotient = self / divisor
        var remainder = self % divisor
        if remainder < 0 {
            remainder += divisor
            quotient -= 1
        }
        return (quotient, remainder)
    }
}

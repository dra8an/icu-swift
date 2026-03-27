// Hebrew calendar arithmetic.
//
// Algorithms from "Calendrical Calculations" by Reingold & Dershowitz (4th ed., 2018),
// ported from ICU4X calendrical_calculations/src/hebrew.rs (Apache-2.0).
//
// Uses "book" (biblical) month numbering internally, converted to civil ordering
// (Tishrei=1) for the public API.

import CalendarCore
import CalendarSimple

/// Low-level arithmetic for the Hebrew calendar.
enum HebrewArithmetic {

    // MARK: - Constants

    /// Hebrew epoch: Tishrei 1, year 1 AM.
    /// Equals the fixed date of October 7, -3761 (Julian book year).
    /// R.D. -1373427
    static let epoch: RataDie = {
        // Julian book year -3761, month 10 (October), day 7.
        // Book years: no year 0, so -3761 book = -3762 proleptic.
        let julianYear: Int32 = -3762  // proleptic Julian year (book -3761 → -3761+1 = -3760? No.)
        // Actually: Reingold uses "book" years where negative years have no year 0.
        // Book year -3761 → proleptic year -3761 + 1 = -3760 for negative.
        // fixed_from_julian_book_version(-3761, 10, 7)
        // For book_year < 0: proleptic = book_year + 1 = -3760
        return JulianArithmetic.fixedFromJulian(year: -3760, month: 10, day: 7)
    }()

    // Biblical month constants
    static let NISAN: UInt8 = 1
    static let IYYAR: UInt8 = 2
    static let SIVAN: UInt8 = 3
    static let TAMMUZ: UInt8 = 4
    static let AV: UInt8 = 5
    static let ELUL: UInt8 = 6
    static let TISHRI: UInt8 = 7
    static let MARHESHVAN: UInt8 = 8
    static let KISLEV: UInt8 = 9
    static let TEVET: UInt8 = 10
    static let SHEVAT: UInt8 = 11
    static let ADAR: UInt8 = 12
    static let ADARII: UInt8 = 13

    // MARK: - Leap Year

    /// Whether a Hebrew year is a leap year (13 months instead of 12).
    /// Leap years occur at positions 3, 6, 8, 11, 14, 17, 19 in the 19-year Metonic cycle.
    static func isLeapYear(_ year: Int32) -> Bool {
        var r = (7 * Int64(year) + 1) % 19
        if r < 0 { r += 19 }
        return r < 7
    }

    /// Last biblical month of the year (12 or 13).
    static func lastMonthOfYear(_ year: Int32) -> UInt8 {
        isLeapYear(year) ? ADARII : ADAR
    }

    // MARK: - Elapsed Days

    /// Days elapsed from the Sunday noon before the Hebrew epoch to the molad of Tishrei.
    static func calendarElapsedDays(_ year: Int32) -> Int32 {
        let monthsElapsed = Int64(
            Double((235 * Int64(year) - 234)) / 19.0
        )  // floor division
        let partsElapsed: Int64 = 12084 + 13753 * monthsElapsed
        let days: Int64 = 29 * monthsElapsed + Int64(Double(partsElapsed) / 25920.0)

        if (3 * (days + 1)).euclideanRemainder(7) < 3 {
            return Int32(days + 1)
        } else {
            return Int32(days)
        }
    }

    /// Correction to keep year lengths in valid range (353-355 or 383-385).
    static func yearLengthCorrection(_ year: Int32) -> UInt8 {
        let ny0 = calendarElapsedDays(year - 1)
        let ny1 = calendarElapsedDays(year)
        let ny2 = calendarElapsedDays(year + 1)

        if (ny2 - ny1) == 356 {
            return 2
        } else if (ny1 - ny0) == 382 {
            return 1
        } else {
            return 0
        }
    }

    // MARK: - New Year

    /// Fixed date of Tishrei 1 (Hebrew New Year) for the given year.
    static func newYear(_ year: Int32) -> RataDie {
        RataDie(
            epoch.dayNumber
            + Int64(calendarElapsedDays(year))
            + Int64(yearLengthCorrection(year))
        )
    }

    // MARK: - Year Length

    /// Total days in the Hebrew year.
    static func daysInYear(_ year: Int32) -> UInt16 {
        UInt16(newYear(year + 1).dayNumber - newYear(year).dayNumber)
    }

    /// Whether Marheshvan has 30 days (complete year).
    static func isLongMarheshvan(_ year: Int32) -> Bool {
        let len = daysInYear(year)
        return len == 355 || len == 385
    }

    /// Whether Kislev has 29 days (deficient year).
    static func isShortKislev(_ year: Int32) -> Bool {
        let len = daysInYear(year)
        return len == 353 || len == 383
    }

    // MARK: - Month Length

    /// Last day (= number of days) of a biblical month in the given year.
    static func lastDayOfMonth(_ year: Int32, month: UInt8) -> UInt8 {
        switch month {
        case IYYAR, TAMMUZ, ELUL, TEVET, ADARII:
            return 29
        case ADAR:
            return isLeapYear(year) ? 30 : 29
        case MARHESHVAN:
            return isLongMarheshvan(year) ? 30 : 29
        case KISLEV:
            return isShortKislev(year) ? 29 : 30
        default:
            // NISAN, SIVAN, AV, TISHRI, SHEVAT
            return 30
        }
    }

    // MARK: - Fixed ↔ Hebrew Conversion

    /// Convert a biblical Hebrew date to a fixed day number.
    static func fixedFromHebrew(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        var totalDays = newYear(year) + Int64(day) - 1

        if month < TISHRI {
            // Add days for Tishri..last month, then Nisan..month-1
            for m in TISHRI...lastMonthOfYear(year) {
                totalDays = totalDays + Int64(lastDayOfMonth(year, month: m))
            }
            for m in NISAN..<month {
                totalDays = totalDays + Int64(lastDayOfMonth(year, month: m))
            }
        } else {
            // Add days for months Tishri..month-1
            for m in TISHRI..<month {
                totalDays = totalDays + Int64(lastDayOfMonth(year, month: m))
            }
        }

        return totalDays
    }

    /// Convert a fixed day number to a biblical Hebrew date.
    static func hebrewFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        // Approximate year using average Hebrew year length ≈ 365.2468
        let approx = Int32(
            1 + Int64(Double(date.dayNumber - epoch.dayNumber) / (35975351.0 / 98496.0))
        )

        // Search forward for exact year
        var year = approx - 1
        while newYear(year + 1) <= date {
            year += 1
        }

        // Determine starting month for search
        let nisanFirst = fixedFromHebrew(year: year, month: NISAN, day: 1)
        let start: UInt8 = date < nisanFirst ? TISHRI : NISAN

        // Search forward for exact month
        var month = start
        while true {
            let lastDay = fixedFromHebrew(year: year, month: month,
                                          day: lastDayOfMonth(year, month: month))
            if date <= lastDay { break }
            month += 1
        }

        // Calculate day
        let day = UInt8(date.dayNumber - fixedFromHebrew(year: year, month: month, day: 1).dayNumber + 1)

        return (year, month, day)
    }

    // MARK: - Civil ↔ Biblical Month Conversion

    /// Convert biblical month to civil month (Tishrei=1).
    static func biblicalToCivil(year: Int32, biblicalMonth: UInt8) -> UInt8 {
        var civil = (biblicalMonth + 6) % 12
        if civil == 0 { civil = 12 }
        if isLeapYear(year) && biblicalMonth < TISHRI {
            civil += 1
        }
        return civil
    }

    /// Convert civil month (Tishrei=1) to biblical month.
    static func civilToBiblical(year: Int32, civilMonth: UInt8) -> UInt8 {
        if civilMonth <= 6 {
            // Civil months 1-6 = biblical months 7-12 (Tishrei-Adar)
            return civilMonth + 6
        } else {
            // Civil months 7+ = biblical months 1-6 (Nisan-Elul)
            var biblical = civilMonth - 6
            if isLeapYear(year) {
                biblical -= 1
            }
            if biblical == 0 {
                // Special case: Adar II in leap year
                biblical = 13
            }
            return biblical
        }
    }

    /// Number of months in the year (12 or 13).
    static func monthsInYear(_ year: Int32) -> UInt8 {
        isLeapYear(year) ? 13 : 12
    }

    /// Days in a civil-ordered month (ordinal 1 = Tishrei).
    static func daysInCivilMonth(year: Int32, civilMonth: UInt8) -> UInt8 {
        let biblical = civilToBiblical(year: year, civilMonth: civilMonth)
        return lastDayOfMonth(year, month: biblical)
    }

    /// Days preceding a civil-ordered month (for day-of-year calculation).
    static func daysPrecedingCivilMonth(year: Int32, civilMonth: UInt8) -> UInt16 {
        var total: UInt16 = 0
        for m: UInt8 in 1..<civilMonth {
            total += UInt16(daysInCivilMonth(year: year, civilMonth: m))
        }
        return total
    }
}

// MARK: - Helper

private extension Int64 {
    func euclideanRemainder(_ divisor: Int64) -> Int64 {
        var r = self % divisor
        if r < 0 { r += divisor }
        return r
    }
}

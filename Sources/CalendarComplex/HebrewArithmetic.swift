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
public enum HebrewArithmetic {

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
    @usableFromInline static let NISAN: UInt8 = 1
    @usableFromInline static let IYYAR: UInt8 = 2
    @usableFromInline static let SIVAN: UInt8 = 3
    @usableFromInline static let TAMMUZ: UInt8 = 4
    @usableFromInline static let AV: UInt8 = 5
    @usableFromInline static let ELUL: UInt8 = 6
    @usableFromInline static let TISHRI: UInt8 = 7
    @usableFromInline static let MARHESHVAN: UInt8 = 8
    @usableFromInline static let KISLEV: UInt8 = 9
    @usableFromInline static let TEVET: UInt8 = 10
    @usableFromInline static let SHEVAT: UInt8 = 11
    @usableFromInline static let ADAR: UInt8 = 12
    @usableFromInline static let ADARII: UInt8 = 13

    @usableFromInline static let epochDayNumber: Int64 = epoch.dayNumber

    // MARK: - Leap Year

    /// Whether a Hebrew year is a leap year (13 months instead of 12).
    /// Leap years occur at positions 3, 6, 8, 11, 14, 17, 19 in the 19-year Metonic cycle.
    @inlinable
    public static func isLeapYear(_ year: Int32) -> Bool {
        var r = (7 &* Int64(year) &+ 1) % 19
        if r < 0 { r += 19 }
        return r < 7
    }

    /// Last biblical month of the year (12 or 13).
    @inlinable
    static func lastMonthOfYear(_ year: Int32) -> UInt8 {
        isLeapYear(year) ? ADARII : ADAR
    }

    // MARK: - Elapsed Days

    /// Days elapsed from the Sunday noon before the Hebrew epoch to the molad of Tishrei.
    ///
    /// Uses integer arithmetic. Returns `Int64` because `days` scales as
    /// ≈ 365 × year and exceeds Int32 at year ≈ ±5.88 M (corresponding to
    /// RD ≈ ±2.15 × 10^9). Callers (`newYear`, `YearData`) already widen
    /// to Int64 in their combine paths, so there's no narrowing penalty.
    @inlinable
    static func calendarElapsedDays(_ year: Int32) -> Int64 {
        let monthsElapsed: Int64 = (235 &* Int64(year) &- 234) / 19
        let partsElapsed: Int64 = 12084 &+ 13753 &* monthsElapsed
        let days: Int64 = 29 &* monthsElapsed &+ partsElapsed / 25920

        if (3 &* (days &+ 1)).euclideanRemainder(7) < 3 {
            return days &+ 1
        } else {
            return days
        }
    }

    /// Correction to keep year lengths in valid range (353-355 or 383-385).
    @inlinable
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
    @inlinable
    public static func newYear(_ year: Int32) -> RataDie {
        RataDie(
            epochDayNumber
            &+ Int64(calendarElapsedDays(year))
            &+ Int64(yearLengthCorrection(year))
        )
    }

    // MARK: - Year Data (computed once per call)

    /// Year-level precomputed metadata.
    ///
    /// Computing this once per `fromRataDie` / `toRataDie` call avoids the redundant
    /// `newYear` / `calendarElapsedDays` invocations that the naive implementation
    /// would incur inside month-walk loops.
    @usableFromInline
    struct YearData {
        @usableFromInline let year: Int32
        @usableFromInline let newYear: RataDie
        @usableFromInline let yearLen: Int32       // days in year (353..385)
        @usableFromInline let isLeap: Bool
        @usableFromInline let longMarheshvan: Bool // Marheshvan 30d
        @usableFromInline let shortKislev: Bool    // Kislev 29d

        @inlinable
        init(year: Int32) {
            self.year = year
            let ny0 = HebrewArithmetic.calendarElapsedDays(year - 1)
            let ny1 = HebrewArithmetic.calendarElapsedDays(year)
            let ny2 = HebrewArithmetic.calendarElapsedDays(year + 1)
            // yearLengthCorrection for `year` uses (ny0, ny1, ny2).
            let corr0: UInt8
            if (ny2 - ny1) == 356 { corr0 = 2 }
            else if (ny1 - ny0) == 382 { corr0 = 1 }
            else { corr0 = 0 }
            let nyThis = HebrewArithmetic.epochDayNumber &+ Int64(ny1) &+ Int64(corr0)
            self.newYear = RataDie(nyThis)
            // For year+1 correction we need ny0'=ny1, ny1'=ny2, ny2'=ced(year+2).
            let ny3 = HebrewArithmetic.calendarElapsedDays(year + 2)
            let corr1: UInt8
            if (ny3 - ny2) == 356 { corr1 = 2 }
            else if (ny2 - ny1) == 382 { corr1 = 1 }
            else { corr1 = 0 }
            let nyNext = HebrewArithmetic.epochDayNumber &+ Int64(ny2) &+ Int64(corr1)
            self.yearLen = Int32(nyNext &- nyThis)
            self.isLeap = HebrewArithmetic.isLeapYear(year)
            self.longMarheshvan = self.yearLen == 355 || self.yearLen == 385
            self.shortKislev = self.yearLen == 353 || self.yearLen == 383
        }

        /// Length of a biblical month within this year.
        @inlinable
        func lastDayOfMonth(_ month: UInt8) -> UInt8 {
            switch month {
            case HebrewArithmetic.IYYAR, HebrewArithmetic.TAMMUZ,
                 HebrewArithmetic.ELUL, HebrewArithmetic.TEVET,
                 HebrewArithmetic.ADARII:
                return 29
            case HebrewArithmetic.ADAR:
                return isLeap ? 30 : 29
            case HebrewArithmetic.MARHESHVAN:
                return longMarheshvan ? 30 : 29
            case HebrewArithmetic.KISLEV:
                return shortKislev ? 29 : 30
            default:
                // NISAN, SIVAN, AV, TISHRI, SHEVAT
                return 30
            }
        }

        /// Last biblical month of this year (12 or 13).
        @inlinable
        var lastMonthOfYear: UInt8 {
            isLeap ? HebrewArithmetic.ADARII : HebrewArithmetic.ADAR
        }
    }

    // MARK: - Year Length

    /// Total days in the Hebrew year.
    @inlinable
    public static func daysInYear(_ year: Int32) -> UInt16 {
        UInt16(YearData(year: year).yearLen)
    }

    /// Whether Marheshvan has 30 days (complete year).
    @inlinable
    public static func isLongMarheshvan(_ year: Int32) -> Bool {
        YearData(year: year).longMarheshvan
    }

    /// Whether Kislev has 29 days (deficient year).
    @inlinable
    public static func isShortKislev(_ year: Int32) -> Bool {
        YearData(year: year).shortKislev
    }

    // MARK: - Month Length

    /// Last day (= number of days) of a biblical month in the given year.
    @inlinable
    public static func lastDayOfMonth(_ year: Int32, month: UInt8) -> UInt8 {
        YearData(year: year).lastDayOfMonth(month)
    }

    // MARK: - Fixed ↔ Hebrew Conversion

    /// Convert a biblical Hebrew date to a fixed day number.
    @inlinable
    public static func fixedFromHebrew(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        let yd = YearData(year: year)
        return fixedFromHebrew(yearData: yd, month: month, day: day)
    }

    /// Convert a biblical Hebrew date to a fixed day number, given precomputed year data.
    @inlinable
    static func fixedFromHebrew(yearData yd: YearData, month: UInt8, day: UInt8) -> RataDie {
        var totalDays: Int64 = yd.newYear.dayNumber &+ Int64(day) &- 1

        if month < TISHRI {
            // Add Tishri..lastMonth, then Nisan..(month-1)
            let last = yd.lastMonthOfYear
            var m: UInt8 = TISHRI
            while m <= last {
                totalDays &+= Int64(yd.lastDayOfMonth(m))
                m &+= 1
            }
            m = NISAN
            while m < month {
                totalDays &+= Int64(yd.lastDayOfMonth(m))
                m &+= 1
            }
        } else {
            var m: UInt8 = TISHRI
            while m < month {
                totalDays &+= Int64(yd.lastDayOfMonth(m))
                m &+= 1
            }
        }

        return RataDie(totalDays)
    }

    /// Floor division of Int64: always rounds toward negative infinity
    /// (Swift's `/` truncates toward zero, which skews one off for negative
    /// numerators). Used by the Hebrew year approximation.
    @inlinable
    static func floorDiv(_ a: Int64, _ b: Int64) -> Int64 {
        if (a >= 0) == (b > 0) {
            return a / b
        } else {
            return (a &- b &+ 1) / b
        }
    }

    /// Convert a fixed day number to a biblical Hebrew date.
    @inlinable
    public static func hebrewFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        // Approximate year using average Hebrew year length ≈ 365.2468.
        // Integer-math form of: date.dayNumber - epoch.dayNumber over 35975351/98496.
        //
        // Uses floor division so the approximation always errs LOW, never high.
        // The linear `while newYear(year + 1) <= date` loop only walks forward,
        // so a high-skewed `approx` at extreme negative RDs would leave `year`
        // pinned past the true value and later produce a negative day-of-year
        // remainder. Floor-div keeps `approx - 1` safely at or below the true
        // year for all RDs in the Int32 year range.
        let dayDelta = Int64(date.dayNumber &- epochDayNumber)
        let approx = Int32(1 &+ floorDiv(dayDelta &* 98496, 35975351))

        // Search forward for the exact year. Typically 0-2 iterations.
        var year = approx - 1
        while newYear(year + 1) <= date {
            year += 1
        }

        // Now compute year-level data once and walk months cheaply.
        let yd = YearData(year: year)

        // Day of year, 0-indexed (0 = Tishri 1).
        var rem = Int(date.dayNumber &- yd.newYear.dayNumber)

        // Civil order of biblical months:
        //   common year: 7, 8, 9, 10, 11, 12, 1, 2, 3, 4, 5, 6
        //   leap year:   7, 8, 9, 10, 11, 12, 13, 1, 2, 3, 4, 5, 6

        // First half: Tishri (7), Marheshvan (8), Kislev (9), Tevet (10), Shevat (11), Adar (12),
        // and AdarII (13) if leap.
        var m: UInt8 = TISHRI
        let last = yd.lastMonthOfYear
        while m <= last {
            let len = Int(yd.lastDayOfMonth(m))
            if rem < len {
                return (year, m, UInt8(rem + 1))
            }
            rem -= len
            m &+= 1
        }

        // Second half: Nisan (1), Iyyar (2), Sivan (3), Tammuz (4), Av (5), Elul (6).
        m = NISAN
        while m < TISHRI {
            let len = Int(yd.lastDayOfMonth(m))
            if rem < len {
                return (year, m, UInt8(rem + 1))
            }
            rem -= len
            m &+= 1
        }

        // Unreachable for a valid in-range date.
        return (year, ELUL, UInt8(rem + 1))
    }

    // MARK: - Civil ↔ Biblical Month Conversion

    /// Convert biblical month to civil month (Tishrei=1).
    @inlinable
    public static func biblicalToCivil(year: Int32, biblicalMonth: UInt8) -> UInt8 {
        var civil = (biblicalMonth + 6) % 12
        if civil == 0 { civil = 12 }
        if isLeapYear(year) && biblicalMonth < TISHRI {
            civil += 1
        }
        return civil
    }

    /// Convert civil month (Tishrei=1) to biblical month.
    @inlinable
    public static func civilToBiblical(year: Int32, civilMonth: UInt8) -> UInt8 {
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
    @inlinable
    public static func monthsInYear(_ year: Int32) -> UInt8 {
        isLeapYear(year) ? 13 : 12
    }

    /// Days in a civil-ordered month (ordinal 1 = Tishrei).
    @inlinable
    public static func daysInCivilMonth(year: Int32, civilMonth: UInt8) -> UInt8 {
        let biblical = civilToBiblical(year: year, civilMonth: civilMonth)
        return lastDayOfMonth(year, month: biblical)
    }

    /// Days preceding a civil-ordered month (for day-of-year calculation).
    @inlinable
    public static func daysPrecedingCivilMonth(year: Int32, civilMonth: UInt8) -> UInt16 {
        let yd = YearData(year: year)
        var total: UInt16 = 0
        for m: UInt8 in 1..<civilMonth {
            let biblical = civilToBiblical(year: year, civilMonth: m)
            total += UInt16(yd.lastDayOfMonth(biblical))
        }
        return total
    }
}

// MARK: - Helper

extension Int64 {
    @inlinable
    func euclideanRemainder(_ divisor: Int64) -> Int64 {
        var r = self % divisor
        if r < 0 { r += divisor }
        return r
    }
}

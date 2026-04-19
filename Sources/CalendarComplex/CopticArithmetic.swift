// Coptic calendar arithmetic — shared by Coptic and Ethiopian calendars.
//
// Algorithms from "Calendrical Calculations" by Reingold & Dershowitz (4th ed., 2018),
// ported from ICU4X calendrical_calculations/src/coptic.rs (Apache-2.0).

import CalendarCore
import CalendarSimple

/// Shared arithmetic for Coptic-family calendars (Coptic and Ethiopian).
///
/// Both use 13 months: 12 months of 30 days + 1 epagomenal month of 5 days (6 in leap years).
/// Leap years follow Julian rules: every 4th year.
public enum CopticArithmetic {

    // MARK: - Constants

    /// Coptic epoch: August 29, 284 CE (Julian) = Tout 1, 1 AM (Anno Martyrum).
    @usableFromInline static let copticEpoch: RataDie = JulianArithmetic.fixedFromJulian(year: 284, month: 8, day: 29)

    @usableFromInline static let copticEpochDayNumber: Int64 = copticEpoch.dayNumber

    /// Offset from Ethiopian epoch to Coptic epoch.
    /// Ethiopian epoch: August 29, 8 CE (Julian) = Mäskäräm 1, 1 AM (Amete Mihret).
    @usableFromInline static let ethiopicToCopticOffset: Int64 = {
        let ethiopianEpoch = JulianArithmetic.fixedFromJulian(year: 8, month: 8, day: 29)
        return copticEpoch.dayNumber - ethiopianEpoch.dayNumber
    }()

    // MARK: - Leap Year

    /// Whether the given Coptic/Ethiopian year is a leap year.
    /// Leap if (year + 1) is divisible by 4.
    @inlinable
    public static func isLeapYear(_ year: Int32) -> Bool {
        var r = (year &+ 1) % 4
        if r < 0 { r += 4 }
        return r == 0
    }

    // MARK: - Days in Month

    /// Days in the given month (1-13) of a Coptic/Ethiopian year.
    @inlinable
    public static func daysInMonth(year: Int32, month: UInt8) -> UInt8 {
        if month <= 12 {
            return 30
        } else {
            return isLeapYear(year) ? 6 : 5
        }
    }

    // MARK: - Coptic Conversions

    /// Convert Coptic (year, month, day) to RataDie.
    @inlinable
    public static func fixedFromCoptic(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        let y = Int64(year)
        let yearDiv4: Int64 = y >= 0 ? y / 4 : (y &- 3) / 4
        return RataDie(
            copticEpochDayNumber &- 1
            &+ 365 &* (y &- 1)
            &+ yearDiv4
            &+ 30 &* (Int64(month) &- 1)
            &+ Int64(day)
        )
    }

    /// Convert RataDie to Coptic (year, month, day).
    @inlinable
    public static func copticFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        // year = floor((4*(date - epoch) + 1463) / 1461)
        let num = 4 &* (date.dayNumber &- copticEpochDayNumber) &+ 1463
        let year: Int32
        if num >= 0 {
            year = Int32(num / 1461)
        } else {
            year = Int32((num &- 1460) / 1461)
        }

        // Compute year start directly (avoid second fixedFromCoptic call).
        let y64 = Int64(year)
        let yearDiv4: Int64 = y64 >= 0 ? y64 / 4 : (y64 &- 3) / 4
        let yearStart = copticEpochDayNumber &- 1 &+ 365 &* (y64 &- 1) &+ yearDiv4
        // yearStart is now the RataDie of (year, month=1, day=0). So year's day 1 is yearStart + 1.
        let doy = date.dayNumber &- yearStart  // 1-indexed day of year

        let monthRaw = (doy &- 1) / 30 &+ 1
        let month = UInt8(min(monthRaw, 13))
        // monthStart in terms of yearStart offset:
        // fixedFromCoptic(year, month, 1) = yearStart + 30*(month-1) + 1
        let dayStartOffset = 30 &* (Int64(month) &- 1)
        let day = UInt8(doy &- dayStartOffset)

        return (year, month, day)
    }

    // MARK: - Ethiopian Conversions

    /// Convert Ethiopian (year, month, day) to RataDie.
    @inlinable
    public static func fixedFromEthiopian(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        let copticRd = fixedFromCoptic(year: year, month: month, day: day)
        return RataDie(copticRd.dayNumber &- ethiopicToCopticOffset)
    }

    /// Convert RataDie to Ethiopian (year, month, day).
    @inlinable
    public static func ethiopianFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        copticFromFixed(RataDie(date.dayNumber &+ ethiopicToCopticOffset))
    }
}

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
enum CopticArithmetic {

    // MARK: - Constants

    /// Coptic epoch: August 29, 284 CE (Julian) = Tout 1, 1 AM (Anno Martyrum).
    static let copticEpoch: RataDie = JulianArithmetic.fixedFromJulian(year: 284, month: 8, day: 29)

    /// Offset from Ethiopian epoch to Coptic epoch.
    /// Ethiopian epoch: August 29, 8 CE (Julian) = Mäskäräm 1, 1 AM (Amete Mihret).
    static let ethiopicToCopticOffset: Int64 = {
        let ethiopianEpoch = JulianArithmetic.fixedFromJulian(year: 8, month: 8, day: 29)
        return copticEpoch.dayNumber - ethiopianEpoch.dayNumber
    }()

    // MARK: - Leap Year

    /// Whether the given Coptic/Ethiopian year is a leap year.
    /// Leap if (year + 1) is divisible by 4.
    static func isLeapYear(_ year: Int32) -> Bool {
        var r = (year + 1) % 4
        if r < 0 { r += 4 }
        return r == 0
    }

    // MARK: - Days in Month

    /// Days in the given month (1-13) of a Coptic/Ethiopian year.
    static func daysInMonth(year: Int32, month: UInt8) -> UInt8 {
        if month <= 12 {
            return 30
        } else {
            // Month 13 (epagomenal): 5 days, or 6 in leap years
            return isLeapYear(year) ? 6 : 5
        }
    }

    // MARK: - Coptic Conversions

    /// Convert Coptic (year, month, day) to RataDie.
    static func fixedFromCoptic(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        let y = Int64(year)
        // Reingold & Dershowitz: epoch - 1 + 365*(y-1) + floor(y/4) + 30*(m-1) + d
        // For negative years, use Euclidean division (floor towards -∞)
        let yearDiv4: Int64 = y >= 0 ? y / 4 : (y - 3) / 4
        return RataDie(
            copticEpoch.dayNumber - 1
            + 365 * (y - 1)
            + yearDiv4
            + 30 * (Int64(month) - 1)
            + Int64(day)
        )
    }

    /// Convert RataDie to Coptic (year, month, day).
    static func copticFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        // year = floor((4*(date - epoch) + 1463) / 1461)
        let num = 4 * (date.dayNumber - copticEpoch.dayNumber) + 1463
        let year: Int32
        if num >= 0 {
            year = Int32(num / 1461)
        } else {
            year = Int32((num - 1460) / 1461)  // floor division
        }

        let monthStart = fixedFromCoptic(year: year, month: 1, day: 1)
        let monthRaw = (date.dayNumber - monthStart.dayNumber) / 30 + 1
        let month = UInt8(min(monthRaw, 13))

        let dayStart = fixedFromCoptic(year: year, month: month, day: 1)
        let day = UInt8(date.dayNumber - dayStart.dayNumber + 1)

        return (year, month, day)
    }

    // MARK: - Ethiopian Conversions

    /// Convert Ethiopian (year, month, day) to RataDie.
    static func fixedFromEthiopian(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        let copticRd = fixedFromCoptic(year: year, month: month, day: day)
        return RataDie(copticRd.dayNumber - ethiopicToCopticOffset)
    }

    /// Convert RataDie to Ethiopian (year, month, day).
    static func ethiopianFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        copticFromFixed(RataDie(date.dayNumber + ethiopicToCopticOffset))
    }
}

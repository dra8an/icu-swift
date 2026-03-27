// Hebrew calendar — lunisolar calendar using civil month ordering (Tishrei = month 1).
//
// Ported from ICU4X components/calendar/src/cal/hebrew.rs (Unicode License).

import CalendarCore
import CalendarSimple

/// The Hebrew (Jewish) calendar.
///
/// A lunisolar calendar with 12 months in common years and 13 in leap years.
/// Uses civil month ordering where Tishrei is month 1.
///
/// Single era: `am` (Anno Mundi).
///
/// Months (civil order):
/// - Tishrei (M01, 30), Ḥešvan (M02, 29/30), Kislev (M03, 30/29), Tevet (M04, 29),
///   Shevat (M05, 30), Adar I (M05L, 30, leap only), Adar (M06, 29),
///   Nisan (M07, 30), Iyyar (M08, 29), Sivan (M09, 30), Tammuz (M10, 29),
///   Av (M11, 30), Elul (M12, 29)
public struct Hebrew: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "hebrew"

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> HebrewDateInner {
        let extYear = try resolveYear(year)
        let monthCount = HebrewArithmetic.monthsInYear(extYear)

        // Resolve month: handle leap month (M05L = Adar I)
        let civilMonth = try resolveCivilMonth(year: extYear, month: month, monthCount: monthCount)

        let maxDay = HebrewArithmetic.daysInCivilMonth(year: extYear, civilMonth: civilMonth)
        guard day >= 1, day <= maxDay else {
            throw DateNewError.invalidDay(max: maxDay)
        }

        return HebrewDateInner(year: extYear, month: civilMonth, day: day)
    }

    public func toRataDie(_ date: HebrewDateInner) -> RataDie {
        let biblical = HebrewArithmetic.civilToBiblical(year: date.year, civilMonth: date.month)
        return HebrewArithmetic.fixedFromHebrew(year: date.year, month: biblical, day: date.day)
    }

    public func fromRataDie(_ rd: RataDie) -> HebrewDateInner {
        let (year, biblicalMonth, day) = HebrewArithmetic.hebrewFromFixed(rd)
        let civilMonth = HebrewArithmetic.biblicalToCivil(year: year, biblicalMonth: biblicalMonth)
        return HebrewDateInner(year: year, month: civilMonth, day: day)
    }

    public func yearInfo(_ date: HebrewDateInner) -> YearInfo {
        .era(EraYear(
            era: "am",
            year: date.year,
            extendedYear: date.year,
            ambiguity: .centuryRequired
        ))
    }

    public func monthInfo(_ date: HebrewDateInner) -> MonthInfo {
        let isLeap = HebrewArithmetic.isLeapYear(date.year)

        // Civil month to Month mapping
        let month: Month
        if isLeap {
            if date.month == 6 {
                // Adar I (leap month)
                month = .leap(5)
            } else if date.month <= 5 {
                month = .new(date.month)
            } else {
                // months 7-13 civil → month numbers 6-12
                month = .new(date.month - 1)
            }
        } else {
            month = .new(date.month)
        }

        return MonthInfo(ordinal: date.month, month: month)
    }

    public func dayOfMonth(_ date: HebrewDateInner) -> UInt8 {
        date.day
    }

    public func dayOfYear(_ date: HebrewDateInner) -> UInt16 {
        HebrewArithmetic.daysPrecedingCivilMonth(year: date.year, civilMonth: date.month)
            + UInt16(date.day)
    }

    public func daysInMonth(_ date: HebrewDateInner) -> UInt8 {
        HebrewArithmetic.daysInCivilMonth(year: date.year, civilMonth: date.month)
    }

    public func daysInYear(_ date: HebrewDateInner) -> UInt16 {
        HebrewArithmetic.daysInYear(date.year)
    }

    public func monthsInYear(_ date: HebrewDateInner) -> UInt8 {
        HebrewArithmetic.monthsInYear(date.year)
    }

    public func isInLeapYear(_ date: HebrewDateInner) -> Bool {
        HebrewArithmetic.isLeapYear(date.year)
    }

    // MARK: - Private Helpers

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y):
            return y
        case .eraYear(let era, let year):
            switch era {
            case "am":
                return year
            default:
                throw DateNewError.invalidEra
            }
        }
    }

    private func resolveCivilMonth(year: Int32, month: Month, monthCount: UInt8) throws -> UInt8 {
        let isLeap = HebrewArithmetic.isLeapYear(year)

        if month.isLeap {
            // Only M05L (Adar I) exists in leap years
            guard month.number == 5, isLeap else {
                if month.number == 5 {
                    throw DateNewError.monthNotInYear
                }
                throw DateNewError.monthNotInCalendar
            }
            return 6  // Civil month 6 = Adar I in leap year
        }

        // Non-leap month
        let num = month.number
        guard num >= 1, num <= 12 else {
            throw DateNewError.monthNotInCalendar
        }

        if isLeap {
            // In leap years, civil months after 5 shift by 1
            if num >= 6 {
                return num + 1  // 6→7, 7→8, ..., 12→13
            }
            return num
        } else {
            guard num <= 12 else {
                throw DateNewError.monthNotInCalendar
            }
            return num
        }
    }
}

// MARK: - HebrewDateInner

/// Internal representation of a Hebrew calendar date.
///
/// Uses civil month ordering (Tishrei = 1).
public struct HebrewDateInner: Equatable, Comparable, Hashable, Sendable {
    let year: Int32
    /// Civil month (1-based, Tishrei=1). 13 months in leap years.
    let month: UInt8
    let day: UInt8

    public static func < (lhs: HebrewDateInner, rhs: HebrewDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

// Indian National (Śaka) calendar.
//
// Ported from ICU4X components/calendar/src/cal/indian.rs (Unicode License).

import CalendarCore
import CalendarSimple

/// The Indian National (Śaka) calendar.
///
/// A solar calendar based on the Gregorian leap year cycle but with different
/// month lengths and epoch.
///
/// Month 1 (Chaitra): 30 days (31 in leap years).
/// Months 2-6 (Vaisakha-Bhadra): 31 days each.
/// Months 7-12 (Asvina-Phalguna): 30 days each.
///
/// Leap year: same as Gregorian for (Śaka year + 78).
/// Epoch: March 22, 79 CE (Gregorian).
///
/// Single era: `shaka`.
public struct Indian: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "indian"

    /// Śaka epoch is 78 years behind Gregorian.
    private static let yearOffset: Int32 = 78

    /// The Śaka era starts on the 81st day of the Gregorian year (March 22 or 21),
    /// which is an 80-day offset.
    private static let dayOffset: UInt16 = 80

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IndianDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return IndianDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: IndianDateInner) -> RataDie {
        let doy = indianDayOfYear(year: date.year, month: date.month, day: date.day)
        let totalDays = daysInIndianYear(date.year)

        var isoYear = date.year + Self.yearOffset
        let isoDoy: UInt16
        if UInt16(doy) + Self.dayOffset > totalDays {
            isoYear += 1
            isoDoy = UInt16(doy) + Self.dayOffset - totalDays
        } else {
            isoDoy = UInt16(doy) + Self.dayOffset
        }

        return GregorianArithmetic.dayBeforeYear(isoYear) + Int64(isoDoy)
    }

    public func fromRataDie(_ rd: RataDie) -> IndianDateInner {
        let isoYear = GregorianArithmetic.yearFromFixed(rd)
        let isoDoy = UInt16(rd.dayNumber - GregorianArithmetic.dayBeforeYear(isoYear).dayNumber)

        var year = isoYear - Self.yearOffset

        let indianDoy: UInt16
        if isoDoy <= Self.dayOffset {
            year -= 1
            let nDays: UInt16 = GregorianArithmetic.isLeapYear(year + Self.yearOffset) ? 366 : 365
            indianDoy = nDays + isoDoy - Self.dayOffset
        } else {
            indianDoy = isoDoy - Self.dayOffset
        }

        // Walk through months to find month and day
        var remaining = Int32(indianDoy)
        var month: UInt8 = 1
        while month <= 12 {
            let mLen = Int32(Self.daysInProvidedMonth(year: year, month: month))
            if remaining <= mLen {
                break
            }
            remaining -= mLen
            month += 1
        }

        return IndianDateInner(year: year, month: month, day: UInt8(remaining))
    }

    public func yearInfo(_ date: IndianDateInner) -> YearInfo {
        .era(EraYear(
            era: "shaka",
            year: date.year,
            extendedYear: date.year,
            ambiguity: .centuryRequired
        ))
    }

    public func monthInfo(_ date: IndianDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: IndianDateInner) -> UInt8 {
        date.day
    }

    public func dayOfYear(_ date: IndianDateInner) -> UInt16 {
        UInt16(indianDayOfYear(year: date.year, month: date.month, day: date.day))
    }

    public func daysInMonth(_ date: IndianDateInner) -> UInt8 {
        Self.daysInProvidedMonth(year: date.year, month: date.month)
    }

    public func daysInYear(_ date: IndianDateInner) -> UInt16 {
        daysInIndianYear(date.year)
    }

    public func monthsInYear(_ date: IndianDateInner) -> UInt8 {
        12
    }

    public func isInLeapYear(_ date: IndianDateInner) -> Bool {
        GregorianArithmetic.isLeapYear(date.year + Self.yearOffset)
    }

    // MARK: - Static Helpers

    /// Days in a given Indian month.
    static func daysInProvidedMonth(year: Int32, month: UInt8) -> UInt8 {
        // Months are 30 days, except first 6 are 31, except month 1 in non-leap is 30
        var days: UInt8 = 30
        if month <= 6 { days += 1 }
        if month == 1 && !GregorianArithmetic.isLeapYear(year + yearOffset) { days -= 1 }
        return days
    }

    // MARK: - Private

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(let era, let year):
            guard era == "shaka" else { throw DateNewError.invalidEra }
            return year
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else { throw DateNewError.monthNotInCalendar }
        guard month.number >= 1, month.number <= 12 else { throw DateNewError.monthNotInCalendar }
        let maxDay = Self.daysInProvidedMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }
    }

    /// 1-indexed day of the Indian year.
    private func indianDayOfYear(year: Int32, month: UInt8, day: UInt8) -> UInt16 {
        var total: UInt16 = 0
        // Sum days in months 1..<month
        total += 30 * UInt16(month - 1)
        // First 6 months are 31 days
        if month - 1 < 6 {
            total += UInt16(month - 1)
        } else {
            total += 6
        }
        // Except month 1 outside a leap year
        if month > 1 && !GregorianArithmetic.isLeapYear(year + Self.yearOffset) {
            total -= 1
        }
        total += UInt16(day)
        return total
    }

    private func daysInIndianYear(_ year: Int32) -> UInt16 {
        GregorianArithmetic.isLeapYear(year + Self.yearOffset) ? 366 : 365
    }
}

// MARK: - IndianDateInner

public struct IndianDateInner: Equatable, Comparable, Hashable, Sendable {
    let year: Int32
    let month: UInt8  // 1-12
    let day: UInt8

    public static func < (lhs: IndianDateInner, rhs: IndianDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

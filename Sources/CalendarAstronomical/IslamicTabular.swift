// Islamic Tabular calendar — pure arithmetic based on 30-year cycle.
//
// Ported from ICU4X calendrical_calculations/src/islamic.rs (Apache-2.0).

import CalendarCore
import CalendarSimple

/// The Islamic Tabular calendar.
///
/// A purely arithmetic approximation of the Islamic lunar calendar using a 30-year cycle.
/// 12 months alternating 30/29 days. Month 12 has 30 days in leap years.
/// Leap years: positions 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29 in the 30-year cycle (Type II).
///
/// Two eras: `ah` (Anno Hegirae) and `bh` (Before Hijrah).
///
/// Epoch: July 16, 622 CE Julian (Friday epoch, most common).
public struct IslamicTabular: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "islamic-tbla"

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IslamicTabularDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return IslamicTabularDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: IslamicTabularDateInner) -> RataDie {
        IslamicTabularArithmetic.fixedFromTabular(year: date.year, month: date.month, day: date.day)
    }

    public func fromRataDie(_ rd: RataDie) -> IslamicTabularDateInner {
        let (y, m, d) = IslamicTabularArithmetic.tabularFromFixed(rd)
        return IslamicTabularDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: IslamicTabularDateInner) -> YearInfo {
        if date.year > 0 {
            return .era(EraYear(
                era: "ah", year: date.year, extendedYear: date.year,
                ambiguity: .centuryRequired
            ))
        } else {
            return .era(EraYear(
                era: "bh", year: 1 - date.year, extendedYear: date.year,
                ambiguity: .eraAndCenturyRequired
            ))
        }
    }

    public func monthInfo(_ date: IslamicTabularDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: IslamicTabularDateInner) -> UInt8 { date.day }

    public func dayOfYear(_ date: IslamicTabularDateInner) -> UInt16 {
        IslamicTabularArithmetic.daysBeforeMonth(date.month) + UInt16(date.day)
    }

    public func daysInMonth(_ date: IslamicTabularDateInner) -> UInt8 {
        IslamicTabularArithmetic.daysInMonth(year: date.year, month: date.month)
    }

    public func daysInYear(_ date: IslamicTabularDateInner) -> UInt16 {
        IslamicTabularArithmetic.isLeapYear(date.year) ? 355 : 354
    }

    public func monthsInYear(_ date: IslamicTabularDateInner) -> UInt8 { 12 }

    public func isInLeapYear(_ date: IslamicTabularDateInner) -> Bool {
        IslamicTabularArithmetic.isLeapYear(date.year)
    }

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(let era, let year):
            switch era {
            case "ah": return year
            case "bh": return 1 - year
            default: throw DateNewError.invalidEra
            }
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else { throw DateNewError.monthNotInCalendar }
        guard month.number >= 1, month.number <= 12 else { throw DateNewError.monthNotInCalendar }
        let maxDay = IslamicTabularArithmetic.daysInMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }
    }
}

// MARK: - IslamicTabularDateInner

public struct IslamicTabularDateInner: Equatable, Comparable, Hashable, Sendable {
    let year: Int32
    let month: UInt8
    let day: UInt8

    public static func < (lhs: IslamicTabularDateInner, rhs: IslamicTabularDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

// MARK: - IslamicTabularArithmetic

enum IslamicTabularArithmetic {

    /// Islamic epoch (Friday): July 16, 622 CE Julian.
    static let epoch: RataDie = JulianArithmetic.fixedFromJulian(year: 622, month: 7, day: 16)

    /// Whether a year is a leap year in the 30-year cycle (Type II).
    /// Leap years: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29.
    static func isLeapYear(_ year: Int32) -> Bool {
        var r = (14 + 11 * Int64(year)) % 30
        if r < 0 { r += 30 }
        return r < 11
    }

    /// Days in a given month (odd months = 30, even months = 29, month 12 = 30 in leap years).
    static func daysInMonth(year: Int32, month: UInt8) -> UInt8 {
        if month % 2 == 1 {
            return 30  // Months 1, 3, 5, 7, 9, 11 = 30 days
        } else if month == 12 && isLeapYear(year) {
            return 30  // Month 12 in leap year = 30 days
        } else {
            return 29  // Even months = 29 days
        }
    }

    /// Days before the given month (0-indexed).
    static func daysBeforeMonth(_ month: UInt8) -> UInt16 {
        // Months alternate 30/29, so: 29*(m-1) + floor(m/2)
        29 * UInt16(month - 1) + UInt16(month / 2)
    }

    /// Convert Islamic Tabular (year, month, day) to RataDie.
    static func fixedFromTabular(year: Int32, month: UInt8, day: UInt8) -> RataDie {
        let y = Int64(year)
        let m = Int64(month)
        let d = Int64(day)

        var leapDays = (3 + y * 11)
        if leapDays >= 0 {
            leapDays = leapDays / 30
        } else {
            leapDays = (leapDays - 29) / 30  // floor division
        }

        return RataDie(
            epoch.dayNumber - 1
            + (y - 1) * 354
            + leapDays
            + 29 * (m - 1)
            + m / 2
            + d
        )
    }

    /// Convert RataDie to Islamic Tabular (year, month, day).
    static func tabularFromFixed(_ date: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        let year = yearFromFixed(date)
        let priorDays = date.dayNumber - fixedFromTabular(year: year, month: 1, day: 1).dayNumber
        let month = UInt8((priorDays * 11 + 330) / 325)
        let day = UInt8(date.dayNumber - fixedFromTabular(year: year, month: month, day: 1).dayNumber + 1)
        return (year, month, day)
    }

    static func yearFromFixed(_ date: RataDie) -> Int32 {
        // Mean year length = (354*30 + 11) / 30 = 10631/30
        let diff = date.dayNumber - epoch.dayNumber
        let rawYear = diff * 30 / (354 * 30 + 11) + (date >= epoch ? 1 : 0)
        return Int32(rawYear)
    }
}

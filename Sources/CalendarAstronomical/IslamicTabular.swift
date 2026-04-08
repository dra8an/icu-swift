// Islamic Tabular calendar — pure arithmetic based on 30-year cycle.
//
// Two CLDR calendars share this arithmetic, differing only in the 1-day
// epoch shift:
//
//   - "islamic-tbla" — `TabularEpoch.thursday` (Jul 15, 622 Julian, "astronomical")
//   - "islamic-civil" — `TabularEpoch.friday`   (Jul 16, 622 Julian, "civil")
//
// `IslamicTabular` is the configurable type and defaults to `.thursday` to
// match the CLDR meaning of `islamic-tbla`. `IslamicCivil` is a thin wrapper
// hard-coded to the Friday epoch, with identifier `islamic-civil`.
//
// Ported from ICU4X calendrical_calculations/src/islamic.rs (Apache-2.0) and
// components/calendar/src/cal/hijri.rs.

import CalendarCore
import CalendarSimple

// MARK: - TabularEpoch

/// Epoch variant used by the Islamic Tabular arithmetic.
///
/// The two epochs differ by exactly one day, leading to two CLDR calendars
/// (`islamic-tbla` and `islamic-civil`) with otherwise identical rules.
public enum TabularEpoch: Sendable, Hashable {
    /// Thursday July 15, 622 CE Julian — "astronomical" epoch (`islamic-tbla`).
    case thursday
    /// Friday July 16, 622 CE Julian — "civil" epoch (`islamic-civil`).
    case friday

    /// The Rata Die value of this epoch.
    public var rataDie: RataDie {
        switch self {
        case .thursday:
            return JulianArithmetic.fixedFromJulian(year: 622, month: 7, day: 15)
        case .friday:
            return JulianArithmetic.fixedFromJulian(year: 622, month: 7, day: 16)
        }
    }
}

// MARK: - IslamicTabular

/// The Islamic Tabular calendar (`islamic-tbla`).
///
/// A purely arithmetic approximation of the Islamic lunar calendar using a
/// 30-year cycle. 12 months alternating 30/29 days. Month 12 has 30 days in
/// leap years. Leap year positions in the 30-year cycle (Type II):
/// 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29.
///
/// Two eras: `ah` (Anno Hegirae) and `bh` (Before Hijrah).
///
/// The CLDR identifier `islamic-tbla` denotes the **Thursday** (astronomical)
/// epoch — July 15, 622 CE Julian — which is also the default. To use the
/// Friday/civil epoch you should normally use `IslamicCivil` instead, but the
/// `epoch` property is exposed for completeness.
public struct IslamicTabular: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "islamic-tbla"

    /// Which epoch this instance uses. Defaults to `.thursday`.
    public let epoch: TabularEpoch

    public init(epoch: TabularEpoch = .thursday) {
        self.epoch = epoch
    }

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IslamicTabularDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return IslamicTabularDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: IslamicTabularDateInner) -> RataDie {
        IslamicTabularArithmetic.fixedFromTabular(
            year: date.year, month: date.month, day: date.day, epoch: epoch.rataDie)
    }

    public func fromRataDie(_ rd: RataDie) -> IslamicTabularDateInner {
        let (y, m, d) = IslamicTabularArithmetic.tabularFromFixed(rd, epoch: epoch.rataDie)
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

// MARK: - IslamicCivil

/// The Islamic Civil calendar (`islamic-civil`).
///
/// Identical to `IslamicTabular(epoch: .friday)` — same Type II 30-year leap
/// cycle, same month lengths, but with the Friday (Jul 16, 622 Julian)
/// epoch. This is the most common civil tabular variant and matches CLDR's
/// `islamic-civil` identifier.
public struct IslamicCivil: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "islamic-civil"
    public typealias DateInner = IslamicTabularDateInner

    private static let epochRD: RataDie = TabularEpoch.friday.rataDie

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IslamicTabularDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return IslamicTabularDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: IslamicTabularDateInner) -> RataDie {
        IslamicTabularArithmetic.fixedFromTabular(
            year: date.year, month: date.month, day: date.day, epoch: Self.epochRD)
    }

    public func fromRataDie(_ rd: RataDie) -> IslamicTabularDateInner {
        let (y, m, d) = IslamicTabularArithmetic.tabularFromFixed(rd, epoch: Self.epochRD)
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

/// Internal representation of a tabular Hijri date — shared by `IslamicTabular`
/// and `IslamicCivil` (both calendars use identical arithmetic on (year, month, day)).
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
            return 30
        } else if month == 12 && isLeapYear(year) {
            return 30
        } else {
            return 29
        }
    }

    /// Days before the given month (0-indexed).
    static func daysBeforeMonth(_ month: UInt8) -> UInt16 {
        29 * UInt16(month - 1) + UInt16(month / 2)
    }

    /// Convert tabular Hijri (year, month, day) to RataDie under the given epoch.
    static func fixedFromTabular(year: Int32, month: UInt8, day: UInt8, epoch: RataDie) -> RataDie {
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

    /// Convert RataDie to tabular Hijri (year, month, day) under the given epoch.
    static func tabularFromFixed(_ date: RataDie, epoch: RataDie) -> (year: Int32, month: UInt8, day: UInt8) {
        let year = yearFromFixed(date, epoch: epoch)
        let priorDays = date.dayNumber - fixedFromTabular(year: year, month: 1, day: 1, epoch: epoch).dayNumber
        let month = UInt8((priorDays * 11 + 330) / 325)
        let day = UInt8(date.dayNumber - fixedFromTabular(year: year, month: month, day: 1, epoch: epoch).dayNumber + 1)
        return (year, month, day)
    }

    static func yearFromFixed(_ date: RataDie, epoch: RataDie) -> Int32 {
        // Mean year length = (354*30 + 11) / 30 = 10631/30 days.
        // Formula from ICU4X calendrical_calculations/src/islamic.rs:
        //   year = floor((30 * (date - epoch) + 10646) / 10631)
        // The +10646 (= 10631 + 15) is the half-cycle bias that places year
        // boundaries correctly. Use floor division for negative diffs.
        let diff = date.dayNumber - epoch.dayNumber
        let n = 30 * diff + 10646
        let d: Int64 = 10631
        let q: Int64
        if n >= 0 {
            q = n / d
        } else {
            q = -((-n + d - 1) / d)  // floor division for negatives
        }
        return Int32(q)
    }
}

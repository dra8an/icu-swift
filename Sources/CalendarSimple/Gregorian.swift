// Gregorian calendar — same arithmetic as ISO, with CE/BCE eras.
//
// Ported from ICU4X components/calendar/src/cal/gregorian.rs (Unicode License).

import CalendarCore

/// The proleptic Gregorian calendar.
///
/// Identical arithmetic to ISO, but uses two eras:
/// - `ce` (Common Era): extended year > 0
/// - `bce` (Before Common Era): extended year ≤ 0, where year 0 = 1 BCE
public struct Gregorian: CalendarProtocol, Sendable {
    public typealias DateInner = IsoDateInner

    public static let calendarIdentifier = "gregorian"

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IsoDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return IsoDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: IsoDateInner) -> RataDie {
        GregorianArithmetic.fixedFromGregorian(year: date.year, month: date.month, day: date.day)
    }

    public func fromRataDie(_ rd: RataDie) -> IsoDateInner {
        let (y, m, d) = GregorianArithmetic.gregorianFromFixed(rd)
        return IsoDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: IsoDateInner) -> YearInfo {
        if date.year > 0 {
            return .era(EraYear(
                era: "ce",
                year: date.year,
                extendedYear: date.year,
                ambiguity: gregorianAmbiguity(date.year)
            ))
        } else {
            return .era(EraYear(
                era: "bce",
                year: 1 - date.year,
                extendedYear: date.year,
                ambiguity: .eraAndCenturyRequired
            ))
        }
    }

    public func monthInfo(_ date: IsoDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: IsoDateInner) -> UInt8 {
        date.day
    }

    public func dayOfYear(_ date: IsoDateInner) -> UInt16 {
        GregorianArithmetic.daysBeforeMonth(year: date.year, month: date.month) + UInt16(date.day)
    }

    public func daysInMonth(_ date: IsoDateInner) -> UInt8 {
        GregorianArithmetic.daysInMonth(year: date.year, month: date.month)
    }

    public func daysInYear(_ date: IsoDateInner) -> UInt16 {
        GregorianArithmetic.isLeapYear(date.year) ? 366 : 365
    }

    public func monthsInYear(_ date: IsoDateInner) -> UInt8 {
        12
    }

    public func isInLeapYear(_ date: IsoDateInner) -> Bool {
        GregorianArithmetic.isLeapYear(date.year)
    }

    // MARK: - Private Helpers

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y):
            return y
        case .eraYear(let era, let year):
            switch era {
            case "ce", "ad":
                return year
            case "bce", "bc":
                return 1 - year
            default:
                throw DateNewError.invalidEra
            }
        }
    }

    private func gregorianAmbiguity(_ extendedYear: Int32) -> YearAmbiguity {
        switch extendedYear {
        case ...999:
            return .eraAndCenturyRequired
        case 1000...1949:
            return .centuryRequired
        case 1950...2049:
            return .unambiguous
        default:
            return .centuryRequired
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else {
            throw DateNewError.monthNotInCalendar
        }
        guard month.number >= 1, month.number <= 12 else {
            throw DateNewError.monthNotInCalendar
        }
        let maxDay = GregorianArithmetic.daysInMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else {
            throw DateNewError.invalidDay(max: maxDay)
        }
    }
}

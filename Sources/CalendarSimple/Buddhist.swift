// Thai Solar Buddhist calendar — Gregorian with year offset +543.
//
// Ported from ICU4X components/calendar/src/cal/buddhist.rs (Unicode License).

import CalendarCore

/// The Thai Solar Buddhist calendar.
///
/// Identical arithmetic to the Gregorian calendar, but uses the Buddhist Era (BE).
/// Buddhist year = Gregorian extended year + 543.
/// Single era: `be`.
///
/// - 1 CE (Gregorian) = 544 BE
/// - 543 BCE (Gregorian extended year -542) = 1 BE
public struct Buddhist: CalendarProtocol, Sendable {
    public typealias DateInner = IsoDateInner

    public static let calendarIdentifier = "buddhist"

    /// Offset from Gregorian extended year to Buddhist era year.
    /// Buddhist year = Gregorian year - offset, where offset = -543.
    /// Equivalently: Gregorian year = Buddhist year + (-543) = Buddhist year - 543.
    static let extendedYearOffset: Int32 = -543

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IsoDateInner {
        let beYear = try resolveToBuddhistYear(year)
        let gregYear = beYear + Self.extendedYearOffset
        try validateMonthDay(year: gregYear, month: month, day: day)
        return IsoDateInner(year: gregYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: IsoDateInner) -> RataDie {
        GregorianArithmetic.fixedFromGregorian(year: date.year, month: date.month, day: date.day)
    }

    public func fromRataDie(_ rd: RataDie) -> IsoDateInner {
        let (y, m, d) = GregorianArithmetic.gregorianFromFixed(rd)
        return IsoDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: IsoDateInner) -> YearInfo {
        let beYear = date.year - Self.extendedYearOffset
        return .era(EraYear(
            era: "be",
            year: beYear,
            extendedYear: date.year,
            ambiguity: .centuryRequired
        ))
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

    private func resolveToBuddhistYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y):
            // Extended year input is treated as Buddhist era year
            return y
        case .eraYear(let era, let year):
            switch era {
            case "be":
                return year
            default:
                throw DateNewError.invalidEra
            }
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

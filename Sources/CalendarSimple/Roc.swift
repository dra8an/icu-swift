// Republic of China (Taiwan/Minguo) calendar — Gregorian with year offset -1911.
//
// Ported from ICU4X components/calendar/src/cal/roc.rs (Unicode License).

import CalendarCore

/// The Republic of China (Minguo) calendar.
///
/// Identical arithmetic to the Gregorian calendar, but uses two eras:
/// - `roc` (Minguo): extended year > 0, where 1 Minguo = 1912 CE
/// - `broc` (Before Minguo): extended year ≤ 0, where 1 Before Minguo = 1911 CE
///
/// Internally, dates store Gregorian extended year. The ROC extended year
/// is the Gregorian year minus 1911.
public struct Roc: CalendarProtocol, Sendable {
    public typealias DateInner = IsoDateInner

    public static let calendarIdentifier = "roc"

    /// Offset from ROC extended year to Gregorian extended year.
    /// Gregorian year = ROC extended year + 1911.
    static let extendedYearOffset: Int32 = 1911

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IsoDateInner {
        let rocExtYear = try resolveToRocExtendedYear(year)
        let gregYear = rocExtYear + Self.extendedYearOffset
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
        let rocExtYear = date.year - Self.extendedYearOffset
        if rocExtYear > 0 {
            return .era(EraYear(
                era: "roc",
                year: rocExtYear,
                extendedYear: date.year,
                ambiguity: .centuryRequired
            ))
        } else {
            return .era(EraYear(
                era: "broc",
                year: 1 - rocExtYear,
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

    private func resolveToRocExtendedYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y):
            // Extended year input is treated as ROC extended year
            return y
        case .eraYear(let era, let year):
            switch era {
            case "roc":
                return year
            case "broc":
                return 1 - year
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

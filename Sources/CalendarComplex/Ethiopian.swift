// Ethiopian calendar — Coptic structure with different epoch and two eras.
//
// Ported from ICU4X components/calendar/src/cal/ethiopian.rs (Unicode License).

import CalendarCore

/// The Ethiopian calendar.
///
/// Same 13-month structure as Coptic (12×30 + 1×5/6), but with a different epoch.
/// Epoch: August 29, 8 CE (Julian) = Mäskäräm 1, 1 AM (Amete Mihret).
///
/// Two eras:
/// - `incar` (Amete Mihret, Era of the Incarnation): the default era
/// - `mundi` (Amete Alem, Era of the World): year = incar year + 5500
public struct Ethiopian: CalendarProtocol, Sendable {
    public typealias DateInner = EthiopianDateInner

    public static let calendarIdentifier = "ethiopian"

    /// Offset between Amete Alem and Amete Mihret eras.
    static let ameteAlemOffset: Int32 = 5500

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> EthiopianDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return EthiopianDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: EthiopianDateInner) -> RataDie {
        CopticArithmetic.fixedFromEthiopian(year: date.year, month: date.month, day: date.day)
    }

    public func fromRataDie(_ rd: RataDie) -> EthiopianDateInner {
        let (y, m, d) = CopticArithmetic.ethiopianFromFixed(rd)
        return EthiopianDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: EthiopianDateInner) -> YearInfo {
        .era(EraYear(
            era: "incar",
            year: date.year,
            extendedYear: date.year,
            ambiguity: .centuryRequired
        ))
    }

    public func monthInfo(_ date: EthiopianDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: EthiopianDateInner) -> UInt8 {
        date.day
    }

    public func dayOfYear(_ date: EthiopianDateInner) -> UInt16 {
        30 * UInt16(date.month - 1) + UInt16(date.day)
    }

    public func daysInMonth(_ date: EthiopianDateInner) -> UInt8 {
        CopticArithmetic.daysInMonth(year: date.year, month: date.month)
    }

    public func daysInYear(_ date: EthiopianDateInner) -> UInt16 {
        CopticArithmetic.isLeapYear(date.year) ? 366 : 365
    }

    public func monthsInYear(_ date: EthiopianDateInner) -> UInt8 {
        13
    }

    public func isInLeapYear(_ date: EthiopianDateInner) -> Bool {
        CopticArithmetic.isLeapYear(date.year)
    }

    // MARK: - Private

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(let era, let year):
            switch era {
            case "incar":
                return year
            case "mundi":
                return year - Self.ameteAlemOffset
            default:
                throw DateNewError.invalidEra
            }
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else { throw DateNewError.monthNotInCalendar }
        guard month.number >= 1, month.number <= 13 else { throw DateNewError.monthNotInCalendar }
        let maxDay = CopticArithmetic.daysInMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }
    }
}

// MARK: - EthiopianDateInner

/// Internal representation of an Ethiopian calendar date.
public struct EthiopianDateInner: Equatable, Comparable, Hashable, Sendable {
    let year: Int32
    let month: UInt8  // 1-13
    let day: UInt8

    public static func < (lhs: EthiopianDateInner, rhs: EthiopianDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

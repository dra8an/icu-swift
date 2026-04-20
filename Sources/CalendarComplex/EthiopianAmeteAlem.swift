// Ethiopian Amete Alem calendar — Ethiopian with the "Age of the World" era.
//
// Shares `CopticArithmetic` and `EthiopianDateInner` with `Ethiopian`.
// Differs only in:
//   - Reports identifier "ethiopic-amete-alem" (CLDR) instead of "ethiopian".
//   - Defaults to the `mundi` era (Amete Alem) when reporting `yearInfo`.
//   - Year N in Amete Alem = Year (N − 5500) in Amete Mihret.
//
// Extended year in `EthiopianDateInner` continues to be stored in Amete
// Mihret coordinates so arithmetic is shared with `Ethiopian`. The Amete
// Alem year is computed at display time.
//
// Ported from ICU4X components/calendar/src/cal/ethiopian.rs; the CLDR
// identifier `ethiopic-amete-alem` matches Foundation's `.ethiopicAmeteAlem`
// `Calendar.Identifier` case.

import CalendarCore

// MARK: - EthiopianAmeteAlem

/// The Ethiopian calendar with the Amete Alem ("Age of the World") era.
///
/// Identical arithmetic to `Ethiopian`. The only differences are surface:
/// - `calendarIdentifier = "ethiopic-amete-alem"` (Foundation's
///   `.ethiopicAmeteAlem` / CLDR `ethioaa`)
/// - `yearInfo` returns the `mundi` era with a year offset of +5500 from
///   Ethiopian's internal extended year
/// - `newDate(year: .eraYear("mundi", y), ...)` is the expected input
///   form; `"incar"` is also accepted for interoperability.
public struct EthiopianAmeteAlem: CalendarProtocol, Sendable {
    public typealias DateInner = EthiopianDateInner

    public static let calendarIdentifier = "ethiopic-amete-alem"

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> EthiopianDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return EthiopianDateInner(year: extYear, month: month.number, day: day)
    }

    @inlinable
    public func toRataDie(_ date: EthiopianDateInner) -> RataDie {
        CopticArithmetic.fixedFromEthiopian(year: date.year, month: date.month, day: date.day)
    }

    @inlinable
    public func fromRataDie(_ rd: RataDie) -> EthiopianDateInner {
        let (y, m, d) = CopticArithmetic.ethiopianFromFixed(rd)
        return EthiopianDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: EthiopianDateInner) -> YearInfo {
        // Surface the Amete Alem year: AM-Alem year = AM-Mihret year + 5500.
        .era(EraYear(
            era: "mundi",
            year: date.year + Ethiopian.ameteAlemOffset,
            extendedYear: date.year,
            ambiguity: .centuryRequired
        ))
    }

    public func monthInfo(_ date: EthiopianDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    @inlinable
    public func dayOfMonth(_ date: EthiopianDateInner) -> UInt8 {
        date.day
    }

    @inlinable
    public func dayOfYear(_ date: EthiopianDateInner) -> UInt16 {
        30 * UInt16(date.month - 1) + UInt16(date.day)
    }

    @inlinable
    public func daysInMonth(_ date: EthiopianDateInner) -> UInt8 {
        CopticArithmetic.daysInMonth(year: date.year, month: date.month)
    }

    @inlinable
    public func daysInYear(_ date: EthiopianDateInner) -> UInt16 {
        CopticArithmetic.isLeapYear(date.year) ? 366 : 365
    }

    @inlinable
    public func monthsInYear(_ date: EthiopianDateInner) -> UInt8 {
        13
    }

    @inlinable
    public func isInLeapYear(_ date: EthiopianDateInner) -> Bool {
        CopticArithmetic.isLeapYear(date.year)
    }

    // MARK: - Private

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y):
            // Extended year is stored in Amete Mihret coordinates for
            // arithmetic sharing with `Ethiopian`. Accept it as-is.
            return y
        case .eraYear(let era, let year):
            switch era {
            case "mundi":
                // Amete Alem year Y → Amete Mihret year (Y − 5500).
                return year - Ethiopian.ameteAlemOffset
            case "incar":
                return year
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

// Coptic calendar — 13 months, Julian-based leap year.
//
// Ported from ICU4X components/calendar/src/cal/coptic.rs (Unicode License).

import CalendarCore

/// The Coptic (Alexandrian) calendar.
///
/// 13 months: 12 months of 30 days + 1 epagomenal month of 5 days (6 in leap years).
/// Leap years follow Julian rules: every 4th year ((year+1) % 4 == 0).
/// Epoch: August 29, 284 CE (Julian) = Tout 1, 1 AM (Anno Martyrum).
///
/// Single era: `am` (Anno Martyrum / Era of the Martyrs).
public struct Coptic: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "coptic"

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> CopticDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return CopticDateInner(year: extYear, month: month.number, day: day)
    }

    @inlinable
    public func toRataDie(_ date: CopticDateInner) -> RataDie {
        CopticArithmetic.fixedFromCoptic(year: date.year, month: date.month, day: date.day)
    }

    @inlinable
    public func fromRataDie(_ rd: RataDie) -> CopticDateInner {
        let (y, m, d) = CopticArithmetic.copticFromFixed(rd)
        return CopticDateInner(year: y, month: m, day: d)
    }

    public func yearInfo(_ date: CopticDateInner) -> YearInfo {
        .era(EraYear(
            era: "am",
            year: date.year,
            extendedYear: date.year,
            ambiguity: .centuryRequired
        ))
    }

    public func monthInfo(_ date: CopticDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: CopticDateInner) -> UInt8 {
        date.day
    }

    public func dayOfYear(_ date: CopticDateInner) -> UInt16 {
        30 * UInt16(date.month - 1) + UInt16(date.day)
    }

    public func daysInMonth(_ date: CopticDateInner) -> UInt8 {
        CopticArithmetic.daysInMonth(year: date.year, month: date.month)
    }

    public func daysInYear(_ date: CopticDateInner) -> UInt16 {
        CopticArithmetic.isLeapYear(date.year) ? 366 : 365
    }

    public func monthsInYear(_ date: CopticDateInner) -> UInt8 {
        13
    }

    public func isInLeapYear(_ date: CopticDateInner) -> Bool {
        CopticArithmetic.isLeapYear(date.year)
    }

    // MARK: - Private

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(let era, let year):
            guard era == "am" else { throw DateNewError.invalidEra }
            return year
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else { throw DateNewError.monthNotInCalendar }
        guard month.number >= 1, month.number <= 13 else { throw DateNewError.monthNotInCalendar }
        let maxDay = CopticArithmetic.daysInMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }
    }
}

// MARK: - CopticDateInner

/// Internal representation of a Coptic calendar date.
public struct CopticDateInner: Equatable, Comparable, Hashable, Sendable {
    @usableFromInline let year: Int32
    @usableFromInline let month: UInt8  // 1-13
    @usableFromInline let day: UInt8

    @inlinable
    init(year: Int32, month: UInt8, day: UInt8) {
        self.year = year
        self.month = month
        self.day = day
    }

    public static func < (lhs: CopticDateInner, rhs: CopticDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

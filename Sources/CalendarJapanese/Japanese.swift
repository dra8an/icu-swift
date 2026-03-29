// Japanese calendar — Gregorian arithmetic with era overlay.
//
// Ported from ICU4X components/calendar/src/cal/japanese.rs (Unicode License).

import CalendarCore
import CalendarSimple

/// The Japanese calendar.
///
/// Identical arithmetic to the Gregorian calendar, but uses Japanese imperial eras
/// instead of CE/BCE. Built-in eras:
///
/// | Era | Code | Start Date |
/// |-----|------|------------|
/// | Meiji | `meiji` | 1868-10-23 |
/// | Taisho | `taisho` | 1912-07-30 |
/// | Showa | `showa` | 1926-12-25 |
/// | Heisei | `heisei` | 1989-01-08 |
/// | Reiwa | `reiwa` | 2019-05-01 |
///
/// Dates before Meiji 6 (1873) fall back to `ce`/`bce` eras, because the
/// lunisolar calendar was in use before then.
///
/// The era table is extensible: `JapaneseEraData` can be updated for future eras.
public struct Japanese: CalendarProtocol, Sendable {
    public typealias DateInner = IsoDateInner

    public static let calendarIdentifier = "japanese"

    /// The era table for this calendar instance.
    public let eraData: JapaneseEraData

    /// Creates a Japanese calendar with built-in era data (Meiji through Reiwa).
    public init() {
        self.eraData = .builtIn
    }

    /// Creates a Japanese calendar with custom era data.
    public init(eraData: JapaneseEraData) {
        self.eraData = eraData
    }

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
        let eraYear = eraData.eraYearFromExtended(
            extendedYear: date.year, month: date.month, day: date.day
        )
        return .era(eraYear)
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

    // MARK: - Private

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y):
            return y
        case .eraYear(let era, let year):
            return try eraData.extendedFromEraYear(era: era, year: year)
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else { throw DateNewError.monthNotInCalendar }
        guard month.number >= 1, month.number <= 12 else { throw DateNewError.monthNotInCalendar }
        let maxDay = GregorianArithmetic.daysInMonth(year: year, month: month.number)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }
    }
}

// MARK: - JapaneseEraData

/// Era data for the Japanese calendar.
///
/// Contains a sorted list of (start date, era code) pairs. The list is sorted
/// by start date descending for efficient lookup (most dates are in recent eras).
public struct JapaneseEraData: Sendable {
    /// Era entries sorted by start date descending (most recent first).
    let eras: [EraEntry]

    /// A single era entry.
    struct EraEntry: Sendable {
        let code: String
        let eraIndex: UInt8
        let startYear: Int32
        let startMonth: UInt8
        let startDay: UInt8
    }

    /// Built-in era data: Meiji through Reiwa.
    public static let builtIn = JapaneseEraData(eras: [
        EraEntry(code: "reiwa",  eraIndex: 6, startYear: 2019, startMonth: 5,  startDay: 1),
        EraEntry(code: "heisei", eraIndex: 5, startYear: 1989, startMonth: 1,  startDay: 8),
        EraEntry(code: "showa",  eraIndex: 4, startYear: 1926, startMonth: 12, startDay: 25),
        EraEntry(code: "taisho", eraIndex: 3, startYear: 1912, startMonth: 7,  startDay: 30),
        EraEntry(code: "meiji",  eraIndex: 2, startYear: 1868, startMonth: 10, startDay: 23),
    ])

    /// Convert era code + year-of-era to extended (Gregorian) year.
    func extendedFromEraYear(era: String, year: Int32) throws -> Int32 {
        // Check Gregorian eras first
        switch era {
        case "ce", "ad":
            return year
        case "bce", "bc":
            return 1 - year
        default:
            break
        }

        // Search for Japanese era
        for entry in eras {
            if entry.code == era {
                return year - 1 + entry.startYear
            }
        }

        throw DateNewError.invalidEra
    }

    /// Convert extended year + month + day to era year info.
    func eraYearFromExtended(extendedYear: Int32, month: UInt8, day: UInt8) -> EraYear {
        // Search for matching era (eras sorted descending by start date)
        for entry in eras {
            if dateOnOrAfter(
                year: extendedYear, month: month, day: day,
                startYear: entry.startYear, startMonth: entry.startMonth, startDay: entry.startDay
            ) {
                let yearOfEra = extendedYear - entry.startYear + 1

                // Meiji 1-5 (before 1873) fall back to CE, because the
                // lunisolar calendar was in use before Meiji 6.
                if entry.code == "meiji" && yearOfEra < 6 {
                    return ceBceEraYear(extendedYear: extendedYear)
                }

                return EraYear(
                    era: entry.code,
                    year: yearOfEra,
                    extendedYear: extendedYear,
                    ambiguity: .centuryRequired
                )
            }
        }

        // Before all Japanese eras: use CE/BCE
        return ceBceEraYear(extendedYear: extendedYear)
    }

    private func dateOnOrAfter(
        year: Int32, month: UInt8, day: UInt8,
        startYear: Int32, startMonth: UInt8, startDay: UInt8
    ) -> Bool {
        if year != startYear { return year > startYear }
        if month != startMonth { return month > startMonth }
        return day >= startDay
    }

    private func ceBceEraYear(extendedYear: Int32) -> EraYear {
        if extendedYear > 0 {
            return EraYear(
                era: "ce",
                year: extendedYear,
                extendedYear: extendedYear,
                ambiguity: .eraAndCenturyRequired
            )
        } else {
            return EraYear(
                era: "bce",
                year: 1 - extendedYear,
                extendedYear: extendedYear,
                ambiguity: .eraAndCenturyRequired
            )
        }
    }
}

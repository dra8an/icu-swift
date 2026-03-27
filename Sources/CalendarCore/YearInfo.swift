/// How a year is specified as input to date construction.
///
/// Supports two modes:
/// - Extended year: a single integer (year 0 exists, negative = BCE)
/// - Era year: an era code string + year within that era
///
/// `YearInput` conforms to `ExpressibleByIntegerLiteral`, so you can write
/// `2024` wherever a `YearInput` is expected.
public enum YearInput: Sendable {
    /// An extended year number. Year 0 exists and equals 1 BCE.
    case extended(Int32)

    /// A year within a named era (e.g., era: "ce", year: 2024).
    case eraYear(era: String, year: Int32)
}

extension YearInput: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int32) {
        self = .extended(value)
    }
}

// MARK: - YearInfo

/// Information about the year of a date.
///
/// Calendars with eras (Gregorian, Japanese, etc.) produce `.era(_)`.
/// Cyclic calendars (Chinese, Korean) produce `.cyclic(_)`.
public enum YearInfo: Sendable, Hashable {
    /// A year defined by an era and year-within-era.
    case era(EraYear)

    /// A cyclic year (e.g., Chinese 60-year cycle) with a related ISO year for disambiguation.
    case cyclic(CyclicYear)

    /// The extended year — a single number that can be compared across eras.
    ///
    /// For era-based calendars, this is typically anchored with year 1 as the first year
    /// of the calendar's primary era. For cyclic calendars, this returns the related ISO year.
    public var extendedYear: Int32 {
        switch self {
        case .era(let e): e.extendedYear
        case .cyclic(let c): c.relatedIso
        }
    }

    /// The era year information, if this is an era-based calendar.
    public var eraYear: EraYear? {
        if case .era(let e) = self { return e }
        return nil
    }

    /// The cyclic year information, if this is a cyclic calendar.
    public var cyclicYear: CyclicYear? {
        if case .cyclic(let c) = self { return c }
        return nil
    }

    /// A displayable year number: the era year for era calendars,
    /// or the related ISO year for cyclic calendars.
    public var displayYear: Int32 {
        switch self {
        case .era(let e): e.year
        case .cyclic(let c): c.relatedIso
        }
    }
}

// MARK: - EraYear

/// Year information for calendars that use eras (Gregorian, Japanese, Buddhist, etc.).
public struct EraYear: Sendable, Hashable {
    /// The era code as defined by CLDR (e.g., "ce", "bce", "reiwa", "be").
    public let era: String

    /// The numeric year within the era (always positive for well-formed dates).
    public let year: Int32

    /// The extended year — see `YearInfo.extendedYear`.
    public let extendedYear: Int32

    /// Whether the era/century is needed to unambiguously display this year.
    public let ambiguity: YearAmbiguity

    public init(era: String, year: Int32, extendedYear: Int32, ambiguity: YearAmbiguity = .unambiguous) {
        self.era = era
        self.year = year
        self.extendedYear = extendedYear
        self.ambiguity = ambiguity
    }
}

// MARK: - CyclicYear

/// Year information for cyclic calendars (Chinese, Korean).
///
/// The 60-year cycle uses 10 celestial stems × 12 terrestrial branches.
/// Since a cyclic year alone doesn't uniquely identify a date, the related
/// ISO year is provided for disambiguation.
public struct CyclicYear: Sendable, Hashable {
    /// The year within the 60-year cycle (1-60).
    public let yearOfCycle: UInt8

    /// The ISO year that corresponds to (or is closest to) this cyclic year.
    public let relatedIso: Int32

    public init(yearOfCycle: UInt8, relatedIso: Int32) {
        self.yearOfCycle = yearOfCycle
        self.relatedIso = relatedIso
    }
}

// MARK: - YearAmbiguity

/// Whether an era or century is required to unambiguously display a year.
///
/// For example, 2024 CE can be displayed as just "2024", but 50 BCE should
/// not be displayed as just "50" (era required), and 1931 CE should not be
/// displayed as "31" (century required).
public enum YearAmbiguity: Sendable, Hashable {
    /// The year is unambiguous without era or century.
    case unambiguous

    /// The century is required (e.g., don't abbreviate 1931 to 31).
    case centuryRequired

    /// The era is required (e.g., years in BCE).
    case eraRequired

    /// Both century and era are required.
    case eraAndCenturyRequired
}

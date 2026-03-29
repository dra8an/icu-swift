// Date duration type and supporting enums.
//
// Ported from ICU4X components/calendar/src/duration.rs (Unicode License).

/// A signed length of time in terms of years, months, weeks, and days.
///
/// Fields are unsigned; `isNegative` indicates the direction. All fields share the same sign.
/// A duration of "1 month" is stored as `months: 1, isNegative: false` without context
/// of how many days the month might be.
public struct DateDuration: Sendable, Equatable {
    /// Whether the duration is negative (all fields have the same sign).
    public var isNegative: Bool
    /// Number of years.
    public var years: UInt32
    /// Number of months.
    public var months: UInt32
    /// Number of weeks.
    public var weeks: UInt32
    /// Number of days.
    public var days: UInt64

    public init(
        isNegative: Bool = false,
        years: UInt32 = 0,
        months: UInt32 = 0,
        weeks: UInt32 = 0,
        days: UInt64 = 0
    ) {
        self.isNegative = isNegative
        self.years = years
        self.months = months
        self.weeks = weeks
        self.days = days
    }

    // MARK: - Factory Methods

    /// Creates a duration representing the given number of years (signed).
    public static func forYears(_ years: Int32) -> DateDuration {
        DateDuration(isNegative: years < 0, years: UInt32(abs(years)))
    }

    /// Creates a duration representing the given number of months (signed).
    public static func forMonths(_ months: Int32) -> DateDuration {
        DateDuration(isNegative: months < 0, months: UInt32(abs(months)))
    }

    /// Creates a duration representing the given number of weeks (signed).
    public static func forWeeks(_ weeks: Int32) -> DateDuration {
        DateDuration(isNegative: weeks < 0, weeks: UInt32(abs(weeks)))
    }

    /// Creates a duration representing the given number of days (signed).
    public static func forDays(_ days: Int64) -> DateDuration {
        DateDuration(isNegative: days < 0, days: UInt64(abs(days)))
    }

    /// Creates a zero duration.
    public static var zero: DateDuration {
        DateDuration()
    }

    // MARK: - Internal Arithmetic Helpers

    /// Add this duration's years to the given extended year.
    func addYearsTo(_ year: Int32) -> Int32 {
        if !isNegative {
            return year &+ Int32(years)
        } else {
            return year &- Int32(years)
        }
    }

    /// Add this duration's months to the given ordinal month, returning a signed offset.
    func addMonthsTo(_ month: UInt8) -> Int64 {
        if !isNegative {
            return Int64(month) + Int64(months)
        } else {
            return Int64(month) - Int64(months)
        }
    }

    /// Add this duration's weeks and days to the given day, returning a signed offset.
    func addWeeksAndDaysTo(_ day: UInt8) -> Int64 {
        if !isNegative {
            return Int64(day) + Int64(weeks) * 7 + Int64(days)
        } else {
            return Int64(day) - Int64(weeks) * 7 - Int64(days)
        }
    }

    /// Creates a duration from signed field values (all must have the same sign).
    static func fromSigned(years: Int64, months: Int64, weeks: Int64, days: Int64) -> DateDuration {
        let isNeg = years < 0 || months < 0 || weeks < 0 || days < 0
        return DateDuration(
            isNegative: isNeg,
            years: UInt32(clamping: abs(years)),
            months: UInt32(clamping: abs(months)),
            weeks: UInt32(clamping: abs(weeks)),
            days: UInt64(abs(days))
        )
    }

    /// Creates a duration in weeks+days from a signed total day count.
    static func forWeeksAndDays(_ totalDays: Int64) -> DateDuration {
        let isNeg = totalDays < 0
        let absDays = UInt64(abs(totalDays))
        return DateDuration(
            isNegative: isNeg,
            weeks: UInt32(absDays / 7),
            days: absDays % 7
        )
    }
}

/// How to handle out-of-range values during date arithmetic.
public enum Overflow: Sendable {
    /// Constrain to the nearest valid value (e.g., Jan 31 + 1 month = Feb 28).
    case constrain
    /// Reject and throw an error if any field is out of range.
    case reject
}

/// The unit for date duration operations (largest unit in `until`).
public enum DateDurationUnit: Sendable {
    case years
    case months
    case weeks
    case days
}

/// Errors from date arithmetic operations.
public enum DateAddError: Error, Sendable {
    /// The resulting date would overflow the valid range.
    case overflow
    /// The day is invalid for the resulting month (only with `.reject` overflow).
    case invalidDay(max: UInt8)
    /// The month doesn't exist in the resulting year (only with `.reject` overflow).
    case monthNotInYear
}

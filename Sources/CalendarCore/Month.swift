/// Representation of a month in a year.
///
/// A month has a "number" and a "leap" flag. In calendars without leap months
/// (e.g., Gregorian), the month with number N is always the Nth month of the year.
/// In lunisolar calendars (e.g., Hebrew, Chinese), a leap month may be inserted
/// without affecting the numbering of subsequent months.
///
/// For example, `Month.leap(2)` is the intercalary month that occurs after
/// `Month.new(2)`, even if the calendar considers it a variant of the following month.
///
/// This matches the "month code" concept from the Temporal proposal:
/// - `Month.new(7)` = "M07"
/// - `Month.leap(2)` = "M02L"
public struct Month: Sendable, Hashable {
    /// The month number (1-99). Not the same as ordinal position in the year
    /// when leap months are present.
    public let number: UInt8

    /// Whether this is a leap (intercalary) month.
    public let isLeap: Bool

    /// Creates a non-leap month with the given number.
    ///
    /// - Parameter number: The month number (1-99). Values above 99 are clamped.
    public static func new(_ number: UInt8) -> Month {
        Month(number: min(number, 99), isLeap: false)
    }

    /// Creates a leap month with the given number.
    ///
    /// - Parameter number: The month number (1-99). Values above 99 are clamped.
    public static func leap(_ number: UInt8) -> Month {
        Month(number: min(number, 99), isLeap: true)
    }

    /// The Temporal-compatible month code string (e.g., "M01", "M05L").
    public var code: MonthCode {
        MonthCode(number: number, isLeap: isLeap)
    }

    // Convenience factory methods for common months.
    public static func january() -> Month { .new(1) }
    public static func february() -> Month { .new(2) }
    public static func march() -> Month { .new(3) }
    public static func april() -> Month { .new(4) }
    public static func may() -> Month { .new(5) }
    public static func june() -> Month { .new(6) }
    public static func july() -> Month { .new(7) }
    public static func august() -> Month { .new(8) }
    public static func september() -> Month { .new(9) }
    public static func october() -> Month { .new(10) }
    public static func november() -> Month { .new(11) }
    public static func december() -> Month { .new(12) }
}

// MARK: - Comparable

extension Month: Comparable {
    public static func < (lhs: Month, rhs: Month) -> Bool {
        if lhs.number != rhs.number {
            return lhs.number < rhs.number
        }
        // Non-leap comes before leap of the same number
        return !lhs.isLeap && rhs.isLeap
    }
}

// MARK: - ExpressibleByIntegerLiteral

extension Month: ExpressibleByIntegerLiteral {
    /// Creates a non-leap month. `let m: Month = 5` is equivalent to `Month.new(5)`.
    public init(integerLiteral value: UInt8) {
        self = Month.new(value)
    }
}

// MARK: - CustomStringConvertible

extension Month: CustomStringConvertible {
    public var description: String {
        code.description
    }
}

/// String representation of a month, following the Temporal proposal format.
///
/// Format: "M01" through "M99", with optional "L" suffix for leap months.
/// - "M01" = January (or first month)
/// - "M13" = 13th month (some calendars)
/// - "M05L" = leap month after month 5
public struct MonthCode: Sendable, Hashable {
    /// The month number (1-99).
    public let number: UInt8

    /// Whether this is a leap month code.
    public let isLeap: Bool

    /// Creates a `MonthCode` from its components.
    public init(number: UInt8, isLeap: Bool) {
        self.number = number
        self.isLeap = isLeap
    }

    /// Parses a Temporal month code string like "M01" or "M05L".
    ///
    /// - Returns: `nil` if the string is not a valid month code.
    public init?(_ string: String) {
        let bytes = Array(string.utf8)
        switch bytes.count {
        case 3:
            guard bytes[0] == UInt8(ascii: "M"),
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[1]),
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[2]) else {
                return nil
            }
            self.number = (bytes[1] - UInt8(ascii: "0")) * 10 + (bytes[2] - UInt8(ascii: "0"))
            self.isLeap = false
        case 4:
            guard bytes[0] == UInt8(ascii: "M"),
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[1]),
                  (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(bytes[2]),
                  bytes[3] == UInt8(ascii: "L") else {
                return nil
            }
            self.number = (bytes[1] - UInt8(ascii: "0")) * 10 + (bytes[2] - UInt8(ascii: "0"))
            self.isLeap = true
        default:
            return nil
        }
        guard self.number >= 1, self.number <= 99 else { return nil }
    }
}

// MARK: - CustomStringConvertible

extension MonthCode: CustomStringConvertible {
    public var description: String {
        let tens = number / 10
        let ones = number % 10
        var result = "M\(tens)\(ones)"
        if isLeap { result += "L" }
        return result
    }
}

// MARK: - MonthInfo

/// Information about a month as it appears in a specific date.
///
/// Unlike `Month` which is an input type, `MonthInfo` is an output type
/// that includes the ordinal position of the month within its year.
public struct MonthInfo: Sendable, Hashable {
    /// The 1-based ordinal position of this month in the year.
    ///
    /// In calendars with leap months, this differs from `month.number`
    /// for months after the leap month. For example, in a Hebrew leap year,
    /// Adar I (the leap month, M05L) has ordinal 6, and Adar II (M06) has ordinal 7.
    public let ordinal: UInt8

    /// The month identity (number + leap flag).
    public let month: Month

    /// Creates a `MonthInfo`.
    public init(ordinal: UInt8, month: Month) {
        self.ordinal = ordinal
        self.month = month
    }

    /// The month number (not the ordinal).
    public var number: UInt8 { month.number }

    /// Whether this is a leap month.
    public var isLeap: Bool { month.isLeap }

    /// The Temporal-compatible month code.
    public var code: MonthCode { month.code }
}

/// A fixed day count from an epoch of January 1, year 1 ISO (R.D. 1).
///
/// This is the universal pivot representation for all calendar conversions.
/// Every calendar converts to and from `RataDie` — no direct calendar-to-calendar
/// conversion is needed.
///
/// The name comes from the Latin "rata die" (fixed day), as used by Reingold & Dershowitz
/// in "Calendrical Calculations."
///
/// Notable fixed points:
/// - R.D. 1 = January 1, 1 ISO (proleptic Gregorian)
/// - R.D. 719163 = January 1, 1970 (Unix epoch)
public struct RataDie: Sendable, Hashable {
    /// The day number. R.D. 1 = January 1, year 1 ISO.
    public let dayNumber: Int64

    /// Creates a `RataDie` from a raw day number.
    public init(_ dayNumber: Int64) {
        self.dayNumber = dayNumber
    }

    /// The `RataDie` corresponding to the Unix epoch (January 1, 1970).
    public static let unixEpoch = RataDie(719_163)

    /// Creates a `RataDie` from a count of days since the Unix epoch.
    public static func fromUnixEpochDays(_ days: Int64) -> RataDie {
        RataDie(days + unixEpoch.dayNumber)
    }

    /// Returns the number of days since the Unix epoch.
    public func toUnixEpochDays() -> Int64 {
        dayNumber - Self.unixEpoch.dayNumber
    }

    /// The valid range for dates (~±999,999 ISO years).
    ///
    /// This matches ICU4X's range, which is guaranteed to be at least as large as
    /// the Temporal specification's validity range (±100,000,000 days from 1970-01-01).
    public static let validRange: ClosedRange<RataDie> = RataDie(-365_000_000)...RataDie(365_000_000)
}

// MARK: - Comparable

extension RataDie: Comparable {
    public static func < (lhs: RataDie, rhs: RataDie) -> Bool {
        lhs.dayNumber < rhs.dayNumber
    }
}

// MARK: - Arithmetic

extension RataDie {
    /// Returns a new `RataDie` offset by the given number of days.
    public static func + (lhs: RataDie, rhs: Int64) -> RataDie {
        RataDie(lhs.dayNumber + rhs)
    }

    /// Returns a new `RataDie` offset backward by the given number of days.
    public static func - (lhs: RataDie, rhs: Int64) -> RataDie {
        RataDie(lhs.dayNumber - rhs)
    }

    /// Returns the number of days between two dates.
    public static func - (lhs: RataDie, rhs: RataDie) -> Int64 {
        lhs.dayNumber - rhs.dayNumber
    }
}

// MARK: - CustomStringConvertible

extension RataDie: CustomStringConvertible {
    public var description: String {
        "RD(\(dayNumber))"
    }
}

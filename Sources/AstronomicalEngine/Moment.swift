// Moment — a fractional RataDie representing a point in time.
//
// Used by astronomical calculations where sub-day precision is needed.
// Moment(730120.5) = noon on January 1, 2000 (J2000.0).

import CalendarCore

/// A point in time as a fractional RataDie value.
///
/// While `RataDie` represents whole days, `Moment` represents an exact instant
/// including the fractional day. Noon is 0.5, midnight is 0.0.
///
/// The relationship to Julian Day: `Moment = JD - 1721424.5`
public struct Moment: Sendable, Comparable, Equatable {
    /// The fractional RataDie value.
    public let inner: Double

    public init(_ value: Double) {
        self.inner = value
    }

    /// The whole-day RataDie (floor of the moment).
    public var rataDie: RataDie {
        RataDie(Int64(inner.rounded(.down)))
    }

    /// Create a Moment from a RataDie (at midnight, start of day).
    public static func fromRataDie(_ rd: RataDie) -> Moment {
        Moment(Double(rd.dayNumber))
    }

    // MARK: - Julian Day Conversion

    /// The offset between Julian Day and RataDie.
    /// JD 0 corresponds to RD -1721424.5 (noon Jan 1, 4713 BCE Julian).
    private static let jdOffset: Double = 1721424.5

    /// Create a Moment from a Julian Day number.
    public static func fromJulianDay(_ jd: Double) -> Moment {
        Moment(jd - jdOffset)
    }

    /// Convert this Moment to a Julian Day number.
    public func toJulianDay() -> Double {
        inner + Self.jdOffset
    }

    // MARK: - Arithmetic

    public static func + (lhs: Moment, rhs: Double) -> Moment {
        Moment(lhs.inner + rhs)
    }

    public static func - (lhs: Moment, rhs: Double) -> Moment {
        Moment(lhs.inner - rhs)
    }

    public static func - (lhs: Moment, rhs: Moment) -> Double {
        lhs.inner - rhs.inner
    }

    // MARK: - Comparable

    public static func < (lhs: Moment, rhs: Moment) -> Bool {
        lhs.inner < rhs.inner
    }
}

// MARK: - Constants

extension Moment {
    /// Noon on January 1, 2000 (J2000.0 epoch).
    public static let j2000 = Moment(730120.5)
}

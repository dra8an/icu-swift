// Mathematical helpers for astronomical calculations.

import Foundation  // for sin, cos, tan, asin, atan2, sqrt, floor

/// Evaluate a polynomial at x: coefficients[0] + coefficients[1]*x + coefficients[2]*x^2 + ...
func poly(_ x: Double, _ coefficients: [Double]) -> Double {
    var result = 0.0
    var power = 1.0
    for c in coefficients {
        result += c * power
        power *= x
    }
    return result
}

/// Normalize an angle to [0, 360).
func mod360(_ x: Double) -> Double {
    var result = x.truncatingRemainder(dividingBy: 360.0)
    if result < 0 { result += 360.0 }
    return result
}

/// Convert degrees to radians.
func toRadians(_ degrees: Double) -> Double {
    degrees * .pi / 180.0
}

/// Convert radians to degrees.
func toDegrees(_ radians: Double) -> Double {
    radians * 180.0 / .pi
}

/// Sine of an angle in degrees.
func sinDeg(_ degrees: Double) -> Double {
    sin(toRadians(degrees))
}

/// Cosine of an angle in degrees.
func cosDeg(_ degrees: Double) -> Double {
    cos(toRadians(degrees))
}

/// Tangent of an angle in degrees.
func tanDeg(_ degrees: Double) -> Double {
    tan(toRadians(degrees))
}

/// Euclidean floor division for doubles (result is always towards -∞).
func divEuclidF64(_ n: Double, _ d: Double) -> Double {
    let (a, b) = (n / d, n.truncatingRemainder(dividingBy: d))
    if n >= 0.0 || b == 0.0 {
        return a
    } else {
        return a - 1.0
    }
}

/// Euclidean remainder for doubles (result is always non-negative when d > 0).
func remEuclidF64(_ n: Double, _ d: Double) -> Double {
    var r = n.truncatingRemainder(dividingBy: d)
    if r < 0 { r += d }
    return r
}

/// Binary search for the moment where a predicate transitions from false to true.
///
/// `lo` and `hi` bracket the transition. Returns the moment where the predicate
/// first becomes true, to within about 1e-5 day precision (~1 second).
func binarySearchMoment(lo: Double, hi: Double, predicate: (Double) -> Bool) -> Double {
    var lo = lo
    var hi = hi
    while hi - lo > 1e-5 {
        let mid = (lo + hi) / 2.0
        if predicate(mid) {
            hi = mid
        } else {
            lo = mid
        }
    }
    return (lo + hi) / 2.0
}

/// Find the next moment >= `start` (checking at integer steps) where `predicate` is true,
/// then refine within that step.
func nextMoment(start: Double, predicate: (Double) -> Bool) -> Double {
    var t = start.rounded(.up)
    while !predicate(t) {
        t += 1.0
    }
    return t
}

/// Invert an angular function: find the moment in [lower, upper] where
/// `f(moment) = target` (mod 360), given that f is monotonically increasing.
func invertAngular(
    target: Double,
    lower: Double,
    upper: Double,
    precision: Double = 1e-5,
    f: (Double) -> Double
) -> Double {
    binarySearchMoment(lo: lower, hi: upper) { moment in
        mod360(f(moment) - target) < 180.0
    }
}

// MARK: - Constants

/// Mean synodic month in days (Reingold & Dershowitz).
let MEAN_SYNODIC_MONTH: Double = 29.530588861

/// Mean tropical year in days.
let MEAN_TROPICAL_YEAR: Double = 365.242189

/// The moment of the first new moon of the CE (January 11, 1 CE).
let NEW_MOON_ZERO = Moment(11.458922815770109)

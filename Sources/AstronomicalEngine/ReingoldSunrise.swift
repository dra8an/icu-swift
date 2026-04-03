// Reingold sunrise, sunset, and related functions.
import CalendarCore
//
// Ported from ICU4X calendrical_calculations/src/astronomy.rs (Apache-2.0).

import Foundation

extension Astronomical {

    // MARK: - Declination & Right Ascension

    /// Declination of an object at ecliptic latitude `beta` and longitude `lambda` (degrees).
    public static func declination(_ moment: Moment, beta: Double, lambda: Double) -> Double {
        let varepsilon = obliquity(moment)
        let result = asin(
            sinDeg(beta) * cosDeg(varepsilon)
            + cosDeg(beta) * sinDeg(varepsilon) * sinDeg(lambda)
        )
        return mod360(toDegrees(result))
    }

    /// Right ascension of an object at ecliptic latitude `beta` and longitude `lambda` (degrees).
    public static func rightAscension(_ moment: Moment, beta: Double, lambda: Double) -> Double {
        let varepsilon = obliquity(moment)
        let y = sinDeg(lambda) * cosDeg(varepsilon) - tanDeg(beta) * sinDeg(varepsilon)
        let x = cosDeg(lambda)
        return mod360(toDegrees(atan2(y, x)))
    }

    // MARK: - Equation of Time

    /// Equation of time: difference between apparent solar time and mean time (fraction of a day).
    public static func equationOfTime(_ moment: Moment) -> Double {
        let c = julianCenturies(moment)
        let lambda = poly(c, [280.46645, 36000.76983, 0.0003032])
        let anomaly = poly(c, [357.52910, 35999.05030, -0.0001559, -0.00000048])
        let eccentricity = poly(c, [0.016708617, -0.000042037, -0.0000001236])
        let varepsilon = obliquity(moment)
        var y = tanDeg(varepsilon / 2.0)
        y = y * y
        let equation = (y * sinDeg(2.0 * lambda)
            - 2.0 * eccentricity * sinDeg(anomaly)
            + 4.0 * eccentricity * y * sinDeg(anomaly) * cosDeg(2.0 * lambda)
            - 0.5 * y * y * sinDeg(4.0 * lambda)
            - 1.25 * eccentricity * eccentricity * sinDeg(2.0 * anomaly)
        ) / (2.0 * .pi)

        return equation.sign == .minus
            ? -min(abs(equation), 0.5)
            : min(equation, 0.5)
    }

    // MARK: - Apparent → Local Time

    /// Convert apparent solar time to local mean time.
    static func localFromApparent(_ moment: Moment, location: Location) -> Moment {
        moment - equationOfTime(location.universalFromLocal(moment))
    }

    // MARK: - Sine Offset (for sunrise/sunset)

    /// The sine of the angular offset of the sun at a given moment and location.
    public static func sineOffset(_ moment: Moment, location: Location, alpha: Double) -> Double {
        let phi = location.latitude
        let tee = location.universalFromLocal(moment)
        let c = julianCenturies(tee)
        let delta = declination(tee, beta: 0.0, lambda: solarLongitude(c))

        return (tanDeg(phi) * tanDeg(delta))
            + (sinDeg(alpha) / (cosDeg(delta) * cosDeg(phi)))
    }

    // MARK: - Refraction

    /// Atmospheric refraction angle at the given location (degrees).
    public static func refraction(_ location: Location) -> Double {
        let h = max(location.elevation, 0.0)
        let earthR = 6.372e6
        let dip = toDegrees(acos(earthR / (earthR + h)))
        return (34.0 / 60.0) + dip + (19.0 / 3600.0) * sqrt(h)
    }

    // MARK: - Moment of Depression

    /// Approximate moment when the sun reaches depression angle `alpha` below the horizon.
    /// `early` = true for morning (sunrise), false for evening (sunset).
    static func approxMomentOfDepression(
        _ moment: Moment, location: Location, alpha: Double, early: Bool
    ) -> Moment? {
        let date = floor(moment.inner)
        let alt: Double
        if alpha >= 0 {
            alt = early ? date : date + 1.0
        } else {
            alt = date + 0.5
        }

        let value: Double
        if abs(sineOffset(moment, location: location, alpha: alpha)) > 1.0 {
            value = sineOffset(Moment(alt), location: location, alpha: alpha)
        } else {
            value = sineOffset(moment, location: location, alpha: alpha)
        }

        guard abs(value) <= 1.0 else { return nil }

        let offset = remEuclidF64(toDegrees(asin(value)) / 360.0 + 0.5, 1.0) - 0.5

        let result = Moment(date + (early ? (6.0 / 24.0) - offset : (18.0 / 24.0) + offset))
        return localFromApparent(result, location: location)
    }

    /// Refined moment of depression (iterative).
    static func momentOfDepression(
        _ approx: Moment, location: Location, alpha: Double, early: Bool
    ) -> Moment? {
        guard let moment = approxMomentOfDepression(approx, location: location, alpha: alpha, early: early) else {
            return nil
        }
        if abs(approx - moment) < 30.0 {
            return moment
        }
        return momentOfDepression(moment, location: location, alpha: alpha, early: early)
    }

    // MARK: - Sunrise & Sunset

    /// Moment of sunrise at the given location on the date of the given moment.
    /// Returns `nil` if no sunrise (polar regions).
    public static func sunrise(at moment: Moment, location: Location) -> Moment? {
        let alpha = refraction(location) + (16.0 / 60.0)  // Sun's apparent radius
        let date = floor(moment.inner)
        let approx = Moment(date + 0.25)  // ~6 AM local approximation

        guard let result = momentOfDepression(approx, location: location, alpha: alpha, early: true) else {
            return nil
        }
        return location.standardFromUniversal(location.universalFromLocal(result))
    }

    /// Moment of sunset at the given location on the date of the given moment.
    /// Returns `nil` if no sunset (polar regions).
    public static func sunset(at moment: Moment, location: Location) -> Moment? {
        let alpha = refraction(location) + (16.0 / 60.0)
        let date = floor(moment.inner)
        let approx = Moment(date + 0.75)  // ~6 PM local approximation

        guard let result = momentOfDepression(approx, location: location, alpha: alpha, early: false) else {
            return nil
        }
        return location.standardFromUniversal(location.universalFromLocal(result))
    }
}

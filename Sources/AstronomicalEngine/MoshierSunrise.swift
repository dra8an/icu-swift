// MoshierSunrise — Sunrise/sunset using the Moshier engine.
import CalendarCore
//
// Refactored from Hindu calendar project's Rise.swift.
// Class → enum with static methods. Delegates solar position to MoshierSolar.

import Foundation

/// Sunrise and sunset calculations using Moshier solar positions.
///
/// Thread-safe: all methods are static, no mutable shared state.
public enum MoshierSunrise {

    private static let DEG2RAD = Double.pi / 180.0
    private static let RAD2DEG = 180.0 / Double.pi
    private static let SOLAR_SEMIDIAM_ARCMIN = 16.0

    private static func normalizeDeg(_ d: Double) -> Double {
        var d = d.truncatingRemainder(dividingBy: 360.0)
        if d < 0 { d += 360.0 }
        return d
    }

    private static func sinclairRefractionHorizon(_ atpress: Double, _ attemp: Double) -> Double {
        var r = 34.46
        r = ((atpress - 80.0) / 930.0 / (1.0 + 0.00008 * (r + 39.0) * (attemp - 10.0)) * r) / 60.0
        return r
    }

    private static func siderealTime0h(_ jd0h: Double) -> Double {
        let T = (jd0h - 2451545.0) / 36525.0
        let T2 = T * T
        let T3 = T2 * T
        let theta = 100.46061837 + 36000.770053608 * T + 0.000387933 * T2 - T3 / 38710000.0
        return normalizeDeg(theta)
    }

    private static func riseSetForDate(_ jd0h: Double, _ lon: Double, _ lat: Double,
                                        _ h0: Double, _ isRise: Bool) -> Double {
        let phi = lat * DEG2RAD

        var theta0 = siderealTime0h(jd0h)
        let jdNoon = jd0h + 0.5
        let dpsi = MoshierSolar.nutationLongitude(jdNoon)
        let eps = MoshierSolar.meanObliquityUt(jdNoon)
        theta0 += dpsi * cos(eps * DEG2RAD)

        let ra = MoshierSolar.solarRa(jdNoon)
        let decl = MoshierSolar.solarDeclination(jdNoon)

        let cosH0 = (sin(h0 * DEG2RAD) - sin(phi) * sin(decl * DEG2RAD))
            / (cos(phi) * cos(decl * DEG2RAD))

        if cosH0 < -1.0 || cosH0 > 1.0 {
            return 0.0
        }

        let H0deg = acos(cosH0) * RAD2DEG

        var m0 = (ra - lon - theta0) / 360.0
        m0 = m0 - floor(m0)

        var m: Double
        if isRise {
            m = m0 - H0deg / 360.0
        } else {
            m = m0 + H0deg / 360.0
        }
        m = m - floor(m)

        for _ in 0..<10 {
            let jdTrial = jd0h + m

            let raI = MoshierSolar.solarRa(jdTrial)
            let declI = MoshierSolar.solarDeclination(jdTrial)

            let theta = theta0 + 360.985647 * m

            var H = normalizeDeg(theta + lon - raI)
            if H > 180.0 { H -= 360.0 }

            let sinH = sin(phi) * sin(declI * DEG2RAD)
                + cos(phi) * cos(declI * DEG2RAD) * cos(H * DEG2RAD)
            let h = asin(sinH) * RAD2DEG

            let denom = 360.0 * cos(declI * DEG2RAD) * cos(phi) * sin(H * DEG2RAD)
            if abs(denom) < 1e-12 { break }
            let dm = (h - h0) / denom
            m += dm

            if abs(dm) < 0.0000001 { break }
        }

        if isRise && m > 0.75 { m -= 1.0 }
        if !isRise && m < 0.25 { m += 1.0 }

        return jd0h + m
    }

    private static func riseSet(_ jdUt: Double, _ lon: Double, _ lat: Double,
                                 _ alt: Double, _ isRise: Bool) -> Double {
        var atpress = 1013.25
        if alt > 0 {
            atpress = 1013.25 * pow(1.0 - 0.0065 * alt / 288.0, 5.255)
        }
        var h0 = -sinclairRefractionHorizon(atpress, 0.0)
        h0 -= SOLAR_SEMIDIAM_ARCMIN / 60.0
        // Horizon dip not applied: inland cities on flat terrain have no
        // ocean-visible horizon, so the dip formula is not appropriate.

        let ymd = MoshierSolar.jdToYMD(jdUt)
        let jd0h = MoshierSolar.ymdToJD(year: ymd.year, month: ymd.month, day: ymd.day, hour: 0.0)

        var result = riseSetForDate(jd0h, lon, lat, h0, isRise)
        if result > 0 && result >= jdUt - 0.0001 {
            return result
        }

        result = riseSetForDate(jd0h + 1.0, lon, lat, h0, isRise)
        return result
    }

    // MARK: - Public API (Julian Day)

    /// Sunrise as JD (UT) for a given JD, longitude (degrees), latitude (degrees),
    /// and altitude (meters). Returns 0 if no rise.
    public static func sunrise(_ jdUt: Double, _ lon: Double, _ lat: Double, _ alt: Double) -> Double {
        return riseSet(jdUt, lon, lat, alt, true)
    }

    /// Sunset as JD (UT) for a given JD, longitude (degrees), latitude (degrees),
    /// and altitude (meters). Returns 0 if no set.
    public static func sunset(_ jdUt: Double, _ lon: Double, _ lat: Double, _ alt: Double) -> Double {
        return riseSet(jdUt, lon, lat, alt, false)
    }

    // MARK: - Public API (Moment / Location)

    /// Sunrise at the given Moment and Location. Returns nil if the sun doesn't rise.
    public static func sunrise(at moment: Moment, location: Location) -> Moment? {
        let jd = moment.toJulianDay()
        let result = sunrise(jd, location.longitude, location.latitude, location.elevation)
        if result == 0.0 { return nil }
        return Moment.fromJulianDay(result)
    }

    /// Sunset at the given Moment and Location. Returns nil if the sun doesn't set.
    public static func sunset(at moment: Moment, location: Location) -> Moment? {
        let jd = moment.toJulianDay()
        let result = sunset(jd, location.longitude, location.latitude, location.elevation)
        if result == 0.0 { return nil }
        return Moment.fromJulianDay(result)
    }
}

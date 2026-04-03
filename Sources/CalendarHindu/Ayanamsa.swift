// Lahiri ayanamsa calculation — converts tropical to sidereal longitude.
//
// Ported from hindu-calendar/swift/Sources/HinduCalendar/Ephemeris/Ayanamsa.swift.
// Uses IAU 1976 3D equatorial precession with the Lahiri epoch.
//
// CRITICAL: The ayanamsa returned is the MEAN ayanamsa (without nutation).
// Nutation cancels in sidereal calculations:
//   sidereal = (tropical + Δψ) − (ayanamsa + Δψ) = tropical − ayanamsa
// Adding nutation to ayanamsa would double-count it.

import Foundation
import CalendarCore
import AstronomicalEngine

/// Lahiri ayanamsa calculation for Hindu calendar sidereal longitude.
public enum HinduAyanamsa {

    private static let DEG2RAD = Double.pi / 180.0
    private static let RAD2DEG = 180.0 / Double.pi
    private static let J2000: Double = 2451545.0

    /// Lahiri reference epoch: September 22, 1956 (JD 2435553.5).
    private static let LAHIRI_T0: Double = 2435553.5

    /// Lahiri ayanamsa at the reference epoch (degrees).
    /// From Swiss Ephemeris sweph.h: 23.250182778° − 0.004658035° = 23.245524743°
    private static let LAHIRI_AYAN_T0: Double = 23.245524743

    // MARK: - IAU 1976 Precession

    /// IAU 1976 precession angles (Z, z, theta) in radians.
    private static func iau1976PrecessionAngles(_ T: Double) -> (Z: Double, z: Double, theta: Double) {
        let Z = ((0.017998 * T + 0.30188) * T + 2306.2181) * T * DEG2RAD / 3600.0
        let z = ((0.018203 * T + 1.09468) * T + 2306.2181) * T * DEG2RAD / 3600.0
        let theta = ((-0.041833 * T - 0.42665) * T + 2004.3109) * T * DEG2RAD / 3600.0
        return (Z, z, theta)
    }

    /// Precess equatorial coordinates between epochs.
    /// `direction > 0`: from J2000 to target epoch.
    /// `direction < 0`: from target epoch to J2000.
    private static func precessEquatorial(_ x: inout [Double], _ J: Double, _ direction: Int) {
        if J == J2000 { return }

        let T = (J - J2000) / 36525.0
        let angles = iau1976PrecessionAngles(T)
        let Z = angles.Z, z = angles.z, theta = angles.theta

        let costh = cos(theta), sinth = sin(theta)
        let cosZ = cos(Z), sinZ = sin(Z)
        let cosz = cos(z), sinz = sin(z)
        let A = cosZ * costh
        let B = sinZ * costh

        var r = [0.0, 0.0, 0.0]
        if direction > 0 {
            r[0] = (A * cosz - sinZ * sinz) * x[0] + (A * sinz + sinZ * cosz) * x[1] + cosZ * sinth * x[2]
            r[1] = -(B * cosz + cosZ * sinz) * x[0] - (B * sinz - cosZ * cosz) * x[1] - sinZ * sinth * x[2]
            r[2] = -sinth * cosz * x[0] - sinth * sinz * x[1] + costh * x[2]
        } else {
            r[0] = (A * cosz - sinZ * sinz) * x[0] - (B * cosz + cosZ * sinz) * x[1] - sinth * cosz * x[2]
            r[1] = (A * sinz + sinZ * cosz) * x[0] - (B * sinz - cosZ * cosz) * x[1] - sinth * sinz * x[2]
            r[2] = cosZ * sinth * x[0] - sinZ * sinth * x[1] + costh * x[2]
        }
        x[0] = r[0]; x[1] = r[1]; x[2] = r[2]
    }

    /// Laskar obliquity at a given JD (TT), in radians.
    private static func obliquityIau1976(_ jdTt: Double) -> Double {
        let T = (jdTt - J2000) / 36525.0
        let U = T / 100.0
        let eps = 23.0 + 26.0 / 60.0 + 21.448 / 3600.0
            + (-4680.93 * U - 1.55 * U * U + 1999.25 * U * U * U
            - 51.38 * U * U * U * U - 249.67 * U * U * U * U * U
            - 39.05 * U * U * U * U * U * U + 7.12 * U * U * U * U * U * U * U
            + 27.87 * U * U * U * U * U * U * U * U + 5.79 * U * U * U * U * U * U * U * U * U
            + 2.45 * U * U * U * U * U * U * U * U * U * U) / 3600.0
        return eps * DEG2RAD
    }

    /// Rotate equatorial coordinates to ecliptic.
    private static func equatorialToEcliptic(_ x: inout [Double], _ eps: Double) {
        let c = cos(eps), s = sin(eps)
        let y1 = c * x[1] + s * x[2]
        let z1 = -s * x[1] + c * x[2]
        x[1] = y1
        x[2] = z1
    }

    // MARK: - Public API

    /// Compute the Lahiri ayanamsa (degrees) at a given Julian Day (UT).
    ///
    /// Uses the Moshier Delta-T for UT→TT conversion.
    /// Returns the mean ayanamsa (without nutation).
    public static func ayanamsa(_ jdUt: Double) -> Double {
        let jdTt = jdUt + MoshierSolar.deltaT(jdUt)

        // Start with vernal point (1, 0, 0) at the target date
        var x = [1.0, 0.0, 0.0]

        // Precess from target → J2000
        precessEquatorial(&x, jdTt, +1)
        // Precess from J2000 → Lahiri epoch
        precessEquatorial(&x, LAHIRI_T0, -1)

        // Rotate to ecliptic of Lahiri epoch
        let epsT0 = obliquityIau1976(LAHIRI_T0)
        equatorialToEcliptic(&x, epsT0)

        // Get polar longitude
        let lon = atan2(x[1], x[0]) * RAD2DEG

        // Ayanamsa = negative longitude + reference value
        var ayan = -lon + LAHIRI_AYAN_T0

        ayan = ayan.truncatingRemainder(dividingBy: 360.0)
        if ayan < 0 { ayan += 360.0 }

        return ayan
    }

    /// Compute sidereal solar longitude (degrees) at a given Julian Day (UT).
    ///
    /// `sidereal = tropical − ayanamsa`
    public static func siderealSolarLongitude(_ jdUt: Double) -> Double {
        let tropical = MoshierSolar.solarLongitude(jdUt)
        let ayan = ayanamsa(jdUt)
        var sidereal = tropical - ayan
        if sidereal < 0 { sidereal += 360.0 }
        return sidereal
    }
}

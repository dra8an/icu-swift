// MoshierEngine — AstronomicalEngineProtocol conformance using
// Moshier VSOP87/DE404 ephemeris.
//
// High precision for the modern era (~1700-2150).
// Delegates to MoshierSolar, MoshierLunar, and MoshierSunrise.

import Foundation

/// Astronomical engine using Moshier VSOP87 (solar) and DE404 (lunar) ephemeris.
///
/// This engine provides high-precision astronomical calculations suitable for
/// the modern era (~1700-2150). For dates outside this range, use ReingoldEngine
/// or HybridEngine.
public struct MoshierEngine: AstronomicalEngineProtocol, Sendable {

    public init() {}

    public func solarLongitude(at moment: Moment) -> Double {
        MoshierSolar.solarLongitude(at: moment)
    }

    public func lunarLongitude(at moment: Moment) -> Double {
        MoshierLunar.lunarLongitude(at: moment)
    }

    public func newMoonBefore(_ moment: Moment) -> Moment {
        MoshierEngine.newMoonBefore(moment)
    }

    public func newMoonAtOrAfter(_ moment: Moment) -> Moment {
        MoshierEngine.newMoonAtOrAfter(moment)
    }

    public func sunrise(at moment: Moment, location: Location) -> Moment? {
        MoshierSunrise.sunrise(at: moment, location: location)
    }

    public func sunset(at moment: Moment, location: Location) -> Moment? {
        MoshierSunrise.sunset(at: moment, location: location)
    }

    // MARK: - New Moon Detection

    // For new moon detection, we use the Reingold nth_new_moon algorithm
    // (which is fast and accurate for finding approximate new moon times)
    // and then optionally refine with Moshier longitude calculations.
    // This avoids the complexity of bisection search on the Moshier phase function.

    private static func newMoonBefore(_ moment: Moment) -> Moment {
        // Use Reingold's algorithm for the initial estimate
        let reingoldNm = Astronomical.newMoonBefore(moment)

        // Refine using Moshier: search near the Reingold estimate for where
        // Moshier lunar phase crosses 0. The Reingold estimate is typically
        // within a few hours of the true new moon.
        return refineMoshierNewMoon(near: reingoldNm)
    }

    private static func newMoonAtOrAfter(_ moment: Moment) -> Moment {
        let reingoldNm = Astronomical.newMoonAtOrAfter(moment)
        return refineMoshierNewMoon(near: reingoldNm)
    }

    /// Refine a new moon estimate using Moshier lunar/solar longitudes.
    /// Searches within ±1 day of the estimate for where the lunar phase crosses 0.
    private static func refineMoshierNewMoon(near estimate: Moment) -> Moment {
        let lo = estimate.inner - 1.0
        let hi = estimate.inner + 1.0

        let result = binarySearchMoment(lo: lo, hi: hi) { t in
            let lunar = MoshierLunar.lunarLongitude(at: Moment(t))
            let solar = MoshierSolar.solarLongitude(at: Moment(t))
            let phase = mod360(lunar - solar)
            return phase < 180.0
        }

        return Moment(result)
    }
}

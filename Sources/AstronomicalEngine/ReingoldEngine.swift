// ReingoldEngine — AstronomicalEngineProtocol conformance using
import CalendarCore
// Reingold & Dershowitz / Meeus polynomial approximations.
//
// Valid for a very wide date range (±10,000 years).
// Lower precision than Moshier for the modern era, but sufficient
// for calendar calculations.

/// Astronomical engine using Meeus polynomial approximations from
/// "Calendrical Calculations" by Reingold & Dershowitz.
///
/// This engine is valid for a very wide date range (±10,000 years)
/// and provides sufficient precision for calendar computations.
public struct ReingoldEngine: AstronomicalEngineProtocol, Sendable {

    public init() {}

    public func solarLongitude(at moment: Moment) -> Double {
        let c = Astronomical.julianCenturies(moment)
        return Astronomical.solarLongitude(c)
    }

    public func lunarLongitude(at moment: Moment) -> Double {
        let c = Astronomical.julianCenturies(moment)
        return Astronomical.lunarLongitude(c)
    }

    public func newMoonBefore(_ moment: Moment) -> Moment {
        Astronomical.newMoonBefore(moment)
    }

    public func newMoonAtOrAfter(_ moment: Moment) -> Moment {
        Astronomical.newMoonAtOrAfter(moment)
    }

    public func sunrise(at moment: Moment, location: Location) -> Moment? {
        Astronomical.sunrise(at: moment, location: location)
    }

    public func sunset(at moment: Moment, location: Location) -> Moment? {
        Astronomical.sunset(at: moment, location: location)
    }
}

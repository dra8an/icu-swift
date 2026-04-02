// HybridEngine — dispatches to Moshier in the modern range, Reingold outside.
//
// Moshier (VSOP87/DE404) is more accurate but only valid ~1700-2150.
// Reingold (Meeus polynomials) covers ±10,000 years at lower precision.

import CalendarCore

/// A hybrid astronomical engine that uses Moshier (VSOP87/DE404) for the modern
/// range (1700-2150 CE) and falls back to Reingold (Meeus) outside that range.
///
/// This gives the best of both worlds: high precision for dates relevant to
/// modern observational calendars, and wide coverage for historical dates.
public struct HybridEngine: AstronomicalEngineProtocol, Sendable {

    // RD for Jan 1, 1700 and Jan 1, 2150
    private static let modernStart: Double = 620654.0   // ~1700-01-01
    private static let modernEnd: Double = 785010.0     // ~2150-01-01

    private let moshier = MoshierEngine()
    private let reingold = ReingoldEngine()

    public init() {}

    private func isModern(_ moment: Moment) -> Bool {
        moment.inner >= Self.modernStart && moment.inner <= Self.modernEnd
    }

    public func solarLongitude(at moment: Moment) -> Double {
        if isModern(moment) {
            return moshier.solarLongitude(at: moment)
        }
        return reingold.solarLongitude(at: moment)
    }

    public func lunarLongitude(at moment: Moment) -> Double {
        if isModern(moment) {
            return moshier.lunarLongitude(at: moment)
        }
        return reingold.lunarLongitude(at: moment)
    }

    public func newMoonBefore(_ moment: Moment) -> Moment {
        if isModern(moment) {
            return moshier.newMoonBefore(moment)
        }
        return reingold.newMoonBefore(moment)
    }

    public func newMoonAtOrAfter(_ moment: Moment) -> Moment {
        if isModern(moment) {
            return moshier.newMoonAtOrAfter(moment)
        }
        return reingold.newMoonAtOrAfter(moment)
    }

    public func sunrise(at moment: Moment, location: Location) -> Moment? {
        if isModern(moment) {
            return moshier.sunrise(at: moment, location: location)
        }
        return reingold.sunrise(at: moment, location: location)
    }

    public func sunset(at moment: Moment, location: Location) -> Moment? {
        if isModern(moment) {
            return moshier.sunset(at: moment, location: location)
        }
        return reingold.sunset(at: moment, location: location)
    }
}

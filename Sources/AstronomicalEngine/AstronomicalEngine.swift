// AstronomicalEngine protocol — the contract for astronomical calculations.
import CalendarCore

/// Protocol for astronomical calculation engines.
///
/// Provides solar/lunar positions and sunrise/sunset calculations needed by
/// Chinese, Dangi, Islamic observational, and Hindu calendars.
///
/// Two implementations:
/// - `ReingoldEngine`: Meeus polynomial approximations, valid ±10,000 years
/// - `MoshierEngine`: VSOP87/DE404, high precision, valid ~1700-2150
/// - `HybridEngine`: dispatches to Moshier in modern range, Reingold outside
public protocol AstronomicalEngineProtocol: Sendable {
    /// Solar longitude in degrees [0, 360) at the given moment.
    func solarLongitude(at moment: Moment) -> Double

    /// Lunar longitude in degrees [0, 360) at the given moment.
    func lunarLongitude(at moment: Moment) -> Double

    /// Moment of the new moon immediately before the given moment.
    func newMoonBefore(_ moment: Moment) -> Moment

    /// Moment of the new moon at or after the given moment.
    func newMoonAtOrAfter(_ moment: Moment) -> Moment

    /// Moment of sunrise on the given date at the given location.
    /// Returns `nil` for polar regions where the sun doesn't rise.
    func sunrise(at moment: Moment, location: Location) -> Moment?

    /// Moment of sunset on the given date at the given location.
    /// Returns `nil` for polar regions where the sun doesn't set.
    func sunset(at moment: Moment, location: Location) -> Moment?
}

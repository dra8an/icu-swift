// Islamic astronomical calendar (`islamic`).
//
// Currently a delegating alias for IslamicUmmAlQura. See
// `Docs/ISLAMIC_ASTRONOMICAL.md` for the design rationale and the
// plan to measure divergence against Foundation's `.islamic` identifier.
//
// Short version: ICU4X deprecated its own `AstronomicalSimulation` in
// favor of UmmAlQura (they now delegate). ICU4C still uses the Reingold
// observational algorithm for the plain `.islamic` identifier. Inside
// the UmmAlQura baked range (1300–1600 AH, ~1882–2174 CE) both
// approaches track actual Saudi observations and should be very close.
// Outside that range they diverge: we (and ICU4X) fall through to
// tabular; ICU4C computes observational new-moon visibility.
//
// We aligned with ICU4X. Divergence testing against Foundation's
// `.islamic` output is a deferred pipeline item.

import CalendarCore
import CalendarSimple

// MARK: - IslamicAstronomical

/// The Islamic astronomical calendar (`islamic`).
///
/// **This type currently delegates to `IslamicUmmAlQura`.** It exists as a
/// distinct public type so it can be routed to from Foundation's
/// `.islamic` `Calendar.Identifier` without conflating with
/// `IslamicUmmAlQura` (which maps to `.islamicUmmAlQura`).
///
/// ICU4X made the same choice (see
/// `components/calendar/src/cal/hijri.rs`, `AstronomicalSimulation` is
/// deprecated there in favor of `UmmAlQura` and the rule impl literally
/// forwards all year queries to the UmmAlQura rule impl). ICU4C, which
/// Foundation still uses today for `.islamic`, uses the Reingold
/// observational new-moon algorithm. The two approaches agree inside
/// the UmmAlQura baked range (1300–1600 AH) but can diverge outside it.
///
/// See `Docs/ISLAMIC_ASTRONOMICAL.md` for the design analysis and
/// deferred divergence-testing plan.
public struct IslamicAstronomical: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "islamic"
    public typealias DateInner = IslamicTabularDateInner

    @usableFromInline internal let backing: IslamicUmmAlQura

    public init() {
        self.backing = IslamicUmmAlQura()
    }

    @inlinable
    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IslamicTabularDateInner {
        try backing.newDate(year: year, month: month, day: day)
    }

    @inlinable
    public func toRataDie(_ date: IslamicTabularDateInner) -> RataDie {
        backing.toRataDie(date)
    }

    @inlinable
    public func fromRataDie(_ rd: RataDie) -> IslamicTabularDateInner {
        backing.fromRataDie(rd)
    }

    @inlinable
    public func yearInfo(_ date: IslamicTabularDateInner) -> YearInfo {
        backing.yearInfo(date)
    }

    @inlinable
    public func monthInfo(_ date: IslamicTabularDateInner) -> MonthInfo {
        backing.monthInfo(date)
    }

    @inlinable
    public func dayOfMonth(_ date: IslamicTabularDateInner) -> UInt8 {
        backing.dayOfMonth(date)
    }

    @inlinable
    public func dayOfYear(_ date: IslamicTabularDateInner) -> UInt16 {
        backing.dayOfYear(date)
    }

    @inlinable
    public func daysInMonth(_ date: IslamicTabularDateInner) -> UInt8 {
        backing.daysInMonth(date)
    }

    @inlinable
    public func daysInYear(_ date: IslamicTabularDateInner) -> UInt16 {
        backing.daysInYear(date)
    }

    @inlinable
    public func monthsInYear(_ date: IslamicTabularDateInner) -> UInt8 {
        backing.monthsInYear(date)
    }

    @inlinable
    public func isInLeapYear(_ date: IslamicTabularDateInner) -> Bool {
        backing.isInLeapYear(date)
    }
}

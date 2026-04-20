// CivilInstant — design stub.
//
// This file is intentionally empty. It exists to hold the planned
// `CivilInstant` type introduced during the Foundation port (Stage 1,
// Phase 1a) as the nanosecond-exact boundary between Foundation's
// `Date` and icu4swift's RataDie-based calendar math.
//
// The design is frozen. Implementation lands when Phase 1a begins.
//
// ## Planned type
//
//     public struct CivilInstant: Sendable, Equatable, Comparable {
//         public let rataDie: RataDie          // Int64 day count
//         public let nanosecondsInDay: Int64   // 0 ..< 86_400_000_000_000
//     }
//
// ## Why this type and not `Moment`
//
// `Moment` in `AstronomicalEngine` is `Double` fractional RataDie.
// At 2024-era RataDie values (~739,000), Double has only ~10
// fractional decimal digits → ~8 µs precision. Foundation's `Date`
// (Double `TimeInterval`) has ~100 ns precision at the same era.
// Using `Moment` as the boundary would make icu4swift lose precision
// vs. Foundation — unacceptable.
//
// `CivilInstant`'s integer `nanosecondsInDay` is exact at all dates and
// round-trips Foundation `Date` losslessly.
//
// ## Conversion
//
// - `(Foundation.Date, TimeZone) -> CivilInstant`:
//     add TZ offset + reference-date offset,
//     split into whole-day rataDie + ns-within-day.
// - `CivilInstant -> (Foundation.Date, TimeZone)`:
//     inverse. Reassemble, subtract offsets.
// - DST gap / fall-back handling lives here; the calendar math
//   layer never sees DST.
//
// ## Relationship to existing types
//
// - `RataDie` (CalendarCore): unchanged. `CivilInstant.rataDie` feeds
//   into the existing `calendar.fromRataDie` / `toRataDie` path.
// - `Moment` (AstronomicalEngine): unchanged. Continues to serve
//   Moshier astronomy. `CivilInstant` and `Moment` do not interact.
// - `Date<C>` (CalendarCore): unchanged. `Date<C>` is the pure
//   calendar-math view; `CivilInstant` is a separate concept for
//   absolute-time bridging.
//
// See:
// - `Docs-Foundation/MigrationIssues.md` § 2 — full precision
//   analysis.
// - `Docs-Foundation/04-icu4swiftGrowthPlan.md` § Tier 3 — role in
//   the Stage 1 phasing.
// - `Docs-Foundation/TIMEZONE_CONSIDERATION.md` — TZ/DST scope.

# Sub-day precision at the Foundation boundary — decision + implementation record

*Decided 2026-04-20. **Re-confirmed 2026-04-20 evening** after a
session-reset confusion where the resumed session mistakenly tried to
revive the rejected `CivilInstant` design. **Implemented 2026-04-22**
in `Sources/CalendarFoundation/`. **This document is authoritative.
Do not re-open unless there is a concrete, new reason.***

## The one-sentence answer

icu4swift carries sub-day time (hour / minute / second / nanosecond)
at the Foundation boundary via **a pair of adapter functions on
`Foundation.Date`** — matching `_CalendarGregorian`'s pattern in
`swift-foundation/Sources/FoundationEssentials/Calendar/Calendar_Gregorian.swift`
exactly. **No new public type.** No `CivilInstant`. No
`(RataDie, nanosecondsInDay)` bundle struct.

## What _CalendarGregorian does (the model we mirror)

`Date` (Foundation's `Double` `timeIntervalSinceReferenceDate`) is the
only transport type. A small extension on `Date` exposes Julian-day
helpers; everything else is derived on demand.

**Extraction** (`Date → Y/M/D/h/m/s/ns`, `Calendar_Gregorian.swift` ~line 1992):

```swift
let tzOffset  = timeZone.secondsFromGMT(for: d)
let localDate = d + Double(tzOffset)
let floorSec  = localDate.timeIntervalSinceReferenceDate.rounded(.down)  // Double

// Integer path for time-of-day
let totalSeconds  = Int(floorSec)
let secondsInDay  = (totalSeconds % 86400 + 86400) % 86400
(hour,  tmp)    = secondsInDay.quotientAndRemainder(dividingBy: 3600)
(minute, second) = tmp.quotientAndRemainder(dividingBy: 60)

// Nanosecond from the Double remainder (NOT from a fractional day)
nanosecond = Int((localDate.timeIntervalSinceReferenceDate - floorSec) * 1_000_000_000)

// Y/M/D path — integer Julian day
let date      = Date(timeIntervalSinceReferenceDate: floorSec)
let julianDay = try date.julianDay()
let (year, month, day) = yearMonthDayFromJulianDay(julianDay, ...)
```

**Assembly** (`Y/M/D/h/m/s/ns → Date`, `Calendar_Gregorian.swift` ~line 1815):

```swift
let julianDay = try self.julianDay(...)

var secondsInDay = 0.0
if let h  = components.hour       { secondsInDay += Double(h)  * 3600 }
if let m  = components.minute     { secondsInDay += Double(m)  * 60 }
if let s  = components.second     { secondsInDay += Double(s) }
if let ns = components.nanosecond { secondsInDay += Double(ns) / 1e9 }

// Julian day is noon-based — rewind 12h, then add TOD
var out = Date(julianDay: julianDay) - 43200 + secondsInDay
out = out - Double(tzOffset) - dstOffset
return out
```

### What to notice

- **There is no named struct** for `(day, time-of-day)`. The
  quantities live inline in local variables.
- **The integer day for calendar math is an `Int`** (`julianDay`) —
  for us, the equivalent is `RataDie`. Same role, different epoch.
- **Nanoseconds come from the Double fractional second**, not a
  fractional day. No `[0, 1)` fractional-day quantity is ever
  materialised. This is the critical precision observation — Double
  has ~15.95 sig figs total; by splitting into `Int seconds` +
  `Double nanosecond-from-fraction-of-second`, the Double never
  carries a magnitude larger than a second-scale number, so the
  fractional bits still resolve to nanoseconds.
- **Julian Day is noon-based**, hence the `-43200` on assembly.

## What icu4swift does — parallel shape, midnight-based

The adapter is two free functions + a helper on a tuple. No protocol
changes, no struct introductions.

```swift
// Extraction
func rataDieAndTimeOfDay(
    from date: Foundation.Date,
    in tz: Foundation.TimeZone
) -> (rataDie: RataDie, secondsInDay: Int, nanosecond: Int)

// Assembly
func date(
    rataDie: RataDie,
    hour: Int,
    minute: Int,
    second: Int,
    nanosecond: Int,
    in tz: Foundation.TimeZone
) -> Foundation.Date
```

**The one difference from `_CalendarGregorian`.** Our RataDie is
**midnight-based** (R.D. 1 = 1 Jan year 1 ISO, midnight). Julian Day
is noon-based. So our assembly skips the `-43200` rewind:

```swift
// icu4swift equivalent (conceptual)
let secondsFromEpoch = Int64(rataDie.dayNumber - rdAt2001) * 86400 + Int64(secondsInDay)
let ti = Double(secondsFromEpoch) + Double(nanosecond) / 1e9
let out = Date(timeIntervalSinceReferenceDate: ti)
            - Double(tzOffset) - dstOffset  // localDate → UTC Date
```

Everything else — integer-path preference for time-of-day, Double
fallback for extreme ranges, nanoseconds from fractional-second
Double — matches verbatim.

## What stays unchanged in icu4swift

This is the important part. **None of the current calendar
implementations or tests change.**

| Existing piece | Effect |
|---|---|
| `RataDie` (Int64 day count) | unchanged |
| `Date<C>` generic date | unchanged — year/month/day only |
| All 28 calendar implementations | unchanged — operate only on RataDie |
| `Moment` in AstronomicalEngine | unchanged — Moshier still uses Double fractional RD |
| `DateArithmetic` (add/until/balance) | unchanged — whole-day math |
| All 338 existing tests | unchanged — all pass |

The adapter sits **above** the calendar layer, not inside it. Its job
is: when someone hands us a `Foundation.Date` that encodes
`(day + time-of-day)`, carry the time-of-day around the calendar math
and reassemble on the way out. The calendar never touches sub-day
information.

## What becomes new surface, later

Once the adapter lands, ergonomic sugar like

```swift
Date<Hebrew>(from: Foundation.Date, in: .autoupdatingCurrent)
```

wraps the adapter for caller convenience. That's new API surface, but
purely additive — it doesn't modify `Hebrew` or `Date<C>`.

## Why not CivilInstant (the rejected alternative)

`CivilInstant(rataDie: Int64, nanosecondsInDay: Int64)` was proposed
as a lossless integer boundary type. Dropped because:

1. **No drift advantage in practice.** Foundation's Double pattern
   doesn't accumulate error — each op re-converts fresh from `Date`.
2. **Precision at the boundary is bounded by `Date` (~100 ns at 2024
   era) either way.** Integer ns can't invent precision that the
   `Date` source never provided.
3. **Lower review friction.** "We do it the same way
   `_CalendarGregorian` does it" is easier to land in swift-foundation
   than "here's a better representation we invented."
4. **Simpler code.** Two free functions beats a type + conversions +
   invariants + tests for the invariants.

Full rejection analysis: `MigrationIssues.md § 2 — Time-of-day
resolution`. Deleted source: `Sources/CalendarCore/CivilInstant.swift`
(was a stub, never implemented).

## What would reopen this decision

- A concrete arithmetic scenario where Double drift survives `Date`
  re-conversion (none has been demonstrated).
- Foundation themselves moving away from Double for sub-day precision
  (no signal of this).
- Our benchmark showing nanosecond-scale precision loss inside icu4swift
  due to Double round-tripping (untested, but would need to be
  demonstrated, not speculated).

Without one of these, leave the decision closed.

## Implementation (2026-04-22)

### What exists

New module **`CalendarFoundation`** (depends on `CalendarCore` + Foundation):

- `Sources/CalendarFoundation/FoundationAdapter.swift` (≈170 lines).
- Two public top-level functions (see signatures below).
- Two public policy enums: `DSTSkippedTimePolicy`, `DSTRepeatedTimePolicy`.
- One public constant: `RataDie.foundationEpoch = RataDie(730_486)` (2001-01-01 UTC).

### Public API

```swift
import CalendarFoundation
import Foundation
import CalendarCore

// Extraction: Date → (RataDie, secondsInDay, nanosecond)
public func rataDieAndTimeOfDay(
    from date: Foundation.Date,
    in tz: Foundation.TimeZone
) -> (rataDie: RataDie, secondsInDay: Int, nanosecond: Int)

// Assembly: (RataDie, h, m, s, ns) → Date
public func date(
    rataDie: RataDie,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0,
    nanosecond: Int = 0,
    in tz: Foundation.TimeZone,
    repeatedTimePolicy: DSTRepeatedTimePolicy = .former,
    skippedTimePolicy: DSTSkippedTimePolicy = .former
) -> Foundation.Date

public enum DSTSkippedTimePolicy: Sendable  { case former, latter }
public enum DSTRepeatedTimePolicy: Sendable { case former, latter }
```

Semantics match Foundation's internal `TimeZone.DaylightSavingTimePolicy`
(and ICU's `UCAL_TZ_LOCAL_FORMER`/`UCAL_TZ_LOCAL_LATTER`):
- **Skipped** (`.former`): use the offset that was in effect **before** the
  DST transition. For US spring-forward 02:30, that's PST.
- **Skipped** (`.latter`): use the offset that came into effect **after**
  the transition. For US spring-forward 02:30, that's PDT.
- **Repeated** (`.former`): return the chronologically earlier occurrence
  (before fall-back).
- **Repeated** (`.latter`): return the chronologically later occurrence
  (after fall-back).

### How assembly resolves DST

`resolveLocalTI(_:in:repeatedTimePolicy:skippedTimePolicy:)` (private helper):

1. Probe the zone at ±24 h around the local time. Standard DST rules
   transition once in any 24-hour-wide window, so this always spans the
   boundary.
2. Fast path: if both probes report the same offset, apply it and return.
3. Otherwise, form two candidates (pre-transition and post-transition
   offsets), test each for self-consistency via `tz.secondsFromGMT(for:)`:
   - **Both round-trip → repeated** (fall-back). Apply `repeatedTimePolicy`.
   - **Neither round-trips → skipped** (spring-forward). Apply `skippedTimePolicy`.
   - **Exactly one round-trips** → normal case on one side of the DST edge.

### Precision profile

Inherited from `Foundation.Date` (Double `TimeInterval`). At TI ≈ 7.4e8
(2024 era), sub-second precision is approximately:

| TI magnitude | Era | Precision |
|---|---|---:|
| ~0 | 2001 reference | ~1 ns |
| ~1e7 | ~2001 ± 0.3 y | ~1 ns |
| ~1e8 | ~2001 ± 3 y | ~10 ns |
| ~1e9 | ~2001 ± 30 y (covers 1970–2030) | ~100 ns |
| ~1e10 | ~2001 ± 300 y | ~1000 ns |

Documented Double-precision quirk at end-of-day: `23:59:59.999_999_999`
round-trips to next-day midnight because `Double(totalSec) + 0.999_999_999`
lands on the next integer at this magnitude. Matches Foundation's own
behavior; callers needing full ns precision at end-of-day should use
millisecond-scale inputs or offset their reference.

### Tests

`Tests/CalendarFoundationTests/FoundationAdapterTests.swift` — **45 tests,
runs in ~17 ms**:

- **Phase A (UTC, 12 tests):** reference date, Unix epoch, every civil
  hour of 2024-06-15, nanosecond extraction, pre-reference dates, end-of-day.
- **Phase B (fixed-offset, 10 tests):** ±05:00, ±13:00, +00:30, +05:45,
  `America/Phoenix` (no-DST named TZ), years 1900 and 2100, cross-TZ
  consistency.
- **Phase C (DST, 14 tests):** LA spring-forward and fall-back at the
  exact skipped/repeated wall times with both `.former` and `.latter`,
  asymmetry sanity checks, pre/post-transition round-trips on both
  transition days, Sydney, Berlin 1900, default-policy check.
- **Phase D/E (extremes + nanoseconds, 9 tests):** year ±10,000, +1,000,000,
  RataDie.validRange bounds, nanosecond-precision profile across TI scales,
  end-of-day rollover quirk.

### Phase F — benchmarks (done 2026-04-22)

Results in `BENCHMARK_RESULTS.md § Sub-day adapter`. Headlines vs
`Calendar(.gregorian)` in UTC (median of 3 runs, 100 k iters, clean
harness):

| Operation | icu4swift | Foundation | Winner |
|---|---:|---:|---|
| Extraction | 1,754 ns | 3,420 ns | **icu4swift 1.95×** |
| Assembly | 3,042 ns | 2,396 ns | Foundation 1.27× |
| Round-trip | 3,683 ns | 4,094 ns | **icu4swift 1.11×** |

Assembly is slower because our `resolveLocalTI` probes the TZ ±24 h
to detect DST skipped/repeated wall times (2 `secondsFromGMT`
calls). Foundation's internal `rawAndDaylightSavingTimeOffset(for:repeatedTimePolicy:)`
does the same work in one ICU dispatch — we can't call it from public
API. A "1-probe + verify" fast path was attempted and reverted — it
silently drops `.latter` semantics on fall-back. The 2-probe approach
is required for policy correctness.

### Phases A–E — what made it clean

- **Matching `_CalendarGregorian`'s shape** meant no novel algorithm
  design. Extraction and assembly are direct translations with the
  midnight-base simplification (RataDie, not JD).
- **RD-based epoch constant** (`foundationEpoch = 730_486`) centralises
  the one magic number the adapter needs. Derivation (`= unixEpoch + 11_323`)
  is in-code and verified by test.
- **Private DST policy enums** avoided a dependency on Foundation's
  `package`-level `DaylightSavingTimePolicy`. Semantics match ICU's
  `UCAL_TZ_LOCAL_FORMER/LATTER` exactly.
- **The ±24h probe is always sufficient** for standard DST because
  transitions never move offsets more than once per 24h at a given
  instant. Exotic TZs (Antarctica's Troll Station, Samoa's IDL jump)
  might not fit this assumption, but aren't in Foundation's tzdata in
  ways that affect our adapter.

## Cross-references

- `MigrationIssues.md § 2` — the original long-form rationale.
- `04-icu4swiftGrowthPlan.md § Tier 3` — where the adapter lives in
  the Stage 1 plan.
- `03-CoverageAndSemanticsGap.md § Tier 3` — the coverage-gap framing.
- `TIMEZONE_CONSIDERATION.md` — scope of what the adapter handles
  re: TZ and DST (it does; the calendar never sees TZ).
- `HANDOFF.md` — session-level pointer for future sessions.
- `Docs/RDvsJD.md` — companion decision record on why RataDie (not
  Julian Day) is icu4swift's universal pivot; explains why the
  adapter assembly skips the `−43200` noon-nudge.

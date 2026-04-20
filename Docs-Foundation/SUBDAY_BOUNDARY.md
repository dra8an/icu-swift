# Sub-day precision at the Foundation boundary — decision record

*Decided 2026-04-20. **Re-confirmed 2026-04-20 evening** after a
session-reset confusion where the resumed session mistakenly tried to
revive the rejected `CivilInstant` design. **This document is
authoritative. Do not re-open unless there is a concrete, new reason.***

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

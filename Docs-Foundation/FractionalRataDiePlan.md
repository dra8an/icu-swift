# Fractional RataDie — implementation plan

*Written 2026-04-20. Actionable plan for the sub-day-time adapter
between `Foundation.Date` and `RataDie`. Design decisions live
elsewhere — this is the "how do we build it" doc.*

## Pre-read (do not skip)

Before writing any code, read these in order:

1. **`SUBDAY_BOUNDARY.md`** — the authoritative design decision.
   **Match `_CalendarGregorian`'s pattern. No `CivilInstant`. No
   new named type.** Two prior sessions reopened this; don't be the
   third. The conclusion: a pair of free functions.
2. **`Docs/RDvsJD.md`** — why the adapter is midnight-based and
   skips the `−43200` noon-nudge that `_CalendarGregorian` uses.
3. **`swift-foundation/Sources/FoundationEssentials/Calendar/Calendar_Gregorian.swift`**,
   specifically:
   - Lines 32–57 — the `Date.julianDate` / `julianDay` extension.
   - Lines 1815–1856 — `date(from:inTimeZone:)` (assembly).
   - Lines 1992–2099 — `_dateComponents(_:from:in:)` (extraction).
   - Lines 2057–2099 — the Int-path vs Double-path logic we mirror.

## The two functions

Public surface lives in a new file, tentatively
`Sources/CalendarCore/FoundationAdapter.swift` (or a new module
— see "Module placement" below).

```swift
import Foundation

/// Extracts a civil RataDie + time-of-day from a `Foundation.Date`.
///
/// Mirrors `_CalendarGregorian._dateComponents(...)` in
/// `swift-foundation`. Handles TZ offset and DST via
/// `TimeZone.secondsFromGMT(for:)` (for extraction we take whatever
/// offset was in effect at that absolute instant — unambiguous).
///
/// - Returns: `(rataDie, secondsInDay, nanosecond)` where
///   `secondsInDay` is in `0 ..< 86_400` and `nanosecond` is in
///   `0 ..< 1_000_000_000`.
public func rataDieAndTimeOfDay(
    from date: Foundation.Date,
    in tz: Foundation.TimeZone
) -> (rataDie: RataDie, secondsInDay: Int, nanosecond: Int)

/// Assembles a `Foundation.Date` from civil RataDie + time-of-day.
///
/// Mirrors `_CalendarGregorian.date(from:inTimeZone:...)` assembly
/// path. `dstSkippedTimePolicy` / `dstRepeatedTimePolicy` resolve
/// ambiguity on DST boundaries; defaults match Foundation's.
public func date(
    rataDie: RataDie,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0,
    nanosecond: Int = 0,
    in tz: Foundation.TimeZone,
    dstRepeatedTimePolicy: Foundation.TimeZone.DaylightSavingTimePolicy = .former,
    dstSkippedTimePolicy: Foundation.TimeZone.DaylightSavingTimePolicy = .former
) -> Foundation.Date
```

**Module placement — open question.** Today `CalendarCore` has no
`import Foundation`. Options:

- Add `import Foundation` to `CalendarCore` — simplest; everything
  already depends on `CalendarCore` anyway.
- Create a new `CalendarFoundation` module that depends on
  `CalendarCore` + Foundation. Cleaner separation for users who
  eventually want a Linux / no-Foundation build.

Recommendation: start with a new `CalendarFoundation` module. Zero
cost now; keeps the option of Foundation-free core open for whoever
wants Linux-server-side-Swift support later. Decide at Phase 1 time.

## The RD-at-2001 epoch constant

Foundation's `Date` counts seconds from 2001-01-01 00:00:00 UTC.
RataDie for that moment:

- `RataDie.unixEpoch = RataDie(719_163)` (= 1970-01-01).
- Days from 1970-01-01 to 2001-01-01: `31 × 365 + 8 leap days` (1972, '76, '80, '84, '88, '92, '96, 2000) `= 11_323`.
- **`RataDie(730_486)` is 2001-01-01 UTC midnight.**

Add as a public constant on `RataDie`:

```swift
extension RataDie {
    public static let foundationEpoch = RataDie(730_486)  // 2001-01-01 UTC
}
```

Include a compile-time-derivable test: assert it matches
`RataDie.unixEpoch + 11323` and that Gregorian 2001-01-01 round-trips.

## Phased build order

Land each phase as its own commit + PR. Don't bundle — each stage
has meaningful independent value and a clear test story.

### Phase A: UTC-only happy path (2 hours)

- Add `foundationEpoch` constant on RataDie + test.
- Implement both functions for UTC only; error or no-op when
  `tz.secondsFromGMT(for: date) != 0`.
- Integer path only — `Int(floorSec)` assumed safe.
- Basic tests: 2001-01-01 midnight, Unix epoch, arbitrary
  2024 dates, round-trip at every civil hour.

**Exit criterion:** 10+ round-trip tests in UTC pass. Ship it.

### Phase B: Fixed-offset TZ (1 hour)

- Extend with `tz.secondsFromGMT(for: date)` call. Works for any
  non-DST TZ (UTC+N, America/Phoenix, etc.).
- Tests at representative offsets: ±05:00, ±13:00, ±00:30.
- **Still** Int-path only.

**Exit criterion:** Round-trips pass for fixed-offset zones at year
extremes (1900, 2100).

### Phase C: DST via `rawAndDaylightSavingTimeOffset` (2 hours)

- Switch extraction to use
  `tz.rawAndDaylightSavingTimeOffset(for:repeatedTimePolicy:)` —
  matches `_CalendarGregorian.date(from:inTimeZone:...)` exactly.
- Assembly: match Foundation's two-policy contract
  (`dstSkippedTimePolicy`, `dstRepeatedTimePolicy`).
- Tests at:
  - 2024-03-10 02:30 America/Los_Angeles (spring-forward skipped).
  - 2024-11-03 01:30 America/Los_Angeles (fall-back repeated).
  - Southern-hemisphere DST (Australia/Sydney 2024-04-07).
  - TZ with second-resolution offset (Europe/Berlin 1945-05-24 pre-standardization).

**Exit criterion:** our output matches `_CalendarGregorian` for
these same inputs.

### Phase D: Double-fallback path (1 hour)

- Copy `_CalendarGregorian.swift:2078–2091` logic for
  `|dateOffsetInSeconds| ≥ Int.max`.
- Test at year ±10_000_000 to exercise the fallback.
- Match `_CalendarGregorian`'s behavior exactly — any divergence is
  a bug in our code.

**Exit criterion:** extreme-year round-trips agree with
`_CalendarGregorian` bit-for-bit (within Double precision).

### Phase E: Nanosecond edge cases (1 hour)

- Test 999_999_999 / 1_000_000_000 boundary behavior.
- Test negative `timeIntervalSinceReferenceDate` (pre-2001 dates)
  with non-zero nanoseconds.
- Document any residual divergence from Foundation that's accepted
  (in the file header comment + a test note).

**Exit criterion:** known-quirk test matrix is green; residual
divergences (if any) are documented.

### Phase F: Benchmark vs `_CalendarGregorian` (1 hour)

Add a benchmark file following the bench-discipline rule (no
`#expect` in timed loop, checksum, 100k iters):

- Extraction-only round trip: `Date → (RD, sec, ns)`.
- Assembly-only round trip: `(RD, h, m, s, ns) → Date`.
- Full round trip: `Date → ... → Date`.

For each, compare against `Calendar(identifier: .gregorian)` in
UTC with the same equivalent operation. **Expectation: we're
faster** — we skip the noon-nudge and the Julian Day integer
conversion, and our calendar backends don't need to execute at all
for the adapter-only scope.

**Exit criterion:** benchmark numbers recorded in
`BENCHMARK_RESULTS.md` under a new "Sub-day adapter" section.

## Total estimate

**~1 working day** for all six phases. Can be split across
sessions; each phase has a clean exit criterion.

## What we are NOT building in this plan

- **Calendar-aware `DateComponents` decomposition.** That's Tier 1
  work in `04-icu4swiftGrowthPlan.md` — takes the adapter's output
  and combines with a specific calendar to produce a full
  `DateComponents`. Out of scope here.
- **`Date<C>.init(from: Foundation.Date)` sugar.** Convenience
  wrapper for Tier 2. Nice-to-have; not part of adapter core.
- **`_CalendarProtocol` conformance.** That's Stage 2 of the
  Foundation port, not a Stage 1 adapter task.

Those are the next three layers up. This plan covers **only the
bottom boundary**: `Foundation.Date ↔ (RataDie, h, m, s, ns)`
outside any specific calendar.

## Files we'll touch

New:
- `Sources/CalendarFoundation/FoundationAdapter.swift` (new module)
- `Sources/CalendarFoundation/Package.swift` entry (or update
  CalendarCore's)
- `Tests/CalendarFoundationTests/FoundationAdapterTests.swift`
- `Tests/CalendarFoundationTests/FoundationAdapterBenchmarks.swift`

Modified:
- `Sources/CalendarCore/RataDie.swift` — add `foundationEpoch`
  constant.
- `Package.swift` — new product & target if separate module.
- `BENCHMARK_RESULTS.md` — adapter bench section.
- `PIPELINE.md` — mark item 9 / Stage 1 kickoff as in progress.

## Why this is a clean "next task"

- **Zero dependencies** on any other Stage 1 work.
- **Independently testable** — doesn't need a Calendar backend
  wired up.
- **Benchable against Foundation directly.**
- **Natural first demonstration** of the "we match
  `_CalendarGregorian`'s shape" claim from the pitch.

## Cross-references

- `SUBDAY_BOUNDARY.md` — design decision (authoritative).
- `Docs/RDvsJD.md` — why RD and not JD.
- `04-icu4swiftGrowthPlan.md § Tier 3` — where this fits in the
  overall growth plan.
- `Calendar_Gregorian.swift` in swift-foundation — the pattern we
  mirror. Line numbers above.

# Foundation Calendar Port — Overview

*Created 2026-04-17. Companion docs in this directory expand on each section.*

## Mission

Replace the C/C++ ICU4C calendar backend in [`swift-foundation`][sf] with
pure-Swift calendar implementations, using the validated algorithms that
[`icu4swift`][iss] has developed. When the port is done,
`swift-foundation`'s calendar layer has **zero runtime dependency on
ICU4C** for calendrical math.

`icu4swift` is a staging project. Its algorithms, tests, and reference
data move into `swift-foundation`. Once the port completes, `icu4swift`
can be archived.

[sf]: https://github.com/apple/swift-foundation
[iss]: https://github.com/dra8an/icu4swift

## Why

1. **Purity.** Pure-Swift Foundation is already the direction of travel
   (see `_CalendarGregorian` — the Gregorian/ISO fast path has no ICU
   calls). Extending that pattern to the remaining 26 calendar
   identifiers completes the trajectory.
2. **Build & binary cost.** `swift-foundation-icu` ships a large C++
   payload. Dropping the calendar dependency reduces the set of ICU
   sources Foundation consumers need.
3. **Correctness transparency.** ICU calendar code is battle-tested but
   opaque in idioms Swift developers don't read fluently. A pure-Swift
   implementation with algorithm references in comments, `Sendable`
   value types, and Swift-native tests is easier to audit, diff, and
   evolve.
4. **Feature extensibility.** Once the backend is Swift, adding new
   calendar systems or modernizing internal representations (e.g.,
   baked tables for lunisolar calendars) is a same-language change.

## Destination state

After the port completes:

- `swift-foundation/Sources/FoundationInternationalization/Calendar/`
  contains pure-Swift backends for every `Calendar.Identifier` case
  (gregorian, iso8601, buddhist, japanese, republicOfChina, persian,
  coptic, ethiopicAmeteMihret, ethiopicAmeteAlem, islamic, islamicCivil,
  islamicTabular, islamicUmmAlQura, hebrew, indian, chinese, dangi,
  vietnamese, bangla, tamil, odia, malayalam, gujarati, kannada,
  marathi, telugu, vikram).
- `_CalendarICU` is deleted.
- `swift-foundation-icu` no longer exposes the i18n calendar sources
  (calendar.cpp, gregocal.cpp, chnsecal.cpp, hebrwcal.cpp, islamcal.cpp,
  coptccal.cpp, ethpccal.cpp, persncal.cpp, indiancal.cpp, japancal.cpp,
  buddhcal.cpp, taiwncal.cpp, dangical.cpp, iso8601cal.cpp, hinducal.cpp,
  astro.cpp). Other ICU modules (formatting, collation, locale data) are
  out of scope.
- `CalendarCache` dispatches every identifier to a pure-Swift backend —
  no fallthrough to `_calendarICUClass()`.

## Scope

**In scope:**

- All 28 `Calendar.Identifier` cases and every method on
  `_CalendarProtocol`: `date(from:)`, `dateComponents(_:from:)`,
  `dateComponents(_:from:to:)`, `date(byAdding:to:wrappingComponents:)`,
  `minimumRange(of:)`, `maximumRange(of:)`, `range(of:in:for:)`,
  `ordinality(of:in:for:)`, `dateInterval(of:for:)`, `isDateInWeekend(_:)`.
- Public `Calendar` APIs that sit on top: `nextDate(after:matching:…)`,
  `enumerateDates(startingAfter:matching:…)`, `dateInterval(of:for:…)`,
  `isDate(_:inSameDayAs:)`, `compare(_:to:toGranularity:)`,
  `startOfDay(for:)`, `isDateInToday(_:)`, `nextWeekend(…)`, the
  recurrence-rule machinery.
- `DateComponents` round-trip semantics (sparse fields, optional
  values, `isLeapMonth`, `isRepeatedDay`).
- `firstWeekday`, `minimumDaysInFirstWeek`, `gregorianStartDate`,
  `timeZone`, `locale` preference state carried on each calendar
  instance — with the same defaults ICU produces today.
- Weekend behavior driven by locale data (today this comes from
  `ucal_isWeekend` + `ucal_getDayOfWeekType`).

**Out of scope:**

- `DateFormatter` / `Date.FormatStyle` / ICU pattern matching —
  formatting calendars is a separate port that depends on CLDR data.
- `TimeZone` internals (TZ identifiers, DST rules, transition tables
  are handled by ICU today via `TimeZone_ICU.swift` and by Apple's TZif
  parser in `_TimeZoneGMTICU.swift`/`_TimeZoneICU.swift`). The calendar
  port consumes whatever TZ backend Foundation ships; it does not try
  to replace TZ at the same time.
- `Locale` internals. The calendar port reads locale preferences for
  `firstWeekday` and `minimumDaysInFirstWeek`; it does not port
  `Locale_ICU`.
- `astro.cpp` — we do **not** port ICU's astronomical code. icu4swift
  already ships a validated Moshier ephemeris engine that replaces it.
- **ucal-style per-field mutation semantics.** icu4swift does **not**
  implement ICU's `ucal_set(field, value)` / `ucal_add` / `ucal_roll`
  contract where any field mutation triggers eager recomputation of
  every other field (julian day, day-of-week, is-leap, zone offset,
  etc.) on each subsequent read. Foundation's public `Calendar` API
  does not expose that contract — it offers high-level queries
  (`range(of:in:for:)`, `ordinality`, `dateInterval`, `nextDate`,
  `enumerateDates`, `isDateInWeekend`, `date(byAdding:value:to:)`)
  on immutable value-type dates. We match Foundation's shape, not
  ICU's. This is an intentional design choice and explains the
  measured speedup over raw ICU4C — we don't pay for a mutation
  protocol we don't expose. See `BENCHMARK_RESULTS.md` for the
  measured consequences.

## Acceptance criteria

A calendar is "ported" when all of the following hold:

1. **Functional parity.** A per-identifier regression test compares
   pure-Swift backend output against `_CalendarICU` output over a
   dense date range (at minimum 1900–2100, daily where tractable) for
   every `_CalendarProtocol` method. Zero divergence on all component
   round-trips; documented allow-list for any intentional divergence
   (e.g., baked-data model differences already seen in Chinese 1906).
2. **Performance parity.** Per-identifier benchmarks (see
   `04-PerformanceParityGate.md`) show no regression vs the ICU
   baseline on the operation mix that existing Foundation benchmarks
   exercise. Threshold TBD (proposed: CPU within ±10%, mallocs ≤
   baseline, throughput within ±10%).
3. **Memory parity.** Allocation count for `Calendar(identifier:)` and
   per-operation malloc counts are at or below the ICU baseline.
4. **Thread safety.** Backend is `Sendable`. Where the ICU backend
   uses a mutex around stateful `UCalendar*`, the Swift backend should
   typically not need one (value-type dates, immutable calendars).
5. **API compatibility.** Zero public API changes. Every existing
   Foundation calendar test passes unchanged. Any behavior that was
   only an ICU quirk is either preserved or documented + approved.

## High-level approach

A single-pass rewrite of `_CalendarICU` is too risky. Instead:

1. **Extend icu4swift first** to cover the Foundation semantics it
   doesn't have yet (firstWeekday/minDaysInFirstWeek state,
   TZ-aware `date(from:)`/`dateComponents(_:from:)`, `range` /
   `ordinality` / `dateInterval`, `nextDate(after:matching:)`,
   `DateComponents` sparse round-trip). Keep shipping icu4swift as a
   standalone library during this phase so the new surface can be
   tested in isolation.

2. **Land a `_CalendarSwift<Identifier>` plumbing** in swift-foundation
   that conforms to `_CalendarProtocol`. Gate it behind a build-time
   or runtime toggle (`#if FOUNDATION_USE_SWIFT_CALENDARS` or a
   per-identifier allow-list). The ICU path remains the default until
   each calendar is certified.

3. **Port calendars in risk order**, easiest first, hardest last (see
   `05-PhasedPortPlan.md`). After each identifier passes functional
   + performance parity, it flips from ICU-backed to Swift-backed in
   `_calendarClass(identifier:)`.

4. **When the last identifier flips**, delete `_CalendarICU`, remove
   the calendar sources from `swift-foundation-icu`, and archive
   `icu4swift`.

## Risks and how we manage them

| Risk | Mitigation |
|---|---|
| ICU quirk replication | Daily-granularity regression against ICU over the full supported date range; review divergences before accepting. |
| Performance regression hidden until after merge | Benchmarks added **before** the port, capturing ICU baseline per identifier. Parity-or-revert per calendar. |
| Paradigm mismatch (ICU mutable state vs. Swift immutable) | Keep the boundary at `_CalendarProtocol`; write a thin adapter that maps Foundation's mutable-feel API onto icu4swift's stateless value types. |
| TZ and DST interactions are subtle | Reuse Foundation's existing TZ infrastructure unchanged; only the calendrical math moves. |
| Locale-driven week rules | Preserve the `locale.prefs?.firstWeekday` / `minDaysInFirstWeek` resolution exactly as `_CalendarICU` does. |
| Vietnamese calendar (Foundation-only, not upstream ICU) | Implement in icu4swift based on the private `hinducal.cpp`/`chnsecal.cpp` fork semantics; treat as a first-class identifier. |
| Second Ethiopian variant (`ethiopicAmeteAlem`) | Epoch-only difference from the existing Ethiopian implementation; trivial add. |

## Success metric

When the last PR of this effort ships:

- `grep -r 'ucal_' swift-foundation/Sources/FoundationInternationalization/Calendar/`
  returns nothing.
- All calendar tests pass with the ICU calendar sources physically
  removed from `swift-foundation-icu`.
- Perf benchmarks show no regression on the existing Gregorian suite
  **and** the newly-added per-identifier suite.

## See also

- `01-FoundationCalendarSurface.md` — `_CalendarProtocol`, the three
  existing backends, dispatch, and the integration seam.
- `02-ICUSurfaceToReplace.md` — the 17 `ucal_*` functions and the C++
  classes behind them.
- `03-CoverageAndSemanticsGap.md` — what icu4swift already covers, what
  it must grow, and the identifier map.
- `04-PerformanceParityGate.md` — benchmark design, baseline-capture,
  thresholds.
- `05-PhasedPortPlan.md` — calendar-by-calendar order with acceptance
  per phase.
- `06-OpenQuestions.md` — alignment items needed from stakeholders
  before we commit to specifics.
- `MigrationIssues.md` — design clarifications on two early concerns
  (Foundation mutability, RataDie vs. millisecond time basis) that
  turn out to be non-issues. Captures the reasoning so it is not lost.

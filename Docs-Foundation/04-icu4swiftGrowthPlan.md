# icu4swift Growth Plan — Stage 1

*Brief — to be expanded with detailed sub-phases before Stage 1 code
work begins. Captures the architectural premise and the list of
capabilities icu4swift needs to add.*

## The guiding design principle

**icu4swift is aligned to Foundation's Date/Calendar API model, not
to ICU4C's `ucal_*` state-machine contract.** This is the central
premise that shapes every Stage 1 decision.

### Why ICU4C is shaped the way it is

ICU's `UCalendar*` is a stateful object. Its public contract
promises:

> You can mutate any field with `ucal_set(field, value)` and
> subsequently read any other field. All fields will be mutually
> consistent.

That promise has a price. Every field read has to trigger a full
resolution from whatever's been set — julian day, day-of-week,
day-of-year, week-of-year, is-leap, era, zone-offset, dst-offset,
all recomputed. For Chinese, "full resolution" means astronomical
calculations to find lunar month boundaries. For everything else
it's still a mountain of bookkeeping every time. The speed cost of
ICU's `ucal_*` API (measured at 250–1,000 ns+ per field access,
41 µs for Chinese) is the cost of honouring that contract.

That same cost is what we measured in
`Docs-Foundation/BENCHMARK_RESULTS.md` when we benchmarked
`ucal_setMillis` + `ucal_get` × 5 + `ucal_clear` + `ucal_set` × 5
+ `ucal_getMillis`. The minimal `ucal_setMillis`-only bench came
in at ~6 ns — confirming that the cost lives almost entirely in
field get/set resolution and the mutation-protocol invariants, not
in the bare ucal infrastructure.

### Why Foundation doesn't need that

Foundation's public `Calendar` API exposes **high-level queries
and derivations** on **immutable value-type dates**:

- `range(of: .day, in: .month, for: date)` — "how many days are in
  this month?"
- `ordinality(of: .day, in: .year, for: date)` — "what day-of-year
  is this?"
- `dateInterval(of: .month, for: date)` — "start + length of the
  containing month"
- `nextDate(after: d, matching: dc, matchingPolicy: ...)` — search
- `enumerateDates(...)` — iterate matches
- `isDateInWeekend(d)`, `dateIntervalOfWeekend(...)`, `nextWeekend(...)`
- `date(byAdding: .day, value: 30, to: d)` — arithmetic

None of these require a mutable calendar state object. They're
pure functions of `(Date, Calendar, Component)` producing new
Dates or metadata. No mutation contract, no eager recalculation,
no cross-field consistency protocol.

### What this means for icu4swift

- We **do not** implement ucal-style per-field setters, `add`, or
  `roll` with eager recalculation.
- We **do** implement Foundation's high-level query API on top of
  pure-Swift calendar math.
- The surface is value-oriented (immutable `Date<C>`, value-type
  calendars with stored knobs like `timeZone`, `firstWeekday`),
  matching Swift idiom and matching `_CalendarGregorian`'s
  existing pattern.
- The observed speedup over raw ICU4C (10–40× on arithmetic
  calendars, ~1,000× on Chinese) is a direct consequence of this
  alignment. **We don't pay for a mutation protocol Foundation
  doesn't expose.**

## What icu4swift already has

From `CalendarProtocol` and the concrete calendar types:

- Atomic conversions: `fromRataDie(_:)` / `toRataDie(_:)`
- Field accessors: `yearInfo`, `monthInfo`, `dayOfMonth`,
  `dayOfYear`, `daysInMonth`, `daysInYear`, `monthsInYear`,
  `isInLeapYear`
- Construction: `newDate(year:month:day:)` with era handling
- Non-bijective day mapping hooks: `DateStatus` / `alternativeDate`
  (for Hindu lunisolar kshaya/adhika tithi)
- Arithmetic: `Date.added(.days, 30)` via the `DateArithmetic`
  module (Temporal-spec add/until/balance)
- 28 of 28 Foundation `Calendar.Identifier` cases covered (as of
  2026-04-20)

## What needs to be added in Stage 1

These are the capabilities Foundation exposes on its public
`Calendar` API that icu4swift does not yet provide. The
implementation will not require ucal-style mutation — each builds
as a pure function on top of the existing calendar-math core.

### State on the calendar struct (stored properties)

- `timeZone: TimeZone` — all calendar operations consume a
  `TimeZone`.
- `firstWeekday: Int` — 1–7, drives week-of-year math.
- `minimumDaysInFirstWeek: Int` — 1–7, drives week-of-year math.
- `locale: Locale?` — for preferred-weekday / min-days resolution.
- `gregorianStartDate: Date?` — Gregorian calendar's Julian-cutover
  configuration.

### Adapter layer — `(Date, TimeZone) ↔ (RataDie, secondsInDay)`

The boundary between Foundation's absolute-time `Date` and our
RataDie-based calendar math. TZ offset application, DST gap/fall-back
handling, second/nanosecond extraction. See
`TIMEZONE_CONSIDERATION.md` for the scope and
`MigrationIssues.md` for the RataDie-vs-milliseconds discussion.

### DateComponents round-trip (sparse)

Foundation's `DateComponents` is sparse — any subset of fields may
be set or read. icu4swift needs to:

- Accept `DateComponents` → construct a `Date` (composition).
- Produce `DateComponents` from a `Date` + requested components
  (decomposition).
- Handle sparse-value semantics (missing fields, over-specified
  combinations, validity rules).

### Foundation query API

Each of these is a pure function of `(Date, Calendar, Component)`:

- `range(of:in:for:)`, `minimumRange(of:)`, `maximumRange(of:)`
- `ordinality(of:in:for:)`
- `dateInterval(of:for:)`
- `nextDate(after:matching:matchingPolicy:repeatedTimePolicy:direction:)`
- `enumerateDates(startingAfter:matching:matchingPolicy:…)`
- `isDateInWeekend(_:)`
- `dateIntervalOfWeekend(containing:start:interval:)`
- `nextWeekend(startingAfter:start:interval:direction:)`
- `startOfDay(for:)`, `isDateInToday(_:)`, `isDate(_:inSameDayAs:)`
- `compare(_:to:toGranularity:)`
- `date(bySetting:value:of:)`, `date(bySettingHour:minute:second:of:…)`
- `date(byAdding:value:to:)` / `date(byAdding:to:wrappingComponents:)`

Most of these decompose into primitives that our core already has
(atomic decompose + compose, field accessors, arithmetic). A few
(notably `nextDate` / `enumerateDates`) are genuinely substantial
on their own — see `OPEN_ISSUES.md` Issue 3 and the
`Calendar_Enumerate.swift` reference in `swift-foundation`.

## Proposed phasing for Stage 1

*To be refined. Each phase has its own acceptance criteria; each
ends with benchmarks against `_CalendarICU` for the operations it
added.*

1. **Phase 1a — Stored state + TZ adapter.** Add the five stored
   properties to every calendar struct. Implement `(Date, TZ) ↔
   (RataDie, secondsInDay)`. No new operations yet; just the
   foundation.
2. **Phase 1b — Sparse DateComponents round-trip.** Compose and
   decompose with sparse field sets.
3. **Phase 1c — Range / ordinality / dateInterval.** The cheap,
   pure-function query APIs.
4. **Phase 1d — `isDateInWeekend` + weekend interval + nextWeekend.**
   Requires locale weekend data; possible interaction with Locale
   layer.
5. **Phase 1e — Arithmetic (`date(byAdding:...)`,
   `compare(_:to:toGranularity:)`).** Bridge our existing
   `DateArithmetic` module to Foundation's component-based add.
6. **Phase 1f — `nextDate` + `enumerateDates` + matching policies +
   repeated-time handling.** The biggest piece; deserves its own
   sub-phase. Includes DST-gap / fall-back / match-policy semantics.

Each phase ends with a performance comparison against
`_CalendarICU` for the operations added in that phase. A phase
passes when it meets the acceptance criteria in
`05-PerformanceParityGate.md`.

## Exit criterion for Stage 1

icu4swift, compiled as a standalone package, passes a porting of
Foundation's `CalendarTests.swift` plus any new tests for
Foundation-shaped operations. Performance benchmarks against
`_CalendarICU` meet the parity gate thresholds for the Foundation
query API specifically (not just the existing raw RataDie
round-trips). At that point Stage 2 — plumbing the icu4swift
backend into `swift-foundation` — can begin.

## See also

- `00-Overview.md` § "Scope" — out-of-scope list includes the
  explicit statement that ucal-style mutation is not ported.
- `02-ICUSurfaceToReplace.md` — what ICU4C's calendar API actually
  does, which is what we are *not* porting.
- `05-PerformanceParityGate.md` — per-operation benchmark gate
  each phase above must clear.
- `BENCHMARK_RESULTS.md` — the measured consequences of the
  API-alignment choice (10–40× / 1,000× speedup over raw ICU4C).
- `MigrationIssues.md` — resolves the mutability and
  RataDie-vs-milliseconds questions.
- `TIMEZONE_CONSIDERATION.md` — scope boundary for the TZ adapter
  work in Phase 1a.

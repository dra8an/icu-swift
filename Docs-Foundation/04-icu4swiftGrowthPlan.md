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

Foundation's public `Calendar` API exposes ~41 public methods plus
the `Calendar.RecurrenceRule` subsystem. **That does not mean
icu4swift has to implement 41 things.** The vast majority of those
41 methods are implemented **once, generically**, in
`swift-foundation`'s `Calendar` struct extensions — they delegate
to a small set of primitive methods on `_CalendarProtocol`, which
the backend (us) must provide. Everything above that layer comes
along for free when we ship the primitives.

We therefore split the work into three tiers.

### Tier 1 — Backend primitives (icu4swift must implement)

These are the methods declared by `_CalendarProtocol` in
`swift-foundation/Sources/FoundationEssentials/Calendar/Calendar_Protocol.swift`
that every backend must provide. They are the **only** Foundation-shaped
methods we need to actually implement on icu4swift's side:

- **Composition** — `date(from: DateComponents) -> Date?`
- **Decomposition** — `dateComponents(_: Set<Component>, from: Date) -> DateComponents`
- **Difference** — `dateComponents(_: Set<Component>, from: Date, to: Date) -> DateComponents`
- **Arithmetic** — `date(byAdding: DateComponents, to: Date, wrappingComponents: Bool) -> Date?`
- **Ranges** — `minimumRange(of:) -> Range<Int>?`, `maximumRange(of:) -> Range<Int>?`, `range(of:in:for:) -> Range<Int>?`
- **Ordinality** — `ordinality(of: Component, in: Component, for: Date) -> Int?`
- **Interval** — `dateInterval(of: Component, for: Date) -> DateInterval?`
  (plus the `inout`-based overload, same primitive)
- **Weekend test** — `isDateInWeekend(Date) -> Bool`
- **Copying** — `copy(changingLocale:timeZone:firstWeekday:minimumDaysInFirstWeek:gregorianStartDate:)`
- **Hashing** — `hash(into:)`

That's it for the backend contract. Roughly **10 methods**, all
pure functions of `(Date, Calendar, Component)`, none requiring a
mutation protocol.

### Tier 2 — Stored state on the calendar struct

Each icu4swift calendar type grows these stored properties so the
Tier 1 methods have the configuration they need. The existing
concrete calendars (`Hebrew`, `Persian`, etc.) are value types with
no state today; adding them is mechanical.

- `timeZone: TimeZone`
- `firstWeekday: Int` (1–7)
- `minimumDaysInFirstWeek: Int` (1–7)
- `locale: Locale?`
- `gregorianStartDate: Date?` (Gregorian only)

### Tier 3 — Adapter infrastructure shared across all backends

- **`Instant` boundary type (new).** Lives in `CalendarCore`.
  Defined as:

  ```swift
  public struct Instant: Sendable, Equatable, Comparable {
      public let rataDie: RataDie          // Int64 day count
      public let nanosecondsInDay: Int64   // 0 ..< 86_400_000_000_000
  }
  ```

  Represents a point in time at exact nanosecond precision — strictly
  better than Foundation's `Date.timeIntervalSinceReferenceDate`
  (~100 ns at 2024 era) — and round-trippable without loss. This is
  **not** the existing `Moment` type from `AstronomicalEngine`:
  `Moment` is Double fractional RataDie and has only ~8 µs precision
  at the same era, which would be a step backward at the Foundation
  boundary. `Moment` continues to serve astronomy; `Instant` serves
  Foundation bridging. See `MigrationIssues.md` § 2 for the full
  precision analysis.

- **TZ adapter** — `(Date, TimeZone) ↔ Instant`. Integer-math
  conversion: subtract reference / timezone offsets, split into
  whole-day `RataDie` + nanosecond-within-day. DST gap / fall-back
  handling lives here; the calendar core never sees DST. See
  `TIMEZONE_CONSIDERATION.md` for the scope.

- **Sparse DateComponents bridging** — Foundation's `DateComponents`
  is a sparse struct (any subset of fields may be set or read). The
  compose / decompose / difference primitives in Tier 1 all consume
  or produce it. Missing-field semantics, over-specified field
  combinations, and validity rules all live in this shared layer.
  `Instant.nanosecondsInDay` decomposes into H/M/S/ns via pure
  integer arithmetic (`nsInDay / 3600_000_000_000` → hour, etc.);
  no Double drift.

### What comes along for free (lives in swift-foundation above `_CalendarProtocol`)

Once Tiers 1–3 ship, these **automatically work** against
icu4swift-backed calendars — we do not reimplement them:

| Foundation public method | Implemented in swift-foundation via |
|---|---|
| `startOfDay(for:)` | `dateInterval(of: .day, for:).start` |
| `isDateInToday(_:)`, `isDateInYesterday(_:)`, `isDateInTomorrow(_:)` | `isDate(_:inSameDayAs:)` + `Date(timeIntervalSinceNow:)` |
| `isDate(_:inSameDayAs:)`, `isDate(_:equalTo:toGranularity:)` | `ordinality` + `component(_:from:)` |
| `compare(_:to:toGranularity:)` | `ordinality` per granularity |
| `component(_ Component, from: Date)` | single-key `dateComponents(_:from:)` |
| `date(byAdding: Component, value:, to:, wrappingComponents:)` | single-component overload of the arithmetic primitive |
| `date(bySetting: Component, value:, of:)` | decompose → mutate → compose |
| `date(bySettingHour:minute:second:of:...)` | same |
| `date(_:matchesComponents:)` | decompose + compare to sparse DC |
| `dateIntervalOfWeekend(containing:)`, `nextWeekend(startingAfter:direction:)` | return-variant wrappers around `isDateInWeekend` + `dateInterval(of: .weekOfMonth, for:)` |
| `nextDate(after:matching:matchingPolicy:repeatedTimePolicy:direction:)` | generic in `Calendar_Enumerate.swift`; uses `dateInterval`, `date(byAdding:)`, `dateComponents(_:from:)` |
| `enumerateDates(startingAfter:matching:...)` | same; `nextDate` built on top of it |
| `dates(byAdding:...)`, `dates(byMatching:...)` | AsyncSequence wrappers around `nextDate` / `date(byAdding:)` |
| `Calendar.RecurrenceRule` | generic machinery in `Calendar+Recurrence.swift` on top of `enumerateDates` |
| `_CalendarBridged` path (NSCalendar) | Foundation-internal; not our concern |

**This is the key insight for scoping Stage 1.** The ceiling isn't
41 methods — it's 10 primitives + state + adapter. `nextDate`,
`enumerateDates`, `RecurrenceRule`, the sequence APIs, every
convenience wrapper — all of it routes through the same 10
primitives. Implement them correctly and a backend "just works"
across every Foundation API Apple ships now or ever will ship
through this contract.

### Risk concentrated in four primitives

Of the 10 primitives, risk is not uniform. Four carry most of the
design work:

1. **`date(from: DateComponents)`** — composition. Sparse-field
   semantics, validity rules (over-specified combinations,
   ambiguous cases), DST gap/fall-back resolution at compose time.
2. **`dateComponents(_:from:)`** — decomposition. Which
   components are requested, how week-of-year derives from
   `firstWeekday` + `minimumDaysInFirstWeek`, how era + year +
   leap-month interact.
3. **`dateComponents(_:from:to:)`** — difference. The semantics
   of "what is `date2 - date1` in years + months + days" is
   subtle; different `matchingPolicy` semantics apply.
4. **`date(byAdding:to:wrappingComponents:)`** — arithmetic with
   month-end overflow handling (Feb 30 → Feb 28), wrapping vs
   carry. Our `DateArithmetic` module already implements the
   Temporal-spec algorithms; binding to Foundation's
   `DateComponents` semantics is the work.

`range` / `ordinality` / `dateInterval` / `isDateInWeekend` are
shallower — mostly straightforward once decomposition is solid.

The big concern earlier in `OPEN_ISSUES.md` Issue 3 about
`nextDate` / `enumerateDates` stands, but is **not** icu4swift's
problem to solve — the complexity lives in
`Calendar_Enumerate.swift`, inherited when we plug in.

## Proposed phasing for Stage 1

*To be refined. Each phase ends with benchmarks against
`_CalendarICU` for the primitives it added, per
`05-PerformanceParityGate.md`.*

1. **Phase 1a — Tier 2 + Tier 3.** Stored state on calendar
   structs, TZ adapter, sparse DateComponents infrastructure.
   No new primitives yet; just the plumbing Tier 1 will build on.
2. **Phase 1b — Tier 1 composition/decomposition.** `date(from:)`
   and `dateComponents(_:from:)`. Sparse-field semantics,
   validity rules, DST gap/fall-back at compose time.
3. **Phase 1c — Tier 1 difference.** `dateComponents(_:from:to:)`
   with the right matching-policy semantics for each component
   combination.
4. **Phase 1d — Tier 1 arithmetic.** `date(byAdding:to:wrappingComponents:)`
   bridging icu4swift's existing `DateArithmetic` module to
   Foundation's DateComponents-based interface. Month-end
   overflow, wrapping vs carry.
5. **Phase 1e — Tier 1 ranges + ordinality + interval.**
   `minimumRange`, `maximumRange`, `range(of:in:for:)`,
   `ordinality(of:in:for:)`, `dateInterval(of:for:)`. Shallower
   than 1b-1d; mostly lookups and week-of-year arithmetic.
6. **Phase 1f — Tier 1 weekend.** `isDateInWeekend` + the locale
   weekend-data hooks.

After Phase 1f, the backend contract is complete. `nextDate`,
`enumerateDates`, `RecurrenceRule`, and all 30+ convenience
methods come along for free via `swift-foundation`'s existing
generic implementations — that work happens in Stage 2 (plumbing
the backend into the Foundation dispatch) not in Stage 1.

## Exit criterion for Stage 1

icu4swift ships all 10 `_CalendarProtocol` primitives with:

- Functional parity: a porting of the relevant subset of
  Foundation's `CalendarTests.swift` passes.
- Performance parity: `05-PerformanceParityGate.md` thresholds
  met on the primitives for every calendar.
- Stored state and adapter layer in place.

At that point Stage 2 begins — we plug icu4swift-backed classes
into `_CalendarProtocol` inside `swift-foundation`, and the full
41-method Foundation API + `RecurrenceRule` light up against our
backend for free.

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

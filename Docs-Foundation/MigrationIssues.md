# Migration Issues — Design Clarifications

*Created 2026-04-17. Captures answers to two design questions raised
during planning.*

Two concerns were raised that, on the surface, looked like they might
create friction when integrating `icu4swift` into `swift-foundation`.
Both turn out to be non-issues once the actual mechanics are examined.
This document records the analysis so the reasoning is preserved.

---

## 1. Mutability — Foundation's Calendar vs. icu4swift

**Concern.** `icu4swift` is designed around immutable value types
(`Date<C>`, stateless calendars). Foundation's `Calendar` appears
mutable (`cal.firstWeekday = 2`, `cal.timeZone = tz`). Does that create
an impedance mismatch?

### Answer: no friction — the two models compose cleanly.

### What Foundation's `Calendar` actually is

- A `struct` (value type). Mutable at the struct level: assigning to
  `firstWeekday`, `timeZone`, `locale`, `minimumDaysInFirstWeek`, and
  `gregorianStartDate` compiles.
- Internally stores a reference to an `AnyObject`-conforming
  `_CalendarProtocol` backend.
- Uses **copy-on-write**: each mutation checks uniqueness of the
  backend reference and clones/regenerates when shared.

The mutation is the *appearance*; structurally, each mutation produces
a new backend value. This is the standard Swift value-semantics pattern.

### What icu4swift is

- Calendar types are value types (`Gregorian`, `Hebrew`,
  `HinduLunisolar(location:)`, `Japanese`, etc.).
- Most carry no stored state today; they are function-holders.
- A few already carry configuration: `HinduLunisolar` holds a
  `Location`, `Japanese` holds a `JapaneseEraData`.
- `Date<C>` is immutable.

### Why they compose

The mismatch people intuitively worry about — "Foundation is stateful,
icu4swift is functional" — is not real. Foundation's `Calendar` uses
**value semantics with COW**, the same paradigm icu4swift already uses.
The only difference is what state the calendar struct carries.

To plug icu4swift into Foundation, we:
- Add the configuration fields that Foundation expects (`timeZone`,
  `firstWeekday`, `minimumDaysInFirstWeek`, `locale`,
  `gregorianStartDate`) as stored properties on the calendar struct.
- Every "mutation" on the Foundation side becomes a new icu4swift
  calendar value underneath.
- No shared mutable state, no locks required, no backend regeneration
  step.

### Contrast to `_CalendarICU`

`_CalendarICU` *is* stateful. It wraps `UCalendar*`, a C object where
you set millis, then read fields. That requires `_CalendarICU._mutex`
to be safe under concurrent access, plus `_locked_regenerate()` when
`locale` or `timeZone` mutate. Replacing it with a Swift backend
**removes** a friction point; it does not add one.

### Plumbing detail

`_CalendarProtocol` is declared `AnyObject`. The icu4swift-backed
implementation wraps its value-type state in a thin reference class
to satisfy the protocol. One pointer indirection; no downside. This
is the same pattern `_CalendarGregorian` already uses.

---

## 2. Time-of-day resolution — RataDie vs. milliseconds

**Concern.** icu4swift is built on RataDie (integer day count). ICU4C
is built on milliseconds since epoch. Does that gap matter? Would
icu4swift need to grow hour/minute/second/nanosecond fields to
participate?

### Answer: no redesign — the adapter layer handles it.

### What ICU does

Stores absolute time as `int64_t` milliseconds since epoch. All math
happens over that integer. Wall-clock components (Y/M/D/H/M/S) are
decoded on demand using the timezone.

### What Foundation does

`Date` is `Double` seconds since reference date — **sub-millisecond
precision already**. ICU's millisecond integer is an internal ICU
choice, not something Foundation exposes. From Foundation's
perspective, `Date` is the wire format, and ICU's millisecond
representation is an implementation detail of `_CalendarICU`.

### What calendar math actually needs

**Days.** Only days. Year, month, day-of-month, day-of-week,
week-of-year, era, leap month, leap day — every field the calendar
protocol defines operates on civil days. Hour, minute, second, and
nanosecond are pure arithmetic on **seconds-since-midnight** of the
wall-clock day. They have nothing to do with calendrical math.

### The idiom already in Foundation

Look at `_CalendarGregorian` (`Calendar_Gregorian.swift` in
`swift-foundation`). It uses exactly the pattern icu4swift needs:

```
absolute Date + timeZone
    │
    ▼ (add tz offset; split)
┌─────────────────┐   ┌──────────────────────────────┐
│ RataDie (day)   │   │ nanosecondsInDay (Int64)     │
│ Int64           │   │ 0 ..< 86_400_000_000_000     │
└─────────────────┘   └──────────────────────────────┘
    │                          │
    ▼ calendar math             ▼ integer arithmetic
Y, M, D, era, week, …     hour, minute, second, nanosecond
```

The two pieces together form a single boundary value:

```swift
public struct CivilInstant: Sendable, Equatable, Comparable {
    public let rataDie: RataDie          // Int64 day count
    public let nanosecondsInDay: Int64   // 0 ..< 86_400_000_000_000
}
```

icu4swift's RataDie-first model **is** this pattern. What we need to
add is the adapter that:

1. Takes `(Date, TimeZone)` → `CivilInstant`.
2. Hands `CivilInstant.rataDie` to the calendar for Y/M/D/era/week fields.
3. Decomposes `CivilInstant.nanosecondsInDay` into hour / minute / second
   / nanosecond via integer arithmetic.
4. Handles DST transitions (where a civil day is not 86400 s long)
   inside the `(Date, TimeZone) ↔ CivilInstant` boundary — the calendar
   itself never sees DST.

The adapter is small, well-understood, and already implemented in
Foundation for Gregorian.

### Why `CivilInstant` uses Int64 nanoseconds, not Double fractional RataDie

The subtlety: you cannot use the existing `Moment` type (Double
fractional RataDie, from `AstronomicalEngine`) as the boundary
representation. For 2024-era dates, a Double fractional RataDie has
only about 10 decimal digits of fractional precision, which works out
to ~8 µs at the day scale — **worse than Foundation's own
`Date.timeIntervalSinceReferenceDate`**, which is ~100 ns at the same
era. `Moment` is the right type for astronomy (where Moshier spans
geological timescales at micro-arcsecond angular precision over
millennia) but is the wrong type for Foundation bridging.

`CivilInstant`, using explicit `Int64` nanoseconds-in-day, is exact at
nanosecond precision at every date — strictly better than, and
perfectly round-trippable against, Foundation's `Date`.

### Sub-second precision where calendar math actually needs it

`Moment` stays as it is for `AstronomicalEngine`: fractional Julian
Day in Double, for Moshier new-moon and solar-longitude calculations
that drive the Chinese, Hindu, Islamic-astronomical, and Persian
calendars. The *output* of those calculations is a civil RataDie
(the day containing the sunrise after the new moon). `Moment` and
`CivilInstant` serve different purposes and do not interact.

### Precision summary

| Type | Precision at 2024 | Use |
|---|---|---|
| Foundation `Date` | ~100 ns | public API boundary |
| **`CivilInstant` (proposed)** | **exact 1 ns** | **icu4swift ↔ Foundation boundary** |
| `RataDie` (existing) | 1 day (whole) | calendar math core |
| `Moment` (existing) | ~8 µs | astronomical engine internals |

---

## Summary

| Concern | Answer |
|---|---|
| Foundation mutability | Maps onto value types with stored properties. Zero friction. Removes a lock compared to `_CalendarICU`. |
| ICU millisecond basis | Foundation does not expose it. An adapter translates `Date ↔ CivilInstant` at the boundary. |
| Sub-day time math | Handled by the adapter as integer-nanosecond arithmetic inside `CivilInstant`, never by the calendar backend. |
| Sub-day precision | **Exact nanosecond**, via `CivilInstant`'s `Int64 nanosecondsInDay` — strictly better than Foundation's own `Date` (~100 ns at 2024). |

### Implication for the plan

No changes to icu4swift's core data model are required. What we add in
Stage 1 of the port (see `00-Overview.md`) is:

- Stored properties on each calendar struct for the Foundation-level
  knobs (`timeZone`, `firstWeekday`, `minimumDaysInFirstWeek`,
  `locale`, `gregorianStartDate`).
- A new `CivilInstant` boundary type in `CalendarCore` (`(RataDie,
  Int64 nanosecondsInDay)`) and an adapter layer that maps
  `(Date, TimeZone) ↔ CivilInstant` losslessly.
- The additional API surface Foundation expects on top of that
  (`range`, `ordinality`, `dateInterval`, `nextDate(after:matching:)`,
  etc.) — which is orthogonal to the mutability/millisecond questions
  addressed here.

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
┌─────────────────┐   ┌──────────────────────────┐
│ RataDie (day)   │   │ secondsInDay ∈ [0, 86400)│
└─────────────────┘   └──────────────────────────┘
    │                          │
    ▼ calendar math             ▼ trivial arithmetic
Y, M, D, era, week, …     hour, minute, second, ns
```

icu4swift's RataDie-first model **is** this pattern. What we need to
add is the adapter that:

1. Takes `(Date, TimeZone)` → `(RataDie, secondsInDay)`.
2. Hands `RataDie` to the calendar for Y/M/D/era/week fields.
3. Computes H/M/S/ns directly from `secondsInDay`.
4. Handles DST transitions (where a civil day is not 86400 s long) at
   the `(Date, TimeZone) ↔ RataDie` boundary — the calendar itself
   never sees DST.

The adapter is small, well-understood, and already implemented in
Foundation for Gregorian.

### Sub-second precision where it matters

icu4swift already has sub-second precision where calendar math
actually needs it: the `Moment` type in `AstronomicalEngine` is a
fractional Julian Day (`Double`, sub-microsecond precision). It is
used for Moshier new-moon and solar-longitude calculations that drive
the Chinese, Hindu, Islamic-astronomical, and Persian calendars.

The *output* of those calculations is a civil RataDie — the day
containing the sunrise after the new moon. The *input* uses fractional
JD. That boundary is already correct and does not change.

### If we ever did need millisecond resolution inside the calendar

(We don't.) It would still not be a problem. Options:

- Use `Double` fractional RataDie (already modeled by `Moment`).
- Use `Int64` ms-since-RataDie-epoch.

Either is a drop-in for anywhere a RataDie is used today. The
algorithms do not care about the backing type as long as integer-day
arithmetic is cheap.

---

## Summary

| Concern | Answer |
|---|---|
| Foundation mutability | Maps onto value types with stored properties. Zero friction. Removes a lock compared to `_CalendarICU`. |
| ICU millisecond basis | Foundation does not expose it. An adapter translates `Date → (RataDie, secondsInDay)`. |
| Sub-day time math | Handled by the adapter as seconds-since-midnight arithmetic, never by the calendar backend. |
| Could icu4swift extend to milliseconds if needed | Yes, trivially. `Moment` already does sub-microsecond. Not needed for the port. |

### Implication for the plan

No changes to icu4swift's core data model are required. What we add in
Stage 1 of the port (see `00-Overview.md`) is:

- Stored properties on each calendar struct for the Foundation-level
  knobs (`timeZone`, `firstWeekday`, `minimumDaysInFirstWeek`,
  `locale`, `gregorianStartDate`).
- An adapter layer that maps `(Date, TimeZone)` to `(RataDie,
  secondsInDay)` and back.
- The additional API surface Foundation expects on top of that
  (`range`, `ordinality`, `dateInterval`, `nextDate(after:matching:)`,
  etc.) — which is orthogonal to the mutability/millisecond questions
  addressed here.

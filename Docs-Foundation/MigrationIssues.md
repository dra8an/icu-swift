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
│ rataDie (Int)   │   │ fractionalDay (Double)       │
│ whole day       │   │ 0.0 ..< 1.0 (time-of-day)    │
└─────────────────┘   └──────────────────────────────┘
    │                          │
    ▼ calendar math             ▼ Double arithmetic
Y, M, D, era, week, …     hour, minute, second, nanosecond
```

icu4swift's RataDie-first model **is** this pattern. What we need
to add is the adapter that:

1. Takes `(Date, TimeZone)` → `(Int rataDie, Double fractionalDay)`.
2. Hands `rataDie` to the calendar for Y/M/D/era/week fields.
3. Extracts hour / minute / second / nanosecond from
   `fractionalDay` via trivial Double arithmetic.
4. Handles DST transitions (where a civil day is not 86400 s long)
   inside the `(Date, TimeZone) → (rataDie, fractionalDay)` boundary
   — the calendar itself never sees DST.

### Alignment with Foundation's existing pattern

This is the **same pattern** Foundation's `_CalendarGregorian`
already uses (see `Calendar_Gregorian.swift`):

```swift
var julianDate: Double {
    timeIntervalSinceReferenceDate / 86400 + julianDayAtDateReference
}
func julianDay() throws -> Int {
    let jd = (julianDate + 0.5).rounded(.down)
    // ...
}
```

Foundation splits `Date` into a Double `julianDate`, rounds to an
Int `julianDay` for calendar math, and handles time-of-day from the
fractional part. We match this shape exactly — same Int day + Double
time-of-day split, same precision characteristics, same integer
arithmetic for Y/M/D and same Double arithmetic for sub-day fields.

**Why we're matching Foundation's pattern rather than inventing our
own.** Earlier drafts of this document proposed a custom
`CivilInstant` type (Int64 rataDie + Int64 nanosecondsInDay) for
drift-free integer arithmetic. That design was reconsidered because:

- **Foundation's Double pattern does not actually accumulate drift
  in practice.** `_CalendarGregorian` re-converts from `Date` on
  every operation — there's no long-lived Double accumulator where
  drift could build up.
- **Matching Foundation's shape lowers review friction.** "We do it
  the same way `_CalendarGregorian` does it" is a shorter sell than
  "here's a different representation we think is better."
- **Precision at the boundary is bounded by `Date` anyway.** `Date`
  is Double; no alternative representation can add precision we
  don't receive from `Date` on input.

`Moment` (Double fractional Julian Day, ~8 µs precision at 2024)
stays in `AstronomicalEngine` for astronomy, where geological-scale
time ranges and sub-arcsecond angular precision demand that
representation. It's not used for the Foundation boundary, but
conceptually it's a close cousin to Foundation's `julianDate`.

### Sub-second precision where calendar math actually needs it

`Moment` stays as it is for `AstronomicalEngine`: fractional Julian
Day in Double, for Moshier new-moon and solar-longitude calculations
that drive the Chinese, Hindu, Islamic-astronomical, and Persian
calendars. The *output* of those calculations is a civil RataDie
(the day containing the sunrise after the new moon). `Moment` does
not participate in the Foundation boundary — the adapter uses its
own `(Int rataDie, Double fractionalDay)` split matching
`_CalendarGregorian`.

### Precision summary

| Type | Representation | Precision at 2024 | Use |
|---|---|---|---|
| Foundation `Date` | `Double` seconds since ref | ~100 ns | public API boundary |
| Foundation `_CalendarGregorian` internal | `Double julianDate` | ~86 ns (matches Date) | today's Swift-native Gregorian path |
| icu4swift Foundation adapter (planned) | Same as above — `(Int rataDie, Double fractionalDay)` | matches `_CalendarGregorian` | our new Stage 1 adapter layer |
| `Moment` (existing) | `Double` fractional RataDie | ~8 µs | astronomy internals only |
| `RataDie` (existing) | `Int64` day count | 1 day (whole) | calendar math core |

At the boundary with Foundation's `Date`, all representations top
out at `Date`'s own ~100 ns Double precision — nothing can invent
bits beyond that. We match `_CalendarGregorian`'s representation
so that our adapter and Foundation's existing Gregorian path look
and behave identically.

---

## Summary

| Concern | Answer |
|---|---|
| Foundation mutability | Maps onto value types with stored properties. Zero friction. Removes a lock compared to `_CalendarICU`. |
| ICU millisecond basis | Foundation does not expose it. An adapter splits `Date` into `(Int rataDie, Double fractionalDay)`, matching `_CalendarGregorian`'s existing pattern. |
| Sub-day time math | Handled by the adapter on `fractionalDay` (Double), same as `_CalendarGregorian`. The calendar backend never sees time-of-day. |
| Sub-day precision | Matches Foundation's Date precision (~100 ns at 2024). We match `_CalendarGregorian`'s representation exactly so the adapter and Foundation's existing Gregorian path look identical. |

### Implication for the plan

No changes to icu4swift's core data model are required. What we add in
Stage 1 of the port (see `00-Overview.md`) is:

- Stored properties on each calendar struct for the Foundation-level
  knobs (`timeZone`, `firstWeekday`, `minimumDaysInFirstWeek`,
  `locale`, `gregorianStartDate`).
- An adapter layer that splits `Date` into `(Int rataDie, Double
  fractionalDay)` — the same representation
  `_CalendarGregorian` already uses in `Calendar_Gregorian.swift`.
  No new named type is needed; the adapter is a pair of free
  functions.
- The additional API surface Foundation expects on top of that
  (`range`, `ordinality`, `dateInterval`, `nextDate(after:matching:)`,
  etc.) — which is orthogonal to the mutability/millisecond questions
  addressed here.

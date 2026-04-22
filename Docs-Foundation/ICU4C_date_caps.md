# ICU4C calendar date caps — reference

*Researched 2026-04-22 in response to a question about whether ICU4C
imposes date caps on calendars (and how that compares to icu4swift).
Kept here so the answer is ready next time the topic comes up.*

## One-paragraph answer

ICU4C has a **global absolute-time ceiling of ±0x7F000000 Julian days**
(about ±5.8 million years around the Unix epoch), enforced at the
base `Calendar` class. On top of that, each calendar overrides
`handleGetLimit()` to declare its own per-field bounds — most
non-Gregorian calendars allow **±5,000,000 years** in `EXTENDED_YEAR`,
while Gregorian itself is tighter at year **1 to 144,683 CE**.
**Chinese does *not* have a 20th-century cap** — ICU4C computes
it algorithmically over the full ±5M range, the opposite of
icu4swift's baked 1901–2099 fast path.

## Global ceiling — base `Calendar` class

Source: `icu/icu4c/source/i18n/gregoimp.h:140–158`,
enforced in `calendar.cpp:1135–1152`.

```cpp
#define MIN_JULIAN (-0x7F000000)
#define MAX_JULIAN (+0x7F000000)
#define MIN_MILLIS ((MIN_JULIAN - 2440588) * 86_400_000.0)
#define MAX_MILLIS ((MAX_JULIAN - 2440588) * 86_400_000.0)
```

- ±0x7F000000 ≈ ±2.13 billion Julian days
- ≈ ±5.8 million years around the Unix epoch
- `setTime()` with an out-of-range millisecond value:
  - **Lenient mode:** clamps to the bound.
  - **Strict mode:** throws `U_ILLEGAL_ARGUMENT_ERROR`.

## Per-calendar `handleGetLimit()` overrides

Each calendar declares a `LIMITS` table keyed on
`UCalendarDateFields`, with four columns per field:
`{MINIMUM, GREATEST_MINIMUM, LEAST_MAXIMUM, MAXIMUM}`. The pattern:

```cpp
enum ELimitType {
  UCAL_LIMIT_MINIMUM = 0,
  UCAL_LIMIT_GREATEST_MINIMUM,
  UCAL_LIMIT_LEAST_MAXIMUM,
  UCAL_LIMIT_MAXIMUM,
  UCAL_LIMIT_COUNT
};
// Exposed via:
//   Calendar::getMinimum(field)
//   Calendar::getGreatestMinimum(field)
//   Calendar::getLeastMaximum(field)
//   Calendar::getMaximum(field)
```

(`unicode/calendar.h:1645–1649`; accessors `calendar.cpp:2680–2725`.)

### Per-calendar `EXTENDED_YEAR` ranges

| Calendar | Min | Max | File:line |
|---|---:|---:|---|
| Gregorian | −140,742 | +144,683 | `gregocal.cpp:78–105` |
| Chinese | **−5,000,000** | **+5,000,000** | `chnsecal.cpp:193` |
| Hebrew | **−5,000,000** | **+5,000,000** | `hebrwcal.cpp:63` |
| Islamic | 1 | **+5,000,000** | `islamcal.cpp:243` |
| Japanese | delegates to Gregorian for most fields; `UCAL_ERA`/`UCAL_YEAR` clamped by era table | — | `japancal.cpp:257–288` |
| Coptic / Ethiopian | see `cecal.cpp` | see `cecal.cpp` | `cecal.cpp` |
| Persian / Indian / Buddhist / ROC | similar ±5M-year patterns | | `persncal.cpp`, `indiancal.cpp`, `buddhcal.cpp`, `taiwncal.cpp` |

**Key observation:** most non-Gregorian calendars explicitly allow
±5,000,000 years — wider than Gregorian's 144,683 CE cap. ICU4C
enforces these per-field via `handleComputeFields()` clamping,
not via a single global year gate.

## Chinese specifically — no 1901–2099 cap in ICU4C

`chnsecal.cpp:956–971` — `handleComputeFields()` clamps to the
full ±5M-year `EXTENDED_YEAR` range. Astronomical computation
(new moon, winter solstice) is done algorithmically with an
internal cache. **No precomputed observatory table limits the
supported range to the 20th century.**

This is deliberately different from icu4swift's Chinese strategy —
but note that **icu4swift's 1901–2099 window is an
optimization-plus-authority overlay, not a hard range cap**. Dates
outside 1901–2099 still compute correctly via the Moshier fallback
(`ChineseCalendar.swift:189–196`, `packedYear` falls through to
`ChineseYearCache`). The only hard range wall in either library is
the precision envelope of whichever astronomical model is active.

| Aspect | ICU4C | icu4swift |
|---|---|---|
| Algorithm outside the hot range | Algorithmic, full declared ±5M-year range | Moshier astronomical, ~±3000-year envelope |
| Algorithm inside 1901–2099 | Same algorithmic path | **Baked HKO-derived lookup** |
| Perf inside 1901–2099 | ~41 µs/date | **~40 ns/date** (~1000×) |
| Agreement with HKO inside 1901–2099 | Subject to astronomical-model divergences (e.g. 1906 cluster) | **Exact, by construction** |
| Stated per-field `EXTENDED_YEAR` range | −5,000,000 to +5,000,000 | None declared; bounded only by `RataDie.validRange` = ±365 M days |
| Authority for 1901–2099 window | ICU's astro model | Hong Kong Observatory |

## Comparison with icu4swift

| | ICU4C | icu4swift |
|---|---|---|
| Absolute-time global cap | ±5.8 M years (Julian-day ±0x7F000000) | Int64 day count + Foundation `Date` precision (see `SUBDAY_BOUNDARY.md`) |
| Gregorian years | 1 to 144,683 CE | No explicit per-year cap; bounded by `RataDie.validRange` |
| `RataDie.validRange` | — | ±365,000,000 days ≈ ±1,000,000 years |
| Chinese | −5M to +5M years, algorithmic | 1901–2099 baked (fast + matches HKO exactly); Moshier fallback outside, bounded by Moshier's ~±3000-year precision envelope |
| Hebrew/Islamic/Coptic/Persian/Indian | ±5M years via `handleGetLimit` | Pure Int64 arithmetic — no declared cap; bounded only by `RataDie.validRange` |
| Per-field bounds exposed as public API | **Yes** (`getMinimum` / `getMaximum` × 4 flavours) | Not exposed as API |
| How bounds are documented | Queryable at runtime; underdocumented in headers | `RataDie.validRange` constant |

## What this means for the Foundation port

- **Foundation doesn't expose ICU's per-field bounds** in its public
  API. `Calendar.maximumRange(of:)` and `Calendar.minimumRange(of:)`
  return `Range<Int>?` but callers rarely use them, and the results
  correspond to `LEAST_MAXIMUM` / `GREATEST_MINIMUM` respectively
  (not the full min/max bounds).
- Port does **not** need to preserve ICU's ±5M-year per-calendar
  bounds — those are internal clamps, not part of Foundation's
  observable surface.
- icu4swift's simpler "RataDie range + let arithmetic calendars run
  freely" model satisfies Foundation's observable behaviour without
  reimplementing ICU's `handleGetLimit` layer verbatim.
- One corner to watch: if Foundation tests assert specific values
  from `Calendar.maximumRange(of:)` at extreme fields, we may need to
  surface equivalent bounds. Otherwise, the bounds are a private
  implementation detail of `_CalendarICU`.

## Public API surface (both libraries)

```cpp
// ICU4C
int32_t Calendar::getMinimum(UCalendarDateFields field);
int32_t Calendar::getGreatestMinimum(UCalendarDateFields field);
int32_t Calendar::getLeastMaximum(UCalendarDateFields field);
int32_t Calendar::getMaximum(UCalendarDateFields field);
```

```swift
// Foundation (bridged from ICU in today's Calendar)
public func maximumRange(of component: Calendar.Component) -> Range<Int>?
public func minimumRange(of component: Calendar.Component) -> Range<Int>?
```

Foundation exposes two flavors, not four. The four ICU flavors collapse
to Foundation's two:
- `minimumRange` ≈ `(getGreatestMinimum, getLeastMaximum + 1)` — the
  range that's **always** valid for this field.
- `maximumRange` ≈ `(getMinimum, getMaximum + 1)` — the **widest
  possible** range for this field.

## Cross-references

- ICU4C source: `/Users/draganbesevic/Projects/claude/icu/icu4c/source/i18n/`
- `Docs/Chinese_reference.md` — icu4swift's 1901–2099 HKO window rationale.
- `Docs/BakedDataStrategy.md` — icu4swift's approach to baked data.
- `Docs-Foundation/02-ICUSurfaceToReplace.md` — which ICU surfaces the port
  is committed to preserving.
- `CLAUDE.md § Key Design Decisions` — `RataDie.validRange = ±365_000_000`.

# CalendarJapanese — Phase 6

*Completed: 2026-03-29*

## Overview

The Japanese calendar is the Gregorian calendar with Japanese imperial eras overlaid. There is no different arithmetic — the same `GregorianArithmetic` and `IsoDateInner` from CalendarSimple are reused. The only new logic is the era table and the lookup from (year, month, day) → era.

This is a separate target (`CalendarJapanese`) rather than being in CalendarSimple because the era data makes it conceptually distinct, and some consumers may want Gregorian without pulling in Japanese era handling.

## Era Table

| Era | Code | Start Date | Era Index | Notes |
|-----|------|------------|-----------|-------|
| Meiji | `meiji` | 1868-10-23 | 2 | Years 1-5 fall back to `ce` |
| Taisho | `taisho` | 1912-07-30 | 3 | |
| Showa | `showa` | 1926-12-25 | 4 | |
| Heisei | `heisei` | 1989-01-08 | 5 | |
| Reiwa | `reiwa` | 2019-05-01 | 6 | Current era |

The table is stored in `JapaneseEraData`, sorted by start date descending for efficient lookup (most dates are in recent eras). Era indices 0-1 are reserved for `bce`/`ce`.

## API

```swift
import CalendarJapanese

let japanese = Japanese()

// Construct with era input
let date = try Date(year: .eraYear(era: "reiwa", year: 7), month: 1, day: 1, calendar: japanese)
date.extendedYear     // 2025 (Gregorian year)
date.year.eraYear!.era   // "reiwa"
date.year.eraYear!.year  // 7

// Construct with extended year
let date2 = try Date(year: 2020, month: 2, day: 20, calendar: japanese)
date2.year.eraYear!.era  // "reiwa"
date2.year.eraYear!.year // 2

// Convert from Gregorian
let greg = try Date(year: 1912, month: 7, day: 30, calendar: Gregorian())
let jp = greg.converting(to: japanese)
jp.year.eraYear!.era     // "taisho"
jp.year.eraYear!.year    // 1
```

## Key Behaviors

### Meiji 1-5 → CE Fallback

The modern Gregorian calendar was adopted in Japan on January 1, Meiji 6 (1873). Before that date, the lunisolar calendar was in use. ICU4X handles this by displaying dates before Meiji 6 as `ce` (or `bce`) instead of `meiji`:

```swift
// 1872 = Meiji 5, but shows as CE
let date = try Date(year: 1872, month: 6, day: 15, calendar: japanese)
date.year.eraYear!.era  // "ce" (not "meiji")
date.year.eraYear!.year // 1872

// 1873 = Meiji 6, first year that shows as Meiji
let date2 = try Date(year: 1873, month: 1, day: 1, calendar: japanese)
date2.year.eraYear!.era  // "meiji"
date2.year.eraYear!.year // 6
```

Construction via `eraYear(era: "meiji", year: 1)` still works — it resolves to extended year 1868. But when queried, the era displays as `ce`.

### Extended Year = Gregorian Year

Unlike Buddhist (offset +543) or ROC (offset -1911), the Japanese calendar's extended year is the Gregorian year with no offset. `extendedYear` on a Japanese date always equals the Gregorian year.

### Era Boundary Transitions

Adjacent eras overlap on the transition date:
- Heisei 31 = April 30, 2019
- Reiwa 1 = May 1, 2019

The lookup finds the most recent era whose start date is ≤ the given date.

### Before All Eras

Dates before Meiji (1868-10-23) automatically fall through to `ce`/`bce` eras.

## Extensibility

`JapaneseEraData` is a struct, not hardcoded logic. To add a future era:

```swift
var eraData = JapaneseEraData.builtIn
// Add hypothetical future era (not a real prediction)
eraData.eras.insert(
    JapaneseEraData.EraEntry(
        code: "nextEra", eraIndex: 7,
        startYear: 2050, startMonth: 1, startDay: 1
    ),
    at: 0  // Insert at front (most recent first)
)
let calendar = Japanese(eraData: eraData)
```

ICU4X uses a similar approach with `PackedEra` for post-Reiwa eras.

## Design Decisions

### Why a separate target?

CalendarJapanese depends on CalendarSimple (for `IsoDateInner` and `GregorianArithmetic`), but CalendarSimple shouldn't depend on Japanese era data. Users who only need Gregorian/Julian/Buddhist/ROC shouldn't pull in the era table.

### Why `IsoDateInner` fields are `public`

CalendarJapanese is in a separate module from CalendarSimple. To construct `IsoDateInner` values and access year/month/day fields, the struct's properties and memberwise init needed to be made `public`. This also benefits any future targets that share `IsoDateInner`.

### Why not store era index in DateInner?

ICU4X's `JapaneseDateInner` is the same as `IsoDateInner` (Gregorian YMD). The era is computed on access, not stored. This is simpler and avoids consistency issues (what if the era data changes?). The lookup is a linear scan of at most 5 entries — negligible cost.

## ICU4C vs ICU4X: Meiji Start Date

ICU4C (and therefore Foundation `Calendar(identifier: .japanese)`) places the
Meiji era start at **September 8, 1868** — this is Meiji 1/1/1 in the old
lunisolar calendar, converted to the proleptic Gregorian calendar.

ICU4X (and therefore icu4swift) places the Meiji era start at
**October 23, 1868** — the date of the era name proclamation.

This is a well-known divergence between the two ICU implementations; neither
is "wrong" — they simply use different historical conventions for the same
event. In practice the difference is invisible because **both** fall back to
`ce`/`bce` for dates before Meiji 6 (January 1, 1873). The modern Gregorian
calendar was not adopted in Japan until that date, so the lunisolar calendar
was still in official use for Meiji 1–5. No user-facing date is affected.

The regression test validates from **1873 onward** (Meiji 6), where both
implementations agree on every era boundary. The CSV is generated from
Foundation and covers all 5 eras (meiji/taisho/showa/heisei/reiwa) through
2100 — 2,744 sample points, 0 failures.

## Source

- **ICU4X** `components/calendar/src/cal/japanese.rs` — main implementation
- **ICU4X** `components/calendar/src/provider.rs` — `EraStartDate`, `JapaneseEras`, `PackedEra`
- **ICU4X** `components/datetime/tests/fixtures/tests/japanese.json` — formatting test fixtures

## Test Coverage

Unit tests (`JapaneseTests.swift`, 15 tests):
- All 5 era boundary transitions (start dates, day-before = previous era)
- Heisei→Reiwa consecutive day transition
- Meiji 6 switchover (pre-1873 → CE, post-1873 → Meiji)
- 9 era year input round-trips from ICU4X `test_japanese`
- 7 fixture dates from ICU4X datetime test data
- Japanese↔Gregorian calendar conversion
- Extended year = Gregorian year
- Round-trip across all era boundaries (3,000+ RD values)
- BCE dates through Japanese calendar
- Invalid era rejection

Regression test (`JapaneseRegressionTests.swift`):
- **2,744 sample points** (first-of-month 1873–2100 + exact era boundary
  days) vs Foundation, validating era code, era year, month, and day.
  Currently 0 failures.

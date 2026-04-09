# Persian Calendar

*Implemented: Phase 3 | Target: CalendarComplex | Regression pass: 2026-04-08*

## Overview

The Persian calendar (also called the Solar Hijri or Jalali calendar) is the
official civil calendar of **Iran** and **Afghanistan**. It is a solar
calendar whose year begins at **Nowruz**, the day of the vernal equinox in
Tehran (UTC+3:30).

There are two implementations of the same calendar:

- **Astronomical Solar Hijri** — leap years are determined by the actual
  vernal equinox observation in Tehran. This is the *official* civil
  definition.
- **33-year arithmetic rule** — a tabular approximation that produces
  identical results to the astronomical algorithm in the modern era and
  diverges only by a single day in occasional far-future years.

icu4swift implements the **33-year arithmetic rule with a NON_LEAP_CORRECTION
table**, which is the same approach taken by ICU4X, ICU4C, and the
Reingold/Dershowitz "modern Persian" algorithm. The 78-entry correction
table records years where the 33-year rule would place a leap year in the
wrong position, so the implementation produces astronomical results without
ever computing the equinox.

Across the validated 1900–2100 range, the arithmetic and astronomical
algorithms produce **identical** new-year dates.

## Calendar Structure

- **Type:** Solar (rule-based, but tracks the astronomical year)
- **Identifier:** `persian`
- **Era:** single era `ah` (Anno Persico / Solar Hijri)
- **Months:** 12, fixed length except month 12
- **Year length:** 365 (common) or 366 (leap)
- **Epoch:** R.D. 226896 = March 19, 622 CE Julian (the Hijra year, in solar terms)
- **Year start:** Nowruz, on or about March 20–21 Gregorian

### Months

| #  | Name (transliteration) | Persian       | Days   | Season  |
|---:|------------------------|---------------|-------:|---------|
| 1  | Farvardin              | فروردین        | 31     | Spring  |
| 2  | Ordibehesht            | اردیبهشت       | 31     | Spring  |
| 3  | Khordad                | خرداد         | 31     | Spring  |
| 4  | Tir                    | تیر           | 31     | Summer  |
| 5  | Mordad                 | مرداد         | 31     | Summer  |
| 6  | Shahrivar              | شهریور         | 31     | Summer  |
| 7  | Mehr                   | مهر           | 30     | Autumn  |
| 8  | Aban                   | آبان          | 30     | Autumn  |
| 9  | Azar                   | آذر           | 30     | Autumn  |
| 10 | Dey                    | دی            | 30     | Winter  |
| 11 | Bahman                 | بهمن          | 30     | Winter  |
| 12 | Esfand                 | اسفند          | 29 / 30 | Winter |

The first six months always have 31 days, the next five always have 30, and
Esfand has 29 or 30 depending on whether the year is leap. This makes month
arithmetic exceptionally cheap.

## How It Works

### 1. The 33-year cycle

In each 33-year cycle, 8 years are leap. The leap-year test is:

```swift
var r = (25 * Int64(year) + 11) % 33
return r < 8
```

This formula produces the leap years 1, 5, 9, 13, 17, 22, 26, 30 in each
cycle (and equivalent positions in shifted cycles), spaced as evenly as 8/33
allows.

### 2. The correction table

The pure 33-year rule drifts from the actual vernal equinox by ~1 day every
few centuries. icu4swift carries a **78-entry correction table** of years
where the rule would place the leap day in the wrong position:

```swift
private static let nonLeapCorrection: [Int32] = [
    1502, 1601, 1634, 1667, 1700, 1733, 1766, 1799, 1832, 1865, 1898, 1931,
    1964, 1997, 2030, 2059, 2063, 2096, ...
]
```

For each year `Y` in the table:
- `isLeapYear(Y)` returns **false** (the 33-year rule would say true).
- `isLeapYear(Y + 1)` returns **true** (the leap day moves forward one year).

The table runs to year ~2987 AP (≈ 3608 CE), keeping the calendar
astronomically correct for the next millennium without any equinox
computation.

### 3. Month / day arithmetic

Because the month lengths are fixed (31×6 + 30×5 + 28/29), recovering the
month from the day-of-year is a closed-form expression:

```swift
let month = dayOfYear <= 186
    ? UInt8(ceilDiv(dayOfYear, 31))
    : UInt8(ceilDiv(dayOfYear - 6, 30))
```

The first six months sum to 186 days; after that the pattern shifts to
length-30 months, hence the `- 6` correction.

## Design Decisions

- **33-year rule + correction table over astronomical computation.** Same
  approach as ICU4X / ICU4C / Reingold-Dershowitz "modern Persian." Avoids
  pulling AstronomicalEngine into CalendarComplex (Phase 3 has no astronomy
  dependencies). The correction table is small (78 entries), and the
  resulting calendar is bit-identical to the astronomical version
  everywhere it has been validated.
- **Single era `ah`.** The Persian calendar in icu4swift uses positive year
  numbers (1 AP = 622 CE). Negative / BCE-equivalent years are supported via
  `extendedYear` but not via a separate era — the proleptic Persian calendar
  isn't widely used anywhere.
- **`PersianArithmetic` is `internal`.** Unlike `HebrewArithmetic` (which is
  `public` because cross-module tests need it), Persian's arithmetic is only
  used inside CalendarComplex.

## Usage

```swift
import CalendarComplex

let persian = Persian()

// Build a date directly
let nowruz = try persian.newDate(
    year: .extended(1404),
    month: .new(1),
    day: 1
)

// Convert from Gregorian
let rd = GregorianArithmetic.fixedFromGregorian(year: 2025, month: 3, day: 21)
let date = Date<Persian>.fromRataDie(rd, calendar: persian)
// date.extendedYear == 1404, month 1 (Farvardin), day 1 — Nowruz 1404

// Year metadata
persian.isInLeapYear(date.inner)   // true for 1403 (last 6-day-Esfand year before 1408)
persian.daysInYear(date.inner)     // 365 or 366
persian.daysInMonth(date.inner)    // 31 for Farvardin
```

## Validation

The Persian calendar is validated against **two independent reference
sources** — see `Docs/Persian_reference.md` for the data setup and
regenerate scripts:

1. **Foundation `Calendar(identifier: .persian)`** — wraps ICU4C, which uses
   the same 33-year rule + correction table.
2. **Python [`convertdate.persian`](https://pypi.org/project/convertdate/)**
   — independent implementation that computes the **actual** vernal equinox
   for each year (true astronomical Solar Hijri).

The two sources **agree across the entire validated 1900–2100 range** — the
33-year rule and the astronomical algorithm don't diverge in this window.
The next mismatch is somewhere around year 2256 AP / 2877 CE in some cited
tables.

The regression test `Tests/CalendarComplexTests/PersianRegressionTests.swift`
checks **3,064 sample points** across 1900–2100:

- 12 first-of-month days per year (Nowruz boundary covered as M1 D1)
- Day 2 of Farvardin (extra new-year coverage)
- Last days of Esfand (28 / 29 / 30 — exercises leap-year length)

≈ 15 samples × 201 years.

```
Persian regression: checked 3064 sample points, failures 0
✔ Test "Persian 1900-2100 sample vs Foundation+convertdate" passed after 0.007s
```

**0 disagreements.** A sparse sample is sufficient because Persian month
lengths are fixed — once the new-year date matches and the leap flag
matches, the rest of the year is mechanical.

## Test Coverage

Unit tests (`PersianTests.swift`, ~30 `@Test` functions, 479 lines):

- Epoch is March 19, 622 Julian
- ICU4X reference RD ↔ Persian conversions
- Leap year rule: 33-year cycle + every entry in the correction table
- Month lengths (31 / 30 / 29 / 30)
- Year lengths (365 / 366)
- Round-trip RD → Persian → RD across many years
- New-year (Nowruz) dates verified against ICU4X
- Era handling
- Boundary cases at the edges of the correction table

Regression test (`PersianRegressionTests.swift`):

- **3,064 daily sample points** vs Foundation + convertdate across 1900–2100,
  currently 0 failures.

## Source

- ICU4X `calendrical_calculations/src/persian.rs` — primary port source for
  `PersianArithmetic`, including the fast 33-year rule and the
  `NON_LEAP_CORRECTION` table.
- ICU4X `components/calendar/src/cal/persian.rs` — public-facing wrapper
  and era / month-code conventions.
- Reingold & Dershowitz, *Calendrical Calculations*, 4th edition, Chapter 15
  ("The Modern Persian Calendar").
- Foundation `Calendar(identifier: .persian)` and Python
  [`convertdate.persian`](https://github.com/fitnr/convertdate) —
  independent reference implementations used for the daily sample regression.

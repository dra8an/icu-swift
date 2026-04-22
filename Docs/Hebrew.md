# Hebrew Calendar

*Implemented: Phase 3 | Target: CalendarComplex | Regression pass: 2026-04-08*

## Overview

The Hebrew (Jewish) calendar is a **lunisolar arithmetic** calendar. Since
Hillel II fixed the rules ~358 CE, it has been fully deterministic — no
astronomical observations are involved. Months still approximate true new
moons, but only via a fixed mean-lunation constant; the calendar slowly
drifts relative to the actual moon and sun.

## Calendar Structure

- **Type:** Lunisolar (rule-based, no astronomy)
- **Identifier:** `hebrew`
- **Era:** single era `am` (Anno Mundi); year 1 AM = 3761 BCE
- **Months:** 12 in common years, 13 in leap years
- **Month lengths:** 29 or 30 days (mostly fixed; Cheshvan & Kislev vary)
- **Year lengths:** one of six values — 353, 354, 355 (common); 383, 384, 385 (leap)
- **Year types (keviyot):** 14 total combinations of starting weekday × length × leap
- **Epoch:** R.D. -1373427 (Julian Oct 7, -3761 book year)

### Civil vs Biblical Month Ordering

The Hebrew tradition has two month orderings:

- **Biblical order** — Nisan = 1, Tishrei = 7 (used in the Torah and in
  Reingold/Dershowitz's algorithms internally).
- **Civil order** — Tishrei = 1, Elul = 12 (used for "Hebrew year 5784 starts
  in Tishrei"; this is the public-facing convention).

`Hebrew` exposes **civil** ordering. `HebrewArithmetic` uses **biblical**
ordering internally and converts at the boundary via `civilToBiblical` /
`biblicalToCivil`.

#### Civil month table

| Civil # | Common year | Leap year |
|--------:|-------------|-----------|
| 1  | Tishrei  | Tishrei  |
| 2  | Cheshvan | Cheshvan |
| 3  | Kislev   | Kislev   |
| 4  | Tevet    | Tevet    |
| 5  | Shevat   | Shevat   |
| 6  | Adar     | Adar I (M05L) |
| 7  | Nisan    | Adar (M06)    |
| 8  | Iyyar    | Nisan         |
| 9  | Sivan    | Iyyar         |
| 10 | Tammuz   | Sivan         |
| 11 | Av       | Tammuz        |
| 12 | Elul     | Av            |
| 13 | —        | Elul          |

The leap month is presented as `M05L` (Adar I) per the Temporal proposal —
month code `5` with the leap suffix — even though it occupies civil ordinal
position 6 in leap years.

## How It Works

The Hebrew calendar reduces to four pieces of arithmetic:

### 1. Leap year rule (19-year Metonic cycle)

```swift
static func isLeapYear(_ year: Int32) -> Bool {
    var r = (7 * Int64(year) + 1) % 19
    if r < 0 { r += 19 }
    return r < 7
}
```

Leap years are positions 3, 6, 8, 11, 14, 17, 19 of each 19-year cycle —
exactly 7 of every 19 years are leap, fixed forever.

### 2. The molad — mean new moon arithmetic

The molad is a *fictional* mean new moon, computed as a constant integer
offset from the molad of Tishrei at Creation:

```
mean lunation = 29 days, 12 hours, 793 halakim
              = 29 + 12/24 + 793/(24·1080) days
              ≈ 29.530594 days
```

(One hour = 1080 halakim. The constant is Babylonian — accurate to ~0.5 s vs
the true mean synodic month, but never updated as that drifts.)

### 3. Four dehiyyot (Rosh Hashanah postponements)

Rosh Hashanah is shifted forward 1–2 days from the molad of Tishrei when any
of these apply:

1. **Lo ADU Rosh** — RH cannot fall on Sunday, Wednesday, or Friday.
2. **Molad Zaken** — if the molad of Tishrei falls at or after noon, postpone.
3. **GaTaRaD** — common year, molad on Tuesday ≥ 9h 204p, postpone 2 days.
4. **BeTU'TaKPaT** — year after a leap year, molad on Monday ≥ 15h 589p, postpone.

These rules guarantee Yom Kippur never falls on Friday/Sunday and Hoshana
Rabbah never on Shabbat.

### 4. Year length is determined

Once Rosh Hashanah of year N and year N+1 are placed, year N's length falls
out as one of the six allowed values. That length determines whether
Cheshvan and Kislev are 29 or 30 days (the only two months whose lengths
vary).

## Design Decisions

- **Civil ordering in the public API.** Most modern Hebrew calendar consumers
  (Hebcal, every Jewish wall calendar, "Rosh Hashanah is the start of the
  year") expect Tishrei = month 1. Biblical ordering stays hidden in
  `HebrewArithmetic`.

- **Biblical ordering internally.** Reingold/Dershowitz's algorithms are
  expressed in biblical months, so we keep the math in their native form and
  only translate at the public boundary.

- **`HebrewArithmetic` is `public`.** Other calendars that share Hebrew
  arithmetic (none today, but the door is open) and the test suite need
  direct access to `isLeapYear`, `civilToBiblical`, etc.

- **No tables.** Unlike the Chinese calendar (`china_data`, `qing_data`), the
  Hebrew calendar has zero precomputed data. Everything reduces to integer
  arithmetic on the year number.

## Usage

```swift
import CalendarComplex

let hebrew = Hebrew()

// Build a date by civil month (Tishrei = 1)
let roshHashana = try hebrew.newDate(
    year: .extended(5784),
    month: .new(1),
    day: 1
)

// Convert from Gregorian
let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 4, day: 23)
let date = Date<Hebrew>.fromRataDie(rd, calendar: hebrew)
// date.extendedYear == 5784, civil month 8 (Nisan), day 15 — first night of Pesach

// Leap month (Adar I) in leap year 5784
let adarI = try hebrew.newDate(
    year: .extended(5784),
    month: .leap(5),
    day: 1
)
// Civil ordinal 6 in leap year, code "M05L"

// Year metadata
hebrew.isInLeapYear(date.inner)   // true for 5784
hebrew.daysInYear(date.inner)     // 385 (5784 is a leap year, max length)
hebrew.monthsInYear(date.inner)   // 13
```

## Validation

The Hebrew calendar is validated against the open-source
[`@hebcal/core`](https://www.npmjs.com/package/@hebcal/core) library — see
`Docs/Hebrew_reference.md` for the data setup, regenerate script, and
month-name mapping.

The regression test
`Tests/CalendarComplexTests/HebrewRegressionTests.swift` checks every
Gregorian day from **1900-01-01 to 2100-12-31** (73,414 days) against
`hebrew_1900_2100_hebcal.csv`:

```
Hebrew regression: checked 73414 days, failures 0
✔ Test "Hebrew daily conversions: 1900-2100 vs Hebcal" passed after 0.287s
```

**0 disagreements** — exactly as expected for a deterministic arithmetic
calendar. Any future failure is a real bug.

## Test Coverage

Unit tests (`HebrewTests.swift`, 18 `@Test` functions, 419 lines):

- Epoch (`R.D. -1373427`)
- ICU4X / Reingold reference RD ↔ Hebrew conversion table (~30 cases)
- Leap year rule (Metonic cycle positions)
- Biblical ↔ civil month conversion round-trip
- Year length one of {353, 354, 355, 383, 384, 385}
- Cheshvan / Kislev length variations
- Adar I / Adar II handling in leap years
- Round-trip RD → Hebrew → RD across many years
- ICU bug 22441 regression (year 88369, length 383)
- Negative-era (BCE) years
- Weekday checks

Regression test (`HebrewRegressionTests.swift`):

- **73,414 daily conversions** vs Hebcal across 1900–2100, currently 0 failures.

Extreme-range tests (`Tests/ExtremeRangeTests/`):

- **Two-point smoke test** at RD ±10,000,000,000 (~±27 M years):
  passes as of 2026-04-22 after Int64 widening.
- **Exhaustive ±10,000-year round-trip** (7,305,216 days, every day):
  passes as of 2026-04-22 after three internal fixes. The exhaustive
  test is what surfaced fix #3 (which the smoke test would never have
  caught).

All three fixes landed 2026-04-22, each caused by the same underlying
issue — Swift's `/` truncates toward zero, but R&D's algorithms assume
mathematical floor division. Each manifested at a different scale:

1. **`hebrewFromFixed` year approximation.** `(dayDelta * 98496) / 35975351`
   skewed one year high at extreme negatives, stranding the forward-only
   search loop past the true year. Result: negative day-of-year remainder,
   trapped a later `UInt8(rem + 1)` init at ~−365 M RD. Fix: route through
   a `floorDiv` helper (new).
2. **`calendarElapsedDays` return type.** Was `Int32`. Intermediate `days`
   value scales as ~365 × year and overflowed Int32 at year ≈ ±5.88 M
   (RD ~±2.15 B). Fix: widen return type to `Int64`. Callers already
   widened to Int64 before combining, so no public API change.
3. **`calendarElapsedDays` internal divisions.** `(235·year − 234) / 19`
   and `partsElapsed / 25920` still used truncating `/`, producing a
   ~29-day offset at negative years. Silent bug caught only by the
   exhaustive ±10,000-year test (9,840 failures at year ≈ −6,223 and
   below before the fix). Fix: floor-div on both.

`HebrewDateInner.year` is still `Int32`, consistent with the other
calendars — 32-bit year width is ~±2.15 B years, comfortably past any
practical input. The three fixes above address internal arithmetic
correctness at extreme negative RDs; none of them changes modern-range
behaviour (73,414-day Hebcal regression stayed at 0/73,414 through all
three fixes).

## Source

- ICU4X `calendrical_calculations/src/hebrew.rs` (Apache-2.0) — primary port
  source for `HebrewArithmetic`.
- ICU4X `components/calendar/src/cal/hebrew.rs` — public-facing wrapper and
  era / month-code conventions.
- Reingold & Dershowitz, *Calendrical Calculations*, 4th edition, **Chapter 8**.
- [Hebcal](https://www.hebcal.com/) and the
  [`@hebcal/core`](https://github.com/hebcal/hebcal-es6) JS/TS library —
  independent reference implementation used for regression.

# Chinese Calendar

*Implemented: 2026-03-30, leap month fix 2026-04-01 | Phase 4b | Target: CalendarAstronomical*

## Overview

The Chinese calendar is a lunisolar calendar determined by astronomical observations. Months begin at new moons, and a leap month is inserted when 13 lunations fall between consecutive winter solstices. The year uses a 60-year cycle (天干地支, Heavenly Stems and Earthly Branches).

## Calendar Structure

- **Type:** Lunisolar (astronomical)
- **Identifier:** `chinese`
- **Months:** 12 in common years, 13 in leap years
- **Month lengths:** 29 or 30 days (determined by new moon dates)
- **Year length:** 353-355 days (common) or 383-385 days (leap)
- **Year numbering:** 60-year cyclic (`CyclicYear`) with `relatedIso` for disambiguation
- **Reference location:** Beijing (UTC+8, pre-1929: local mean solar time 116.4°E)

## How It Works

### 1. Winter Solstice
Find the day when solar longitude reaches 270° (冬至, Dōngzhì). This anchors the solar year (歲, suì).

### 2. New Moon Enumeration
Find all new moons between consecutive winter solstices. If there are 13 new moons, the year has a leap month.

### 3. Leap Month Detection
The first month that does **not contain a zhōngqì** (major solar term — a 30° boundary crossing) is the leap month.

**Critical rule:** A month "contains" a zhōngqì if the sun crosses a multiple of 30° during that month. This is checked by **forward comparison**: if the major solar term at the start of month N equals the major solar term at the start of month N+1, then no 30° crossing occurred during month N, and it is the leap month.

```swift
// Correct (forward comparison — matching ICU4X):
if majorSolarTerm(thisNewMoon) == majorSolarTerm(nextNewMoon) {
    // thisMonth has no zhōngqì → it is the leap month
}
```

### 4. New Year
The second new moon after the winter solstice (month 1, day 1), unless a leap month falls in months 11-12 of the previous year.

## The 2023 Leap Month Bug Fix

The initial implementation used a **backward** comparison (`terms[i] == terms[i-1]`), which identified the wrong month as the leap. This produced M03L instead of the correct M02L for Chinese year 2023.

The bug was discovered through a chain of validation:
1. Our result (M03L) disagreed with ICU4X (M02L)
2. Initially attributed to astronomical precision differences
3. Hindu project Moshier engine confirmed solar longitude = 29.837° at the boundary
4. **Real Swiss Ephemeris (JPL DE431)** confirmed: 29.837° — all engines agree, no precision issue
5. Re-reading the Chinese calendar rule revealed the forward vs backward comparison error
6. Confirmed by reading ICU4X's `get_leap_month_from_new_year` — forward comparison

The fix was a one-line change: compare current month's term with the **next** month's term, not the previous.

## Performance

Computing a Chinese year requires ~15 new moon calculations via the Moshier engine (~600ms). A `ChineseYearCache` (LRU, 8 entries, `os_unfair_lock`) avoids recomputation for consecutive dates in the same year:

| Operation | Without cache | With cache | Speedup |
|-----------|------:|------:|------:|
| Single date | 586 ms | 650 ms | ~1x |
| 3 dates, same year | 1,727 ms | 650 ms | 2.7x |
| 30 consecutive days | 25,378 ms | 644 ms | **39x** |

## Usage

```swift
import CalendarAstronomical

let chinese = Chinese()

// Convert from Gregorian
let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 2, day: 10)
let date = Date<Chinese>.fromRataDie(rd, calendar: chinese)
// date.extendedYear == 2024, month 1, day 1 (Chinese New Year!)

// Cyclic year
date.year.cyclicYear?.yearOfCycle  // 41 (Jia-Chen, Year of the Dragon)

// Month codes
date.month.code  // "M01"

// Leap month example (2023 has leap month 2)
let leapDate = Date<Chinese>.fromRataDie(
    GregorianArithmetic.fixedFromGregorian(year: 2023, month: 4, day: 9),
    calendar: chinese
)
leapDate.month.code  // "M02L" (leap month 2)
```

## Known Limitation

Ancient dates (before ~1900): our astronomical calculation may differ from ICU4X by ±1 month near leap month boundaries. ICU4X uses a mean-based approximation for dates outside its precomputed range (1900-2100). We always compute astronomically. Both approaches are valid; they use different algorithms.

## Test Coverage

11 tests:
- 16 ICU4X reference RD→Chinese conversions
- Month lengths for 2023 (13 months, verified day-by-day)
- 15 ISO→Chinese month code mappings (M02L leap month verified)
- 6 Chinese New Year dates (2020-2025)
- Round-trip: every day in 2023-2024 (~730 dates)
- 60-year cyclic year verification (including 60-year wrap)
- Year structure: 353-385 days, 12-13 months, 29-30 day months
- Calendar conversion round-trip

## Source

- ICU4X `calendrical_calculations/src/chinese_based.rs` — `get_leap_month_from_new_year`, `major_solar_term_from_fixed`, `new_moon_on_or_after`, `winter_solstice_on_or_before`
- ICU4X `components/calendar/src/cal/east_asian_traditional.rs` — test data, `ChineseFromFixedResult`
- Reingold & Dershowitz, *Calendrical Calculations*, 4th edition, Chapter 19
- Swiss Ephemeris (JPL DE431) — leap month boundary validation

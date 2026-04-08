# Chinese Calendar

*Implemented: 2026-03-30, leap month fix 2026-04-01, HKO-accuracy pass 2026-04-08 | Phase 4b | Target: CalendarAstronomical*

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

`ChineseYearData.compute` computes the 12 (or 13) months of a Chinese year in four steps.

### 1. Find the New Year (this year and next)

A nested helper `findNewYear(forJan1:)` computes M01 of a given Chinese year:

1. Find the **winter solstice on or before** the target January 1 (Reingold's `estimatePriorSolarLongitude` at 270°, then day-refined against the engine's `solarLongitude`).
2. `m11 = newMoonOnOrBefore(solstice)` — the 11th month is the lunation *containing* the solstice (not the one after it). Getting this wrong by one new moon (using `OnOrAfter`) was the single biggest source of prior failures.
3. `m12 = newMoonOnOrAfter(m11 + 1)`, `m13 = newMoonOnOrAfter(m12 + 1)`.
4. Normally `m13` is M01 (the new year). If either M11 or M12 is itself a leap month (detected via forward-comparison of major solar terms), new year is pushed one lunation further.

`compute` calls `findNewYear` for both the current and next Chinese year. The interval `[newYear, nextNewYear)` defines the year's total span.

### 2. Iterate 12 Months

Starting from `newYear`, iterate exactly 12 months:

```swift
for i in 0..<12 {
    let next = newMoonOnOrAfter(current + 1)
    let nextTerm = majorSolarTerm(next)
    if currentTerm == nextTerm {
        detectedLeap = UInt8(i)  // take the LAST such pair, not the first
    }
    monthLengths.append((next - current) == 30)
    current = next
    currentTerm = nextTerm
}
```

A month has no zhōngqì — and is therefore a leap month — when `majorSolarTerm(current) == majorSolarTerm(next)`, because the sun didn't cross a 30° boundary during the lunation.

**Why last, not first?** Boundary-precision false positives (new moons where a zhōngqì falls within ~1 hour of local midnight) typically fire earlier in the year than the real leap month. Taking the last match gives the real leap in all observed cases.

### 3. Detect the 13th Month (if any)

After 12 iterations, if `current != nextNewYear` the year has a 13th month:

```swift
if current != nextNewYear {
    monthLengths.append((nextNewYear - current) == 30)
    leapMonthNum = detectedLeap ?? 12  // 13th month is leap if none found earlier
}
// 12-month year: commit nothing, dropping any false-positive leap
```

This handles the rare M11L case (Chinese year 2033): the leap month is the year's 13th and final month, and no same-term pair is found during the 12 iterations because the leap month itself is at the boundary. The fallback assigns it directly. Matches ICU4X's `month_structure_for_year` algorithm.

### 4. Midnight Epsilon Snap

`newMoonOnOrAfter` applies a small correction when the computed local moment falls within `1e-4` days (~8.6 seconds) past local midnight — in that case it snaps back to the previous day. This compensates for sub-second-level precision differences between Moshier (VSOP87/DE404) and HKO's astronomical source at conjunctions that happen within seconds of midnight.

```swift
let frac = local - local.rounded(.down)
if frac < 1e-4 {
    return RataDie(Int64(local.rounded(.down)) - 1)
}
return RataDie(Int64(local.rounded(.down)))
```

The tolerance is tight enough that no normal new moon timing is affected — only the literal "few seconds past midnight" edge case.

## Validation

The Chinese calendar is validated against **Hong Kong Observatory** (HKO) authoritative data — see `Docs/HKO_reference.md`. The regression test at `Tests/CalendarAstronomicalTests/ChineseRegressionTests.swift` checks all 2,461 month rows across Chinese years 1901–2099 (199 years, 73 of them leap) against `chinese_months_1901_2100_hko.csv`.

**Current accuracy: 2,458 / 2,461 rows match HKO (~99.88%).** The 3 remaining failures are all in a single 1906 M03→M04 cluster, where Moshier places the April 1906 new moon 8 minutes before midnight Apr 24 LMT while HKO places it on Apr 24 — a genuine astronomical model disagreement at the historical end of the table, accepted as a known limitation.

### History of the accuracy work

The session that brought the count from 245 to 3 is documented in `backup/snap00..snap03/` and `backup/README.md`. Key fixes in order:

1. **Replaced the regression test's CSV source** with HKO-derived data. The prior CSV was derived from ICU4X's `china_data.rs` via a script that had an off-by-one bug interpreting the `Some(N)` ordinal-position encoding as a display number, producing ~121 false alarms.
2. **Fixed `nm11 = newMoonOnOrBefore(solstice)`** — was `newMoonOnOrAfter`, off by one new moon.
3. **Rewrote `compute` around `findNewYear`** for both the current and next year, iterating exactly 12 months and applying a "13th month is leap if none detected" fallback. This handles M11L-style leaps (year 2033) that fall in a different sui from the year being computed.
4. **Take the LAST same-term pair** (guards against boundary-precision false positives earlier in the year) and **only commit a leap if there's actually a 13th month** (drops false positives in 12-month years).
5. **Midnight epsilon snap** — see step 4 above.

An earlier fix (2026-04-01) had resolved the 2023 M02L case by switching from a **backward** to a **forward** solar term comparison. That fix is still in place and correct.

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

**1906 M03→M04 boundary (3 regression failures).** Moshier places the April 1906 new moon at Apr 23 23:52:04 LMT — 8 minutes before midnight — so our code assigns M04 to Apr 23. HKO and ICU4X's HKO-derived `qing_data` place it on Apr 24. This is an 8-minute discrepancy (too far to be a rounding boundary), in the opposite direction from the epsilon snap, and appears to be a real Moshier-vs-HKO astronomical model disagreement at the historical end of the table. Accepted as a known limitation; resolving it would require embedding a JPL-grade ephemeris matching HKO's source.

Ancient dates well before 1900 may also differ from HKO/ICU4X at leap-month boundaries for similar precision reasons; those are not covered by the regression test.

## Test Coverage

Unit tests (all passing):
- 16 ICU4X reference RD→Chinese conversions
- Month lengths for 2023 (13 months, verified day-by-day)
- 15 ISO→Chinese month code mappings (M02L leap month verified)
- 6 Chinese New Year dates (2020-2025)
- Round-trip: every day in 2023-2024 (~730 dates)
- 60-year cyclic year verification (including 60-year wrap)
- Year structure: 353-385 days, 12-13 months, 29-30 day months
- Calendar conversion round-trip

Regression test (`ChineseRegressionTests.swift`):
- **2,461 month rows** from Hong Kong Observatory data spanning Chinese years 1901-2099 (199 years, 73 leap months).
- Checks `month.number`, `isLeap`, `dayOfMonth == 1`, `extendedYear`, and `daysInMonth` for each row.
- Currently at **3 failures** (1906 M03→M04 cluster) — see Known Limitation above.

## Source

- ICU4X `calendrical_calculations/src/chinese_based.rs` — `get_leap_month_from_new_year`, `month_structure_for_year`, `major_solar_term_from_fixed`, `new_moon_on_or_after`, `new_moon_before`, `winter_solstice_on_or_before`, `new_year_in_sui`
- ICU4X `components/calendar/src/cal/east_asian_traditional.rs` — reference data, leap_month indexing semantics (`leap_month` returns the 1-indexed ordinal position, display number = position - 1)
- Reingold & Dershowitz, *Calendrical Calculations*, 4th edition, Chapter 19
- **Hong Kong Observatory** lunisolar tables for 1901-2100 — authoritative validation source. See `Docs/HKO_reference.md`.
- Swiss Ephemeris (JPL DE431) — leap month boundary validation for 2023

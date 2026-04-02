# Dangi (Korean) Calendar

*Implemented: 2026-03-30 | Phase 4b | Target: CalendarAstronomical*

## Overview

The Dangi calendar (단기, 檀紀) is the Korean traditional lunisolar calendar. It uses the same astronomical algorithm as the Chinese calendar but with a different reference location (Seoul) and a different epoch (founding of Gojoseon).

## Calendar Structure

- **Type:** Lunisolar (astronomical)
- **Identifier:** `dangi`
- **Months:** 12 in common years, 13 in leap years
- **Month lengths:** 29 or 30 days (determined by new moon dates)
- **Year length:** 353-355 days (common) or 383-385 days (leap)
- **Year numbering:** 60-year cyclic (`CyclicYear`) with `relatedIso` for disambiguation
- **Reference location:** Seoul (UTC+9)

## Relationship to Chinese Calendar

Dangi and Chinese are the same algorithm parameterized differently via the `EastAsianVariant` protocol:

```swift
public typealias Chinese = ChineseCalendar<China>
public typealias Dangi = ChineseCalendar<Korea>
```

| Aspect | Chinese | Dangi |
|--------|---------|-------|
| Identifier | `chinese` | `dangi` |
| Modern UTC offset | UTC+8 | UTC+9 |
| Pre-1908 UTC offset | 1397/180/24 (Beijing 116.4°E) | 3809/450/24 (Seoul 126.97°E) |
| Historical offsets | One change (1929) | Four changes (1908, 1912, 1954, 1961) |
| Epoch | Feb 15, -2636 (Chinese traditional) | Feb 15, -2332 (Gojoseon founding) |

### UTC Offset History (Korea)

| Period | Offset | Reason |
|--------|--------|--------|
| Before 1908 | +8.464h (local mean solar) | Traditional |
| 1908-1911 | +8.5h | First standard time |
| 1912-1953 | +9.0h | Japanese occupation |
| 1954-1961 | +8.5h | Post-war adjustment |
| 1961-present | +9.0h | Current KST |

### When Do They Differ?

Because Seoul is 1 hour ahead of Beijing, the same new moon can fall on different local dates. This means:
- Most years: Chinese and Dangi have the same month/day for a given RD
- Occasionally: a new moon near local midnight falls on different dates, shifting a month boundary by 1 day
- Rarely: a different month boundary changes which month lacks a zhōngqì, producing a different leap month

## Usage

```swift
import CalendarAstronomical

let dangi = Dangi()

let date = Date<Dangi>.fromRataDie(
    GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 15),
    calendar: dangi
)

date.extendedYear           // 2024 (related ISO year)
date.year.cyclicYear?.yearOfCycle  // cyclic position (1-60)
date.month.code             // month code (e.g., "M05")
date.dayOfMonth             // day of month

// Convert to ISO and back
let iso = Iso()
let isoDate = date.converting(to: iso)
let backToDangi = isoDate.converting(to: dangi)
// backToDangi == date
```

## Test Coverage

8 tests:
- Different epoch from Chinese (verified)
- Calendar identifiers (`dangi` vs `chinese`)
- Round-trip: every day in 2023-2024 (~730 dates)
- Year structure: 12-13 months, 353-385 days, 29-30 day months
- Dangi↔Chinese alignment for same RD
- Calendar conversion round-trip (Dangi→ISO→Dangi)

## Source

- ICU4X `calendrical_calculations/src/chinese_based.rs` — `ChineseBased` trait, `Dangi` implementation with UTC offset history
- ICU4X `components/calendar/src/cal/east_asian_traditional.rs` — `Korea` rules implementation, test data
- Korea Astronomy and Space Science Institute — historical calendar validation

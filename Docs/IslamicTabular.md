# Islamic Tabular Calendar

*Implemented: 2026-03-30 | Phase 4b | Target: CalendarAstronomical*

## Overview

The Islamic Tabular calendar is a purely arithmetic approximation of the Islamic lunar calendar. It uses a 30-year cycle to determine leap years, with no astronomical calculations needed.

## Calendar Structure

- **Type:** Lunar
- **Identifier:** `islamic-tbla`
- **Months:** 12 (always — no leap months)
- **Month lengths:** Odd months (1,3,5,7,9,11) = 30 days; even months (2,4,6,8,10) = 29 days; month 12 = 30 days in leap years
- **Year length:** 354 days (common) or 355 days (leap)
- **Epoch:** July 16, 622 CE Julian (Friday epoch)
- **Eras:** `ah` (Anno Hegirae), `bh` (Before Hijrah)

## Leap Year Rule

11 leap years per 30-year cycle (Type II): years 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29.

Formula: `(14 + 11 × year) mod 30 < 11`

## Key Formula

```
RataDie = epoch - 1 + (year-1) × 354 + floor((3 + year×11) / 30)
        + 29 × (month-1) + floor(month/2) + day
```

## Usage

```swift
import CalendarAstronomical

let islamic = IslamicTabular()

// Construct with AH era
let date = try Date(year: .eraYear(era: "ah", year: 1445), month: 1, day: 1, calendar: islamic)

// Construct with extended year
let date2 = try Date(year: 1445, month: 6, day: 15, calendar: islamic)

// Before Hijrah
let bh = try Date(year: .eraYear(era: "bh", year: 1), month: 1, day: 1, calendar: islamic)
// bh.extendedYear == 0
```

## Variants Not Yet Implemented

- **Umm al-Qura:** Saudi Arabia's official calendar. Requires a lookup table of precomputed month lengths from KACST. Years 1300-1600 AH covered by ICU4X data.
- **Observational (Saudi criterion):** Uses crescent moon visibility at Mecca. Requires moonrise/moonset calculations and the Shaukat visibility criterion.

## Test Coverage

14 tests:
- All 33 reference date pairs from Reingold & Dershowitz / ICU4X (years -1245 to 1518 AH)
- Round-trip: 20,000 dates near RD zero + 2,000 near epoch
- 30-year leap cycle verification (positive, negative, and cycle repetition)
- Month lengths for both common and leap years
- Year lengths across full 30-year cycle (11 leap years verified)
- Era handling (ah/bh with extended year mapping)
- Directionality: -100..100

## Source

- ICU4X `calendrical_calculations/src/islamic.rs` — `fixed_from_tabular_islamic`, `tabular_islamic_from_fixed`
- ICU4X `components/calendar/src/cal/hijri.rs` — 33 reference date pairs
- Reingold & Dershowitz, *Calendrical Calculations*, 4th edition, Chapter 6

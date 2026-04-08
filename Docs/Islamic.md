# Islamic Tabular & Islamic Civil Calendars

*Implemented: Phase 4b | Refactored: 2026-04-08 | Target: CalendarAstronomical*

## Overview

Two CLDR calendars share a single arithmetic implementation:

- **`islamic-tbla`** — *tabular astronomical*, Thursday epoch (Jul 15, 622 Julian)
- **`islamic-civil`** — *civil*, Friday epoch (Jul 16, 622 Julian)

They are otherwise identical: same Type II 30-year leap cycle, same 12-month
structure, same era handling. The only difference is a 1-day shift of the
epoch — a historical disagreement about the exact date of Mohammed's
migration to Mecca.

Both are **purely arithmetic** approximations. Neither is used by any
government for actual religious purposes (Saudi Arabia uses Umm al-Qura;
most Muslim countries rely on actual lunar crescent sighting); they exist as
deterministic conversion calendars for scholarly and computer-historical use.

## Calendar Structure

- **Type:** Lunar (rule-based, no astronomy)
- **Identifiers:** `islamic-tbla`, `islamic-civil`
- **Eras:** `ah` (Anno Hegirae) and `bh` (Before Hijrah)
- **Months:** 12, alternating 30/29 days
- **Month 12:** 29 days (common) or 30 days (leap)
- **Year length:** 354 (common) or 355 (leap)
- **Leap cycle:** 30 years, 11 leap (Type II positions: 2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29)

### Months

| # | Name             | Days |
|--:|------------------|-----:|
| 1 | Muḥarram         | 30 |
| 2 | Ṣafar            | 29 |
| 3 | Rabīʿ al-Awwal   | 30 |
| 4 | Rabīʿ al-Thānī   | 29 |
| 5 | Jumādá al-Awwal  | 30 |
| 6 | Jumādá al-Thānī  | 29 |
| 7 | Rajab            | 30 |
| 8 | Shaʿbān          | 29 |
| 9 | Ramaḍān          | 30 |
| 10| Shawwāl          | 29 |
| 11| Dhū al-Qaʿdah    | 30 |
| 12| Dhū al-Ḥijjah    | 29 / 30 |

## How It Works

Three pieces of arithmetic, all epoch-independent except where noted:

### 1. Leap year (Kūshyār ibn Labbān, Type II)

```swift
static func isLeapYear(_ year: Int32) -> Bool {
    var r = (14 + 11 * Int64(year)) % 30
    if r < 0 { r += 30 }
    return r < 11
}
```

This produces leap years at exactly 11 of every 30 cycle positions:
2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29.

### 2. `fixedFromTabular` — (year, month, day) → R.D.

```
RD = epoch - 1
   + (year - 1) * 354
   + floor((3 + year * 11) / 30)   // accumulated leap days
   + 29 * (month - 1) + floor(month / 2)
   + day
```

The `floor((3 + 11y) / 30)` term counts how many leap days have accumulated
since the epoch, so the total stays an integer day count.

### 3. `yearFromFixed` — R.D. → year (epoch-dependent)

```
year = floor((30 * (date - epoch) + 10646) / 10631)
```

The mean year is `10631/30 = 354.366…` days. The `+10646` (= `10631 + 15`)
half-cycle bias places year boundaries correctly. **An earlier approximate
formula** (`30·diff/10631 + 1 if diff≥0`) was off-by-one at end-of-year
boundaries — see [History](#history) below.

The month and day are then recovered by subtracting `fixedFromTabular(year, 1, 1)`
from the date and using `month = floor((priorDays·11 + 330) / 325)`.

## Design Decisions

### One arithmetic, two calendars

`IslamicTabularArithmetic` is a single `enum` with epoch-parameterized
functions:

```swift
enum IslamicTabularArithmetic {
    static func isLeapYear(_ year: Int32) -> Bool
    static func daysInMonth(year: Int32, month: UInt8) -> UInt8
    static func fixedFromTabular(year: Int32, month: UInt8, day: UInt8, epoch: RataDie) -> RataDie
    static func tabularFromFixed(_ date: RataDie, epoch: RataDie) -> (Int32, UInt8, UInt8)
}
```

Both calendar facades share the same `IslamicTabularDateInner` (since the
inner triple `(year, month, day)` carries no epoch state on its own).

### `IslamicTabular` is configurable, default `.thursday`

```swift
public enum TabularEpoch: Sendable, Hashable {
    case thursday  // Jul 15, 622 — astronomical (islamic-tbla)
    case friday    // Jul 16, 622 — civil (islamic-civil)
}

public struct IslamicTabular: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "islamic-tbla"
    public let epoch: TabularEpoch
    public init(epoch: TabularEpoch = .thursday)
}
```

The default `.thursday` matches the CLDR meaning of `islamic-tbla`. The
`epoch` property is exposed for completeness, but for the Friday variant the
`IslamicCivil` calendar is the proper choice — it has the correct identifier.

### `IslamicCivil` is a thin facade

```swift
public struct IslamicCivil: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "islamic-civil"
    public typealias DateInner = IslamicTabularDateInner
    // ... forwards every operation through IslamicTabularArithmetic with the Friday epoch
}
```

Type-distinct from `IslamicTabular`, so `Date<IslamicCivil>` and
`Date<IslamicTabular>` are separate generic instantiations even though they
share the same inner storage.

## Usage

```swift
import CalendarAstronomical

// "islamic-tbla" — default Thursday epoch
let tabular = IslamicTabular()
let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 4, day: 9)
let d1 = Date<IslamicTabular>.fromRataDie(rd, calendar: tabular)
// d1 = 1445 / Shawwāl (10) / 1

// "islamic-civil" — Friday epoch
let civil = IslamicCivil()
let d2 = Date<IslamicCivil>.fromRataDie(rd, calendar: civil)
// d2 = 1445 / Ramaḍān (9) / 30  — one day "earlier" than tabular for the same RD

// Direct construction
let dhul = try civil.newDate(year: .extended(1445), month: .new(12), day: 10)

// Both eras
let bce = try Date(year: .eraYear(era: "bh", year: 1), month: 1, day: 1, calendar: civil)
```

## Validation

Both calendars are validated by **two independent reference sources**:

1. **Foundation `Calendar(identifier:)`** — `.islamicTabular` and
   `.islamicCivil`, which are thin wrappers over ICU4C.
2. **Python [`convertdate`](https://pypi.org/project/convertdate/)** —
   independent pure-Python implementation derived from Reingold &
   Dershowitz's Lisp code.

Foundation and `convertdate` agree bit-for-bit across 1900–2100 (after
shifting `convertdate` by ±1 day to bridge the two epochs). See
`Docs/Islamic_reference.md` for the data setup, regenerate scripts, and
epoch correspondence table.

The regression test
`Tests/CalendarAstronomicalTests/IslamicTabularRegressionTests.swift` checks
every Gregorian day from **1900-01-01 to 2100-12-31** (73,414 days each) for
both calendars:

```
Islamic Tabular regression: checked 73414 days, failures 0
Islamic Civil    regression: checked 73414 days, failures 0
```

## History

Two real bugs were uncovered while building this regression suite (2026-04-08):

1. **Misnamed calendar.** The original `IslamicTabular` had identifier
   `islamic-tbla` but used the **Friday** epoch — i.e. it was implementing
   `islamic-civil` semantics under the wrong name. Fixed by introducing a
   configurable `TabularEpoch`, defaulting `IslamicTabular` to `.thursday`,
   and adding `IslamicCivil` as a separate facade.

2. **Approximate `yearFromFixed`.** The original formula
   `30·diff/10631 + (diff ≥ 0 ? 1 : 0)` was off-by-one at end-of-year
   boundaries. The 33 hand-picked ICU4X reference cases never hit a year
   boundary so the bug was silent until the daily regression caught it
   (104 failures across 200 years, all of the form `Y/12/30` instead of
   `(Y+1)/1/1`). Replaced with ICU4X's exact integer formula
   `floor((30·(date − epoch) + 10646) / 10631)`.

Both fixes landed together; both calendars are now at 0 failures.

## Test Coverage

`IslamicTabularTests.swift` (Thursday epoch, default):

- 33 ICU4X `ASTRONOMICAL_CASES` reference pairs (RD ↔ Hijri)
- Round-trip RD → Date → RD for `[-10000, 10000]`
- Round-trip ±1000 days around the epoch
- 30-year leap cycle (Type II positions verified)
- Month / year lengths
- Year gap consistency (354 or 355 only)
- Era handling (ah / bh)
- Directionality (RD ordering = Date ordering)
- Identifier check
- Cross-check: `IslamicTabular(epoch: .friday)` ≡ `IslamicCivil`

`IslamicCivilTests.swift` (Friday epoch):

- 33 ICU4X `ARITHMETIC_CASES` reference pairs (RD ↔ Hijri)
- Round-trip wide range and around epoch
- Identifier check

`IslamicTabularRegressionTests.swift`:

- **73,414 daily conversions** for each of `IslamicTabular` and `IslamicCivil`
  (1900–2100), 0 failures.

## Source

- ICU4X `calendrical_calculations/src/islamic.rs` — primary port source for
  `IslamicTabularArithmetic`, including the corrected `yearFromFixed`.
- ICU4X `components/calendar/src/cal/hijri.rs` — `TabularAlgorithmEpoch` /
  `TabularAlgorithmLeapYears` design and the 33 + 33 reference test pairs
  (`ARITHMETIC_CASES`, `ASTRONOMICAL_CASES`).
- Reingold & Dershowitz, *Calendrical Calculations*, 4th edition, Chapter 7.
- Kūshyār ibn Labbān (10th century) — original Type II 30-year leap pattern.
- Foundation `Calendar(identifier: .islamicTabular | .islamicCivil)` and
  Python [`convertdate.islamic`](https://pypi.org/project/convertdate/) —
  independent reference implementations used for the daily regression.

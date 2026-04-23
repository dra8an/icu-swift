# icu4swift

> **⚠ Archived — this repository is frozen.**
> All continuing work on pure-Swift calendar implementations happens in
> [`swift-foundation`](https://github.com/swiftlang/swift-foundation),
> directly replacing `_CalendarICU` inside Foundation per identifier.
> See `Docs-Foundation/PORT_DIRECTION.md` for the decision record.

A type-safe, pure-Swift calendar library ported from [ICU4X](https://github.com/unicode-org/icu4x) (Rust) and [ICU4C](https://unicode-org.github.io/icu/) (C++). Covers **all 28 `Foundation.Calendar.Identifier` cases** with a modern Swift 6 API, strict concurrency, and zero dependencies.

Developed 2025–2026 as the staging ground for a Foundation calendar rewrite. Code, tests, benchmarks, and reference data all move into swift-foundation as the port progresses. This repo remains as the historical record of how the algorithms and perf narrative were developed.

## Status

- **28 calendar systems** implemented across **9 targets**.
- **306,897 dates verified** against external reference sources (see **Testing** below), plus thousands of in-code round-trip and edge-case tests. Full suite runs in ~30 s in release mode; Swift Testing parallelises suites, and the ~30 s floor is set almost entirely by the 55,152-day Hindu lunisolar regression (~3.3 ms/date on the still-astronomical Moshier path — not yet baked). All other calendars combined complete in well under a second.
- One standing failure on an ICU-vs-HKO physical disagreement for 3 Chinese dates in 1906; see `Docs/Chinese_reference.md`.
- **Fast.** See **Performance** below.

## Calendar systems

All 28 `Foundation.Calendar.Identifier` cases are covered:

| Target | Calendars |
|---|---|
| **CalendarCore** | Protocols + types: `CalendarProtocol`, `Date<C>`, `RataDie`, `Month`, `Weekday`, `YearInfo`, `Location` |
| **CalendarSimple** | ISO, Gregorian, Julian, Buddhist, ROC |
| **CalendarComplex** | Hebrew, Coptic, Ethiopian, Ethiopian Amete Alem, Persian, Indian |
| **CalendarJapanese** | Japanese (Meiji → Reiwa, extensible era table) |
| **AstronomicalEngine** | Moshier VSOP87 + Reingold + Hybrid engines — validated against Swiss Ephemeris (JPL DE431) to 0.00001° |
| **CalendarAstronomical** | Islamic Civil, Islamic Tabular, Islamic Umm al-Qura, Islamic Astronomical, Chinese, Dangi, Vietnamese |
| **CalendarHindu** | Tamil, Bengali, Odia, Malayalam (solar), Amanta, Purnimanta (lunisolar) — 100 % validated |
| **DateArithmetic** | `DateDuration`, `added(_:)`, `until(_:largestUnit:)` — Temporal spec |
| **CalendarFoundation** | `Foundation.Date ↔ RataDie + time-of-day` adapter with DST-aware assembly |

### Planned

- `DateFormat` — semantic skeletons, raw patterns, CLDR data
- `DateParse` — pattern-based parsing
- `DateFormatInterval` — interval and relative formatting

## Performance

All round-trip measurements taken in release mode (`swift test -c release`) with clean benchmarking methodology (no `#expect` in timed loops, 100 k iterations, warm-up excluded, checksum to prevent dead-code elimination). See `Docs-Foundation/BENCHMARK_RESULTS.md` for full numbers.

| Family | icu4swift | ICU4C direct | Foundation `Calendar` API |
|---|---:|---:|---:|
| Simple / arithmetic (Gregorian, Coptic, Ethiopian, Persian, Japanese, Indian) | 9–26 ns | 250–330 ns | ~1,100–1,400 ns |
| Hebrew | 96 ns | 1,085 ns | ~1,600 ns |
| Islamic ×3 (Civil / Tabular / UQ) | 20–43 ns | 330–721 ns | ~1,200–1,300 ns |
| Chinese / Dangi (baked, 1901–2099) | 38–42 ns | 41,652 ns | ~12,000 ns |
| Hindu solar (baked) | 109–200 ns | macOS 26+ only | macOS 26+ only |
| Hindu lunisolar (Moshier) | ~3.3 ms | macOS 26+ only | macOS 26+ only |

**icu4swift is 10–40× faster than raw ICU4C on arithmetic calendars and ~1,000× on Chinese.** The win is an API-shape consequence: ICU's `ucal_set` / `add` / `roll` contract forces full field recalculation on every read; our Date is an immutable value type and avoids that tax entirely.

## Usage

### Basic calendar use

```swift
import CalendarSimple
import CalendarComplex

let iso = Iso()
let today = try Date(year: 2024, month: 3, day: 15, calendar: iso)

// Convert between calendars — hub-and-spoke through RataDie
let hebrew = Hebrew()
let hebrewDate = today.converting(to: hebrew)
print(hebrewDate)               // hebrew: 5784-M06-5
print(hebrewDate.extendedYear)  // 5784
print(hebrewDate.weekday)       // .friday
print(hebrewDate.isInLeapYear)  // true

// Era input
let greg = Gregorian()
let caesar = try Date(year: .eraYear(era: "bce", year: 44),
                      month: 3, day: 15, calendar: greg)
```

### Date arithmetic

```swift
import DateArithmetic

let date  = try Date(year: 1992, month: 9, day: 2, calendar: Iso())
let later = try date.added(DateDuration(years: 1, months: 2, weeks: 3, days: 4))
// later = 1993-11-27

// Month-end clamping: Jan 31 + 1 month = Feb 28 (or throw with .reject)
let jan31 = try Date(year: 2021, month: 1, day: 31, calendar: Iso())
let feb28 = try jan31.added(.forMonths(1), overflow: .constrain)

// Compute difference
let diff = date.until(later, largestUnit: .years)
// 1 year, 2 months, 25 days
```

### Foundation interop (sub-day time)

```swift
import Foundation
import CalendarCore
import CalendarFoundation

let now = Foundation.Date()          // absolute instant
let tz  = TimeZone.current

// Decompose to civil RataDie + time-of-day
let (rd, sec, ns) = rataDieAndTimeOfDay(from: now, in: tz)
// → RD 739363, secondsInDay 51_234, nanosecond 123_456_789 (at TZ-local wall time)

// Assemble back — with DST-aware policies
let back = date(rataDie: rd, hour: 14, minute: 30, in: tz)

// On DST transitions, choose the resolution
let skipped = date(
    rataDie: rd,
    hour: 2, minute: 30,  // 02:30 on spring-forward day
    in: TimeZone(identifier: "America/Los_Angeles")!,
    skippedTimePolicy: .latter  // interpret as post-shift (PDT), not pre-shift (PST)
)
```

The adapter matches `_CalendarGregorian`'s split pattern in swift-foundation. See `Docs-Foundation/SUBDAY_BOUNDARY.md` for the design record.

## Architecture

**Hub-and-spoke conversion** through `RataDie` (fixed day number, midnight-based, epoch 0001-01-01 ISO — as in Reingold & Dershowitz). No direct calendar-to-calendar paths.

```
Date<Iso>       ─┐
Date<Hebrew>    ─┤
Date<Persian>   ─┼── RataDie ──┬─ Date<Gregorian>
Date<Coptic>    ─┤             ├─ Date<Julian>
Date<Chinese>   ─┤             └─ Date<Buddhist>
Date<HinduLuni> ─┘
```

**`CalendarProtocol`** defines the contract: `newDate`, `toRataDie`, `fromRataDie`, plus field accessors. Each calendar is a lightweight struct (most zero-size, a few carry configuration like `Chinese`'s `EastAsianVariant` or `HinduLunisolar`'s `Location`).

**`Date<C>`** is a generic, immutable value type parameterised over the calendar. Compile-time type safety: `Date<Hebrew>` cannot be accidentally passed where `Date<Gregorian>` is expected. Runtime-selected calendars use `Date<AnyCalendar>` in future `CalendarAll`.

**`CalendarFoundation`** is the adapter layer. It lives *above* the calendar layer — sub-day time is carried in `(secondsInDay, nanosecond)` alongside RataDie, and the calendar itself never sees time-of-day. This matches `_CalendarGregorian`'s pattern in swift-foundation.

**Target-level granularity** via SPM: depend on `CalendarSimple` without pulling in `CalendarComplex`, astronomical engines, or Foundation.

## Adding to your project

```swift
// Package.swift
dependencies: [
    .package(url: "<your-clone-url>.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "CalendarSimple",      package: "icu4swift"),
            .product(name: "CalendarComplex",     package: "icu4swift"),
            .product(name: "CalendarFoundation",  package: "icu4swift"),
        ]
    ),
]
```

## Testing

```bash
swift test -c release   # ~30 seconds; Hindu lunisolar (not yet baked) is the long pole
```

Use `-c release` — the Moshier VSOP87 astronomical calculations run ~50× slower in debug mode.

### Dates verified against external references

**306,897 total dates**, zero divergences (except 3 known ICU-vs-HKO disagreements on Chinese 1906 dates).

| Calendar | Dates verified | Span | Reference source |
|---|---:|---|---|
| Hebrew | **73,414** | every day, 1900 – 2100 | [Hebcal](https://www.hebcal.com/) |
| Islamic Civil | **73,414** | every day, 1900 – 2100 | `Foundation` + [convertdate](https://pypi.org/project/convertdate/) |
| Islamic Tabular | **73,414** | every day, 1900 – 2100 | `Foundation` + convertdate |
| Hindu lunisolar (Amanta, Purnimanta) | **55,152** | every day, 1900 – 2050 | [drikpanchang.com](https://www.drikpanchang.com/) |
| Hindu solar × 4 (Tamil, Bengali, Odia, Malayalam) | **7,244** | month starts, 1900 – 2050 | drikpanchang.com |
| Islamic Umm al-Qura | **4,379** | every day, 1300 – 1600 AH (~1882 – 2174 CE) | [KACST](https://www.kacst.edu.sa/) via ICU4X |
| Coptic | **3,265** | month starts, 1900 – 2100 | `Foundation` + convertdate |
| Ethiopian | **3,265** | month starts, 1900 – 2100 | `Foundation` + convertdate |
| Indian (Saka) | **3,215** | month starts, 1900 – 2100 | `Foundation` + convertdate |
| Persian | **3,063** | month starts, 1900 – 2100 | `Foundation` + convertdate |
| Japanese | **2,743** | Meiji 6 – Reiwa, 1873 – 2100 | `Foundation` |
| Chinese (primary) | **2,461** | month starts, 1901 – 2099 | [Hong Kong Observatory](https://www.hko.gov.hk/) |
| Chinese (cross-check) | **1,868** | month starts, 1900 – 2050 | `Foundation` |

### Other validation

- **Moshier VSOP87 engine** — cross-validated against Swiss Ephemeris / JPL DE431 to 0.00001°.
- **Date arithmetic** — every day in 2000 – 2001 × multiple month/year offsets.
- **Foundation adapter (`CalendarFoundation`)** — 45 dedicated tests: UTC round-trips, every hour of 2024-06-15, fixed-offset TZs (±05:00 through ±13:00, +00:30, +05:45 Nepal, `America/Phoenix`), LA spring-forward and fall-back with `.former` / `.latter` policies, Sydney southern-hemisphere DST, Berlin 1900 pre-standardisation, year ±10,000 to ±1,000,000, nanosecond precision profile.
- **Directionality checks** — ensuring RataDie ordering matches YMD ordering across all calendars.
- **Round-trip verification** — tens of thousands of random dates per calendar.

## Sources

Algorithms ported from:

- [ICU4X](https://github.com/unicode-org/icu4x) `calendrical_calculations` crate (Apache-2.0)
- [ICU4X](https://github.com/unicode-org/icu4x) `icu_calendar` component (Unicode License)
- Reingold & Dershowitz, *Calendrical Calculations*, 4th edition (2018)

Reference data sources are listed in the Testing table above.

## Requirements

- Swift 6.0 +
- macOS 14 + / iOS 17 +
- No external dependencies

## License

Apache-2.0

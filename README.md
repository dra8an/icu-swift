# icu4swift

A type-safe Swift calendar library inspired by [ICU4X](https://github.com/unicode-org/icu4x) and [ICU4C](https://unicode-org.github.io/icu/). Provides correct, well-tested implementations of world calendar systems with a modern Swift API.

## Calendar Systems

20 calendar systems implemented across 8 targets:

| Target | What | Notes |
|--------|------|-------|
| **CalendarCore** | Protocols and types | `CalendarProtocol`, `Date<C>`, `RataDie`, `Month`, `Weekday`, `YearInfo`, `Location`, `DateStatus` |
| **CalendarSimple** | ISO, Gregorian, Julian, Buddhist, ROC | Gregorian-family arithmetic with era/offset variants |
| **CalendarComplex** | Hebrew, Coptic, Ethiopian, Persian, Indian | Lunisolar, 13-month, and solar calendars |
| **CalendarJapanese** | Japanese | Gregorian + era overlay (Meiji→Reiwa), extensible era table |
| **AstronomicalEngine** | Moshier + Reingold + Hybrid | VSOP87/DE404 (±1″) and Meeus polynomials |
| **CalendarAstronomical** | Islamic Tabular, Chinese, Dangi | 30-year cycle arithmetic + lunisolar astronomical |
| **CalendarHindu** | Tamil, Bengali, Odia, Malayalam, Amanta, Purnimanta | Solar + lunisolar Hindu calendars (accuracy WIP) |
| **DateArithmetic** | `DateDuration`, add/until | Temporal-spec algorithms, works with all calendars |

### Planned

| Target | What |
|--------|------|
| **CalendarAstronomical** | Islamic (Umm al-Qura, Observational) |
| **DateFormat** | Semantic skeletons, raw patterns, CLDR data |
| **DateParse** | Pattern-based parsing |
| **DateFormatInterval** | Interval and relative formatting |

## Usage

```swift
import CalendarSimple
import CalendarComplex

// Create dates
let iso = Iso()
let today = try Date(year: 2024, month: 3, day: 15, calendar: iso)

// Convert between calendars
let hebrew = Hebrew()
let hebrewDate = today.converting(to: hebrew)
print(hebrewDate) // hebrew: 5784-M06-5

// Access fields
print(hebrewDate.extendedYear)  // 5784
print(hebrewDate.weekday)       // .friday
print(hebrewDate.isInLeapYear)  // true

// Construct with era input
let greg = Gregorian()
let bce = try Date(year: .eraYear(era: "bce", year: 44), month: 3, day: 15, calendar: greg)

// All conversions go through RataDie (hub-and-spoke)
let persian = Persian()
let nowruz = bce.converting(to: persian)

// Date arithmetic (works with any calendar)
import DateArithmetic

let date = try Date(year: 1992, month: 9, day: 2, calendar: iso)
let later = try date.added(DateDuration(years: 1, months: 2, weeks: 3, days: 4))
// later = 1993-11-27

// Month-end clamping: Jan 31 + 1 month = Feb 28 (constrain) or error (reject)
let jan31 = try Date(year: 2021, month: 1, day: 31, calendar: iso)
let feb28 = try jan31.added(.forMonths(1), overflow: .constrain)

// Compute difference between dates
let diff = date.until(later, largestUnit: .years)
// diff = 1 year, 2 months, 25 days
```

## Architecture

**Hub-and-spoke conversion** through `RataDie` (fixed day numbers from Reingold & Dershowitz). No direct calendar-to-calendar paths needed.

```
Date<Iso> ─────┐
Date<Hebrew> ──┤
Date<Persian> ─┼── RataDie ──┼── Date<Gregorian>
Date<Coptic> ──┤             ├── Date<Julian>
Date<Indian> ──┘             └── Date<Buddhist>
```

**`CalendarProtocol`** defines the contract: `newDate`, `toRataDie`, `fromRataDie`, plus field accessors. Each calendar is a lightweight struct (most are zero-size) conforming to this protocol.

**`Date<C>`** is a generic, immutable value type parameterized over the calendar. Compile-time type safety: a `Date<Hebrew>` cannot be accidentally passed where a `Date<Gregorian>` is expected.

**Target-level granularity** via SPM: depend on `CalendarSimple` without pulling in `CalendarComplex` or future targets.

## Adding to Your Project

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/anthropics/icu4swift.git", from: "0.1.0"),
],
targets: [
    .target(
        name: "MyApp",
        dependencies: [
            .product(name: "CalendarSimple", package: "icu4swift"),
            .product(name: "CalendarComplex", package: "icu4swift"),
        ]
    ),
]
```

## Testing

270 tests across 44 suites, verified against ICU4X reference data and Reingold & Dershowitz "Calendrical Calculations" (4th ed.).

```bash
swift test
```

Test data includes:
- 33 fixed-date pairs from Calendrical Calculations (Hebrew)
- 293 Nowruz dates from the University of Tehran (Persian)
- 48 ISO-Hebrew date pairs from ICU4X
- Round-trip verification over tens of thousands of dates per calendar
- Directionality checks ensuring RataDie ordering matches YMD ordering
- Exhaustive day arithmetic: every day in 2000-2001 tested with multiple offsets
- Moshier engine validated against real Swiss Ephemeris (JPL DE431) to 0.00001° precision
- Chinese calendar leap month (M02L) verified against Swiss Ephemeris and ICU4X

## Sources

Algorithms ported from:
- [ICU4X](https://github.com/unicode-org/icu4x) `calendrical_calculations` crate (Apache-2.0)
- [ICU4X](https://github.com/unicode-org/icu4x) `icu_calendar` component (Unicode License)
- Reingold & Dershowitz, *Calendrical Calculations*, 4th edition (2018)

## Requirements

- Swift 6.0+
- macOS 14+ / iOS 17+

## License

Apache-2.0

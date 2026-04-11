# CLAUDE.md

## Project Overview

icu4swift is a type-safe Swift calendar library porting algorithms from ICU4X (Rust) and ICU4C (C++) to Swift. It implements world calendar systems using a hub-and-spoke architecture where all conversions go through RataDie (fixed day numbers).

## Build & Test

```bash
swift build              # Build all targets
swift test -c release    # Run all 283 tests (~30 seconds in release mode)
```

No external dependencies. Swift 6.0, strict concurrency enabled.

**Always use `-c release`** for test runs — the Moshier VSOP87 calculations are 50x slower in debug mode (~2 minutes vs ~5 seconds).

## Package Structure

```
Sources/
  CalendarCore/          # Protocols, RataDie, Date<C>, Month, Weekday, YearInfo, errors
  CalendarSimple/        # ISO, Gregorian, Julian, Buddhist, ROC + arithmetic helpers
  CalendarComplex/       # Hebrew, Coptic, Ethiopian, Persian, Indian + arithmetic helpers
  CalendarJapanese/      # Japanese calendar with era data (Meiji→Reiwa)
  AstronomicalEngine/    # Reingold + Moshier + HybridEngine, Moment, Location
  CalendarAstronomical/  # Islamic Tabular + Islamic Civil, Chinese, Dangi + year cache
  CalendarHindu/         # Tamil, Bengali, Odia, Malayalam (solar) + Amanta, Purnimanta (lunisolar) + Ayanamsa
  DateArithmetic/        # DateDuration, Date.added(), Date.until(), balance algorithm
Tests/
  CalendarCoreTests/     # 26 tests for core types
  CalendarSimpleTests/   # 48 tests for simple calendars
  CalendarComplexTests/  # 53 tests for complex calendars
  CalendarJapaneseTests/ # 15 tests for Japanese calendar
  AstronomicalEngineTests/ # 36 tests for Reingold, Moshier, cross-validation
  CalendarAstronomicalTests/ # tests for Islamic Tabular, Islamic Civil, Chinese, Dangi + perf + regression
  CalendarHinduTests/    # 33 tests: ayanamsa, solar, lunisolar, CSV regression
  DateArithmeticTests/   # 24 tests for date arithmetic
Docs/                    # Architecture analysis and implementation plan
```

## Key Design Decisions

- **`CalendarProtocol`** in `CalendarCore/Calendar.swift` — all calendars conform to this. Associated type `DateInner` holds the internal date representation.
- **`Date<C: CalendarProtocol>`** in `CalendarCore/Date.swift` — generic immutable date. Fields are computed via the calendar instance.
- **`RataDie`** in `CalendarCore/RataDie.swift` — universal day-count pivot. R.D. 1 = January 1, year 1 ISO.
- **Arithmetic enums** (`GregorianArithmetic`, `JulianArithmetic`, `HebrewArithmetic`, `CopticArithmetic`, `PersianArithmetic`) are `public` because CalendarComplex depends on CalendarSimple's arithmetic.
- **`IsoDateInner`** is shared by ISO, Gregorian, Buddhist, and ROC (they differ only in era mapping). `JulianDateInner` is separate because Julian has different arithmetic.
- **Hebrew calendar** uses civil month ordering (Tishrei = month 1) publicly, but converts to biblical month ordering (Nisan = month 1) internally for the Reingold & Dershowitz algorithms.
- **Coptic/Ethiopian** share `CopticArithmetic` — Ethiopian is Coptic with a different epoch offset.
- **Persian** uses the fast 33-year rule with a 78-entry NON_LEAP_CORRECTION table, not the 2820-year cycle.
- **DateArithmetic** depends only on CalendarCore — it extends `Date<C>` generically, so it works with any calendar without importing CalendarSimple/Complex. Uses the Temporal spec's NonISODateAdd / NonISODateUntil / BalanceNonISODate algorithms.
- **CalendarJapanese** depends on CalendarSimple (shares `IsoDateInner` and `GregorianArithmetic`). `IsoDateInner` fields and init are `public` so CalendarJapanese can access them across module boundaries. `JapaneseEraData` is a struct with a sorted era table — extensible for future eras without code changes.
- **AstronomicalEngine** depends only on CalendarCore (for `RataDie`). Contains `Moment` (fractional RataDie), `Location`, and three engine implementations. MoshierEngine is refactored from the Hindu calendar project — all mutable scratch arrays converted to local variables for `Sendable`. Validated against real Swiss Ephemeris (JPL DE431) to 0.00001° precision.
- **CalendarAstronomical** depends on CalendarCore, CalendarSimple, and AstronomicalEngine. Chinese calendar uses `HybridEngine` for astronomical calculations with `ChineseYearCache` for performance. `ChineseYearData.compute` uses a `findNewYear` helper called for both the current and next Chinese year, then iterates exactly 12 months between them and applies the "13th month is leap if no leap detected" fallback (matching ICU4X's `month_structure_for_year`). Leap detection uses forward comparison of major solar terms, taking the **last** same-term pair and only committing if `current != nextNewYear` (guards against boundary-precision false positives). `newMoonOnOrAfter` applies a sub-10-second midnight epsilon snap to match HKO boundary placements. Chinese calendar validates against authoritative Hong Kong Observatory data in `Tests/CalendarAstronomicalTests/chinese_months_1901_2100_hko.csv` — see `Docs/Chinese_reference.md`.
- **Islamic Tabular & Civil** are two CLDR calendars sharing one arithmetic implementation (`IslamicTabularArithmetic`, epoch-parameterized). `IslamicTabular` (identifier `islamic-tbla`) takes a `TabularEpoch` and defaults to `.thursday` (Jul 15, 622 Julian); `IslamicCivil` (identifier `islamic-civil`) is a separate calendar facade hard-coded to `.friday` (Jul 16, 622 Julian). Both share `IslamicTabularDateInner`. Validated daily 1900–2100 against two independent sources (Foundation and Python `convertdate`) — see `Docs/Islamic_reference.md`. The `yearFromFixed` formula must use ICU4X's exact `floor((30·diff + 10646) / 10631)` — the simpler `30·diff/10631 + 1` approximation is off-by-one at end-of-year boundaries.
- **Islamic Umm al-Qura** (`islamic-umalqura`) is Saudi Arabia's official Hijri calendar, using observation-based month lengths from KACST. Uses a 301-entry baked data table (`PackedHijriYearData`, UInt16 per year) for 1300–1600 AH (~1882–2174 CE), falling back to Islamic Civil arithmetic outside that range. Data originates from KACST → ICU4C → ICU4X; offsets recomputed for our epoch using Foundation. Validated against official Saudi government dates and Foundation (4,380 / 0). See `Docs/Islamic.md`.

## Test Coverage and Per-Calendar Docs

See `Docs/TestCoverageAndDocs.md` for the master index of which calendars
have a `Docs/X.md`, a `Docs/X_reference.md`, and a regression test (with
row counts and reference sources). **Keep that file in sync** whenever you
add new calendar docs, regression tests, or reference CSVs.

## Implementation Plan

See `Docs/Swift_Implementation_Plan.md` for the full 10-phase plan. Phases 1-3, 4a, 4b, 6, and 7 are complete:
- Phase 1: CalendarCore (done)
- Phase 2: CalendarSimple — ISO, Gregorian, Julian, Buddhist, ROC (done)
- Phase 3: CalendarComplex — Hebrew, Coptic, Ethiopian, Persian, Indian (done)
- Phase 4a: AstronomicalEngine — Reingold + Moshier + HybridEngine (done)
- Phase 4b: CalendarAstronomical — Islamic Tabular, Islamic Civil, Chinese, Dangi (done)
- Phase 6: CalendarJapanese — Japanese with era data (done)
- Phase 7: DateArithmetic — DateDuration, add/until/balance (done)

Phase 5 (CalendarHindu) is complete — all 6 calendars at 100% accuracy.

Next: DateFormat (Phase 8).

## Reference Sources

- ICU4X source: `../icu4x/` (Rust reference implementation)
- ICU4C source: `../icu/icu4c/` (C++ reference implementation)
- Hindu calendar: `/Users/draganbesevic/Projects/claude/hindu-calendar/` (existing Swift code for Phase 5)

## Conventions

- All dates are immutable value types
- Extended year numbering: year 0 exists (= 1 BCE), negative years allowed
- Era year is always positive; extended year can be negative
- Month codes follow Temporal proposal: "M01"-"M13", "L" suffix for leap months
- Tests use Swift Testing framework (`@Test`, `#expect`, `@Suite`)
- Test data is ported from ICU4X reference test suites

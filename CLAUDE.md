# CLAUDE.md

## Project Overview

icu4swift is a type-safe Swift calendar library porting algorithms from ICU4X (Rust) and ICU4C (C++) to Swift. It implements world calendar systems using a hub-and-spoke architecture where all conversions go through RataDie (fixed day numbers).

## Build & Test

```bash
swift build    # Build all targets
swift test     # Run all 127 tests (takes ~1 second)
```

No external dependencies. Swift 6.0, strict concurrency enabled.

## Package Structure

```
Sources/
  CalendarCore/          # Protocols, RataDie, Date<C>, Month, Weekday, YearInfo, errors
  CalendarSimple/        # ISO, Gregorian, Julian, Buddhist, ROC + arithmetic helpers
  CalendarComplex/       # Hebrew, Coptic, Ethiopian, Persian, Indian + arithmetic helpers
Tests/
  CalendarCoreTests/     # 26 tests for core types
  CalendarSimpleTests/   # 48 tests for simple calendars
  CalendarComplexTests/  # 53 tests for complex calendars
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

## Implementation Plan

See `Docs/Swift_Implementation_Plan.md` for the full 10-phase plan. Phases 1-3 are complete:
- Phase 1: CalendarCore (done)
- Phase 2: CalendarSimple — ISO, Gregorian, Julian, Buddhist, ROC (done)
- Phase 3: CalendarComplex — Hebrew, Coptic, Ethiopian, Persian, Indian (done)

Next phases: AstronomicalEngine, Chinese/Dangi/Islamic, Hindu, Japanese, DateArithmetic, DateFormat.

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

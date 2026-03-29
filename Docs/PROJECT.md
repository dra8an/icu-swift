# icu4swift — Project Definition

## What

A comprehensive Swift internationalization library for calendar operations and date formatting, covering 22 calendar systems with correct astronomical calculations and locale-aware formatting.

## Why

Apple's Foundation `Calendar` supports ~18 calendar systems but provides no formatting control below `DateFormatter` (which wraps ICU4C internally, with all its C++ baggage). There is no pure-Swift option that offers:

- Type-safe calendar operations (`Date<Hebrew>` vs `Date<Gregorian>`)
- Target-level granularity (use calendars without pulling in formatting)
- Correct astronomical calendar implementations (Chinese, Islamic observational)
- Hindu calendar support beyond what ICU4C provides
- Modern semantic formatting (Temporal-style field sets, not raw patterns)

icu4swift fills this gap by porting the best of ICU4X's architecture and ICU4C's feature surface to idiomatic Swift.

## Scope

### In Scope

| Area | Description |
|------|-------------|
| **Calendar systems** | 22 calendars: 5 Gregorian-family, 5 complex algorithmic, 5 astronomical, 6 Hindu, 1 era-based (Japanese) |
| **Date arithmetic** | Add, roll, difference with overflow handling (constrain/reject) |
| **Date formatting** | Semantic skeletons (primary), raw patterns (power-user), locale-aware |
| **Date parsing** | Pattern-based parsing with strict/lenient modes |
| **Interval formatting** | "Jan 10-20, 2024" style, greatest-difference detection |
| **Relative formatting** | "yesterday", "in 3 days", "next Tuesday" |
| **Astronomical engine** | Hybrid Moshier (high-precision modern) + Reingold (wide-range historical) |

### Out of Scope

- Time zones (use Foundation or swift-datetime)
- Time-of-day beyond what formatting needs (hour/minute/second fields)
- Number formatting (use Foundation or a separate library)
- Full locale data management (we embed CLDR data for a core set of locales)

## Architecture

**Hub-and-spoke** calendar conversion through `RataDie` (fixed day numbers). No direct calendar-to-calendar paths.

**Generic `Date<C>`** parameterized over `CalendarProtocol`. Compile-time type safety for known calendars, `AnyCalendar` for runtime selection.

**SPM multi-target package** — consumers depend on only what they need:

```
CalendarCore          ← protocols, RataDie, Date<C>, types
  ├── CalendarSimple  ← ISO, Gregorian, Julian, Buddhist, ROC
  │     ├── CalendarComplex    ← Hebrew, Persian, Coptic, Ethiopian, Indian
  │     │     └── CalendarJapanese  ← Japanese (era data)
  │     └── AstronomicalEngine     ← Moshier + Reingold hybrid
  │           ├── CalendarAstronomical  ← Chinese, Dangi, Islamic variants
  │           └── CalendarHindu         ← 6 Hindu calendar systems
  ├── DateArithmetic  ← DateDuration, add/roll/difference
  └── CalendarAll     ← umbrella re-export + AnyCalendar
        └── DateFormat    ← formatters, skeletons, CLDR data
              ├── DateParse           ← pattern-based parsing
              └── DateFormatInterval  ← interval + relative formatting
```

## Sources

Algorithms ported from:
- **ICU4X** (`calendrical_calculations` crate, `icu_calendar` component) — primary architectural reference
- **ICU4C** (`source/i18n/`) — feature surface reference, especially for formatting and arithmetic
- **Reingold & Dershowitz**, *Calendrical Calculations*, 4th edition (2018) — algorithmic reference
- **Hindu calendar project** (`hindu-calendar/swift/`) — existing validated Moshier engine and Hindu calendar code

## Quality Bar

- Every calendar round-trips: `fromRataDie(toRataDie(date)) == date` for tens of thousands of dates
- Every calendar tested against ICU4X reference data
- Directionality: RataDie ordering always matches YMD ordering
- Formatting: golden-file tests against ICU4C/ICU4X output for all calendar × locale × field-set combinations
- Persian: validated against 293 University of Tehran Nowruz dates
- Hebrew: validated against 33 Calendrical Calculations reference pairs
- Hindu: must preserve existing 99.971% accuracy (62 tests, 59,497 assertions)

## Tactical Documents

- `Docs/ICU4C_vs_ICU4X_Calendar_API_Analysis.md` — detailed comparison of calendar API designs
- `Docs/ICU4C_vs_ICU4X_DateFormat_Analysis.md` — detailed comparison of formatting approaches
- `Docs/Swift_Calendar_Library_Architecture.md` — architectural decisions and rationale
- `Docs/Swift_Implementation_Plan.md` — full 10-phase implementation plan with API sketches
- `Docs/DateArithmetic.md` — Phase 7 design: Temporal algorithms, API, overflow semantics
- `Docs/CalendarJapanese.md` — Phase 6 design: era table, Meiji switchover, extensibility

# CalendarAstronomical — Phase 4b Overview

*Completed: 2026-04-01*

## Overview

Phase 4b implements three calendar systems in the `CalendarAstronomical` target. Each has its own detailed document:

| Calendar | Type | Document |
|----------|------|----------|
| [Islamic Tabular](IslamicTabular.md) | Arithmetic (30-year cycle) | Eras `ah`/`bh`, 354/355 days |
| [Chinese](Chinese.md) | Lunisolar (astronomical) | Winter solstice + new moons + zhōngqì |
| [Dangi (Korean)](Dangi.md) | Lunisolar (astronomical) | Same as Chinese, UTC+9 (Seoul) |

## Architecture

Islamic Tabular is purely arithmetic — it needs no astronomical engine.

Chinese and Dangi use the `HybridEngine` from Phase 4a via a shared generic implementation:

```swift
public struct ChineseCalendar<V: EastAsianVariant>: CalendarProtocol { ... }

public typealias Chinese = ChineseCalendar<China>   // UTC+8, Beijing
public typealias Dangi = ChineseCalendar<Korea>     // UTC+9, Seoul
```

## Key Technical Achievement

The Chinese calendar leap month detection required matching ICU4X's **forward comparison** algorithm — a month has no zhōngqì when its solar term equals the **next** month's solar term. This was validated against real Swiss Ephemeris (JPL DE431) to confirm the astronomical precision was not the issue. See [Chinese.md](Chinese.md) for the full story.

## Files

| File | What |
|------|------|
| `IslamicTabular.swift` | Islamic Tabular calendar + arithmetic |
| `ChineseCalendar.swift` | `EastAsianVariant` protocol, `China`/`Korea` variants, `ChineseCalendar<V>`, `ChineseYearData`, `ChineseYearCache` |

## Dependencies

```
CalendarAstronomical
  ├── CalendarCore (protocols, RataDie)
  ├── CalendarSimple (GregorianArithmetic, JulianArithmetic, IsoDateInner)
  └── AstronomicalEngine (HybridEngine, Moment, Location)
```

## Test Coverage

32 tests total. See individual calendar documents for details.

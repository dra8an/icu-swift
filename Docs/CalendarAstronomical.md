# CalendarAstronomical — Phase 4b Overview

*Completed: 2026-04-01 | Updated: 2026-04-16*

## Overview

Phase 4b implements six calendar systems in the `CalendarAstronomical` target. Each has its own detailed document:

| Calendar | Type | Document |
|----------|------|----------|
| [Islamic Tabular](Islamic.md) | Arithmetic (Thursday epoch) | `islamic-tbla`, configurable `TabularEpoch` |
| [Islamic Civil](Islamic.md) | Arithmetic (Friday epoch) | `islamic-civil`, facade over tabular |
| [Islamic Umm al-Qura](Islamic.md) | Baked data (KACST) | `islamic-umalqura`, 301-entry table (1300–1600 AH) |
| [Chinese](Chinese.md) | Lunisolar (baked + astronomical) | 199-entry table (1901–2099), Moshier fallback |
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
| `IslamicTabular.swift` | Islamic Tabular + Civil + `TabularEpoch` enum |
| `IslamicUmmAlQura.swift` | UQ calendar + `PackedHijriYearData` + 301-entry KACST table |
| `ChineseCalendar.swift` | `EastAsianVariant` protocol, `China`/`Korea` variants, `ChineseCalendar<V>`, `ChineseYearData`, `ChineseYearCache` |
| `PackedChineseYear.swift` | `PackedChineseYearData` + 199-entry HKO baked table |

## Baked data

- **Chinese:** `ChineseYearTable` — 199 entries × 4 bytes (UInt32) = 796 bytes. Fields: 13-bit month lengths, 4-bit leap month ordinal, 6-bit new-year offset from Jan 19.
- **Umm al-Qura:** `UmmAlQuraData` — 301 entries × 2 bytes (UInt16) = 602 bytes. Fields: 12-bit month lengths, sign bit, 3-bit offset from mean tabular start.
- **Dangi:** no baked table yet — uses Moshier at Seoul longitude. See `Docs/NEXT.md`.

## Dependencies

```
CalendarAstronomical
  ├── CalendarCore (protocols, RataDie)
  ├── CalendarSimple (GregorianArithmetic, JulianArithmetic, IsoDateInner)
  └── AstronomicalEngine (HybridEngine, Moment, Location)
```

## Test Coverage

57 tests across 5 calendars. See individual calendar documents and `Docs/TestCoverageAndDocs.md`.

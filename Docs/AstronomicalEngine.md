# AstronomicalEngine — Phase 4a

*Completed: 2026-03-29*

## Overview

The AstronomicalEngine provides solar/lunar position calculations and sunrise/sunset times needed by Chinese, Dangi, Islamic observational, and Hindu calendars. It implements two independent calculation backends and a hybrid dispatcher.

## Architecture

```
AstronomicalEngineProtocol
  ├── ReingoldEngine    (Meeus polynomials, ±10,000 years, fast)
  ├── MoshierEngine     (VSOP87/DE404, ~1700-2150, high precision)
  └── HybridEngine      (Moshier for modern, Reingold for ancient)
```

### AstronomicalEngineProtocol

```swift
public protocol AstronomicalEngineProtocol: Sendable {
    func solarLongitude(at moment: Moment) -> Double
    func lunarLongitude(at moment: Moment) -> Double
    func newMoonBefore(_ moment: Moment) -> Moment
    func newMoonAtOrAfter(_ moment: Moment) -> Moment
    func sunrise(at moment: Moment, location: Location) -> Moment?
    func sunset(at moment: Moment, location: Location) -> Moment?
}
```

### Moment

Fractional RataDie representing a point in time. `Moment(730120.5)` = noon on January 1, 2000 (J2000.0).

Conversion: `JD = Moment + 1721424.5`. Verified: `730120.5 + 1721424.5 = 2451545.0 = J2000.0`.

### Location

Geographic position with latitude, longitude, elevation, and UTC offset (fractional days). Pre-defined locations for Beijing, Seoul, Mecca, Jerusalem, New Delhi.

## ReingoldEngine

Meeus polynomial approximations from "Calendrical Calculations" by Reingold & Dershowitz. Ported from ICU4X `astronomy.rs` (~1,900 lines Rust → Swift).

| Function | Algorithm | Terms |
|----------|-----------|------:|
| Solar longitude | Bretagnon & Simon series | 49 |
| Lunar longitude | Meeus series | 59 |
| New moon | Meeus algorithm | 24 + 13 |
| Nutation | Two-term model | 2 |
| Ephemeris correction | Polynomial segments by century | ~10 |
| Sunrise/sunset | Equation of time + moment of depression | — |

Valid for ±10,000 years. Lower precision than Moshier but fast (microseconds per call).

## MoshierEngine

VSOP87 solar + DE404 lunar ephemeris. Refactored from the Hindu calendar project (`hindu-calendar/swift/Sources/HinduCalendar/Ephemeris/`).

| Function | Algorithm | Precision vs Swiss Ephemeris |
|----------|-----------|------------------------------|
| Solar longitude | VSOP87 (135 harmonic terms) | ±1 arcsecond |
| Lunar longitude | DE404 (full pipeline) | ±0.07 arcsecond RMS |
| Nutation | 13-term IAU 1980 model | Sub-arcsecond |
| Delta-T | Lookup table (1900-2050) + polynomials | ±2 seconds |
| Sunrise/sunset | Sinclair refraction + GAST | ±2 seconds |

### Refactoring from Hindu Project

The original code used mutable class instances with shared scratch arrays:
- `Sun.ssTbl: [[Double]](9×24)` and `ccTbl: [[Double]](9×24)`
- `Moon.ss: [[Double]](5×8)`, `cc: [[Double]](5×8)`, plus 12 instance variables

Refactored to:
- `enum MoshierSolar` and `enum MoshierLunar` with all-static methods
- Scratch arrays allocated as local variables inside each computation
- All constant tables preserved exactly (EARTABL, EARARGS, LR, LRT, LRT2, Z, etc.)
- Result: zero-size `Sendable` types, thread-safe by construction

### New Moon Detection

The Hindu project didn't include new moon detection. The MoshierEngine finds new moons by:
1. Using Reingold's `nthNewMoon` for an initial estimate (fast, ~1 second accuracy)
2. Refining within ±1 day using Moshier lunar/solar longitude bisection search

### Precision Validation

Cross-validated against the **real Swiss Ephemeris (JPL DE431)** for the critical Chinese calendar 2023 leap month boundary:

| Engine | Solar lon at Apr 20, 2023 04:13 UTC |
|--------|----:|
| Real Swiss Ephemeris (JPL DE431) | 29.83672628° |
| Hindu Moshier (VSOP87) | 29.83671762° |
| Our Reingold (Meeus) | 29.96° |

Moshier matches JPL DE431 to 0.00001°. Reingold is within 0.13° — sufficient for calendar calculations but not for boundary-critical decisions.

## HybridEngine

Dispatches to Moshier for dates in the modern range (RD 620654–785010, approximately 1700–2150 CE), Reingold outside.

## Files

| File | Lines | What |
|------|------:|------|
| `Moment.swift` | ~70 | Fractional RataDie, JD conversion |
| `Location.swift` | ~75 | Geographic position, well-known locations |
| `Helpers.swift` | ~100 | poly, sinDeg, mod360, binary search, constants |
| `AstronomicalEngine.swift` | ~30 | Protocol definition |
| `ReingoldSolar.swift` | ~180 | Ephemeris correction, solar longitude, nutation |
| `ReingoldLunar.swift` | ~165 | Lunar longitude, new moon |
| `ReingoldSunrise.swift` | ~140 | Equation of time, sunrise/sunset |
| `ReingoldEngine.swift` | ~40 | Protocol facade |
| `MoshierSolar.swift` | ~730 | VSOP87, Delta-T, nutation (mostly tables) |
| `MoshierLunar.swift` | ~660 | DE404 lunar longitude (mostly tables) |
| `MoshierSunrise.swift` | ~155 | Sunrise/sunset via Moshier |
| `MoshierEngine.swift` | ~90 | Protocol facade + new moon refinement |
| `HybridEngine.swift` | ~70 | Range-based dispatch |

## Test Coverage

36 tests:
- Moment/JD conversion, RataDie floor
- Reingold: solar longitude at J2000 and equinox, monotonicity, ephemeris correction, lunar longitude, new moon spacing/ordering/phase, sunrise
- Moshier: solar longitude, Delta-T, nutation, lunar longitude, sunrise, new moon
- Cross-validation: solar longitude agreement (<0.05°), new moon agreement (same day)
- HybridEngine: modern range → Moshier, historical → Reingold

## Source

- **ICU4X** `calendrical_calculations/src/astronomy.rs` — Reingold engine reference
- **Hindu calendar project** `Ephemeris/` — Moshier engine source (Sun.swift, Moon.swift, Rise.swift)
- **Reingold & Dershowitz**, *Calendrical Calculations*, 4th edition — algorithmic reference
- **Swiss Ephemeris** (JPL DE431) — precision validation

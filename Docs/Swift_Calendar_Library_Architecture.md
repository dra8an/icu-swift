# Swift Calendar & Date Formatting Library: Architectural Plan

## Overview

A Swift i18n library for calendar operations and date formatting, combining the best of ICU4C and ICU4X with a novel hybrid astronomical engine. The design uses ICU4X as the architectural blueprint (it maps naturally to Swift's type system) while filling feature gaps from ICU4C's 25-year maturity.

## Why ICU4X's Architecture Maps to Swift

Swift's type system is much closer to Rust than C++:

| ICU4X (Rust) | Swift Equivalent |
|--------------|-----------------|
| `Calendar` trait | `protocol Calendar` with associated types |
| `Date<A: AsCalendar>` | `struct Date<C: Calendar>` — same monomorphization |
| Zero-size `Gregorian` struct | Empty `struct Gregorian: Calendar` — same optimization |
| `AnyCalendar` (type-erased) | `any Calendar` existential or a manual enum |
| `Result<T, E>` | Swift's `throws` or `Result<T, E>` |
| `Copy` / `Clone` | Value semantics by default in Swift structs |
| `Writeable` | `CustomStringConvertible` or a write-to-stream protocol |

Both languages support:
- Value types (structs) with protocol conformance
- Generics with monomorphization (specialized code per type)
- Protocol-oriented design over class inheritance
- Immutability as the default

ICU4C's C++ model (heap-allocated polymorphic objects, vtable dispatch, mutable field bags, `UErrorCode&` out-parameters) is the opposite of idiomatic Swift.

## Core Design Decisions

### 1. Calendar Model — Follow ICU4X

- Protocol-based: `protocol Calendar` with associated `DateInner` type
- Generic `Date<C: Calendar>` — value type, immutable, 1-indexed months
- Zero-size calendar markers for simple calendars (`Gregorian`, `Buddhist`, `Hebrew`, etc.)
- Two-tier polymorphism:
  - `Date<Gregorian>` — compile-time known, zero-cost (monomorphized, no existential overhead)
  - `Date<AnyCalendar>` — runtime-selected, uses witness table (like ICU4C's `Calendar*`)
- **Do not** replicate ICU4C's mutable 24-field bag — that's a C++ artifact

### 2. Date Arithmetic — ICU4C Features, ICU4X Style

- Take ICU4C's feature surface: `add`, `roll`, `fieldDifference` are all genuinely useful
- Use ICU4X's API style: return new values instead of mutating, use typed `DateDuration`, use `throws` for errors
- `Overflow` handling: `.constrain` (clamp) or `.reject` (throw) — per-operation, not global toggle

### 3. Date Formatting — Semantic Skeletons + Raw Patterns

- **Primary API:** Semantic skeletons like ICU4X (`YMD.long`, `YMDT.medium`)
  - Prevents locale-inappropriate patterns (the classic ICU4C misuse)
  - Type-safe field sets at compile time
- **Power-user API:** Raw LDML patterns for apps that need them
  - ICU4X is arguably too restrictive by hiding patterns entirely
  - Real-world apps need pattern control sometimes
- **Three-tier formatter model** (from ICU4X):
  - `FixedCalendarDateFormatter<C>` — single calendar, minimal data
  - `DateFormatter` — any calendar, converts at format time
  - `TimeFormatter` — time/timezone only, no calendar data
- **Immutable formatters** — construct once, format many (no `applyPattern()` mutation)

### 4. Date Parsing — Separate Type

- Parsing is a fundamentally different operation from formatting — keep it as a separate type
- ICU4C bundles parsing into `SimpleDateFormat`; this is wrong for Swift
- Design with Swift idioms: throwing initializers, `DateParseStrategy`-like approach
- Pattern-based parsing with `throws` instead of ICU4C's `ParsePosition`

### 5. Date Interval Formatting — From ICU4C

- ICU4X doesn't have this; ICU4C's `DateIntervalFormat` concept is essential
- Skeleton-based, automatically omits redundant fields
- "Jan 10-20, 2007" instead of "Jan 10, 2007 - Jan 20, 2007"

### 6. Relative Date/Time Formatting

- Follow ICU4C's `RelativeDateTimeFormatter` feature set
- Support both numeric ("2 days ago") and named ("yesterday") modes
- Support absolute references ("next Tuesday", "this month")

### 7. Number System Integration

- Global numbering system per formatter (like ICU4X)
- Consider per-field overrides (ICU4C feature) — useful but adds complexity

### 8. Name Resolution

- Month, weekday, era names: context (format vs standalone) x width (wide, abbreviated, narrow)
- Load only needed widths (like ICU4X, unlike ICU4C which loads everything)
- Calendar-specific names (Hebrew month names, Japanese era names, etc.)

## Hybrid Astronomical Engine

### The Problem

Two astronomical calculation models exist:

| | Moshier/VSOP87 (Hindu calendar project) | Reingold & Dershowitz (ICU4X) |
|--|------------------------------------------|-------------------------------|
| **Basis** | Modern planetary ephemerides (VSOP87 solar, DE404 lunar) | Meeus polynomial approximations |
| **Precision** | ±1" solar, ±0.07" lunar, ±2s sunrise | Lower — sufficient for calendar boundaries but not observatory-grade |
| **Validated range** | 1900-2050 (extensively), practical limit ~1800-2150 | ±10,000 years (accuracy degrades gracefully) |
| **Size** | ~1,943 lines (Moshier library) | ~2,632 lines (ICU4X astronomy.rs) |
| **Key strength** | Matches what real panchang/calendar publishers produce today | Works across all of recorded history |

Neither model alone is ideal:
- Moshier is more accurate but its VSOP87 polynomials are designed for ~1800-2050
- Reingold covers millennia but is less accurate for modern dates where we can validate

### The Solution: Hybrid Engine

```
            <-- Reingold -->|<-- Moshier -->|<-- Reingold -->
    ────────────────────────────────────────────────────────────
    ...  1000  1200  1400  1700  1900  2050  2150  2400  ...
```

- **Modern window (~1700-2050):** Use the Moshier pipeline — validated, precise, matches real-world calendar publishers
- **Outside that window:** Fall back to Reingold & Dershowitz algorithms which degrade gracefully over millennia

### Design

The switch should be transparent — the `Calendar` protocol hides which engine is active:

```swift
protocol AstronomicalEngine {
    func solarLongitude(at jd: Double) -> Double
    func lunarLongitude(at jd: Double) -> Double
    func sunrise(at jd: Double, location: Location) -> Double
    func newMoonBefore(_ jd: Double) -> Double
    func newMoonAtOrAfter(_ jd: Double) -> Double
}

struct HybridEngine: AstronomicalEngine {
    private let moshier = MoshierEngine()
    private let reingold = ReingoldEngine()
    private let modernRange = JD(1700, 1, 1)...JD(2150, 1, 1)

    func solarLongitude(at jd: Double) -> Double {
        if modernRange.contains(jd) {
            return moshier.solarLongitude(at: jd)
        } else {
            return reingold.solarLongitude(at: jd)
        }
    }
}
```

### Crossover Validation

The boundaries (~1700 and ~2150) should be chosen where both models produce the same calendar results. Validate by running both engines across a crossover zone (e.g., 1700-1750) and confirming they agree on:
- New moon dates (same day)
- Solar longitude boundaries (same rashi/month)
- Tithi at sunrise (same tithi number)

If they agree within the zone, users never notice the switch.

### Benefits Beyond Hindu Calendars

The Moshier engine gives better `newMoonBefore()`, `solarLongitude()`, and `sunrise()` for the modern period across *all* astronomical calendars — Chinese, Korean, Islamic observational, Hindu. More accurate month boundaries for all of these, not just Hindu.

**This is a novel contribution** — neither ICU4C nor ICU4X has a hybrid astronomical engine. They each pick one model and stick with it.

### Existing Assets

The Moshier ephemeris library is already ported to Swift:
- Location: `/Users/draganbesevic/Projects/claude/hindu-calendar/swift/`
- 62 tests, identical output to C reference implementation
- ~1,943 lines, self-contained, no external dependencies

## Supported Calendar Systems (Target)

Combining ICU4C + ICU4X + Hindu calendar project:

| Calendar | Source | Notes |
|----------|--------|-------|
| ISO 8601 | ICU4X | Conversion pivot |
| Gregorian | Both | CE/BCE eras |
| Julian | ICU4X | Historical dates |
| Buddhist | Both | Gregorian + 543 offset |
| Japanese | Both | Era-based (Meiji-Reiwa) |
| ROC/Taiwan | Both | Gregorian - 1911 offset |
| Hebrew | Both | Metonic cycle |
| Islamic (Civil/Tabular) | Both | Arithmetic, no astronomy |
| Islamic (Umm al-Qura) | Both | Saudi Arabia official |
| Islamic (Observational) | Both | Crescent visibility |
| Chinese | Both | 60-year cycle, leap months |
| Dangi (Korean) | Both | Chinese variant |
| Persian | Both | Solar Hijri |
| Indian (Saka) | Both | National Calendar of India |
| Coptic | Both | 13 months |
| Ethiopian | Both | Amete Mihret/Amete Alem |
| Hindu Lunisolar (Amanta) | Hindu project | Drik Siddhanta, validated |
| Hindu Lunisolar (Purnimanta) | Hindu project | North India variant |
| Hindu Solar (Tamil) | Hindu project | Chittirai year start |
| Hindu Solar (Bengali) | Hindu project | Complex midnight boundary rule |
| Hindu Solar (Odia) | Hindu project | Fixed 22:12 IST cutoff |
| Hindu Solar (Malayalam) | Hindu project | Madhyahna-based |

**22 calendar systems total** — more than either ICU4C (15) or ICU4X (16), and with better astronomical accuracy for the modern period.

## Summary

| Dimension | This Library |
|-----------|-------------|
| **Language** | Swift |
| **Architecture** | ICU4X-inspired (protocols, generics, value types) |
| **Feature completeness** | ICU4C-level (parsing, intervals, relative time, roll) |
| **Astronomical engine** | Hybrid Moshier + Reingold (novel) |
| **Calendar count** | 22 (ICU4C=15, ICU4X=16) |
| **Parsing** | Separate type (not bundled with formatting) |
| **Pattern API** | Semantic skeletons (primary) + raw patterns (power-user) |
| **Hindu calendars** | 6 systems with 99.971% validated accuracy |

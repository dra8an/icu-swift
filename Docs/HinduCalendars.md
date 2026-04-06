# Hindu Calendars — Phase 5

*Planning: 2026-04-02 | Status: In Progress*

## Overview

Phase 5 implements 6 Hindu calendar systems — 2 lunisolar and 4 solar — by adapting the validated code from the [Hindu calendar project](https://github.com/dra8an/hindu-calendar). This is the most architecturally challenging phase because the Hindu calendar has properties that don't exist in any other calendar system we've implemented.

## Calendar Systems

### Lunisolar Calendars

| Calendar | Identifier | Scheme | Description |
|----------|-----------|--------|-------------|
| **Amanta** | `hindu-lunar-amanta` | New moon to new moon | Used in most of India |
| **Purnimanta** | `hindu-lunar-purnimanta` | Full moon to full moon | Used in North India |

Both use the same astronomical calculations but define month boundaries differently:
- **Amanta**: month starts at new moon (amāvāsyā)
- **Purnimanta**: month starts at full moon (pūrṇimā)

### Solar Calendars

| Calendar | Identifier | Region | Critical Time | Year Start |
|----------|-----------|--------|---------------|------------|
| **Tamil** | `hindu-solar-tamil` | Tamil Nadu | Sunset − 9.5 min | Mesha (rashi 1) |
| **Bengali** | `hindu-solar-bengali` | West Bengal | Midnight + 24 min IST | Mesha (rashi 1) |
| **Odia** | `hindu-solar-odia` | Odisha | 22:12 IST (fixed) | Kanya (rashi 6) |
| **Malayalam** | `hindu-solar-malayalam` | Kerala | Madhyahna end − 9.5 min | Simha (rashi 5) |

Solar calendars determine months by when the sidereal sun enters each zodiac sign (rashi). The "critical time" is when the rashi is evaluated — different regions use different conventions.

## Architectural Challenges

### 1. Location Dependency

**Problem:** The Hindu calendar requires sunrise/sunset at a specific geographic location to determine dates. A date in Delhi and a date in Mumbai can have different tithis on the same Gregorian day. No other calendar in our system has this property.

**Decision:** Add an optional `location` property to `CalendarProtocol` with a default `nil` implementation. Only Hindu (and potentially Islamic observational) calendars override it.

```swift
public protocol CalendarProtocol: Sendable {
    // ... existing methods ...
    var location: Location? { get }
}

extension CalendarProtocol {
    public var location: Location? { nil }  // computed, zero cost
}
```

**Why this approach:**
- The protocol itself has no size — adding a computed property costs nothing
- Existing zero-size calendar structs (`Gregorian`, `Hebrew`, etc.) remain zero-size
- Only Hindu calendar structs store a `Location`, making them non-zero-size (like `Japanese` already stores `JapaneseEraData`)
- Generic code can check `calendar.location` to determine if a calendar is location-dependent
- Other calendars (Islamic observational) may need location later

```swift
let delhi = HinduLunisolar<Amanta>(location: .newDelhi)
let mumbai = HinduLunisolar<Amanta>(location: .mumbai)

// Same civil day, potentially different tithi
let delhiDate = Date.fromRataDie(rd, calendar: delhi)
let mumbaiDate = Date.fromRataDie(rd, calendar: mumbai)
```

### 2. Non-Bijective Day Mapping (Kshaya and Adhika Tithis)

**Problem:** The mapping between Gregorian days and Hindu lunisolar dates is not 1:1:

- **Kshaya tithi (skipped):** A tithi starts and ends entirely within one sunrise-to-sunrise period. It never appears as the tithi-at-sunrise on any day. The day "skips" from tithi N to tithi N+2. This means **one Gregorian day has two Hindu dates** — the primary tithi at sunrise, and the kshaya tithi that was consumed during that day.

- **Adhika tithi (repeated):** A tithi is so long that it spans two consecutive sunrises. Two Gregorian days report the same tithi at sunrise. This means **two Gregorian days share one Hindu date.**

**Decision:** Add two methods to `CalendarProtocol` with default implementations:

```swift
public enum DateStatus: Sendable {
    case normal      // 1:1 mapping with civil day
    case repeated    // this date also occurred on the previous civil day (adhika)
    case skipped     // this date was skipped; see alternativeDate
}

public protocol CalendarProtocol: Sendable {
    // ... existing methods ...
    func dateStatus(_ date: DateInner) -> DateStatus
    func alternativeDate(_ date: DateInner) -> DateInner?
}

extension CalendarProtocol {
    public func dateStatus(_ date: DateInner) -> DateStatus { .normal }
    public func alternativeDate(_ date: DateInner) -> DateInner? { nil }
}
```

**How it works:**

For a **kshaya tithi** (e.g., tithi 15 is skipped):
```swift
let date = Date.fromRataDie(rd, calendar: amanta)
date.dayOfMonth        // 14 (tithi at sunrise)
date.alternativeDate   // tithi 15 (the kshaya tithi consumed during this day)
```

For an **adhika tithi** (e.g., tithi 8 spans two days):
```swift
let day1 = Date.fromRataDie(rd, calendar: amanta)
let day2 = Date.fromRataDie(rd + 1, calendar: amanta)
day1.dayOfMonth  // 8
day2.dayOfMonth  // 8 (same tithi!)
day2.dateStatus  // .repeated
```

**Construction of kshaya tithis:** Attempting to construct a kshaya tithi via `newDate` throws `DateNewError` (similar to Feb 30 in Gregorian). The kshaya tithi can only be discovered via `alternativeDate` on the adjacent day.

### 3. Day Boundaries

**Problem:** RataDie assumes midnight boundaries. Hindu days run sunrise-to-sunrise.

**Decision:** `fromRataDie` computes sunrise for the given civil day and evaluates the tithi at that moment. The RataDie still represents the civil (Gregorian) day — we don't try to change the fundamental day counting system. The Hindu date is "the date that applies at sunrise of this civil day."

### 4. Sidereal vs Tropical Longitude

**Problem:** Hindu calendars use sidereal (nirayana) solar longitude, not tropical. Our `AstronomicalEngine` computes tropical longitude.

**Decision:** Add an `Ayanamsa` calculation to the `CalendarHindu` module (not to `AstronomicalEngine`, since ayanamsa is Hindu-specific). The Lahiri ayanamsa calculation is ported from the Hindu project's `Ayanamsa.swift`.

```
sidereal longitude = tropical longitude − ayanamsa
```

The ayanamsa uses IAU 1976 3D equatorial precession with the Lahiri epoch (JD 2435553.5, September 22, 1956). This matches Swiss Ephemeris's `swe_get_ayanamsa_ut()` to ±0.3 arcseconds.

**Critical subtlety:** The ayanamsa returned is the **mean** ayanamsa (without nutation). Nutation cancels in sidereal calculations:
```
sidereal = (tropical + Δψ) − (ayanamsa + Δψ) = tropical − ayanamsa
```
If nutation were added to the ayanamsa, it would be double-counted. This was a bug that was found and fixed in the Hindu calendar project (see `Docs/VSOP87_IMPLEMENTATION.md` in that project).

## Data Model Mapping

### Lunisolar Date → CalendarProtocol

| Hindu Concept | CalendarProtocol Field | Notes |
|---------------|----------------------|-------|
| Masa (month name) | `month.number` (1-12) | Chaitra=1 through Phalguna=12 |
| Adhika masa | `month.isLeap` | `Month.leap(N)` for intercalary month |
| Paksha | Encoded in day | Shukla tithis 1-15, Krishna tithis 16-30 |
| Tithi | `dayOfMonth` (1-30) | 1-15 = Shukla, 16-30 = Krishna |
| Saka year | `yearInfo.eraYear` with era `"saka"` | |
| Vikram Samvat | Could be a second era | Vikram = Saka + 135 |

### Solar Date → CalendarProtocol

| Hindu Concept | CalendarProtocol Field | Notes |
|---------------|----------------------|-------|
| Regional month | `month.number` (1-12) | Per-calendar month names |
| Day of month | `dayOfMonth` (1-32) | Sequential civil days |
| Regional year | `yearInfo.eraYear` | Tamil=Saka, Bengali=Bangabda, Odia=Amli, Malayalam=Kollam |
| Rashi | Internal to DateInner | Zodiac sign (1-12) |

## Implementation Strategy

### Phase 5a: Protocol Extensions

Update `CalendarProtocol` with the three new optional capabilities:
1. `location: Location?`
2. `dateStatus(_:) -> DateStatus`
3. `alternativeDate(_:) -> DateInner?`

All with default implementations. Zero impact on existing calendars.

### Phase 5b: Ayanamsa

Port `Ayanamsa.swift` from the Hindu project into `CalendarHindu`. Refactor from class to enum with static methods (same pattern as MoshierSolar). Uses our `MoshierSolar` for Delta-T and nutation.

### Phase 5c: Solar Calendars (4 calendars)

Simpler than lunisolar — no skipped/repeated days. Each solar calendar is parameterized by:
- Critical time convention
- Year start rashi
- Gregorian year offset
- Regional month names

```swift
public protocol HinduSolarVariant: Sendable {
    static var calendarIdentifier: String { get }
    static var calendarType: SolarCalendarType { get }
}

public struct HinduSolar<V: HinduSolarVariant>: CalendarProtocol {
    public let location: Location
    // ...
}
```

### Phase 5d: Lunisolar Calendars (2 calendars)

The complex part. Requires:
- Tithi calculation (lunar phase / 12° = tithi number)
- Masa determination (solar rashi at new moon)
- Adhika masa detection (same rashi at consecutive new moons)
- Kshaya/adhika tithi detection
- Amanta vs Purnimanta month boundary

```swift
public protocol LunisolarVariant: Sendable {
    static var calendarIdentifier: String { get }
    static var scheme: LunisolarScheme { get }
}

public struct HinduLunisolar<V: LunisolarVariant>: CalendarProtocol {
    public let location: Location
    // ...
}
```

## Validation

### Target (from Hindu project's Swift port)

The Hindu project's Swift port achieves:
- **Tamil**: 0 failures / 1,811 months (100%)
- **Bengali**: 0 or very few failures / 1,811 months
- **Odia**: 0 failures / 1,811 months (100%)
- **Malayalam**: 0 failures / 1,811 months (100%)
- **Lunisolar**: ~15-20 irreducible boundary failures / 55,152 days (99.971%)

### Current State (our implementation)

| Calendar | Failures | Total | Match Rate | Target |
|----------|--------:|------:|-----------:|--------|
| Odia | **0** | 1,811 | **100%** | ✓ |
| Tamil | 6 | 1,811 | 99.67% | Should be 0 |
| Bengali | 12 | 1,811 | 99.34% | Should be 0 |
| Malayalam | 339 | 1,811 | 81.3% | Should be 0 |
| Lunisolar | 191 | 1,104 | 82.7% | Should be ~15 |

### Bugs Found and Fixed

1. **utcOffset unit mismatch** (fixed 2026-04-03): Bengali and Odia critical time formulas divided `Location.utcOffset` (already in fractional days) by 24 again. The Hindu project uses hours; our `Location` uses fractional days. Fixed Bengali from 1,025→12 failures, Odia from 1,019→0.

2. **JulianDayHelper epoch** (fixed 2026-04-03): `ymdToJd` returned RD+0.5 instead of real Julian Day (should add 1721424.5, not 0.5). This caused the Saka year calculation to be off by ~4,700 years. Fixed by adding the correct JD offset.

### Root Cause of Remaining Failures

Our refactored MoshierSunrise (ported from the Hindu project's `Rise.swift` by converting mutable class arrays to local variables) produces sunrise times ~2.5 minutes different from the original. Cross-check:

| Quantity | Our port | Hindu project | Difference |
|----------|------:|------:|------:|
| Sunrise JD (Jan 15, 2024) | 2460324.5711 | 2460324.5728 | 2.5 min |
| Solar longitude | 270.452° | 270.452° | <0.001° |

Solar longitude matches perfectly — the issue is isolated to the sunrise calculation. The 2.5-minute shift is enough to move month boundaries for Malayalam (which depends on sunrise + sunset for its critical time) and lunisolar (which depends on sunrise for tithi determination).

### Proposed Fix

**Option A (recommended):** Add the Hindu project (`hindu-calendar`) as a Swift package dependency. CalendarHindu calls the original `Ephemeris`, `Tithi`, `Masa`, `Solar` classes directly. Guarantees bit-identical results — zero porting bugs.

**Option B:** Debug the numerical difference between our `MoshierSunrise` and the original `Rise.swift`. The `sscc` sine/cosine recurrence or the iterative sunrise refinement likely diverged during the class→enum refactoring. High effort, uncertain payoff since the original code already exists in Swift.

## Source

- **Hindu calendar project** `swift/Sources/HinduCalendar/` — validated Swift implementation (0 errors on solar, ~15 on lunisolar)
- **Hindu calendar project** `Docs/` — extensive validation reports, physics documentation
- **Hindu calendar project** `validation/moshier/` — CSV reference data (55K lunisolar + 4×1,811 solar months)
- **ICU4X** does not implement Hindu calendars (only Indian National/Saka, which we already have in Phase 3)
- **Drikpanchang.com** — authoritative Hindu calendar reference for validation

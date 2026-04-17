# Performance

*Last updated: 2026-04-13*

## Build Configuration

**Always use release mode for tests:**
```bash
swift test -c release    # ~28 seconds for full suite (319 tests)
swift test               # ~2+ minutes (debug mode, 50x slower for Moshier calculations)
```

The Moshier VSOP87/DE404 ephemeris calculations are compute-heavy (135 harmonic terms, 10-iteration sunrise refinement). Debug mode disables compiler optimizations, making these 50x slower.

## Current Benchmarks

| Test Suite | Release | Debug | Notes |
|-----------|-------:|------:|-------|
| Full suite (319 tests) | **28s** | ~140s | |
| Hindu lunisolar (55,152 days) | **27s** | ~120s | Dominates total time |
| Hindu solar (4×1,811 months) | **3s** | ~60s | Per calendar ~1s |
| Chinese calendar (730-day round-trip) | **1s** | ~4s | With year cache |
| All other calendars | **<1s** | ~2s | Arithmetic only |

## Per-Calendar Benchmark Baseline

*Measured 2026-04-13, release mode, x86_64. Each calendar converts 1,000
consecutive Gregorian days (2024-01-01 onward) to the target calendar and
back. Hindu uses 100 dates due to higher per-date cost.*

Run with: `swift test -c release --filter "Benchmark"`

| Calendar | µs/date | Category |
|---|---:|---|
| ISO | 1.9 | arithmetic |
| Buddhist | 1.9 | arithmetic |
| ROC | 2.1 | arithmetic |
| Gregorian | 2.1 | arithmetic |
| Japanese | 2.1 | arithmetic |
| Persian | 2.1 | arithmetic |
| Indian | 2.1 | arithmetic |
| Julian | 2.2 | arithmetic |
| Chinese (baked) | 2.2 | table lookup |
| Islamic Umm al-Qura | 2.3 | table lookup |
| Hindu Tamil (baked) | 2.4 | table lookup |
| Hindu Bengali (baked) | 2.5 | table lookup |
| Hindu Odia (baked) | 2.5 | table lookup |
| Hindu Malayalam (baked) | 2.7 | table lookup |
| Ethiopian | 2.4 | arithmetic |
| Islamic Civil | 2.5 | arithmetic |
| Islamic Tabular | 2.5 | arithmetic |
| Coptic | 2.7 | arithmetic |
| Hebrew | 3.5 | arithmetic |
| Dangi (baked) | 3.6 | table lookup |
| Chinese (Moshier) | 437 | astronomical fallback |
| Purnimanta (lunisolar) | 3,847 | astronomical |
| Amanta (lunisolar) | 3,880 | astronomical |

All arithmetic and table-lookup calendars are **< 4 µs/date** — effectively
equivalent. The astronomical calendars (Hindu, Chinese Moshier fallback) are
200–2000× slower, dominated by Moshier VSOP87 ephemeris evaluations.

## Lazy Field Computation

### The Pattern

Our `CalendarProtocol` separates basic date identification from expensive auxiliary computations:

```swift
// Basic — always computed by fromRataDie
func dayOfMonth(_ date: DateInner) -> UInt8      // tithi number
func monthInfo(_ date: DateInner) -> MonthInfo    // masa
func yearInfo(_ date: DateInner) -> YearInfo      // Saka year

// Expensive — only computed when explicitly queried
func dateStatus(_ date: DateInner) -> DateStatus          // kshaya/adhika detection
func alternativeDate(_ date: DateInner) -> DateInner?     // skipped tithi
```

This is similar to ICU4C's `Calendar::get(field)` pattern where fields are computed on demand, not the "compute everything upfront" approach used by the Hindu calendar project's `PanchangDay`.

### Impact on Hindu Calendars

For the 55,152-day lunisolar regression test:

| Approach | Ephemeris evaluations per day | Time (55K days) |
|----------|----:|----:|
| Hindu project (full PanchangDay) | ~70+ | ~120s |
| Our fromRataDie (basic fields only) | ~25 | **~27s** |

The difference: the Hindu project's `tithiAtSunrise` always computes tithi start/end boundaries (two bisection searches, ~50 evaluations) and kshaya detection (tomorrow's sunrise + tithi). Our `fromRataDie` skips all of this — it only computes the tithi number, masa, and year. The expensive boundary and kshaya computations only happen when `dateStatus` or `alternativeDate` is called.

This wasn't an intentional optimization — it's a natural consequence of the protocol design separating basic date identity from auxiliary properties. But it delivers a ~4.5x speedup on the most expensive calendar system.

### Design Principle

The general rule: `fromRataDie` should compute the minimum needed to identify the date. Expensive derived properties (boundaries, status flags, alternative dates) should be computed lazily when queried. This matters most for calendars that require astronomical calculations (Hindu, Chinese), where each ephemeris evaluation costs microseconds.

## Baked Year Data Tables

### Chinese Calendar (1901–2099)

For dates in the common range, the Chinese calendar uses a **199-entry baked
data table** (`ChineseYearTable`), generated from Hong Kong Observatory
authoritative data. No astronomical calculations — all year structure queries
reduce to an array index + bit manipulation.

Each year is packed into a `PackedChineseYearData` (UInt32, 24 bits used):

```
Bits  0-12: month lengths for up to 13 months (1 = 30d, 0 = 29d)
Bits 13-16: leap month ordinal (0 = no leap)
Bits 17-22: new year offset from Jan 19 of the related ISO year
```

The packed data is **stored in `ChineseDateInner`**, so field accessors
(`daysInMonth`, `monthsInYear`, `isInLeapYear`, etc.) and date arithmetic
read directly from the date — no cache, no lock, no computation.

| Operation (1901–2099) | Before (Moshier) | After (baked) | Speedup |
|---|------:|------:|------:|
| Single date construction | ~586 ms | < 0.001 ms | **>500,000×** |
| Field access | cache + lock | inline bit ops | lock-free |
| Date arithmetic | cache + lock per step | inline bit ops | lock-free |

### Islamic Umm al-Qura (1300–1600 AH)

301 entries of `PackedHijriYearData` (UInt16, 16 bits):

```
Bits  0-11: month lengths (1 = 30d, 0 = 29d)
Bit    12 : sign flag for start-day offset
Bits 13-15: abs(offset) from mean tabular start
```

Source: KACST (via ICU4C), offsets recomputed for our epoch.

### Fallback: ChineseYearCache (outside baked range)

Dates before 1901 or after 2099 fall through to the Moshier engine via
`ChineseYearCache` (LRU-8, `os_unfair_lock`). The computed `ChineseYearData`
is packed into `PackedChineseYearData` on the fly, so the date still carries
its year data and field accessors remain lock-free after construction.

Historical cache-only performance (before baked table):

| Operation | Without cache | With cache | Speedup |
|-----------|------:|------:|------:|
| Single date lookup | 586 ms | 650 ms | ~1x (first computation) |
| 3 dates, same year | 1,727 ms | 650 ms | **2.7x** |
| 30 consecutive days | 25,378 ms | 644 ms | **39x** |

## Moshier vs Reingold Performance

| Engine | Solar longitude | New moon | Use case |
|--------|------:|------:|----------|
| Reingold (Meeus) | ~1 µs | ~10 µs | Chinese/Dangi year computation |
| Moshier (VSOP87) | ~50 µs | ~500 µs | Hindu sunrise/sunset |
| HybridEngine | Moshier for 1700-2150 | Reingold estimate + Moshier refinement | Best accuracy in modern range |

The Chinese calendar uses the HybridEngine (which dispatches to Moshier for modern dates), but the year cache amortizes the cost. Hindu calendars call MoshierSunrise directly for each date, making their per-date cost higher.

## Data and Library Size

### Library Modules (release, x86_64)

| Module | Size | Contents |
|---|---:|---|
| AstronomicalEngine | 592 KB | Moshier VSOP87, Reingold, HybridEngine |
| CalendarAstronomical | 448 KB | Chinese + baked table, Dangi, Islamic ×3 + UQ table |
| CalendarComplex | 456 KB | Hebrew, Coptic, Ethiopian, Persian, Indian |
| CalendarHindu | 408 KB | 6 Hindu calendars, ayanamsa |
| CalendarCore | 340 KB | Protocols, RataDie, Date<C>, Month, Weekday |
| CalendarSimple | 320 KB | ISO, Gregorian, Julian, Buddhist, ROC |
| DateArithmetic | 152 KB | add/until/balance (Temporal spec) |
| CalendarJapanese | 88 KB | Japanese + era data |
| **Total** | **2,804 KB** | |

An app that only needs simple calendars (ISO/Gregorian/Julian) pulls in
~660 KB (Core + Simple). The full library with all 23 calendars and
astronomy is 2.8 MB.

### Baked Data Table Overhead

| Table | Entries | Per entry | Total |
|---|---:|---:|---:|
| Chinese (HKO, 1901–2099) | 199 | 4 bytes (UInt32) | 796 bytes |
| Umm al-Qura (KACST, 1300–1600 AH) | 301 | 2 bytes (UInt16) | 602 bytes |
| Hindu Tamil (1822–1971 Saka) | 150 | 6 bytes (UInt32 + UInt16) + 4 | 904 bytes |
| Hindu Bengali (1307–1456) | 150 | 6 bytes + 4 | 904 bytes |
| Hindu Odia (1308–1457) | 150 | 6 bytes + 4 | 904 bytes |
| Hindu Malayalam (1076–1225) | 150 | 6 bytes + 4 | 904 bytes |
| **Total** | | | **5,014 bytes** (~5 KB) |

The baked tables add **~5 KB** — 1.2% of the relevant modules, 0.16% of
the full library. The payoff: eliminating all Moshier astronomical
calculations for the most common date range, with speedups ranging from
200× (Chinese) to 500× (Hindu solar).

Hindu solar years use a **UInt16 offset** from a per-variant `baseNewYear:
Int32` constant (instead of storing each year's full RataDie). Offsets
range 0–54,423 days across 150 years, fitting comfortably in UInt16
(max 65,535). Saves 2 bytes per year × 600 entries = 1,184 bytes.

### Source Code

| Category | Lines | Files |
|---|---:|---:|
| Source (all modules) | 8,583 | 45 |
| Tests | 5,311 | 298 tests |
| Docs | 4,812 | 18 |
| Test data (CSVs) | 244,512 | — |

## Remaining Optimization Opportunities

1. **Hindu sunrise cache:** Cache sunrise/sunset times by (date, location)
   since consecutive dates often query the same sunrise. A simple 2-entry
   cache (today + yesterday) would help lunisolar kshaya detection.

2. **Dangi baked data:** Same packed format as Chinese, KASI-sourced.
   Deferred — Dangi currently uses Moshier fallback for all dates.

3. **Batch date operations:** For operations that process many consecutive
   dates (formatting a month, computing a calendar page), a batch API could
   compute sunrise once and reuse it across related queries.

4. **Solar calendar sankranti cache:** `solarMonthStart` and
   `solarMonthLength` each compute a sankranti independently. Caching the
   last few sankranti JDs would halve the cost.

See [`BakedDataStrategy.md`](BakedDataStrategy.md) for the full analysis
and prioritized action plan.

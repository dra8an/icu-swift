# Performance

*Last updated: 2026-04-06*

## Build Configuration

**Always use release mode for tests:**
```bash
swift test -c release    # ~28 seconds for full suite (270 tests)
swift test               # ~2+ minutes (debug mode, 50x slower for Moshier calculations)
```

The Moshier VSOP87/DE404 ephemeris calculations are compute-heavy (135 harmonic terms, 10-iteration sunrise refinement). Debug mode disables compiler optimizations, making these 50x slower.

## Current Benchmarks

| Test Suite | Release | Debug | Notes |
|-----------|-------:|------:|-------|
| Full suite (270 tests) | **28s** | ~140s | |
| Hindu lunisolar (55,152 days) | **27s** | ~120s | Dominates total time |
| Hindu solar (4×1,811 months) | **3s** | ~60s | Per calendar ~1s |
| Chinese calendar (730-day round-trip) | **1s** | ~4s | With year cache |
| All other calendars | **<1s** | ~2s | Arithmetic only |

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

## Chinese Calendar Year Cache

Computing a Chinese/Dangi year requires ~15 new moon calculations via the Moshier engine. A `ChineseYearCache` (LRU, 8 entries, `os_unfair_lock`) avoids recomputation for consecutive dates in the same year:

| Operation | Without cache | With cache | Speedup |
|-----------|------:|------:|------:|
| Single date lookup | 586 ms | 650 ms | ~1x (first computation) |
| 3 dates, same year | 1,727 ms | 650 ms | **2.7x** |
| 30 consecutive days | 25,378 ms | 644 ms | **39x** |

The cache is essential for any operation that iterates over dates (round-trip tests, month enumeration, formatting ranges). Without it, 30 consecutive days take 25 seconds; with it, 0.6 seconds.

## Moshier vs Reingold Performance

| Engine | Solar longitude | New moon | Use case |
|--------|------:|------:|----------|
| Reingold (Meeus) | ~1 µs | ~10 µs | Chinese/Dangi year computation |
| Moshier (VSOP87) | ~50 µs | ~500 µs | Hindu sunrise/sunset |
| HybridEngine | Moshier for 1700-2150 | Reingold estimate + Moshier refinement | Best accuracy in modern range |

The Chinese calendar uses the HybridEngine (which dispatches to Moshier for modern dates), but the year cache amortizes the cost. Hindu calendars call MoshierSunrise directly for each date, making their per-date cost higher.

## Future Optimization Opportunities

1. **Hindu sunrise cache:** Cache sunrise/sunset times by (date, location) since consecutive dates often query the same sunrise. A simple 2-entry cache (today + yesterday) would help lunisolar kshaya detection.

2. **Chinese precomputed data:** ICU4X uses precomputed year data tables for 1900-2100, falling back to astronomical calculation outside that range. This would eliminate the Moshier calls entirely for the common date range.

3. **Batch date operations:** For operations that process many consecutive dates (formatting a month, computing a calendar page), a batch API could compute sunrise once and reuse it across related queries.

4. **Solar calendar sankranti cache:** `solarMonthStart` and `solarMonthLength` each compute a sankranti independently. Caching the last few sankranti JDs would halve the cost.

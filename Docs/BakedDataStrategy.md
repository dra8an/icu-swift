# Baked Data & Year Compression Strategy

*Created: 2026-04-10 — based on ICU4X design research and input from ICU4X
contributor*

## Context

ICU4X's design philosophy for complex calendars is built around two ideas:

1. **Year compression** — all the expensive calculations for a given year
   (month lengths, leap month identity, new year date) are compressed into a
   small packed struct (`YearInfo`), computed once, and reused for every date
   in that year.

2. **Baked-in data tables** — for a "normal" date range (typically
   1900–2100), the packed year data is precomputed and shipped as a const
   array. Runtime code does a simple table lookup instead of astronomical
   computation. Astronomical calculation is only used as a fallback outside
   the baked range.

This document records how ICU4X implements these patterns, what icu4swift
currently does, and a prioritized plan for closing the gap.

## How ICU4X Does It

### East Asian Calendars (Chinese, Dangi)

**Type:** `PackedEastAsianTraditionalYearData` — **3 bytes (24 bits)**

```
Bits  0-12: Month lengths bitmask for 13 months (1 = 30 days, 0 = 29 days)
Bits 13-16: Leap month ordinal (0 = no leap, 2-13 = which month)
Bits 17-22: Chinese New Year offset from January 19 (range 0-34 days)
```

A single 24-bit value fully describes a Chinese/Dangi year: its new-year
date, every month length, and the leap month identity. Given a year's packed
data and the related ISO year, every calendar operation reduces to bit
manipulation — no astronomy needed.

**Baked data tables:**

| Table | Range | Entries | Location |
|---|---|---:|---|
| `china_data` | 1912–2102 CE | 191 | `east_asian_traditional.rs` |
| `qing_data` | 1900–1911 CE | 12 | `east_asian_traditional.rs` |
| `korea_data` | 1912–2102 CE | 191 | `east_asian_traditional.rs` |

**Decision logic:**

```
if year in china_data (1912–2102) → table lookup
else if year > 1912 → simplified runtime calculation
else if year in qing_data (1900–1911) → table lookup
else → simplified runtime calculation
```

The "simplified" calculation uses a UTC+8 (Beijing) timezone approximation
rather than full astronomical computation, and only kicks in outside the
baked range.

### Islamic Calendars (Umm al-Qura)

**Type:** `PackedHijriYearData` — **2 bytes (16 bits)**

```
Bits  0-11: Month lengths bitmask (1 = 30 days, 0 = 29 days) for 12 months
Bit    12 : Sign bit for start-day offset
Bits 13-15: Absolute value of start-day offset from tabular epoch (±5 days)
```

This is used for the **Umm al-Qura** calendar (observational/astronomical),
not for Islamic Tabular which is already pure arithmetic. The baked data
covers 1300 AH onward (~1882 CE).

**Note:** icu4swift does not implement Umm al-Qura yet, so this pattern is
informational — it would be needed if/when we add that calendar.

### Hindu Calendars

ICU4X does not appear to use baked data for Hindu calendars (they are
computed astronomically at runtime). This matches our current approach.

## What icu4swift Currently Does

### Chinese / Dangi

```
ChineseYearData struct:
  - newYear: RataDie          (8 bytes)
  - monthLengths: [Bool]      (heap-allocated array, 13 entries)
  - leapMonth: UInt8?          (2 bytes)

ChineseYearCache:
  - Global singleton (ChineseYearCache.shared)
  - LRU-8 (os_unfair_lock protected)
  - Computes via full Moshier engine on cache miss
  - ~586 ms per cache miss (cold), near-zero on hit
```

**No baked data.** Every first-access to a year triggers the full
Moshier-based astronomical pipeline: winter solstice search, ~15 new moon
calculations, leap month detection, month length enumeration.

### Islamic Tabular / Civil

Already pure integer arithmetic. No year compression needed — every
operation is already O(1) with trivial constants.

### Hindu

Full astronomical computation at runtime. No caching layer currently.
Performance has not been profiled in detail.

## Gap Analysis

| Area | ICU4X | icu4swift | Status |
|---|---|---|---|
| Chinese year packing | 3 bytes packed | `PackedChineseYearData` (UInt32) | ✅ Done (2026-04-13) |
| Chinese baked data | 191+12 entries | 199 entries (1901–2099) | ✅ Done — HKO-sourced |
| Chinese date carries year data | YearInfo in date | `packed` field in `ChineseDateInner` | ✅ Done — lock-free accessors |
| Dangi baked data | 191 entries | Uses Chinese table + Moshier fallback | Deferred |
| Islamic Umm al-Qura | 2-byte packed + baked | 301 entries (1300–1600 AH) | ✅ Done (2026-04-10) |
| Hindu solar baked | Not done | 4×150 entries (~1900–2050) | ✅ Done (2026-04-16) |
| Hindu lunisolar caching | No caching | No caching | Not attempted (complex structure) |

## Recommended Actions — Prioritized

### 1. ✅ Bake Chinese year data (DONE — 2026-04-13)

**Result:** 199-entry `ChineseYearTable` covering 1901–2099, generated from
HKO data. `PackedChineseYearData` (UInt32) encodes month lengths (13 bits),
leap month ordinal (4 bits), and new-year offset from Jan 19 (6 bits).

`ChineseDateInner` now carries its `packed: PackedChineseYearData` field.
All field accessors and arithmetic read from it directly — no cache, no
lock. Moshier fallback remains for dates outside 1901–2099 via
`ChineseYearCache`.

Cold start: **~586 ms → < 0.001 ms** for 1901–2099 dates.

### 2. ✅ Pack `ChineseYearData` (DONE — merged with #1)

`PackedChineseYearData` is the packed type. It serves as both the baked
table entry and the field stored in `ChineseDateInner`. Computed
`ChineseYearData` (from Moshier) is packed on the fly via
`PackedChineseYearData.from(yearData:relatedIso:)` for dates outside the
baked range.

### 3. Bake Dangi year data for 1900–2100

**Impact:** Same as Chinese, but for the Korean calendar.

**Approach:**
- Generate from `korean_lunar_calendar_py` (KASI-sourced tables) or from
  our own Moshier engine at the Seoul longitude.
- Same packed format as Chinese.
- Separate table (`korea_data`) since month boundaries can differ by ±1 day
  due to the Seoul-vs-Beijing longitude shift.

### 4. Profile and consider caching for Hindu calendars

**Impact:** Unknown — needs profiling first.

**Approach:**
- Run the Hindu regression test under Instruments to identify hot spots.
- If sunrise/longitude calculations dominate, consider a similar year-data
  cache. Hindu year structure is more complex (solar months don't map 1:1
  to lunar months in the lunisolar variant), so packing is harder.
- May not need baked data if a simple LRU cache provides sufficient speedup.

### 5. Future: Umm al-Qura with baked data

**Impact:** Only relevant if/when we implement the Umm al-Qura calendar.

**Approach:**
- Follow ICU4X's `PackedHijriYearData` pattern (2 bytes per year).
- Bake the official Saudi Umm al-Qura tables.
- Fallback to observational calculation or tabular approximation outside
  the baked range.

## What NOT to Do

- **Don't bake Islamic Tabular / Civil.** Already pure arithmetic — table
  lookup would not be faster than the integer formula.
- **Don't bake Hebrew.** Same — pure arithmetic, already sub-microsecond.
- **Don't bake Coptic / Ethiopian / Persian / Indian.** Same.
- **Don't over-engineer the cache.** The current LRU-8 with `os_unfair_lock`
  is simple and correct. Consider growing it or making it per-instance, but
  don't introduce complex eviction policies.

## References

- ICU4X `components/calendar/src/cal/east_asian_traditional.rs` — packed
  year data, baked tables (`china_data`, `qing_data`, `korea_data`), and the
  lookup/fallback logic.
- ICU4X `components/calendar/src/cal/hijri.rs` — `PackedHijriYearData` and
  Umm al-Qura baked data.
- ICU4X `utils/calendrical_calculations/src/chinese_based.rs` — the
  astronomical fallback code.
- icu4swift `Sources/CalendarAstronomical/ChineseCalendar.swift` — current
  `ChineseYearData` and `ChineseYearCache`.
- icu4swift `Tests/CalendarAstronomicalTests/chinese_months_1901_2100_hko.csv`
  — HKO-validated year data that can seed the baked table.
- icu4swift `Docs/PERFORMANCE.md` — existing Chinese cache benchmarks
  (586 ms uncached, 644 ms cached, 39× speedup over 30 consecutive days).

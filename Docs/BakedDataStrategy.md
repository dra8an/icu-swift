# Baked Data & Year Compression Strategy

*Created: 2026-04-10. Last updated: 2026-04-16.*

Based on ICU4X design research and input from an ICU4X contributor.

## Principle

Complex calendars (astronomical lunisolar, Umm al-Qura) are expensive to
compute at runtime — Moshier ephemeris evaluations for a single Chinese year
cost ~586 ms. For the "normal" date range that most applications need,
icu4swift **precomputes** the year structure into compact const arrays
("baked data"), packed into the date's inner representation so that every
field accessor and arithmetic operation is a lock-free bit op.

Outside the baked range, we fall back to the full astronomical engine.

## Current State

### Chinese — `ChineseYearTable` (2026-04-13)

- **Range:** 1901–2099 (199 entries, HKO-sourced)
- **Per-entry:** `UInt32` (4 bytes)
  - Bits 0–12: month lengths for 13 months (1 = 30d, 0 = 29d)
  - Bits 13–16: leap month ordinal (0 = none, 2–13 = position)
  - Bits 17–22: new year offset from Jan 19 of related ISO year
- **Storage:** 199 × 4 bytes = **796 bytes**
- **DateInner:** `ChineseDateInner` carries `packed: PackedChineseYearData`
- **Fallback:** Moshier via `ChineseYearCache` (LRU-8) for dates outside range
- **Result:** ~586 ms cold start → **< 0.001 ms** for baked range

### Islamic Umm al-Qura — `UmmAlQuraData` (2026-04-10)

- **Range:** 1300–1600 AH / ~1882–2174 CE (301 entries, KACST-sourced)
- **Per-entry:** `UInt16` (2 bytes)
  - Bits 0–11: month lengths for 12 months
  - Bit 12: sign flag for start-day offset
  - Bits 13–15: abs(offset) from mean tabular start (max ±1)
- **Storage:** 301 × 2 bytes = **602 bytes**
- **Fallback:** Islamic Civil (Friday epoch, Type II) for dates outside range
- **Data provenance:** KACST → ICU4C; offsets recomputed for our epoch

### Hindu Solar — `HinduSolarYearTable` (2026-04-16)

- **Range:** ~1900–2050 for each of 4 regional variants
  - Tamil (1822–1971 Saka)
  - Bengali (1307–1456)
  - Odia (1308–1457) — `yearStartMonth = 6` (year runs chronologically 6,7,…,12,1,2,…,5)
  - Malayalam (1076–1225)
- **Per-entry:** `UInt32` month data + `UInt16` new-year offset = **6 bytes**
  - Month data (24 bits): 2 bits × 12 months (00=29d, 01=30d, 10=31d, 11=32d)
  - New-year offset: days from a per-variant `baseNewYear: Int32` constant
    - Max observed offset: 54,423 (fits in UInt16; max 65,535)
- **Per-variant fixed overhead:** 4 bytes (baseNewYear)
- **Storage per variant:** 150 × 6 + 4 = 904 bytes
- **Total:** 4 × 904 = **3,616 bytes**
- **Fallback:** Moshier via the existing `HinduSolarArithmetic` engine

### Grand Total

| Calendar | Entries | Bytes |
|---|---:|---:|
| Chinese (1901–2099) | 199 | 796 |
| Umm al-Qura (1300–1600 AH) | 301 | 602 |
| Hindu Tamil | 150 | 904 |
| Hindu Bengali | 150 | 904 |
| Hindu Odia | 150 | 904 |
| Hindu Malayalam | 150 | 904 |
| **Total** | **1,100** | **5,014** |

**~5 KB of baked data**, 0.16% of the 2.8 MB full library.

## Design Choices

### Pack year data into the date

ICU4X's `DateInner` types carry the packed year data alongside year/month/day.
We follow the same pattern: `ChineseDateInner.packed: PackedChineseYearData`.
This eliminates cache lookups and lock contention during arithmetic —
`Date.added(.days, 100)` walks month boundaries using the packed data
directly, never reaching back to the calendar.

### Compute once, then cheap bit ops

For the baked range, all expensive work is done at compile time (table
generation from Moshier or HKO). At runtime, every query is an array index
plus a bit shift. For the fallback range, compute once via Moshier, cache
the result, and pack it into the same format — so the date carries
pre-computed year data regardless of which path produced it.

### Use UInt16 offsets when possible

For Hindu solar: storing full RataDie values as `Int32` wasted 2 bytes per
year (RD values were 693k–748k, trivially encoded as a UInt16 offset from a
per-variant base). Saved 1,184 bytes (~19% of Hindu solar data).

Same principle applies to the Chinese new year offset (Jan 19 + ≤34 days →
6 bits) and the Umm al-Qura offset (±1 → 3 bits).

### Variant-specific year-start handling

Hindu Odia's year starts at regional month 6 (Kanya/September), so the
chronological order is 6,7,…,12,1,2,…,5. The `yearStartMonth` is
computed from the variant's static constants (`yearStartRashi`,
`firstRashi`) — not stored in the packed data, since it's constant per
variant.

## What NOT to Bake

- **Arithmetic calendars** — ISO, Gregorian, Julian, Buddhist, ROC, Coptic,
  Ethiopian, Persian, Hebrew, Indian, Islamic Tabular, Islamic Civil,
  Japanese. All are already sub-microsecond with direct integer math.
  Table lookup would not be faster.

- **Hindu lunisolar** — Amanta, Purnimanta. Year structure is complex
  (adhika masa, kshaya tithi) and the months-per-year varies. Would require
  a more elaborate packing scheme. Currently ~3,900 µs/date via Moshier;
  worth profiling before committing to a design.

- **Dangi (Korean)** — structurally identical to Chinese but with UTC+9
  reference longitude. Differences only show up at the ±1-hour boundary
  between Seoul and Beijing midnight. Deferred; would need KASI-sourced
  data (not as accessible as HKO).

## Deferred Work

| Item | Why deferred |
|---|---|
| Dangi baked data | KASI data harder to get than HKO; differences vs Chinese are rare boundary cases |
| Hindu lunisolar baked data | Complex year structure (adhika, kshaya); worth profiling first |
| Chinese 1700–1900 extension | HKO data only covers 1901+; would need Qing-era astronomical recomputation |

## Reference Implementation (ICU4X)

Where we followed ICU4X's design:

- `components/calendar/src/cal/east_asian_traditional.rs` — `PackedEastAsianTraditionalYearData`, `china_data`, `qing_data`, `korea_data`.
- `components/calendar/src/cal/hijri.rs` — `PackedHijriYearData`, Umm al-Qura baked data.
- `utils/calendrical_calculations/src/chinese_based.rs` — astronomical fallback code.

Where we diverged:

- **Hindu solar baking** — ICU4X does not bake Hindu data. Our Moshier-based
  Hindu implementation is slow enough (~1,300 µs/date) that baking paid off
  handsomely (~500× speedup). ICU4X may not have this need because it uses
  different algorithms.
- **Epoch** — our `JulianArithmetic.fixedFromJulian(622, 7, 16)` = 227015.
  ICU4X's = 227016. This caused issues when copying ICU4X's Umm al-Qura
  packed offsets directly — we had to recompute them against Foundation
  (which matches our epoch).

## Benchmark Summary (2026-04-16)

| Calendar | Before (µs/date) | After (µs/date) | Speedup |
|---|---:|---:|---:|
| Chinese | 586,000 (cold) / 21 (cached) | 2.2 | ~270,000× / ~10× |
| Umm al-Qura | — (new calendar) | 2.3 | baseline |
| Hindu Tamil | 1,334 | 2.4 | ~556× |
| Hindu Bengali | 819 | 2.5 | ~328× |
| Hindu Odia | ~450 | 2.5 | ~180× |
| Hindu Malayalam | ~450 | 2.7 | ~167× |

See `PERFORMANCE.md` for the full benchmark table and methodology.

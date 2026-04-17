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
  a concrete layout proposal exists below under "Deferred Work → Hindu
  lunisolar baking proposal" — shelved because it would nearly triple
  total baked data for a single calendar.

- **Dangi (Korean)** — structurally identical to Chinese but with UTC+9
  reference longitude. Differences only show up at the ±1-hour boundary
  between Seoul and Beijing midnight. Deferred; would need KASI-sourced
  data (not as accessible as HKO).

## Deferred Work

| Item | Why deferred |
|---|---|
| Dangi baked data | KASI data harder to get than HKO; differences vs Chinese are rare boundary cases |
| Hindu lunisolar baked data | ~8 KB/calendar; 7× blow-up of total baked footprint for one calendar. Concrete layout below. |
| Chinese 1700–1900 extension | HKO data only covers 1901+; would need Qing-era astronomical recomputation |

### Hindu lunisolar baking proposal (shelved 2026-04-17)

**Context.** Lunisolar Amanta/Purnimanta is the last slow-tier calendar at
~3,900 µs/date. Baking would land it in the 2–5 µs tier like Chinese and
Hindu solar — an estimated ~1,000× speedup. Shelved because the data
footprint (~8 KB) is ~7× larger per calendar than anything else we bake,
nearly tripling the total (5 KB → 13 KB). Revisit if lunisolar performance
becomes a concrete blocker.

**Why it's structurally harder than Chinese.** Chinese has a clean year
structure: 12 or 13 lunar months, each 29 or 30 civil days, day-of-month
maps 1:1 to civil-day-ordinal within the month. Hindu lunisolar adds
**kshaya tithi** (a tithi skipped — civil-day-to-tithi mapping jumps) and
**adhika tithi** (a tithi repeated — two consecutive civil days share a
tithi number). These events are frequent, not rare: ~28 events/year on
average (roughly half kshaya, half adhika).

**Event-frequency evidence** (from `validation/moshier/adhika_kshaya_tithis.csv`,
151 years 1900–2050, reference location New Delhi):

| Metric | Value |
|---|---:|
| Total events (1900–2050) | 4,269 |
| Mean events/year | 28.3 |
| Max events/year | 33 (1971) |
| Max events in a single masa | 7 (masa 2 of 1934) |

**Proposed packing (variable-length per year):**

```
Header (UInt32, 4 bytes):
  newYearOffset    : 16 bits   days from per-calendar baseNewYear: Int32
  monthLengthBits  : 13 bits   29d (0) or 30d (1) per month
  leapMonthOrdinal : 4 bits    0 = no leap masa, 1–13 = ordinal position
  (padding)        : ~3 bits

eventCount (UInt8, 1 byte):
  Max observed 33; 6 bits would suffice but UInt8 keeps byte-alignment.

Events (10 bits × eventCount, packed):
  month    : 4 bits  (1–13)
  civilDay : 5 bits  (1–30 — day within the masa)
  type     : 1 bit   (0 = kshaya, 1 = adhika)
```

The skipped kshaya tithi is not stored — it's derivable from the adjacent
civil day's tithi-at-sunrise, which the calendar can reconstruct from
month + civilDay + event sequence.

**Storage (200-year range, New Delhi):**

| Item | Bytes |
|---|---:|
| Header + eventCount | 5 |
| Events (mean 28 events) | 35 |
| Events (max 33 events) | 42 |
| Per-year typical | ~40 |
| Per-year max | ~47 |
| 200 years × mean | ~8.0 KB |
| Per-year offset index (UInt16 × 200, for O(1) lookup) | 0.4 KB |
| **Total per calendar** | **~8.4 KB** |

This would be shared between Amanta and Purnimanta — they have identical
underlying year structure; Purnimanta is a label remap at the month level
(shukla tithis keep the masa; krishna tithis belong to the next masa).

**Location constraint.** Hindu lunisolar is location-dependent
(sunrise-sensitive). Baking assumes the default location (`newDelhi`);
other locations fall through to Moshier, mirroring how Chinese assumes
Beijing and Dangi assumes Seoul.

**Alternative to full baking — LRU cache of year structure.** Would give
a ~5–20× speedup (~200–800 µs/date) with zero baked data and full
location flexibility. Worth trying first if anyone picks this up.

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

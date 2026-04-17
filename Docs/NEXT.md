# icu4swift — Next Steps

*Last updated: 2026-04-16*

## Current State

23 calendars implemented. 321 tests passing in ~28 seconds (release mode). All calendars validated against external authoritative sources; Chinese has 3 known-limitation failures in the 1906 cluster (Moshier-vs-HKO physical disagreement).

**Performance:** all arithmetic and baked-table calendars at 2–4 µs/date. Only Hindu lunisolar remains in the slow tier at ~3,900 µs/date.

See [`TestCoverageAndDocs.md`](TestCoverageAndDocs.md) for the master per-calendar index, [`PERFORMANCE.md`](PERFORMANCE.md) for benchmarks, and [`HANDOFF.md`](HANDOFF.md) for a full session-handoff summary.

## Completed work

### Chinese Calendar Investigation — Done
3 regression failures (1906 cluster), accepted as Moshier-vs-HKO model disagreement. Moved from ICU4X-derived test data to HKO authoritative data; refactored `ChineseYearData.compute` with proper `findNewYear` logic, leap detection guards, and midnight epsilon snap. See `Docs/Chinese_reference.md`.

### Baked Data Architecture — Done
Three calendar families now use packed year data stored in `DateInner`:

1. ✅ **Chinese** — 199 entries (1901–2099), HKO-sourced, `PackedChineseYearData` UInt32. ~586 ms cold → 2.2 µs/date. (2026-04-13)
2. ✅ **Islamic Umm al-Qura** — 301 entries (1300–1600 AH), KACST-sourced, `PackedHijriYearData` UInt16. Validated against official Saudi government dates. (2026-04-10)
3. ✅ **Hindu solar ×4** — 150 entries each (~1900–2050), Moshier-sourced, `PackedHinduSolarYearData` (UInt32 months + UInt16 offset from per-variant base). ~500× speedup. (2026-04-16)

**Total baked data: ~5 KB** (0.16% of library). See [`BakedDataStrategy.md`](BakedDataStrategy.md).

### Regression Coverage — Done
- Hebrew ×73,414 vs Hebcal
- Islamic ×3 (Tabular, Civil, UQ) vs Foundation + convertdate
- Persian, Coptic, Ethiopian, Indian (Saka) vs Foundation + convertdate
- Japanese vs Foundation (era mapping)
- Chinese vs Hong Kong Observatory
- Hindu ×6 vs Moshier regression CSVs

## Deferred / Remaining Work

### Performance optimization

**Hindu lunisolar** is the last slow tier (~3,900 µs/date for Amanta, Purnimanta). Not yet profiled or baked.

- **Profile first** to identify hot spots (`toRataDie` dominates — up to 14 iterations of `masaForGregorian` in `amantaMonthStart`, then up to 32 civil-day sunrise+tithi evaluations).
- **Baking proposal documented** in `BakedDataStrategy.md` → "Hindu lunisolar baking proposal" (~8 KB per calendar, est. ~1,000× speedup). Shelved — ~7× blow-up of total baked footprint for one calendar.
- **Alternative: LRU cache of year structure** — 5–20× speedup without baked data.
- **Impact:** current 3,900 µs is fine for one-off conversions but slow for bulk date rendering.

### Dangi (Korean) baked data — Deferred

Dangi is structurally identical to Chinese but uses UTC+9 (Seoul) instead of UTC+8 (Beijing). Differences only appear at ~1-hour midnight boundaries. Currently falls through to Moshier for all dates.

**Source options:**
- **KASI Open API** (Korea Astronomy and Space Science Institute) — per-date query, requires API key
- **Python `korean_lunar_calendar_py`** — embeds KASI tables for 1000–2050 as lookup arrays
- **Recompute from our Moshier engine** at the Seoul longitude

**Status:** Low priority. Can be revisited if specific Dangi-vs-Chinese bugs surface. No governmental authoritative source comparable to HKO for Chinese.

### Phase 8: DateFormat — Very Large

**Depends on:** All calendar phases + Phase 7 (all done).

**Deliverables:**
- Semantic skeleton API (`YMD.long`, `YMDE.medium`)
- Raw pattern API (`PatternDateFormatter`)
- Three formatter tiers: fixed-calendar, any-calendar, time-only
- `DateSymbols` — month/weekday/era names by locale
- `FormattedDate` with field parts
- CLDR data embedding for core locale set

**Sub-phases:**
1. Pattern engine (pattern parsing, field rendering)
2. Skeleton matching (CLDR best-pattern algorithm)
3. Data embedding (code-gen CLDR data for ~14 locales)
4. Public API (the three formatter tiers)

**Source:** ICU4X `fieldsets.rs`, `pattern/`, `format/`. CLDR data.

**Status:** Deferred — user explicitly said "Phase 8 will have to wait" (2026-04-08). Calendar work and performance optimization are the priority until user signals otherwise.

### Phase 9-10: DateParse + DateFormatInterval

**Depends on:** Phase 8.

Can run in parallel with each other. Lower priority — formatting is more commonly needed than parsing.

## Open Questions (for when DateFormat work starts)

1. **CLDR data strategy:** Embed as generated Swift source? External files? Build-time code generation for locale subsetting?
2. **AnyCalendar design:** Manual enum (exhaustive, fast) vs protocol existential (extensible, slower)?
3. **Minimum locale set for v1:** en, ja, ar, he, hi, zh, ko, fa, th, de, fr, es, pt, ru covers all calendar systems. Is this enough?

## Lowest-Hanging Fruit (if you want something small)

- **Benchmark Hindu lunisolar** under Instruments — identify whether sunrise or tithi bisection dominates. Even a 2× improvement would move it from 3,900 µs to ~2,000 µs.
- **Chinese pre-1901 / post-2099** — HKO data doesn't extend; would need Qing-era recompute or accept the fallback. Probably not worth it for edge-of-range dates.
- **Extend Hebrew regression** beyond 1900–2100 — Hebrew is pure arithmetic, so we could validate against Hebcal for ±10,000 years cheaply. Mostly diminishing returns since 0 failures across 73k days is strong evidence.

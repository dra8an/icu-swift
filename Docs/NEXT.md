# icu4swift — Next Steps

*Last updated: 2026-04-08*

## Current State

22 of 22 calendars implemented (Islamic Civil added 2026-04-08). Hindu calendars at 100% accuracy (55,152 lunisolar days + 4×1,811 solar months). 283 tests passing in ~30 seconds (release mode).

See [`TestCoverageAndDocs.md`](TestCoverageAndDocs.md) for the master per-calendar index of docs and regression coverage.

## Chinese Calendar Investigation — Mostly Resolved

**Status:** 3 regression failures remaining, down from 245. All 23 unit tests passing. See `Docs/Chinese_reference.md` for the authoritative data setup, and `backup/README.md` for snapshots of intermediate states.

### What we did
1. **Switched the regression test from an ICU4X-derived CSV to authoritative Hong Kong Observatory data** (`Data/hko_raw/T{1901..2100}e.txt`, generator at `Data/build_hko_csv.py`, CSV at `Tests/CalendarAstronomicalTests/chinese_months_1901_2100_hko.csv`). The ICU4X-derived CSV had a generator off-by-one bug producing ~121 false alarms.
2. **Fixed the `nm11` semantics** — was `newMoonOnOrAfter(solstice)`, should be `newMoonOnOrBefore(solstice)` (the 11th month is the lunation *containing* the solstice).
3. **Restructured `ChineseYearData.compute` to use a `findNewYear` helper** for both the current and next Chinese year, then iterate exactly 12 months between them and apply the "13th month is leap if no leap detected" fallback (matching ICU4X's `month_structure_for_year`). This handles M11L-style leaps that fall in a different sui from the year being computed.
4. **Two boundary-precision guards:** take the LAST same-term pair in the 12-iter loop (the real leap is later than any false positive), and only commit a leap if there's actually a 13th month.
5. **Midnight epsilon snap** in `newMoonOnOrAfter`: when the local moment is within `1e-4` days (~8.6 s) past local midnight, snap to the previous day. Resolved 2057 M08→M09 (Moshier placed that new moon 3.5 seconds past midnight Beijing vs HKO's prior-day placement).

### Remaining 3 failures (1 cluster)
**1906 M03→M04 boundary.** Moshier places the April 1906 new moon at Apr 23 23:52:04 LMT — 8 minutes before midnight. HKO places it on Apr 24. This is an 8-minute discrepancy, too far to be a simple rounding issue, and in the opposite direction from the epsilon fix. Appears to be a real Moshier-vs-HKO astronomical model disagreement at the historical end of the table. Accepted as a known limitation; not worth further investigation unless we change engines.

## Performance — Astronomical Calendars

The next major focus is **further optimization of astronomical calendars**.
Arithmetic calendars are already sub-microsecond per conversion and are not
a concern.

### Astronomical (perf-sensitive) calendars

| Calendar | Engine path | Status |
|---|---|---|
| Chinese | Moshier + HybridEngine | ~586 ms uncached, ~644 ms cached, **39× speedup over 30 days** via `ChineseYearCache` (LRU 8) |
| Dangi | Moshier + HybridEngine | Structurally identical to Chinese, no dedicated cache |
| Hindu Amanta / Purnimanta (lunisolar) | AstronomicalEngine + sunrise/equinox | 100% accurate, perf not yet profiled |
| Hindu Tamil / Bengali / Odia / Malayalam (solar) | Sun longitude only | 100% accurate, perf not yet profiled |

### Arithmetic (no perf concern) — for reference

ISO, Gregorian, Julian, Buddhist, ROC, Coptic, Ethiopian, Persian, Hebrew,
Indian, Japanese, Islamic Tabular, Islamic Civil. All sub-microsecond per
conversion; no further perf work warranted.

### Lowest-hanging fruit when we dig in

1. **Profile Moshier itself.** It's the bottom of the pyramid for
   *everything* astronomical — any speedup there compounds across all six
   astronomical calendars.
2. **`ChineseYearCache` sizing & lifetime.** Currently LRU 8. Should it
   grow? Should it become per-calendar instance vs shared?
3. **Share cache across Chinese ↔ Dangi.** The underlying year-boundary
   computations (winter solstice, new moons around it) overlap heavily —
   only the reference longitude differs (Beijing vs Seoul). A shared
   underlying year-data layer could halve the cost when both are used.
4. **Hindu engine profiling** — has not been targeted yet; may have its
   own low-hanging fruit independent of Moshier.

## After Astronomical Perf Work

### 1. DateFormat (Phase 8) — Very Large complexity

**Depends on:** All calendar phases + Phase 7.

**Deliverables:**
- Semantic skeleton API (`YMD.long`, `YMDE.medium`)
- Raw pattern API (`PatternDateFormatter`)
- Three formatter tiers: fixed-calendar, any-calendar, time-only
- `DateSymbols` — month/weekday/era names by locale
- `FormattedDate` with field parts
- CLDR data embedding for core locale set

**This is the largest single phase.** Consider breaking it into sub-phases:
1. Pattern engine (pattern parsing, field rendering)
2. Skeleton matching (CLDR best-pattern algorithm)
3. Data embedding (code-gen CLDR data for ~14 locales)
4. Public API (the three formatter tiers)

**Source:** ICU4X `fieldsets.rs`, `pattern/`, `format/`. CLDR data.

### 2. DateParse + DateFormatInterval (Phases 9-10)

**Depends on:** Phase 8.

Can run in parallel with each other. Lower priority — formatting is more commonly needed than parsing.

## Open Questions

1. **CLDR data strategy:** Embed as generated Swift source? External files? Build-time code generation for locale subsetting?
2. **AnyCalendar design:** Manual enum (exhaustive, fast) vs protocol existential (extensible, slower)?
3. **Minimum locale set for v1:** en, ja, ar, he, hi, zh, ko, fa, th, de, fr, es, pt, ru covers all calendar systems. Is this enough?
4. **Chinese calendar authority:** For post-1912 dates, should we trust our Moshier calculation (JPL-grade precision) or match ICU4X's Reingold-generated tables?

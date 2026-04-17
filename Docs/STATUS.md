# icu4swift — Project Status

*Last updated: 2026-04-16*

## Overall Progress

```
Phase 1:  CalendarCore           ████████████████████ DONE
Phase 2:  CalendarSimple         ████████████████████ DONE
Phase 3:  CalendarComplex        ████████████████████ DONE
Phase 4a: AstronomicalEngine     ████████████████████ DONE
Phase 4b: CalendarAstronomical   ████████████████████ DONE  (+ UQ added 2026-04-10)
Phase 5:  CalendarHindu          ████████████████████ DONE  (+ solar baked tables 2026-04-16)
Phase 6:  CalendarJapanese       ████████████████████ DONE
Phase 7:  DateArithmetic         ████████████████████ DONE
Phase 8:  DateFormat             ░░░░░░░░░░░░░░░░░░░░ DEFERRED
Phase 9:  DateParse              ░░░░░░░░░░░░░░░░░░░░ DEFERRED
Phase 10: DateFormatInterval     ░░░░░░░░░░░░░░░░░░░░ DEFERRED
```

**23 calendars, 321 tests, ~28 seconds full suite (release mode).**
**All calendars at 100% accuracy except Chinese 3/2,461 (known limitation).**
**Formatting (Phase 8-10) deferred pending user signal.**

## Calendar Inventory

| Module | Calendars | Status |
|---|---|---|
| **CalendarSimple** | ISO, Gregorian, Julian, Buddhist, ROC | All 100% |
| **CalendarComplex** | Hebrew, Coptic, Ethiopian, Persian, Indian | All 100% |
| **CalendarJapanese** | Japanese (5 imperial eras) | 100% |
| **CalendarAstronomical** | Islamic Tabular, Islamic Civil, Islamic Umm al-Qura, Chinese, Dangi | All at 100% except Chinese 3/2461 |
| **CalendarHindu** | Tamil, Bengali, Odia, Malayalam, Amanta, Purnimanta | All 100% |

## Recent Activity

### 2026-04-16 — Hindu solar baked tables
- `PackedHinduSolarYearData` with UInt16 offsets from per-variant `baseNewYear`
- 4×150 entries (~1900–2050), 3.6 KB total
- **~500× speedup**: Tamil/Bengali/Odia/Malayalam all at 2.4–2.7 µs/date
- Odia year-start gotcha fixed (`yearStartMonth = 6`)
- `BakedDataStrategy.md`, `PERFORMANCE.md`, `NEXT.md` all updated

### 2026-04-13 — Chinese baked table
- `PackedChineseYearData` UInt32 stored in `ChineseDateInner`
- 199-entry HKO table (1901–2099)
- ~586 ms → 2.2 µs/date
- Moshier fallback retained for pre-1901/post-2099

### 2026-04-10 — Islamic Umm al-Qura
- New calendar (`islamic-umalqura`) implemented
- 301-entry `PackedHijriYearData` UInt16 table (1300–1600 AH)
- KACST-sourced via ICU4C; offsets recomputed for our epoch
- Validated against official Saudi government dates

### 2026-04-10 — Islamic refactor
- Split into `IslamicTabular` (Thursday epoch, default) + `IslamicCivil` (Friday epoch)
- Fixed off-by-one `yearFromFixed` formula

## What's Done

### Phase 1: CalendarCore (8 files, 26 tests)

Core protocols and types that everything builds on.

| File | What |
|------|------|
| `CalendarProtocol` | Protocol with `DateInner`, `toRataDie`, `fromRataDie`, field accessors |
| `Date<C>` | Generic immutable date, field properties, `converting(to:)` |
| `RataDie` | Fixed day count, arithmetic, Unix epoch conversion |
| `Month` / `MonthCode` / `MonthInfo` | Month representation with leap month support |
| `YearInfo` / `EraYear` / `CyclicYear` | Era-based and cyclic year representations |
| `Weekday` | ISO 8601 weekday enum, computed from RataDie |
| `Location` | For Hindu astronomical calculations |
| `DateNewError` | Error type for date construction |

### Phase 2: CalendarSimple (7 files, 48 tests)

Five calendars sharing Gregorian-family arithmetic.

| Calendar | Identifier | Eras | Notes |
|----------|-----------|------|-------|
| ISO | `iso8601` | `default` | Pivot calendar, year 0 exists |
| Gregorian | `gregorian` | `ce`, `bce` | Year ambiguity flags |
| Julian | `julian` | `ce`, `bce` | Leap every 4 years, no century exception |
| Buddhist | `buddhist` | `be` | Gregorian + 543 year offset |
| ROC | `roc` | `roc`, `broc` | Gregorian - 1911 year offset |

Shared arithmetic: `GregorianArithmetic`, `JulianArithmetic` (both `public` for downstream use).

### Phase 3: CalendarComplex (7 files, 53 tests)

Five calendars with non-trivial algorithmic rules.

| Calendar | Identifier | Eras | Notes |
|----------|-----------|------|-------|
| Hebrew | `hebrew` | `am` | Lunisolar, 19-year Metonic cycle, 12/13 months, 3 year types |
| Coptic | `coptic` | `am` | 13 months (12×30 + 1×5/6), Julian leap rule |
| Ethiopian | `ethiopian` | `incar`, `mundi` | Coptic structure, different epoch, two eras |
| Persian | `persian` | `ap` | 33-year rule + 78-entry correction table |
| Indian | `indian` | `shaka` | Gregorian leap rule, 80-day/78-year offset |

Shared arithmetic: `HebrewArithmetic`, `CopticArithmetic` (Coptic+Ethiopian), `PersianArithmetic`.

### Phase 4a: AstronomicalEngine (13 files, 36 tests)

Hybrid astronomical calculation engine with two backends:

| Engine | Algorithm | Precision | Range |
|--------|-----------|-----------|-------|
| ReingoldEngine | Meeus polynomials | ~0.13° solar | ±10,000 years |
| MoshierEngine | VSOP87 + DE404 | ±1 arcsecond solar | ~1700-2150 |
| HybridEngine | Moshier in modern range, Reingold outside | Best of both | Full range |

Moshier validated against real Swiss Ephemeris (JPL DE431) — agrees to 0.00001°.

### Phase 4b: CalendarAstronomical (4 files, 57 tests)

Five calendar systems:

| Calendar | Identifier | Type | Algorithm |
|----------|-----------|------|-----------|
| Islamic Tabular | `islamic-tbla` | Arithmetic | 30-year cycle, Thursday epoch (default) |
| Islamic Civil | `islamic-civil` | Arithmetic | Same as Tabular, Friday epoch |
| Islamic Umm al-Qura | `islamic-umalqura` | Baked data | 301-entry KACST table (1300–1600 AH), tabular fallback |
| Chinese | `chinese` | Lunisolar | 199-entry HKO baked table (1901–2099), Moshier fallback |
| Dangi | `dangi` | Lunisolar | Same as Chinese, UTC+9 (Seoul); no baked table yet |

Chinese and UQ use packed year data stored in `DateInner` — all field access is lock-free bit ops.

### Phase 5: CalendarHindu (3 files, 33 tests + 5 CSV regression tests)

Protocol extended with `location`, `dateStatus`, `alternativeDate`. All 6 calendars validated against Hindu project Moshier CSVs.

| Calendar | Identifier | Type | Validation |
|----------|-----------|------|------------|
| Tamil | `hindu-solar-tamil` | Solar | **1,811 / 0 (100%)** + baked table |
| Bengali | `hindu-solar-bengali` | Solar | **1,811 / 0 (100%)** + baked table |
| Odia | `hindu-solar-odia` | Solar | **1,811 / 0 (100%)** + baked table |
| Malayalam | `hindu-solar-malayalam` | Solar | **1,811 / 0 (100%)** + baked table |
| Amanta | `hindu-lunisolar-amanta` | Lunisolar | **55,152 / 0 (100%)** — astronomical |
| Purnimanta | `hindu-lunisolar-purnimanta` | Lunisolar | **55,152 / 0 (100%)** — astronomical |

Hindu solar now uses `PackedHinduSolarYearData` (UInt32 monthData + UInt16 offset from per-variant `baseNewYear`). Moshier fallback outside ~1900–2050.

**Odia gotcha:** `firstRashi = 1, yearStartRashi = 6`. Year runs chronologically 6,7,…,12,1,2,…,5 (September–August), not 1–12.

### Phase 6: CalendarJapanese (1 file, 15 tests + regression)

Gregorian arithmetic with Japanese imperial era overlay.

| Era | Code | Start Date | Era Index |
|-----|------|------------|-----------|
| Meiji | `meiji` | 1868-10-23 | 2 |
| Taisho | `taisho` | 1912-07-30 | 3 |
| Showa | `showa` | 1926-12-25 | 4 |
| Heisei | `heisei` | 1989-01-08 | 5 |
| Reiwa | `reiwa` | 2019-05-01 | 6 |

Dates before Meiji 6 (1873) fall back to `ce`/`bce` eras. `JapaneseEraData` is extensible for future eras.

Note: ICU4C/Foundation uses 1868-09-08 for Meiji start (lunisolar Meiji 1/1/1). Both agree on `ce` before 1873 where the Gregorian calendar was officially adopted.

### Phase 7: DateArithmetic (2 files, 24 tests)

Date addition, difference, and field balancing — works with all calendars.

| Type | What |
|------|------|
| `DateDuration` | Signed duration: years, months, weeks, days + isNegative flag |
| `Overflow` | `.constrain` (clamp to valid) or `.reject` (throw error) |
| `DateDurationUnit` | `.years`, `.months`, `.weeks`, `.days` |
| `DateAddError` | Overflow, invalid day, month-not-in-year |
| `Date.added(_:overflow:)` | Temporal NonISODateAdd algorithm |
| `Date.until(_:largestUnit:)` | Temporal NonISODateUntil algorithm |
| `DateArithmeticHelper.balance()` | Temporal BalanceNonISODate |

### Test Coverage Summary

See `Docs/TestCoverageAndDocs.md` for the master per-calendar regression index.

**321 tests total**, ~28 second full suite in release mode. Benchmark suite available via `--filter "Benchmark"` (per `Docs/PERFORMANCE.md`).

## Performance

See `Docs/PERFORMANCE.md` for full benchmarks.

Baseline (µs/date, round-trip, release mode):

| Tier | Calendars | Speed |
|---|---|---:|
| Arithmetic / baked table | ISO, Gregorian, Julian, Buddhist, ROC, Coptic, Ethiopian, Persian, Hebrew, Indian, Japanese, Islamic ×3, Chinese (baked), Dangi (baked), Hindu solar ×4 (baked) | 2–4 |
| Moshier fallback | Chinese pre-1901 | ~437 |
| Hindu lunisolar | Amanta, Purnimanta | ~3,900 |

## What's Not Done

See `Docs/NEXT.md` for prioritized next steps.

- Dangi baked data (deferred, low priority)
- Hindu lunisolar baking (deferred, complex structure)
- Formatting/parsing infrastructure (Phase 8–10, deferred pending user signal)

## Session Handoff

See `Docs/HANDOFF.md` for a comprehensive handoff summary intended to bring a fresh session fully up to speed.

# icu4swift — Project Status

*Last updated: 2026-04-03*

## Overall Progress

```
Phase 1:  CalendarCore           ████████████████████ DONE
Phase 2:  CalendarSimple         ████████████████████ DONE
Phase 3:  CalendarComplex        ████████████████████ DONE
Phase 4a: AstronomicalEngine     ████████████████████ DONE
Phase 4b: CalendarAstronomical   ████████████████████ DONE
Phase 6:  CalendarJapanese       ████████████████████ DONE
Phase 7:  DateArithmetic         ████████████████████ DONE
Phase 5:  CalendarHindu          ██████████░░░░░░░░░░ IN PROGRESS (accuracy issues)
Phase 8:  DateFormat             ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 9:  DateParse              ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 10: DateFormatInterval     ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
```

**Calendars: 20 of 22 implemented. 6 Hindu calendars have accuracy issues. Formatting: not started.**

## What's Done

### Phase 1: CalendarCore (7 files, 26 tests)

Core protocols and types that everything builds on.

| File | What |
|------|------|
| `CalendarProtocol` | Protocol with `DateInner`, `toRataDie`, `fromRataDie`, field accessors |
| `Date<C>` | Generic immutable date, field properties, `converting(to:)` |
| `RataDie` | Fixed day count, arithmetic, Unix epoch conversion |
| `Month` / `MonthCode` / `MonthInfo` | Month representation with leap month support |
| `YearInfo` / `EraYear` / `CyclicYear` | Era-based and cyclic year representations |
| `Weekday` | ISO 8601 weekday enum, computed from RataDie |
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

### Phase 7: DateArithmetic (2 files, 24 tests)

Date addition, difference, and field balancing — works with all 10 calendars.

| Type | What |
|------|------|
| `DateDuration` | Signed duration: years, months, weeks, days + isNegative flag |
| `Overflow` | `.constrain` (clamp to valid) or `.reject` (throw error) |
| `DateDurationUnit` | `.years`, `.months`, `.weeks`, `.days` |
| `DateAddError` | Overflow, invalid day, month-not-in-year |
| `Date.added(_:overflow:)` | Temporal NonISODateAdd algorithm |
| `Date.until(_:largestUnit:)` | Temporal NonISODateUntil algorithm |
| `DateArithmeticHelper.balance()` | Temporal BalanceNonISODate |

See `Docs/DateArithmetic.md` for algorithm details.

### Phase 6: CalendarJapanese (1 file, 15 tests)

Gregorian arithmetic with Japanese imperial era overlay.

| Era | Code | Start Date | Era Index |
|-----|------|------------|-----------|
| Meiji | `meiji` | 1868-10-23 | 2 |
| Taisho | `taisho` | 1912-07-30 | 3 |
| Showa | `showa` | 1926-12-25 | 4 |
| Heisei | `heisei` | 1989-01-08 | 5 |
| Reiwa | `reiwa` | 2019-05-01 | 6 |

Dates before Meiji 6 (1873) fall back to `ce`/`bce` eras. `JapaneseEraData` is extensible for future eras.

See `Docs/CalendarJapanese.md` for design details.

### Phase 4a: AstronomicalEngine (13 files, 36 tests)

Hybrid astronomical calculation engine with two backends:

| Engine | Algorithm | Precision | Range |
|--------|-----------|-----------|-------|
| ReingoldEngine | Meeus polynomials | ~0.13° solar | ±10,000 years |
| MoshierEngine | VSOP87 + DE404 | ±1 arcsecond solar | ~1700-2150 |
| HybridEngine | Moshier in modern range, Reingold outside | Best of both | Full range |

Moshier validated against real Swiss Ephemeris (JPL DE431) — agrees to 0.00001°.

See `Docs/AstronomicalEngine.md` for full details.

### Phase 4b: CalendarAstronomical (2 files, 32 tests)

Three calendar systems using the AstronomicalEngine:

| Calendar | Identifier | Type | Algorithm |
|----------|-----------|------|-----------|
| Islamic Tabular | `islamic-tbla` | Arithmetic | 30-year cycle, eras `ah`/`bh` |
| Chinese | `chinese` | Lunisolar | Winter solstice + new moon + major solar terms |
| Dangi | `dangi` | Lunisolar | Same as Chinese, UTC+9 (Seoul) |

Chinese calendar uses `ChineseYearCache` (LRU) for performance: 39x speedup for consecutive dates.

See `Docs/CalendarAstronomical.md` for full details including the leap month bug fix.

### Phase 5: CalendarHindu (3 files, IN PROGRESS — accuracy issues)

Protocol extended with `location`, `dateStatus`, `alternativeDate`. Location moved to CalendarCore.

| Calendar | Identifier | Type | Status |
|----------|-----------|------|--------|
| Tamil | `hindu-solar-tamil` | Solar | 6 failures / 1,811 months (should be 0) |
| Bengali | `hindu-solar-bengali` | Solar | 12 failures / 1,811 months (should be 0) |
| Odia | `hindu-solar-odia` | Solar | **0 failures / 1,811 (100%)** |
| Malayalam | `hindu-solar-malayalam` | Solar | 339 failures / 1,811 (should be 0) |
| Amanta | `hindu-lunisolar-amanta` | Lunisolar | 191 failures / 1,104 sampled (should be ~15) |
| Purnimanta | `hindu-lunisolar-purnimanta` | Lunisolar | Not yet regression-tested |

**Root cause:** Our refactored MoshierSunrise produces sunrise times ~2.5 minutes different from the original Hindu project's Rise.swift. The original Hindu project's Swift port has 0 errors on Tamil/Odia/Malayalam and ~15-20 irreducible boundary errors on lunisolar.

**Bugs found and fixed during Phase 5:**
- `utcOffset` unit mismatch: Bengali/Odia critical time formulas divided fractional-day offset by 24 again (fixed Bengali 1,025→12, Odia 1,019→0)
- `JulianDayHelper.ymdToJd` returned RD+0.5 instead of real Julian Day (fixed Saka year calculation)

**Proposed fix:** Use the original Hindu project (`hindu-calendar`) as a Swift package dependency instead of our refactored Moshier port, to guarantee bit-identical astronomical results.

See `Docs/HinduCalendars.md` for architecture decisions and full details.

### Test Coverage

| Suite | Tests | Verified Against |
|-------|------:|-----------------|
| CalendarCore | 26 | Unit tests |
| ISO | 10 | ICU4X `iso.rs` RD↔YMD pairs |
| Gregorian | 6 | ICU4X `gregorian.rs` CE/BCE test cases |
| Julian | 9 | ICU4X `julian.rs`, Gregorian cutover (Oct 1582) |
| Buddhist | 7 | ICU4X `buddhist.rs` epoch + near-zero cases |
| ROC | 7 | ICU4X `roc.rs` both eras + epoch directionality |
| Cross-Calendar | 7 | Full chain: ISO→Julian→Buddhist→ROC→Gregorian→ISO |
| Hebrew | 17 | 33 R&D reference pairs, 48 ICU4X ISO↔Hebrew pairs, arithmetic internals |
| Coptic | 7 | ICU4X epoch, regression #2254 |
| Ethiopian | 10 | ICU4X Amete Mihret/Alem, leap year, regression #2254 |
| Persian | 8 | 21 R&D pairs, 293 U. Tehran Nowruz dates |
| Indian | 9 | ICU4X 8 roundtrip pairs, epoch, near-zero |
| DateDuration | 2 | Factory methods, weeks/days decomposition |
| Date Addition | 14 | ICU4X `iso.rs` offset tests, month-end clamping, combined durations |
| Date Difference | 5 | Day/week/year-month diff, round-trip verification |
| Day Arithmetic | 1 | Exhaustive: every day in 2000-2001 × 5 offsets |
| Japanese | 15 | ICU4X era boundaries, Meiji 6 switchover, datetime fixtures |
| Moment/Reingold | 17 | JD conversion, solar/lunar at J2000, new moon spacing, sunrise |
| Moshier | 6 | Solar longitude, Delta-T, nutation, lunar, sunrise, new moon |
| Cross-Validation | 3 | Moshier vs Reingold: solar (<0.05°), new moon (same day), sunrise |
| HybridEngine | 3 | Modern→Moshier, historical→Reingold, boundary |
| Chinese Perf | 3 | Single date, 3 dates cached, 30-day cached |
| Islamic Tabular | 14 | 33 R&D pairs, 30-year cycle, round-trip, eras, directionality |
| Chinese | 11 | 16 RD conversions, month codes (M02L verified), CNY dates, round-trip |
| Dangi | 8 | Round-trip, month structure, alignment, conversion |
| Ayanamsa | 6 | Lahiri epoch, J2000, monotonic, sidereal relation |
| Hindu Solar | 12 | 4 calendar identifiers, round-trips (30d × 4), structure, eras |
| Hindu Lunisolar | 10 | Round-trips (10d × 2), tithi/masa range, Saka year, adhika, dateStatus |
| Full Regression | 5 | CSV: 1,104 lunisolar days + 4×1,811 solar months (some failing) |
| **Total** | **270** | |

## What's Not Done

See `Docs/NEXT.md` for prioritized next steps.

Hindu calendar accuracy needs to be fixed before Phase 5 is complete. 2 Islamic variants (Umm al-Qura, Observational) deferred. Formatting/parsing infrastructure not started.

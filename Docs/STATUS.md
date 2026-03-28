# icu4swift — Project Status

*Last updated: 2026-03-27*

## Overall Progress

```
Phase 1:  CalendarCore           ████████████████████ DONE
Phase 2:  CalendarSimple         ████████████████████ DONE
Phase 3:  CalendarComplex        ████████████████████ DONE
Phase 4a: AstronomicalEngine     ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 4b: CalendarAstronomical   ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 5:  CalendarHindu          ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 6:  CalendarJapanese       ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 7:  DateArithmetic         ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 8:  DateFormat             ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 9:  DateParse              ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
Phase 10: DateFormatInterval     ░░░░░░░░░░░░░░░░░░░░ NOT STARTED
```

**Calendars: 10 of 22 implemented. Formatting: not started.**

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
| **Total** | **127** | |

## What's Not Done

See `Docs/NEXT.md` for prioritized next steps.

12 remaining calendar systems + all formatting/parsing/arithmetic infrastructure.

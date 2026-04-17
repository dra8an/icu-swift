# icu4swift — Session Handoff

*Written 2026-04-16 for context-clearing handoff. Consult this first when resuming work on this project.*

## What is this project

**icu4swift** is a Swift package — a library for world calendar systems. It ports ICU4X/ICU4C calendar algorithms to pure Swift. No Foundation dependency, no external deps, Swift 6 with strict concurrency.

**Output:** a library (no executable). Consumers import modules like `CalendarCore`, `CalendarSimple`, `CalendarComplex`, `CalendarAstronomical`, `CalendarHindu`, `CalendarJapanese`, `DateArithmetic`.

## Current state at handoff

- **23 calendars implemented**, all passing regression tests (1 known Chinese limitation — see below).
- **321 tests**, full suite runs in ~28 seconds (`swift test -c release`).
- **Phase 8 (DateFormat) deferred** — user wants to continue calendar/perf work.
- **Library size: 2.8 MB** compiled (release, x86_64).
- **Baked data: ~5 KB total** across Chinese, Umm al-Qura, and Hindu solar (all 4 variants).

### Calendar inventory

| Module | Calendars |
|---|---|
| CalendarSimple | ISO, Gregorian, Julian, Buddhist, ROC |
| CalendarComplex | Hebrew, Coptic, Ethiopian, Persian, Indian |
| CalendarJapanese | Japanese (5 imperial eras: meiji/taisho/showa/heisei/reiwa) |
| CalendarAstronomical | Islamic Tabular, Islamic Civil, Islamic Umm al-Qura, Chinese, Dangi |
| CalendarHindu | 4 solar (Tamil, Bengali, Odia, Malayalam), 2 lunisolar (Amanta, Purnimanta) |

### Regression summary

See `Docs/TestCoverageAndDocs.md` for the master index.

| Calendar | Regression | Reference |
|---|---|---|
| Hebrew | 73,414 / 0 | Hebcal (`@hebcal/core`) |
| Islamic Tabular | 73,414 / 0 | Foundation + convertdate |
| Islamic Civil | 73,414 / 0 | Foundation + convertdate |
| Islamic UQ | 4,380 / 0 | Foundation (KACST-derived) |
| Persian | 3,064 / 0 | Foundation + convertdate |
| Coptic | 3,266 / 0 | Foundation + convertdate |
| Ethiopian | 3,266 / 0 | Foundation + convertdate |
| Indian (Saka) | 3,216 / 0 | Foundation + convertdate |
| Japanese | 2,744 / 0 | Foundation (era mapping, 1873–2100) |
| Chinese | **2,461 / 3** | Hong Kong Observatory (1906 cluster, known limit) |
| Hindu ×4 solar | 1,811 / 0 each | Hindu project Moshier CSVs |
| Hindu ×2 lunisolar | 55,152 / 0 each | Hindu project Moshier CSVs |
| Dangi | — | deferred |
| Simple 5 | n/a (trivial) | unit tests |

## Performance at handoff

Benchmark suite: `swift test -c release --filter "Benchmark"`. See `Docs/PERFORMANCE.md`.

| Tier | Calendars | µs/date |
|---|---|---:|
| Arithmetic / baked table | ISO, Gregorian, Julian, Buddhist, ROC, Coptic, Ethiopian, Persian, Hebrew, Indian, Japanese, Islamic ×3, Chinese (baked), Dangi (baked), Hindu solar ×4 (baked) | 2–4 |
| Moshier fallback | Chinese pre-1901 | ~437 |
| Hindu lunisolar | Amanta, Purnimanta | ~3,900 |

## Recent big work (session before handoff)

### Baked data refactor — 3 calendars done

All following **store packed year data inside `DateInner`** so field accessors are lock-free bit ops (no cache lookup during arithmetic).

1. **Chinese (1901–2099)** — 199 entries, `PackedChineseYearData` UInt32 (13-bit month lengths + 4-bit leap month + 6-bit new year offset). Source: HKO. **~586 ms → 2.2 µs/date.** File: `Sources/CalendarAstronomical/PackedChineseYear.swift`.

2. **Islamic Umm al-Qura (1300–1600 AH)** — 301 entries, `PackedHijriYearData` UInt16 (12-bit month lengths + sign + 3-bit offset). Source: KACST via ICU4C. Validated against official Saudi government dates. File: `Sources/CalendarAstronomical/IslamicUmmAlQura.swift`.

3. **Hindu solar ×4 (~1900–2050)** — 150 entries each, `PackedHinduSolarYearData` (UInt32 monthData: 2 bits × 12 months encoding 29/30/31/32; UInt16 newYearOffset from per-variant `baseNewYear: Int32`). Source: Hindu project Moshier CSVs. **1,334 µs → 2.4 µs/date (Tamil) / ~500× speedup**. File: `Sources/CalendarHindu/PackedHinduSolarYear.swift`.

### Odia gotcha (fixed)

Odia has `firstRashi = 1, yearStartRashi = 6`. **Its year starts at regional month 6** (Ashvina/September), not month 1 — the year runs chronologically 6,7,…,12,1,2,…,5. The other three Hindu solar variants have `yearStartMonth = 1`.

`yearStartMonth` is computed at compile time from variant static constants:
```swift
UInt8(((V.yearStartRashi - V.firstRashi + 12) % 12) + 1)
```
Tamil/Bengali/Malayalam → 1. Odia → 6. Not stored in packed data (saves 4 bits per entry and avoids redundancy).

### UInt16 offset optimization

Hindu solar originally stored each year's `newYear: Int32` (4 bytes). Replaced with per-variant `baseNewYear: Int32` + `newYearOffset: UInt16` (2 bytes per year). Saved **1,184 bytes** (~19% of Hindu solar data). Max observed offset: 54,423 (UInt16 max is 65,535).

## Critical gotchas — memorize these

### 1. ICU4X Julian epoch off-by-one

Our `JulianArithmetic.fixedFromJulian(622, 7, 16) = 227015`.
ICU4X's `fixed_from_julian(622, 7, 16) = 227016`.

**Ours matches Foundation/ICU4C and the official Saudi UQ calendar.** When copying ICU4X's packed tables, **offset bits need regeneration** against Foundation or our own epoch. Month-length bits are epoch-independent and copy cleanly.

### 2. Test discipline

- **Always `swift test -c release`**. Debug mode makes Moshier 50× slower → tests can hang for 160+ minutes.
- **Never run tests in a loop hoping for different results.** Read the code. An infinite loop in `fromRataDie` cost an entire session.
- **Kill stuck swift processes** before retrying: `ps aux | grep swift`, kill stragglers before a new invocation.
- **Narrow filters**: `--filter "uqRegression"` instead of `--filter "Umm"`.

### 3. Kshaya tithi in Hindu lunisolar

Round-trip tests for Amanta/Purnimanta can't assert `back == rd` — kshaya tithis cause two consecutive RDs to map to the same Hindu date. Use `back == rd || back == rd - 1` (see `HinduBenchmarks.swift`'s `allowKshaya: true`).

### 4. Foundation bridging cost

`Foundation.Calendar.dateComponents` in a 73k-iteration loop takes minutes due to Swift→ObjC→ICU bridging. For arithmetic calendars, use sparse samples (first-of-month + year boundaries, ~3k points) instead of daily coverage.

### 5. Meiji start date

ICU4C/Foundation places Meiji at **1868-09-08** (lunisolar Meiji 1/1/1). ICU4X and icu4swift use **1868-10-23** (proclamation). Both fall back to `ce` before 1873 (Meiji 6), where the Gregorian calendar was officially adopted. No practical impact.

## File layout

```
Sources/
  CalendarCore/        — CalendarProtocol, Date<C>, RataDie, Month, YearInfo
  CalendarSimple/      — ISO/Gregorian/Julian/Buddhist/ROC + arithmetic helpers
  CalendarComplex/     — Hebrew/Coptic/Ethiopian/Persian/Indian + arithmetic helpers
  CalendarJapanese/    — Japanese with JapaneseEraData (extensible era table)
  AstronomicalEngine/  — Moshier/Reingold/HybridEngine, Moment, Location
  CalendarAstronomical/
    ChineseCalendar.swift       — Chinese + Dangi via ChineseCalendar<V>
    PackedChineseYear.swift     — 199-entry baked HKO table
    IslamicTabular.swift        — Tabular + Civil + TabularEpoch
    IslamicUmmAlQura.swift      — UQ with 301-entry KACST table
  CalendarHindu/
    HinduSolar.swift             — solar variants (Tamil/Bengali/Odia/Malayalam)
    HinduLunisolar.swift         — lunisolar (Amanta/Purnimanta)
    PackedHinduSolarYear.swift   — 4×150-entry baked tables
    Ayanamsa.swift
  DateArithmetic/      — DateDuration, add/until/balance (Temporal spec)

Tests/
  {module}Tests/
  CalendarBenchmarks.swift      — per-calendar µs/date baselines
  ComplexCalendarBenchmarks.swift
  AstronomicalBenchmarks.swift
  HinduBenchmarks.swift         — allowKshaya: true for lunisolar
  JapaneseBenchmarks.swift
  FullRegressionTests.swift     — Hindu 55k lunisolar + 4×1,811 solar

Docs/
  TestCoverageAndDocs.md        — master per-calendar regression index
  PERFORMANCE.md                — benchmark baseline, library size, table overhead
  BakedDataStrategy.md          — current-state doc for baked data architecture
  NEXT.md                       — roadmap (DateFormat deferred)
  STATUS.md                     — phase-level status
  HANDOFF.md                    — this doc
  Chinese.md, Chinese_reference.md
  Islamic.md, Islamic_reference.md
  Hebrew.md, Hebrew_reference.md
  Persian.md, Persian_reference.md
  Dangi.md, CalendarJapanese.md, HinduCalendars.md
  AstronomicalEngine.md, CalendarAstronomical.md, DateArithmetic.md
```

## Deferred work

| Item | Why | Where it'd go |
|---|---|---|
| Dangi baked data | KASI data less accessible than HKO; rare boundary differences vs Chinese | Same format as Chinese, separate table |
| Hindu lunisolar baking | Complex adhika masa / kshaya tithi structure; profile first | Would need new packing scheme |
| Phase 8 DateFormat | Calendar work priority | Per `Docs/Swift_Implementation_Plan.md` |
| Chinese pre-1901 | HKO data doesn't extend back | Would need Qing-era recompute |

## User preferences (from accumulated feedback)

- **`swift test -c release` always** — debug mode is 50× slower.
- **Terse responses**, no emojis in code, no emojis in messages unless asked.
- **Don't create docs unless asked** — user may request cleanup.
- **Keep `Docs/TestCoverageAndDocs.md` in sync** when tests/docs change.
- **Read code before retrying failing tests.** Kill stuck builds first.
- **Verify before recommending.** Check that functions/files still exist (memory can be stale).
- **Phase 8 (DateFormat) is deferred** — calendar/perf work continues.

## Session continuity checklist

When resuming:

1. Read `Docs/HANDOFF.md` (this file).
2. Read `Docs/TestCoverageAndDocs.md` for regression status.
3. Read `Docs/PERFORMANCE.md` for benchmark baseline.
4. Glance at `MEMORY.md` index in the memory system.
5. Run `swift test -c release 2>&1 | tail -3` to confirm state (should show 321 tests, 1 known failure).
6. Then ask the user what to work on.

## Next obvious work (not committed to, just possibilities)

- **Dangi baked data** — biggest calendar gap. Need KASI-sourced data or recompute via Moshier.
- **Hindu lunisolar profiling + baking** — 3,900 µs/date is the slowest calendar by far.
- **Phase 8 DateFormat** — when user signals calendar work is "done enough."
- **Chinese pre-1901 / post-2099 improvements** — if needed for historical research use cases.

Otherwise the project is in excellent shape — all 23 calendars validated, performance optimized where it matters, documentation comprehensive.

# icu4swift — Project Definition

*Last updated: 2026-04-16*

## What

A pure-Swift internationalization library for calendar operations and (eventually) date formatting, covering **23 calendar systems** with correct astronomical calculations and type-safe APIs.

## Why

Apple's Foundation `Calendar` supports ~18 calendar systems but provides no formatting control below `DateFormatter` (which wraps ICU4C internally, with all its C++ baggage). There is no pure-Swift option that offers:

- Type-safe calendar operations (`Date<Hebrew>` vs `Date<Gregorian>`)
- Target-level granularity (use calendars without pulling in formatting)
- Correct astronomical calendar implementations (Chinese, Umm al-Qura, Hindu)
- Hindu calendar support beyond what ICU4C provides
- Modern semantic formatting (Temporal-style field sets, not raw patterns)
- Packed year data and baked tables for microsecond-level performance

icu4swift fills this gap by porting the best of ICU4X's architecture and ICU4C's feature surface to idiomatic Swift.

## Scope

### In Scope

| Area | Description | Status |
|------|-------------|--------|
| **Calendar systems** | 23 calendars across 5 targets | ✅ Complete |
| **Date arithmetic** | Add, difference with overflow handling (constrain/reject) | ✅ Complete |
| **Astronomical engine** | Hybrid Moshier (high-precision modern) + Reingold (wide-range historical) | ✅ Complete |
| **Baked year data** | UInt16/UInt32 packed tables for Chinese/UQ/Hindu solar | ✅ Complete |
| **Date formatting** | Semantic skeletons, raw patterns, locale-aware | ⏸ Deferred |
| **Date parsing** | Pattern-based parsing with strict/lenient modes | ⏸ Deferred |
| **Interval formatting** | "Jan 10-20, 2024" style, greatest-difference detection | ⏸ Deferred |
| **Relative formatting** | "yesterday", "in 3 days", "next Tuesday" | ⏸ Deferred |

### Out of Scope

- Time zones (use Foundation or swift-datetime)
- Time-of-day beyond what formatting needs (hour/minute/second fields)
- Number formatting (use Foundation or a separate library)
- Full locale data management (we would embed CLDR data for a core set of locales)

## Architecture

**Hub-and-spoke** calendar conversion through `RataDie` (fixed day numbers). No direct calendar-to-calendar paths — every conversion goes through RD.

**Generic `Date<C>`** parameterized over `CalendarProtocol`. Compile-time type safety for known calendars.

**Packed year data in `DateInner`** — for astronomical calendars (Chinese, Hindu solar), the packed year representation travels with the date. Field accessors and arithmetic become lock-free bit ops — no cache lookup, no lock contention.

**Baked const tables** — for date ranges that matter in practice (1900–2100 roughly), year structure is precomputed and shipped as `static let` arrays. Astronomical calculation is only a fallback outside the baked range.

**SPM multi-target package** — consumers depend on only what they need:

```
CalendarCore          ← protocols, RataDie, Date<C>, types
  ├── CalendarSimple  ← ISO, Gregorian, Julian, Buddhist, ROC
  │     ├── CalendarComplex    ← Hebrew, Persian, Coptic, Ethiopian, Indian
  │     │     └── CalendarJapanese  ← Japanese (era data)
  │     └── AstronomicalEngine     ← Moshier + Reingold hybrid
  │           ├── CalendarAstronomical  ← Chinese, Dangi, Islamic ×3 + UQ
  │           └── CalendarHindu         ← 6 Hindu calendar systems
  └── DateArithmetic  ← DateDuration, add/until/balance
```

### Module sizes (release, x86_64)

| Module | Size | Notes |
|---|---:|---|
| AstronomicalEngine | 592 KB | Moshier VSOP87 + Reingold polynomials |
| CalendarComplex | 456 KB | Hebrew/Coptic/Ethiopian/Persian/Indian |
| CalendarAstronomical | 448 KB | + ~1.4 KB baked data (Chinese + UQ) |
| CalendarHindu | 408 KB | + 3.6 KB baked data (4 solar variants) |
| CalendarCore | 340 KB | Protocols, RataDie, Date<C>, types |
| CalendarSimple | 320 KB | ISO/Gregorian/Julian/Buddhist/ROC |
| DateArithmetic | 152 KB | Temporal add/until/balance |
| CalendarJapanese | 88 KB | Japanese + era data |
| **Total library** | **2.8 MB** | |
| **Baked data overhead** | **~5 KB** | 0.16% of total |

## Sources

Algorithms ported from:
- **ICU4X** (`calendrical_calculations` crate, `icu_calendar` component) — primary architectural reference
- **ICU4C** (`source/i18n/`) — feature surface reference, especially for Umm al-Qura data
- **Reingold & Dershowitz**, *Calendrical Calculations*, 4th edition (2018) — algorithmic reference
- **Hindu calendar project** (`hindu-calendar/swift/`) — validated Moshier engine and Hindu calendar code

External reference data:
- **Hong Kong Observatory** (Chinese, 1901–2100)
- **KACST** via ICU4C (Umm al-Qura, 1300–1600 AH)
- **@hebcal/core** (Hebrew validation)
- **convertdate** Python lib (Islamic, Persian, Coptic, Indian, Ethiopian cross-validation)
- **Foundation** (`Calendar` — ICU4C wrapper, matches our epoch)

## Quality Bar

- Every calendar round-trips: `fromRataDie(toRataDie(date)) == date` for tens of thousands of dates.
- Every calendar validated against at least one independent external source (Foundation, Hebcal, convertdate, HKO, KACST, or official government data).
- Chinese at **2,458 / 2,461** vs Hong Kong Observatory — one 3-failure cluster in 1906, accepted as a known Moshier-vs-HKO physical disagreement.
- All others at **100% accuracy** across their regression ranges.
- Performance: **~2–4 µs/date** for all arithmetic and baked-table calendars. Only Hindu lunisolar (not baked) is slower (~3,900 µs/date).

See `Docs/TestCoverageAndDocs.md` for the full per-calendar index.

## Current State (2026-04-16)

- **321 tests** passing in ~28 seconds (`swift test -c release`).
- **23 calendars** implemented, validated.
- **3 baked data tables** (Chinese, Umm al-Qura, Hindu solar ×4) — ~5 KB total.
- **Phase 8 (DateFormat) deferred** — calendar work and performance optimization is the priority.

See `Docs/HANDOFF.md` for a comprehensive session-handoff summary.

## Key Documents

- `Docs/HANDOFF.md` — **start here** when resuming work
- `Docs/TestCoverageAndDocs.md` — master per-calendar regression index
- `Docs/STATUS.md` — phase-level completion status
- `Docs/NEXT.md` — prioritized roadmap
- `Docs/PERFORMANCE.md` — benchmarks, library size, baked table overhead
- `Docs/BakedDataStrategy.md` — baked data architecture and rationale

### Calendar-specific docs
- `Docs/Chinese.md` / `Docs/Chinese_reference.md`
- `Docs/Hebrew.md` / `Docs/Hebrew_reference.md`
- `Docs/Persian.md` / `Docs/Persian_reference.md`
- `Docs/Islamic.md` / `Docs/Islamic_reference.md`
- `Docs/HinduCalendars.md`
- `Docs/Dangi.md`
- `Docs/CalendarJapanese.md`

### Architecture / design
- `Docs/Swift_Calendar_Library_Architecture.md` — architectural decisions and rationale
- `Docs/Swift_Implementation_Plan.md` — full 10-phase implementation plan
- `Docs/DateArithmetic.md` — Phase 7 design: Temporal algorithms, overflow semantics
- `Docs/AstronomicalEngine.md` — Moshier + Reingold engines, precision validation
- `Docs/ICU4C_vs_ICU4X_Calendar_API_Analysis.md` — API design comparison
- `Docs/ICU4C_vs_ICU4X_DateFormat_Analysis.md` — formatting approaches comparison

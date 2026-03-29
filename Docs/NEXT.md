# icu4swift — Next Steps

*Last updated: 2026-03-29*

## Parallelization Opportunity

With Phases 1-3 and 7 complete, three independent workstreams can proceed in parallel:

```
                                  ┌─ A: CalendarJapanese (Phase 6) ─── small, independent
                                  │
Phases 1-3 + 7 (done) ───────────┼─ B: AstronomicalEngine (4a) → CalendarAstronomical (4b) → CalendarHindu (5)
                                  │
                                  └─ C: CalendarAll (Phase 8 prep) ─── AnyCalendar, umbrella re-exports
```

DateFormat (Phase 8) is the bottleneck — it depends on all calendar phases. DateArithmetic (its other dependency) is now done.

## Recommended Order

### 1. CalendarJapanese (Phase 6) — Medium complexity

**Why second:** Small scope, unblocks CalendarAll. Gregorian arithmetic with era overlay — no new math.

**Deliverables:**
- `Japanese` calendar with `JapaneseEraData` (5 modern eras: Meiji→Reiwa)
- Era boundary resolution (date → era lookup in sorted table)
- Future extensibility: `JapaneseEraData` updateable without code changes

**Source:** ICU4X `cal/japanese.rs`.

### 2. AstronomicalEngine (Phase 4a) — Large complexity

**Why third:** Blocks 11 calendars (Chinese, Dangi, Islamic variants, 6 Hindu). Existing Swift code in `hindu-calendar/swift/Sources/HinduCalendar/Ephemeris/` can be adapted.

**Deliverables:**
- `AstronomicalEngine` protocol: solar/lunar longitude, new moon, sunrise/sunset
- `MoshierEngine` — port existing Swift code, refactor for thread safety
- `ReingoldEngine` — port from ICU4X `astronomy.rs` (~2,632 lines)
- `HybridEngine` — Moshier for 1700-2150, Reingold outside
- Cross-validation: both engines must agree within tolerances for overlap period

**Source:** Hindu project `Ephemeris/`, ICU4X `calendrical_calculations/src/astronomy.rs`.

### 3. CalendarAstronomical (Phase 4b+c) — Large complexity

**Depends on:** Phase 4a.

**Deliverables:**
- Chinese calendar (`ChineseTraditional<China>`)
- Korean calendar (`ChineseTraditional<Korea>`)
- Islamic Tabular (`Hijri<TabularAlgorithm>`)
- Islamic Umm al-Qura (`Hijri<UmmAlQura>`)
- Islamic Observational (`Hijri<Observational>`)

**Source:** ICU4X `cal/east_asian_traditional/`, `cal/hijri/`.

### 4. CalendarHindu (Phase 5) — Large complexity

**Depends on:** Phase 4a.

**Deliverables:**
- Lunisolar Amanta and Purnimanta
- Solar Tamil, Bengali, Odia, Malayalam
- Adapter from existing Hindu calendar code to `CalendarProtocol`

**Source:** `hindu-calendar/swift/` adapted to use `HybridEngine`.

### 5. DateFormat (Phase 8) — Very Large complexity

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

### 6. DateParse + DateFormatInterval (Phases 9-10)

**Depends on:** Phase 8.

Can run in parallel with each other. Lower priority — formatting is more commonly needed than parsing.

## Open Questions

1. **CLDR data strategy:** Embed as generated Swift source? External files? Build-time code generation for locale subsetting?
2. **AnyCalendar design:** Manual enum (exhaustive, fast) vs protocol existential (extensible, slower)?
3. **Hindu engine integration:** Adapt in-place or copy? The existing code uses mutable class-based arrays that need refactoring for `Sendable`.
4. **Minimum locale set for v1:** en, ja, ar, he, hi, zh, ko, fa, th, de, fr, es, pt, ru covers all calendar systems. Is this enough?

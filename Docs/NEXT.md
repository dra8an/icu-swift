# icu4swift — Next Steps

*Last updated: 2026-04-06*

## Current State

All calendar phases complete. 20 of 22 calendars implemented, all at 100% accuracy. 270 tests passing in ~5 seconds (release mode).

## Recommended Order

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

### 3. DateParse + DateFormatInterval (Phases 9-10)

**Depends on:** Phase 8.

Can run in parallel with each other. Lower priority — formatting is more commonly needed than parsing.

## Open Questions

1. **CLDR data strategy:** Embed as generated Swift source? External files? Build-time code generation for locale subsetting?
2. **AnyCalendar design:** Manual enum (exhaustive, fast) vs protocol existential (extensible, slower)?
3. **Hindu engine integration:** Adapt in-place or copy? The existing code uses mutable class-based arrays that need refactoring for `Sendable`.
4. **Minimum locale set for v1:** en, ja, ar, he, hi, zh, ko, fa, th, de, fr, es, pt, ru covers all calendar systems. Is this enough?

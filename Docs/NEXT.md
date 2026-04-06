# icu4swift — Next Steps

*Last updated: 2026-04-03*

## Immediate Priority: Fix Hindu Calendar Accuracy

Phase 5 is implemented but has accuracy issues. All 6 Hindu calendars are functional (round-trips work, protocol conformance complete), but validation against the Hindu project's CSV reference data shows failures that should not exist.

### The Problem

Our refactored MoshierSunrise produces sunrise times ~2.5 minutes different from the original Hindu project's Rise.swift. This causes month boundary misalignments in Malayalam (339 failures), Tamil (6), Bengali (12), and lunisolar (191). The original Hindu project's Swift port has **0 errors** on Tamil/Odia/Malayalam.

### Option A: Use Hindu project as package dependency (recommended)

Add `hindu-calendar` as a Swift package dependency. CalendarHindu calls `Ephemeris()`, `Tithi()`, `Masa()`, `Solar()` directly — guaranteed bit-identical results, zero porting bugs.

```swift
.package(url: "https://github.com/dra8an/hindu-calendar.git", branch: "main"),
```

### Option B: Find and fix the numerical difference

Debug why our MoshierSunrise produces different sunrise times. The solar longitude matches to 0.001° but sunrise differs by 2.5 minutes. Likely in the `sscc` sine/cosine table or the iterative sunrise refinement loop. High effort, uncertain payoff.

## After Hindu Fix

### 1. DateFormat (Phase 8) — Very Large complexity

### 2. DateFormat (Phase 8) — Very Large complexity

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

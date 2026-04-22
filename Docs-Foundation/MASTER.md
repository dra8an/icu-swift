# Docs-Foundation — Master Index

*Last updated 2026-04-17.*

This directory contains all planning, design, and tracking documents for
the effort to integrate `icu4swift`'s calendar algorithms into
`swift-foundation`, replacing the C/C++ ICU4C calendar backend.

## How to use this directory

Start with **`PROJECT_PLAN.md`** for the high-level roadmap. Check
**`STATUS.md`** for where we are, and **`NEXT.md`** for what is being
worked on now. The numbered docs (`00`–`07`) are durable design
references; the four project-tracking docs update as the project
progresses.

## Project-tracking documents

Read-and-update throughout the project. Keep them current.

| File | Purpose |
|---|---|
| **`MASTER.md`** | This file — index of every document here and what it is for. |
| **`PROJECT_PLAN.md`** | High-level roadmap: the four stages of the port, phases within each, and acceptance criteria. The answer to "what are we doing and in what order". |
| **`STATUS.md`** | Current state: which docs exist, which calendars are ported, which perf baselines are captured, what is in flight vs. complete. Updated at each checkpoint. |
| **`NEXT.md`** | The **single focused next task** to pick up at session start. **Updated only at session end.** |
| **`PIPELINE.md`** | The **full pipeline** of candidate tasks. **Updated freely during a session** — strike through finished items, add new candidates at the bottom, rearrange priorities. |
| **`OPEN_ISSUES.md`** | Project-level risks and concerns: stakeholder alignment, ICU quirks, perf unknowns, scope creep. Updated when issues resolve or new ones emerge. Distinct from `07-OpenQuestions.md`, which holds stakeholder-decision items. |
| **`PITCH.md`** | The plan for pitching this project to the `swift-foundation` team in a 3–5 minute window. Four-beat structure, proof points, anti-stranding rules, pre-pitch checklist. |
| **`BENCHMARK_RESULTS.md`** | Measured benchmark results comparing icu4swift against Foundation. Clean sweep across all 22 calendars (2026-04-19 PM): icu4swift is 17–285× faster than Foundation's `Calendar` API. Apples-to-oranges caveat documented inside. |

## Design & reference documents

Written once per topic; updated only when the design changes.

| File | Purpose |
|---|---|
| **`00-Overview.md`** | Mission, destination state, scope, acceptance criteria, risk register. The "why this exists" doc. |
| **`01-FoundationCalendarSurface.md`** | How `swift-foundation`'s calendar layer works today: `_CalendarProtocol`, `_CalendarGregorian`, `_CalendarICU`, `_CalendarBridged`, `CalendarCache` dispatch, the integration seam. |
| **`02-ICUSurfaceToReplace.md`** | The 17 `ucal_*` functions `_CalendarICU` calls, the C++ classes behind them, and — crucially — **why ICU's API has the shape it does** (eager-recalculation consistency contract). What we are *not* porting. |
| **`03-CoverageAndSemanticsGap.md`** | Identifier map (28 Foundation identifiers × icu4swift backends as of 2026-04-20: all 28 covered) and capability-level gap (Foundation query API surface icu4swift still needs to grow). |
| **`04-icu4swiftGrowthPlan.md`** | **Stage 1 roadmap + the guiding design principle.** States clearly that icu4swift aligns to Foundation's API model, not ICU's ucal state machine. Lists the Foundation-shape capabilities to add (TZ adapter, stored state, sparse DateComponents, range/ordinality/dateInterval, nextDate/enumerateDates, weekend queries). Phased plan. |
| **`05-PerformanceParityGate.md`** | Benchmark design, baseline-capture protocol, per-calendar per-operation thresholds. Proposes 3-level gate (PR, port, release), per-metric thresholds, rollout procedure. Crosscuts every stage. |
| **`06-FoundationPortPlan.md`** | **Stages 2–4 roadmap.** Plumbing (Stage 2) → calendar-by-calendar port in risk order (Stage 3) → removal of `_CalendarICU` (Stage 4). Per-phase canonical flow. |
| **`07-OpenQuestions.md`** | Alignment items needing stakeholder decisions before we commit to specifics. Organised by strategic / performance / correctness / scope / process. Distinct from `OPEN_ISSUES.md` (which is the risk register). |
| **`MigrationIssues.md`** | Design clarifications on two early concerns (Foundation mutability, RataDie vs. millisecond time basis) that turned out to be non-issues. Captures reasoning so it is not lost. |
| **`SUBDAY_BOUNDARY.md`** | **Authoritative, closed decision**: how icu4swift carries sub-day time at the `Foundation.Date ↔ RataDie` boundary. Matches `_CalendarGregorian`'s pattern — a pair of adapter functions, no new named type. Lists what does NOT change in existing code (answer: nothing). Read this before touching anything sub-day-related, especially after a session reset. |
| **`FractionalRataDiePlan.md`** | **Implementation plan** for the sub-day adapter. Phased build order (A–F), ~1 working day total, with per-phase exit criteria. Start here when actually coding the adapter. Cross-references `SUBDAY_BOUNDARY.md` for the design and `Docs/RDvsJD.md` for the midnight-based-RD rationale. |
| **`ICU4C_date_caps.md`** | Reference answer to "what date caps does ICU4C impose?" — global ±5.8 M-year Julian-day ceiling, per-calendar `handleGetLimit()` overrides (most non-Gregorian calendars allow ±5 M years), the fact that Chinese has **no 1901–2099 cap** (unlike icu4swift's baked fast path), and how all of this maps onto `Foundation.Calendar.maximumRange(of:)` / `minimumRange(of:)`. Use when the port-scope conversation turns to "what bounds must we preserve?" |
| **`TIMEZONE_CONSIDERATION.md`** | How the port handles TimeZone and DST — an anticipated concern from the `swift-foundation` team. Scope boundary (TZ data out, TZ-aware adapter in), DST follow-up Q&A. |

## Relationship to icu4swift's own docs

The icu4swift project ships its own `Docs/` directory with per-calendar
specs (`Docs/Chinese.md`, `Docs/Hebrew.md`, etc.) plus its own tracking
(`Docs/STATUS.md`, `Docs/NEXT.md`, `Docs/HANDOFF.md`). Those remain the
authoritative sources for icu4swift's algorithms and test coverage.
`Docs-Foundation/` concerns only the Foundation integration effort and
does not duplicate per-calendar algorithm details.

# Foundation Calendar Port — Pipeline

*Last updated 2026-04-19. Unordered list of work items in the hopper;
**prioritize by rearranging, then pull the top item into `NEXT.md`.***

This doc is the full pipeline of candidate tasks. `NEXT.md` is the
single focused next task. `PROJECT_PLAN.md` is the permanent
stage-level roadmap. `STATUS.md` is the current state snapshot.

**Update cadence.** This doc is updated **freely during a session**
— strike through / remove completed items, add new candidates at
the bottom, rearrange as priorities shift. `NEXT.md` is only
updated at session end (to signal what to pick up next time).

## In flight

~~### 2 — Close the arithmetic-calendar perf gap~~ *(resolved differently, 2026-04-19 PM)*
**Turned out the premise was wrong.** The 1.3–1.7× "Foundation wins"
number measured `#expect`-macro overhead, not calendar math.
Standalone benchmarks show icu4swift at **5 ns** (Coptic), **22 ns**
(Persian), **95 ns** (Hebrew) per round-trip — 10–300× faster than
Foundation's public `Calendar` API at the low level.

Real story: our calendar math is dramatically faster; the
end-to-end `Calendar`-API speedup depends on how much of that
survives when we wrap icu4swift in Foundation's Calendar layer
(Stage 1 of port).

The Hebrew optimization from earlier still landed and is correct —
it removed redundant `newYear` computation that WAS a real cost,
just one that the `#expect`-overhead measurement masked.

~~### 14 — Close the "Swift tax" floor~~ *(not needed)*
The "Swift tax floor" hypothesis was wrong. Calendar-math overhead
is already near machine speed. Removing this item from the pipeline.

## Items in the pipeline

### 1 — Deliver the pitch to Apple
Use `PITCH.md` with your `swift-foundation` contacts. Either a real
conversation or an async message (forum / DM / email) in the 4-beat
shape. Leads with Chinese 7× from `BENCHMARK_RESULTS.md`.

- **Delivers:** direction validation (or redirect).
- **Effort:** hours to prepare, minutes to deliver.
- **Dependencies:** none — all inputs ready.
- **Unblocks:** every downstream code decision.
- **Risk if skipped:** building for months on an unwelcome direction.

### 2 — Close the arithmetic-calendar perf gap
Foundation currently wins 1.3–1.7× on Hebrew, Persian, Coptic,
Ethiopian, Indian, Japanese, Islamic×3. Targeted Swift optimization:
`@inlinable` on hot paths, specialization audits, per-call allocation
hunts.

- **Delivers:** "parity or better on every calendar" story for the
  pitch (or retrospectively for the port).
- **Effort:** 1–3 days. Bounded.
- **Dependencies:** none.
- **Unblocks:** stronger pitch framing; reduces the scope of the
  arithmetic-calendar phase in Stage 3.

### 3 — Write `01-FoundationCalendarSurface.md`
Distill the swift-foundation exploration-agent report (2026-04-17)
into durable form: `_CalendarProtocol`, the three existing backends,
`CalendarCache` dispatch, the integration seam.

- **Delivers:** reference doc that anchors every Stage 2/3
  discussion.
- **Effort:** half a day. Raw material already gathered.
- **Dependencies:** none.
- **Unblocks:** nothing critical; informational.

### 4 — Write `02-ICUSurfaceToReplace.md`
Distill the ICU4C exploration-agent report (2026-04-17): the 17
`ucal_*` functions Foundation calls, the C++ classes behind each,
what each semantic means for a Swift reimplementation.

- **Delivers:** reference doc; "what must icu4swift match" spec.
- **Effort:** half a day.
- **Dependencies:** none.
- **Unblocks:** nothing critical; informational.

### 5 — Write `03-CoverageAndSemanticsGap.md`
Consolidate the identifier map (Foundation × upstream ICU ×
swift-foundation-icu fork × icu4swift) plus the capability gap
table that icu4swift must close.

- **Delivers:** single reference table so nothing is missed.
- **Effort:** half a day. Raw material in `00-Overview.md` and
  the two exploration reports.
- **Dependencies:** could land before #3 and #4 — it pulls from
  both.
- **Unblocks:** `04-icu4swiftGrowthPlan.md`.

### 6 — Write `04-icu4swiftGrowthPlan.md` (Stage 1 roadmap)
Break down icu4swift's capability additions (TZ-aware adapter,
stored `firstWeekday`/`minDaysInFirstWeek`, `DateComponents` sparse
round-trip, `range`/`ordinality`/`dateInterval`, `nextDate`,
`enumerateDates`) into phases with acceptance criteria.

- **Delivers:** the plan that unlocks Stage 1 code.
- **Effort:** 1 day. Needs thought about ordering + dependencies
  between capabilities.
- **Dependencies:** helpful to have #5 first.
- **Unblocks:** Stage 1 code work.

### 7 — Write `06-FoundationPortPlan.md` (Stages 2–4 detail)
Per-calendar port order, risk analysis, per-phase acceptance
criteria beyond the parity gate, rollback policy specifics.

- **Delivers:** the plan for Stages 2–4.
- **Effort:** 1 day.
- **Dependencies:** helpful to have #5 and #6 first.
- **Unblocks:** Stage 2/3 code work.

### 8 — Write `07-OpenQuestions.md`
Collect alignment items needing stakeholder (Apple) decisions
before Stage 1 code begins. Different from `OPEN_ISSUES.md`, which
holds project risks; this one holds decisions.

- **Delivers:** a checklist to run past `swift-foundation`
  maintainers once engagement opens.
- **Effort:** half a day.
- **Dependencies:** helpful to have #3 + #4 first so we know what
  decisions we need.
- **Unblocks:** maintainer conversations.

### 9 — Begin Stage 1 code in icu4swift (smallest first)
Pick the smallest growth item — likely stored `firstWeekday` +
`minimumDaysInFirstWeek` on each calendar — and do it end-to-end:
state, tests, measurement, docs.

- **Delivers:** proof that the growth plan is actionable.
- **Effort:** 1–2 weeks depending on item.
- **Dependencies:** helpful to have #6 first but not strictly
  required for the simplest item.
- **Unblocks:** Stage 1 momentum.

### 10 — Implement the Stage 0 benchmark harness in swift-foundation
Build the actual harness described in `05-PerformanceParityGate.md`:
- canonical baseline JSON format,
- `--record` and `--compare` modes for `Benchmarks/`,
- per-identifier × per-operation coverage,
- build flag to force the ICU path for baseline capture,
- CI wiring.

- **Delivers:** the gate code that enforces `05-PerformanceParityGate.md`.
- **Effort:** 1–2 weeks. Substantial infrastructure work.
- **Dependencies:** `05-PerformanceParityGate.md` (done).
- **Unblocks:** every Stage 3 calendar port.

### 11 — Hindu lunisolar baking in icu4swift
Pull the shelved proposal from `icu4swift/Docs/BakedDataStrategy.md`
§ "Hindu lunisolar baking proposal" and implement it. ~8 KB per
calendar; brings Amanta/Purnimanta from ~3,500 µs/date to 2–3 µs.

- **Delivers:** 22 of 22 calendars sub-3 µs. Closes the pitch
  footnote.
- **Effort:** 1 week including regression validation.
- **Dependencies:** none (pure icu4swift work).
- **Unblocks:** stronger "sub-3 µs across the board" narrative.

### 12 — Investigate Chinese 1850-vs-2200 asymmetry
357 µs/date for 30-day pre-1901 spans vs 11 µs/date for 30-day
post-2099 spans. Cache should behave equally. Something is not
caching at 1850.

- **Delivers:** either a fix (faster pre-1901) or an explanation
  (documented behavior).
- **Effort:** hours to a day.
- **Dependencies:** none.
- **Unblocks:** small pitch-narrative improvement; may widen the
  perf moat on the one scenario where Foundation currently wins.

### 15 — Build generic `YearCache<Data>` as shared infrastructure *(deferred from option B)*
Not useful for current arithmetic calendars (their per-call compute
is already ~nanoseconds, cache overhead would exceed the win). Useful
for future work:
- Refactor Chinese's bespoke `ChineseYearCache` to use this pattern.
- Prep for observational Islamic (when added) — year compute is
  genuinely expensive.
- Prep for Hindu lunisolar baking (in pipeline).

Single generic `YearCache<Data>` with `os_unfair_lock` + LRU. Lives
in `CalendarCore` or a shared utilities target.

- **Delivers:** reusable infrastructure for calendars with
  expensive year-level metadata.
- **Effort:** half a day.
- **Dependencies:** none.
- **Unblocks:** cleaner Chinese code; new astronomical calendars.

~~### 16 — Re-run all perf tests with clean methodology~~ *(done 2026-04-19 PM)*
All five benchmark files refactored to no-`#expect` pattern (100k
iterations, warm-up excluded, checksum, single `#expect` after).
Clean sweep captured in `BENCHMARK_RESULTS.md`. Headline: icu4swift
is 17–285× faster than Foundation's `Calendar` API on every
measurable identifier. Chinese is the biggest win at ~285×.

~~### 17 — Direct ICU4C benchmark for apples-to-apples comparison~~ *(done 2026-04-20)*
C benchmark written (`Scripts/ICU4CCalBench.c`), compiled against
Homebrew's ICU4C v78, run for 14 calendars. Three-way table now in
`BENCHMARK_RESULTS.md`. Headline: **icu4swift beats raw ICU4C math
by 10–40× on arithmetic calendars, ~1,000× on Chinese.** Foundation
adds ~800 ns wrapper cost on top of ICU4C. Apples-to-oranges caveat
substantially resolved.

Anomaly to investigate later (low priority): ICU4C Chinese measured
slower than Foundation's Chinese (~41 µs vs ~12 µs) — likely an
ICU-version or Apple-specific-optimization difference. icu4swift
wins both at 42 ns regardless.

### 18 — Extreme-range regression testing for arithmetic calendars
Today's Hebrew regression runs 73,414 days (1900–2100) against
Hebcal with zero divergences. Since Hebrew (and the other arithmetic
calendars) are pure integer math, in principle they should be
correct for any year in the `Int32` / `Int64` range. Worth validating
that claim explicitly, even if only as a one-off confidence test.

**Compute cost estimate (Hebrew, ±10,000 years → ~7.3 M days):**
at the measured 96 ns/round-trip: **~0.7 seconds** of raw
computation. Including Hebcal-row comparison overhead: **~7 seconds**
standalone, **~30 seconds** inside Swift Testing. Compute is
trivial; the real question is the reference source.

**Three sub-options, increasing value-per-effort:**

**(a) Round-trip stability** (fastest, no external deps)
For every RD in the range, assert `toRataDie(fromRataDie(rd)) == rd`.
Doesn't catch shift-by-constant errors but catches any internal
inconsistency in the implementation. Over ±10,000 years: ~1.4 s for
Hebrew, similar for other arithmetic calendars. Zero storage, zero
external dependencies. **Recommended as the first thing to land.**

**(b) Reingold & Dershowitz reference port as oracle** (moderate effort)
R&D's Lisp/Python reference implementations in *Calendrical
Calculations* are the canonical source for all these algorithms.
Port one file (e.g. Python `hebrew.py`) into a test fixture, use
it as the oracle over any year range. Catches shift-by-constant
errors too. One-time port effort; then validates any arithmetic
calendar indefinitely without needing Hebcal or similar.

**(c) Full Hebcal extension** (most comprehensive, diminishing returns)
Extract a ±10,000 year CSV from Hebcal (~7.3M rows, ~220 MB). Run
the existing regression shape against it. Validates against the
same external reference the 1900–2100 test uses today. Storage
and generation cost non-trivial; value over (b) minimal for
arithmetic calendars.

**Applies to:** Hebrew, Coptic, Ethiopian, Persian, Indian,
Islamic Civil, Islamic Tabular (the pure-arithmetic calendars).
Not applicable to baked-data (range-bounded) or astronomical
calendars.

- **Delivers:** demonstrable correctness guarantee over any year
  range a user could plausibly query. Useful for the pitch
  ("we're correct outside the historical range too") and for
  long-horizon planning calendars (religious year tables, etc.).
- **Effort:** (a) an hour, (b) 1–2 days per ported R&D file, (c)
  a few hours but with large-data storage cost.
- **Dependencies:** none for (a); R&D reference for (b); Hebcal
  tooling for (c).
- **Unblocks:** confidence in arithmetic calendar correctness
  beyond the 1900–2100 window. Modest but real.

My recommendation: **do (a) soon as a one-off validation; (b) only
if we want a reusable oracle for future arithmetic calendars; skip
(c).**

### 13 — Extend `FoundationCalBench.swift` to macOS 26.0+ identifiers
Wrap `dangi`, `bangla`, `tamil`, `malayalam`, `odia` in
`@available(macOS 26, *)` and add them to the benchmark matrix.
Once macOS 26 is available, get head-to-head numbers on the
newly-shipped Hindu solar and Dangi identifiers.

- **Delivers:** complete comparison data set.
- **Effort:** couple of hours; may be blocked on macOS 26 availability.
- **Dependencies:** macOS 26 toolchain.
- **Unblocks:** more complete pitch numbers.

## Prioritization notes

A few natural constraints worth keeping in mind when rearranging:

- **Item 1 (pitch)** is exogenous timing-dependent; whenever your
  Apple contact is available.
- **Items 3–8** (reference docs) have internal dependencies
  (5 → 6 → 7, 3 & 4 before 5).
- **Items 9 and 10** (code work) should be preceded by item 6.
- **Items 11, 12, 13, 15, 17, 18** are independent of the rest; fill
  time between blocked items.
- **Item 17** removes the apples-to-oranges concern in the perf
  comparison — good to land before the pitch conversation happens.
- **Item 18(a)** (round-trip stability) is an hour of work and
  gives us a nice "correct over ±10,000 years" talking point.

## Process

1. Rearrange this list top-to-bottom in priority order at any time.
2. **During a session**: work through items from the top. As each
   finishes, strike through or remove here. Add new candidates at
   the bottom as they surface.
3. **At session end**: write the single top item (or the item
   best-suited for the next session) into `NEXT.md` with enough
   detail to resume cold.
4. **At session start**: read `NEXT.md`, confirm still relevant,
   pull it off and into this PIPELINE's in-flight slot, and go.

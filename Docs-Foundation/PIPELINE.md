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

~~### 3–8 — Write reference docs `01`–`07`~~ *(briefs done 2026-04-20)*
All six numbered reference docs now exist as briefs:
`01-FoundationCalendarSurface.md`, `02-ICUSurfaceToReplace.md`,
`03-CoverageAndSemanticsGap.md`, `04-icu4swiftGrowthPlan.md`,
`06-FoundationPortPlan.md`, `07-OpenQuestions.md`. The guiding
Stage 1 design principle (icu4swift aligns to Foundation's API
model, not ICU's ucal state machine) is captured prominently in
`04`. Each brief is sufficient to orient a reader and can be
expanded as needed.

### 9 — Begin Stage 1 code in icu4swift (smallest first)
Pick the smallest growth item — likely stored `firstWeekday` +
`minimumDaysInFirstWeek` on each calendar — and do it end-to-end:
state, tests, measurement, docs.

- **Delivers:** proof that the growth plan is actionable.
- **Effort:** 1–2 weeks depending on item.
- **Dependencies:** helpful to have #6 first but not strictly
  required for the simplest item.
- **Unblocks:** Stage 1 momentum.

### 9a — Build the sub-day Foundation adapter (fractional RataDie)
Pair of free functions between `Foundation.Date` and
`(RataDie, secondsInDay, nanosecond)` — matches `_CalendarGregorian`'s
pattern. Full plan + phased build order in
`FractionalRataDiePlan.md`. Six phases (A–F) totaling ~1 working day.
No existing code changes; no calendar backends involved; independently
testable. Benchable vs. Foundation directly — clean first data point
for the "we match `_CalendarGregorian`'s shape but skip the noon-nudge"
claim.

- **Delivers:** working `Foundation.Date ↔ (RD, h, m, s, ns)` adapter
  + benchmark vs. Foundation's path. First visible Stage 1 result.
- **Effort:** ~1 working day.
- **Dependencies:** design decisions are locked in `SUBDAY_BOUNDARY.md`
  and `Docs/RDvsJD.md`. Ready to build.
- **Unblocks:** every downstream Stage 1 primitive (`DateComponents`
  decomposition, `Date<C>` convenience inits, `_CalendarProtocol`
  conformance in Stage 2).

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

### 19 — Measure divergence of `IslamicAstronomical` vs Foundation's `.islamic`
icu4swift's `IslamicAstronomical` ships as a delegating alias for
`IslamicUmmAlQura` (see `Docs/ISLAMIC_ASTRONOMICAL.md` for the full
design rationale). ICU4X made the same choice (their
`AstronomicalSimulation` is deprecated in favor of UmmAlQura).
ICU4C, which Foundation still uses, continues to use the Reingold
observational algorithm. The two approaches agree within the
UmmAlQura baked range (1300–1600 AH / ~1882–2174 CE) but can
diverge outside it.

Scope:
- Daily conversion comparison for 1900–2100 CE (the common-usage
  case) between our `IslamicAstronomical` and Foundation's
  `Calendar(identifier: .islamic)`. Expected divergence: near zero.
- Extend comparison to pre-1882 and post-2174 to quantify the
  fallback-range gap. Expected divergence: non-zero, up to ±1–2 days
  at month boundaries.
- Decision tree based on results:
  - Zero divergence → keep alias. Close this item.
  - Small divergence inside baked range → investigate (KACST
    source mismatch?).
  - Large divergence outside baked range → decide whether to port
    the Reingold observational algorithm from
    `calendrical_calculations/src/islamic.rs`.

- **Delivers:** confidence that our `.islamic` output matches
  Foundation in the usage ranges that matter. Clears one of the
  three "missing identifiers" from OPEN_ISSUES Issue 6.
- **Effort:** half a day for the comparison test and analysis;
  optionally 1–2 more days if porting Reingold is needed.
- **Dependencies:** none.
- **Unblocks:** identifier-coverage story in the pitch, Stage 3.

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
- **Items 11, 12, 13, 15, 18, 19** are independent of the rest; fill
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

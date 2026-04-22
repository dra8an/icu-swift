# icu4swift — Session Handoff

*Written 2026-04-20. Updated 2026-04-22 with CalendarFoundation adapter
landing. Consult this first when resuming work on this project.*

## Most recent work (2026-04-22)

**Sub-day Foundation adapter landed — all six phases A–F** of
`Docs-Foundation/FractionalRataDiePlan.md`. New `CalendarFoundation`
module provides `rataDieAndTimeOfDay(from:in:)` and
`date(rataDie:hour:minute:second:nanosecond:in:repeatedTimePolicy:skippedTimePolicy:)`
— pair of free functions matching `_CalendarGregorian`'s pattern, with
public DST-policy enums. 51 tests (45 correctness + 6 benchmarks). Full
suite: 383/384 pass (the 1 failure is the pre-existing Chinese 1906
cluster). Phase F perf results in `BENCHMARK_RESULTS.md § Sub-day adapter`:
extraction **1.95× faster than Foundation**, round-trip **1.11× faster**,
assembly 1.27× slower (cost of 2 `secondsFromGMT` probes for DST policy
correctness — accepted).

Authoritative reference: `Docs-Foundation/SUBDAY_BOUNDARY.md`
**§ Implementation**. That doc has full API signatures, DST algorithm,
precision profile, and test inventory.

**Extreme-range round-trip test + Hebrew fixes (2026-04-22).**
Added `Tests/ExtremeRangeTests/` with a sweep verifying every
pure-arithmetic calendar survives `RataDie(±10_000_000_000)` round-trip
(~±27 M years, ~27× past `validRange`). All 16 pure-arithmetic calendars
pass. Astronomical calendars (Chinese / Dangi / Vietnamese / Hindu)
excluded — Moshier's ~±3 k-year precision envelope makes them
unanswerable at that scale.

Exercise surfaced two Hebrew bugs at extreme RDs, both fixed in
`Sources/CalendarComplex/HebrewArithmetic.swift`:

1. Truncating `/` in the year approximation inside `hebrewFromFixed`
   skewed one year high at extreme negatives, producing a negative
   day-of-year remainder and trapping a later `UInt8` init. Replaced
   with a `floorDiv` helper.
2. `calendarElapsedDays` returned `Int32`; the `days` intermediate
   scales as ~365 × year and overflowed at year ≈ ±5.88 M. Widened
   return type to `Int64`; callers already widened so no public API
   change.

Hebrew regression (73,414 days vs Hebcal, 1900–2100): still 0 divergences.
Public `HebrewDateInner.year` remains `Int32` — not a breaking change.

## What is this project

**icu4swift** is a Swift package — a library for world calendar
systems. It ports ICU4X/ICU4C calendar algorithms to pure Swift.
No Foundation dependency, no external deps, Swift 6 with strict
concurrency.

**Output:** a library (no executable). Consumers import modules like
`CalendarCore`, `CalendarSimple`, `CalendarComplex`, `CalendarAstronomical`,
`CalendarHindu`, `CalendarJapaneseSupport`, `DateArithmetic`.

**Active narrative since 2026-04-17:** icu4swift is the staging
ground for a **Foundation port**. The endgame is to replace
`swift-foundation`'s ICU4C-backed calendar path with pure-Swift
implementations derived from icu4swift. When the port completes,
`_CalendarICU` is deleted and icu4swift is archived. See
**`Docs-Foundation/`** (not `Docs/`) for everything about that
effort.

## Current state — one-page snapshot

### Library (icu4swift package)

- **28 calendars implemented** (up from 23 on 2026-04-16). New
  this week: `IslamicAstronomical` (delegating alias over
  `IslamicUmmAlQura`), `EthiopianAmeteAlem`, `Vietnamese`
  (= `ChineseCalendar<Vietnam>` at UTC+7). Covers all 28
  `Foundation.Calendar.Identifier` cases.
- **338 tests**, full suite runs in ~28 s. One standing failure
  (Chinese 1906 cluster, 3/2,461 — documented ICU-vs-HKO
  physical disagreement).

### Performance — post-clean-methodology

**Critical update 2026-04-19:** our benchmark harness was leaking
`#expect` macro overhead (~1.5 µs per call) into every reported
number, making all pre-2026-04-19 perf figures inflated by
~1.5 µs. After refactoring the harness across all 5 bench files
to use a `(warmup, 100k iters, checksum, one #expect after)`
pattern, the real numbers emerged.

**Actual icu4swift per-round-trip performance (release mode):**

| Tier | Calendars | ns/date |
|---|---|---:|
| Simple (ISO/Gregorian/Julian/Buddhist/ROC) | 16–19 |
| Arithmetic (Coptic/Ethiopian/Persian/Japanese/Indian/Hebrew) | 9–96 |
| Islamic ×3 (Civil/Tabular/UQ) | 20–43 |
| Chinese/Dangi (baked) | 38–42 |
| Hindu solar ×4 (baked) | 109–200 |
| Hindu lunisolar (Moshier, not baked) | ~3.3 ms |
| Chinese Moshier fallback (1000d span) | 3–26 µs (cache-amortised) |

Hebrew was specifically optimised 2026-04-19 (2.9 µs → 96 ns)
via `YearData` struct + integer arithmetic + `@inlinable`.
Persian and Coptic also got small wins via `@inlinable` + binary
search (Persian).

### Three-way perf comparison vs Foundation / ICU4C

Measured 2026-04-20 via `Scripts/ICU4CCalBench.c` against Homebrew
ICU4C v78:

- **icu4swift beats raw ICU4C's C API by 10–40× on arithmetic
  calendars and ~1,000× on Chinese.** Foundation's public
  `Calendar` API adds another ~800 ns wrapper overhead per
  iteration on top of that.
- This is NOT a micro-optimisation trick — it's a consequence of
  API shape. ICU's `ucal_set`/`add`/`roll` contract forces
  full field recalculation on every read; Foundation's public
  API doesn't expose that contract; we therefore don't pay for
  it. See `Docs-Foundation/04-icu4swiftGrowthPlan.md` § "The
  guiding design principle" for the full argument.

### Identifier coverage (for Foundation port)

All 28 `Foundation.Calendar.Identifier` cases have Swift-native
backends in icu4swift:

- Gregorian, ISO8601, Buddhist, ROC, Japanese — `CalendarSimple` + `CalendarJapanese`
- Persian, Coptic, Ethiopian (both variants), Indian, Hebrew — `CalendarComplex`
- Islamic Civil, Tabular, UmmAlQura, Astronomical — `CalendarAstronomical`
- Chinese, Dangi, Vietnamese — `CalendarAstronomical` (all are `ChineseCalendar<Variant>`)
- Tamil, Bengali, Odia, Malayalam (solar) — `CalendarHindu`
- Amanta, Purnimanta (lunisolar) — `CalendarHindu`
- `.gujarati/.kannada/.marathi/.telugu/.vikram`: mapping TBD
  (likely aliases of Amanta/Purnimanta with regional display
  labels). Tracked in `OPEN_ISSUES.md` Issue 6 and `07-OpenQuestions.md`.

## The Foundation port effort — what happened in this session

The big thread 2026-04-17 through 2026-04-20. **Read
`Docs-Foundation/MASTER.md` first** — it's the doc index. Then
`STATUS.md` (current state), `NEXT.md` (one next task),
`PIPELINE.md` (backlog), `OPEN_ISSUES.md` (risks), and
`00-Overview.md` (mission).

### ⚠ Before touching anything sub-day-related, READ THIS

**`Docs-Foundation/SUBDAY_BOUNDARY.md` is the authoritative decision record for how icu4swift handles sub-day time at the Foundation boundary.** Two sessions in a row confused this. The decision is: **match `_CalendarGregorian`'s pattern — pair of adapter functions on `Foundation.Date`, no new named type**. `CivilInstant` was proposed and **rejected**. If a resumed session starts reaching for an Int64-nanoseconds-in-day struct, stop and re-read `SUBDAY_BOUNDARY.md` first.

**`Docs/RDvsJD.md`** is the closed decision record for "why RataDie and not Julian Day?" — read it if anyone asks why we don't use JD as the universal pivot. Short answer: R&D and ICU4X both use RD, civil days are midnight-based (matching RD), JD is for astronomy only, and the RD↔JD bridge already exists in `Moment.jdOffset`.

**`Docs-Foundation/FractionalRataDiePlan.md`** is the actionable implementation plan for the sub-day adapter. Phased (A–F), ~1 working day total. Start there when it's time to actually write the code.

### Key architectural decisions locked in this session

These are load-bearing and should not be re-litigated without a
concrete reason:

1. **icu4swift aligns to Foundation's Date/Calendar API model, not
   ICU's ucal state machine.** Foundation exposes high-level
   queries (`range`, `ordinality`, `dateInterval`, `nextDate`,
   `enumerateDates`, weekend queries) on immutable value-type
   dates. It does NOT expose `ucal_set(field,value)` / `add` /
   `roll` with eager cross-field recalculation. We don't port
   that contract. **Canonical home: `04-icu4swiftGrowthPlan.md`
   § "The guiding design principle".** Cross-referenced from
   `00-Overview.md` § Scope, `02-ICUSurfaceToReplace.md`,
   `03-CoverageAndSemanticsGap.md`, `BENCHMARK_RESULTS.md`,
   `PITCH.md` Beat 3.

2. **Stage 1 surface is 10 primitives + state + adapter, NOT
   ~41 public methods.** Foundation's public `Calendar` API has
   ~41 methods + `RecurrenceRule`, but only ~10 are protocol
   primitives on `_CalendarProtocol`. Everything else is
   implemented generically in `swift-foundation` above the
   protocol and comes along for free. This meaningfully
   reduces the scope of Stage 1 work. Tiered breakdown in
   `04-icu4swiftGrowthPlan.md` § "What needs to be added in
   Stage 1" and `03-CoverageAndSemanticsGap.md` § "Capability
   gap".

3. **Sub-day precision: match `_CalendarGregorian`'s pattern
   exactly.** The adapter splits `Date` into `(Int rataDie,
   Double fractionalDay)` — identical shape to
   `_CalendarGregorian`'s `julianDate: Double` +
   `julianDay() -> Int` in `swift-foundation`. No new named
   type. An earlier proposal for a custom `CivilInstant`
   (Int64 rataDie + Int64 nsInDay) was reconsidered because
   (a) Foundation's Double pattern doesn't actually accumulate
   drift (each op re-converts from Date), and (b) matching
   Foundation's existing shape lowers review friction. The
   decision history is preserved in `MigrationIssues.md` § 2
   and `04-icu4swiftGrowthPlan.md` Tier 3 under "Why we're
   matching Foundation's pattern rather than inventing our own."

4. **TimeZone scope: we do not port TZ internals.** Foundation's
   existing `TimeZone` (TZif parsing, historical transitions)
   is consumed unchanged. The port only touches
   `(Date, TimeZone) → (Int rataDie, Double fractionalDay)` at
   the adapter boundary. Captured in `TIMEZONE_CONSIDERATION.md`.

5. **Benchmark discipline: never `#expect` inside timed loops.**
   Swift Testing's `#expect` macro costs ~1.5 µs/call even on
   the success path. For microbenchmarks this dominates every
   measurement. Rule documented in `CLAUDE.md` (with scope: perf
   benchmarks only — normal correctness tests are fine), in
   feedback memory, and in `Docs-Foundation/05-PerformanceParityGate.md`.

### Docs-Foundation/ file inventory (created this session)

Tracking:
- `MASTER.md` — doc index
- `STATUS.md` — snapshot (updated frequently)
- `NEXT.md` — single next task (updated only at session end)
- `PIPELINE.md` — backlog (updated freely during session)
- `OPEN_ISSUES.md` — project risk register
- `PITCH.md` — 3–5 min pitch plan for swift-foundation maintainers
- `BENCHMARK_RESULTS.md` — all perf measurements, three-way table

Design & reference:
- `00-Overview.md` — mission, destination, scope, acceptance
- `01-FoundationCalendarSurface.md` — `_CalendarProtocol`, dispatch
- `02-ICUSurfaceToReplace.md` — 17 `ucal_*` functions + why
- `03-CoverageAndSemanticsGap.md` — identifier + capability gap
- `04-icu4swiftGrowthPlan.md` — Stage 1 plan + guiding principle
- `05-PerformanceParityGate.md` — per-PR/per-port/per-release gate spec
- `06-FoundationPortPlan.md` — Stages 2–4 rollout
- `07-OpenQuestions.md` — stakeholder decision items
- `MigrationIssues.md` — mutability + precision clarifications
- `TIMEZONE_CONSIDERATION.md` — TZ scope
- `PROJECT_PLAN.md` — overall stage roadmap

### icu4swift source changes this session

- `Sources/CalendarComplex/HebrewArithmetic.swift` — major refactor: `YearData` struct, integer arithmetic, `@inlinable`. Hebrew 2.9 µs → 96 ns.
- `Sources/CalendarComplex/Persian.swift` — binary search on `nonLeapCorrection`, `@inlinable`. Small improvement.
- `Sources/CalendarComplex/CopticArithmetic.swift` — integer arithmetic, single-year compute, `@inlinable`.
- `Sources/CalendarComplex/Coptic.swift` — `@inlinable`.
- `Sources/CalendarComplex/Ethiopian.swift` — `EthiopianDateInner` promoted `@usableFromInline`.
- **`Sources/CalendarComplex/EthiopianAmeteAlem.swift` (new)** — sibling struct, `mundi` era, `calendarIdentifier = "ethiopic-amete-alem"`.
- `Sources/CalendarAstronomical/ChineseCalendar.swift` — added `Vietnam: EastAsianVariant` (UTC+7) and `typealias Vietnamese = ChineseCalendar<Vietnam>`.
- **`Sources/CalendarAstronomical/IslamicAstronomical.swift` (new)** — delegating wrapper over `IslamicUmmAlQura`. `calendarIdentifier = "islamic"`.
- `Sources/CalendarCore/Date.swift` — `@inlinable` on hot-path methods (`fromRataDie`, `init`, `rataDie`).
- All 5 bench files refactored to no-`#expect` pattern:
  `CalendarBenchmarks.swift`, `ComplexCalendarBenchmarks.swift`,
  `JapaneseBenchmarks.swift`, `AstronomicalBenchmarks.swift`,
  `HinduBenchmarks.swift`.
- New regression tests: `EthiopianAmeteAlemTests.swift` (8 tests, all passing) and `VietnameseTests.swift` (6 tests, all passing).

### New scripts (for three-way perf comparison)

- `Scripts/FoundationCalBench.swift` — standalone Swift benchmark against Foundation's public `Calendar` API.
- `Scripts/FoundationChineseBench.swift` — Chinese-specific variant with tunable range.
- `Scripts/ICU4CCalBench.c` — standalone C benchmark against ICU4C's `ucal_*` API directly. Compile with Homebrew ICU:
  ```
  cc -O2 -o /tmp/icubench Scripts/ICU4CCalBench.c \
     -I/usr/local/opt/icu4c@78/include \
     -L/usr/local/opt/icu4c@78/lib \
     -Wl,-rpath,/usr/local/opt/icu4c@78/lib \
     -licui18n -licuuc
  ```
- `Scripts/ICU4CMinimalBench.c` — diagnostic: `ucal_setMillis`-only, confirms setMillis is ~6 ns (the expense lives in get/set/clear).

### New docs in `Docs/` (not `Docs-Foundation/`)

- `Docs/ISLAMIC_ASTRONOMICAL.md` — design note for
  `IslamicAstronomical` alias decision. Explains ICU4X deprecation
  of `AstronomicalSimulation` in favour of UmmAlQura; we followed
  that direction.
- `Docs/TestCoverageAndDocs.md` — updated with three new rows
  (Islamic astronomical, Ethiopian Amete Alem, Vietnamese).
- `Docs/HANDOFF.md` — this file.

Also: most other `Docs/` files (HANDOFF, NEXT, STATUS, PERFORMANCE, PROJECT, BakedDataStrategy, HinduCalendars) got ⚠ notes flagging that their old µs-scale numbers were `#expect`-inflated and pointing at `Docs-Foundation/BENCHMARK_RESULTS.md` for the clean numbers.

## Session-continuity checklist

When resuming after context reset:

1. Read `Docs/HANDOFF.md` (this file).
2. Read `Docs-Foundation/MASTER.md` — doc index for the port work.
3. Read `Docs-Foundation/STATUS.md` — current state.
4. Read `Docs-Foundation/NEXT.md` — one focused next task.
5. Read `Docs-Foundation/PIPELINE.md` — backlog.
6. If confused about why something was decided a certain way,
   check `Docs-Foundation/OPEN_ISSUES.md` and
   `Docs-Foundation/MigrationIssues.md`.
7. Pitch-delivery thread is `Docs-Foundation/PITCH.md`; read it
   if user signals they're about to pitch.

## Gotchas / things easy to forget

- **Always `swift test -c release`.** Debug Moshier is 50× slower.
- **Never `#expect` inside a timed loop** in perf tests
  (correctness tests are fine). Documented in `CLAUDE.md`.
- **Kill stuck swift processes** before retrying: `ps aux | grep swift`.
- **`swift-foundation-icu` has a private `hinducal.{cpp,h}` fork** that isn't in upstream ICU4C — Apple-added to support the Hindu identifiers. We don't need to match its internals; we have our own Moshier-based Hindu math.
- **ICU4X deprecated observational Islamic in favour of UmmAlQura.** We follow that lead. `IslamicAstronomical` is a delegating alias; divergence testing against Foundation's own `.islamic` is deferred (PIPELINE item 19).
- **Our Julian epoch = 227015**, ICU4X's = 227016. Ours matches Foundation/ICU4C.
- **Test build quirk:** `swift test -c release --filter X` can fail with "module 'CalendarSimple' was not compiled for testing" if a previous non-filtered build is stale. Fix: `rm -rf .build && swift test -c release --filter X`. Pre-existing issue; not from any of our changes.
- **Hindu lunisolar (Amanta, Purnimanta) is the one slow tier** at ~3.3 ms/date. Documented in `icu4swift/Docs/BakedDataStrategy.md` with a deferred baking proposal (PIPELINE item 11).
- **Chinese 1906 cluster:** 3 failures in the regression test, pre-existing, documented in `Docs/Chinese_reference.md`. Not something to "fix" — it's an ICU-vs-HKO physical disagreement.

## Current pipeline highlights

Top items in `Docs-Foundation/PIPELINE.md` that are independent
(can be done whenever):

- **Item 1** — deliver the pitch (all prep material is ready)
- **Item 9** — start Stage 1 code in icu4swift (needs `04-icu4swiftGrowthPlan.md` review first)
- **Item 10** — implement Stage 0 benchmark harness in swift-foundation
- **Item 11** — Hindu lunisolar baking (~8 KB per calendar, ~1000× speedup)
- **Item 18(a)** — ±10,000-year round-trip stability test (1 hour; cheap talking point)
- **Item 19** — Islamic astronomical divergence test vs Foundation's `.islamic`

`NEXT.md` at time of handoff points at Pipeline item 17 — but
that item already landed this session. The next session should
re-read `NEXT.md` and likely update it, or pick freely from
Pipeline.

## Where the session ended

Last user interaction: approved reverting the `CivilInstant`
decision in favour of matching `_CalendarGregorian`'s Double
`julianDate` pattern. All three affected docs updated; source
file deleted; build clean. Context was saturated; user asked for
handoff + reset.

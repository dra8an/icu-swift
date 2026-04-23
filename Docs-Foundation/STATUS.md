# Foundation Calendar Port — Status

*Last updated 2026-04-20. Update this file at every checkpoint.*

One-page snapshot of where the project stands. For the roadmap see
`PROJECT_PLAN.md`; for immediate next steps see `NEXT.md`.

## Stage status

| Stage | Title | Status |
|---|---|---|
| 0 | Performance parity gate (crosscuts) | not started |
| 1 | Extend icu4swift | **in progress — sub-day adapter landed 2026-04-22** |
| 2 | Plumbing in swift-foundation | not started |
| 3 | Port calendars in risk order | not started |
| 4 | Removal | not started |

**Current phase of active work:** Stage 1. Sub-day Foundation adapter
(`CalendarFoundation` module) complete through Phase E of
`FractionalRataDiePlan.md`. 45 new tests passing. See
`SUBDAY_BOUNDARY.md § Implementation` for the API + test inventory.

## Documentation

Durable design + reference docs:

| File | Status |
|---|---|
| `MASTER.md` | written |
| `PROJECT_PLAN.md` | written |
| `STATUS.md` | written (this file) |
| `NEXT.md` | written (single-task focus) |
| `PIPELINE.md` | written |
| `OPEN_ISSUES.md` | written |
| `PITCH.md` | written |
| `TIMEZONE_CONSIDERATION.md` | written |
| `BENCHMARK_RESULTS.md` | written (Chinese only) |
| `00-Overview.md` | written |
| `MigrationIssues.md` | written |
| `01-FoundationCalendarSurface.md` | written (brief) |
| `02-ICUSurfaceToReplace.md` | written (brief) |
| `03-CoverageAndSemanticsGap.md` | written (brief) |
| `04-icu4swiftGrowthPlan.md` | written (brief, includes the Stage 1 design principle) |
| `05-PerformanceParityGate.md` | written |
| `06-FoundationPortPlan.md` | written (brief) |
| `07-OpenQuestions.md` | written (brief) |

## Calendar port tracker

One row per `Calendar.Identifier` case. A calendar becomes "ported"
only after it passes both the functional regression and the Stage 0
performance parity gate, and the router entry in `CalendarCache` has
flipped from ICU to Swift.

| Identifier | icu4swift backend exists | Foundation semantics covered | Perf baseline captured | Ported |
|---|:-:|:-:|:-:|:-:|
| gregorian | ✓ (via swift-foundation's `_CalendarGregorian`) | ✓ (already pure-Swift in Foundation) | — | already pure-Swift |
| iso8601 | ✓ (via swift-foundation's `_CalendarGregorian`) | ✓ | — | already pure-Swift |
| buddhist | ✓ | — | — | — |
| japanese | ✓ | — | — | — |
| republicOfChina | ✓ (ROC) | — | — | — |
| persian | ✓ | — | — | — |
| coptic | ✓ | — | — | — |
| ethiopicAmeteMihret | ✓ | — | — | — |
| ethiopicAmeteAlem | ✓ (`EthiopianAmeteAlem`) | — | — | — |
| indian | ✓ | — | — | — |
| hebrew | ✓ | — | — | — |
| islamic | ✓ (alias for IslamicUmmAlQura — see `Docs/ISLAMIC_ASTRONOMICAL.md`) | — | — | — |
| islamicCivil | ✓ | — | — | — |
| islamicTabular | ✓ | — | — | — |
| islamicUmmAlQura | ✓ | — | — | — |
| chinese | ✓ | — | — | — |
| dangi | ✓ | — | — | — |
| vietnamese | ✓ (`Vietnamese = ChineseCalendar<Vietnam>`) | — | — | — |
| bangla | ✓ (Hindu solar Bengali) | — | — | — |
| tamil | ✓ (Hindu solar Tamil) | — | — | — |
| odia | ✓ (Hindu solar Odia) | — | — | — |
| malayalam | ✓ (Hindu solar Malayalam) | — | — | — |
| gujarati | ~ (lunisolar; regional label TBD) | — | — | — |
| kannada | ~ (lunisolar; regional label TBD) | — | — | — |
| marathi | ~ (lunisolar; regional label TBD) | — | — | — |
| telugu | ~ (lunisolar; regional label TBD) | — | — | — |
| vikram | ~ (lunisolar; regional label TBD) | — | — | — |

Legend: ✓ implemented · ~ partial · — missing.

## Performance baselines

Initial spot-measurements captured in `BENCHMARK_RESULTS.md` — not
the formal Stage 0 gate, but enough to de-risk the pitch.

| Calendar family | icu4swift | Foundation | Spot-measured |
|---|---:|---:|:-:|
| Chinese (baked, 2024) | 1.9 µs | ~12 µs | ✓ (icu4swift 7× faster) |
| Chinese (Moshier, 2200, 1000d) | 3.4 µs | ~41 µs | ✓ (icu4swift 12× faster) |
| Chinese (Moshier, 1850, 1000d) | 26 µs | ~44 µs | ✓ (icu4swift 1.7× faster) |
| Chinese (Moshier, 1850, 30d) | 357 µs | ~30 µs | ✓ (**Foundation 12× faster** — narrow window) |
Three-way (2026-04-20 update, Homebrew ICU4C v78 as "ICU4C direct"):

| Calendar family | icu4swift | ICU4C direct | Foundation |
|---|---:|---:|---:|
| Simple / arithmetic (most identifiers) | 9–26 ns | 250–330 ns | ~1,100–1,400 ns |
| Hebrew | 96 ns | 1,085 ns | ~1,600 ns |
| Islamic Civil / Tabular / UQ | 20–43 ns | 330–721 ns | ~1,200–1,300 ns |
| Chinese (baked) | 42 ns | 41,652 ns | ~12,000 ns |
| Hindu solar (baked) | 109–200 ns | macOS 26+ only | macOS 26+ only |
| Hindu lunisolar (Moshier) | ~3.3 ms | macOS 26+ only | macOS 26+ only |

**All measurements use clean harness** — no `#expect` in the timed
loop, 100k iterations, warm-up excluded, checksum prevents
dead-code elimination.

Formal Stage 0 (per-calendar ICU baseline capture within
`swift-foundation`'s benchmark harness) is still pending.

## Open blockers

None blocking further doc work. For project-level risks see
`OPEN_ISSUES.md`. The single most valuable next concrete action
is resolving Issue 4 (measure Gregorian pure-Swift vs. ICU perf)
— see `OPEN_ISSUES.md` § "Recommended sequencing".

## Recent checkpoints

- 2026-04-22 PM — **Phase F benchmarks** for the sub-day adapter. Median
  of 3 runs, UTC: extraction **icu4swift 1.95× faster**, assembly
  Foundation 1.27× faster (cost of 2 `secondsFromGMT` probes for DST
  policy correctness), round-trip **icu4swift 1.11× faster**. Recorded
  in `BENCHMARK_RESULTS.md § Sub-day adapter`. All six phases of
  `FractionalRataDiePlan.md` now complete.
  **⚠ Perf concern surfaced:** these adapter numbers were far narrower
  than the "17–285× faster" headline from the 2026-04-19 calendar-math
  sweep. Logged as `OPEN_ISSUES.md § Issue 8` / `PIPELINE.md § 9b`.

- 2026-04-22 evening — **Adapter perf investigation closed** (Issue 8 /
  9b). Three-slice investigation in
  `Docs-Foundation/AdapterPerfInvestigation.md`. Extended benchmarks
  to cover `TimeZone.gmt` (fast path), `TimeZone(identifier: "UTC")`,
  and `America/Los_Angeles` (realistic DST). **Key finding: TZ
  dispatch cost is the entire gap.** On `TimeZone.gmt` icu4swift is
  **10× faster than Foundation end-to-end** (118 ns vs 1,182 ns
  round-trip) — matching the calendar-math-layer narrative. On DST
  zones both sides are TZ-bound to ~5 µs. Two single-probe
  optimizations attempted and reverted (one broke `.latter` policy,
  one broke round-trip correctness on transition days). 2-probe is
  minimum correct algorithm with public `TimeZone` API. **Inside
  swift-foundation the internal `rawAndDaylightSavingTimeOffset` is
  accessible — the tax vanishes by construction.** PITCH.md Beat 3
  updated with three-zone matrix.

- 2026-04-22 — **Sub-day Foundation adapter implemented** (Phases A–E of
  `FractionalRataDiePlan.md`). New `CalendarFoundation` module: two free
  functions (`rataDieAndTimeOfDay`, `date`) matching `_CalendarGregorian`'s
  pattern. Public DST policy enums. `RataDie.foundationEpoch = 730_486`.
  45 tests in `Tests/CalendarFoundationTests/`: UTC, fixed-offset TZs,
  LA spring/fall-back with `.former`/`.latter` policies, Sydney DST,
  Berlin 1900, year ±10,000 to ±1,000,000, nanosecond precision profile,
  end-of-day quirk documented. Full test suite: 383/384 (unchanged — only
  failure is pre-existing Chinese 1906 cluster).



- 2026-04-17 — Project started. Agents mapped swift-foundation and
  ICU surfaces. `00-Overview.md`, `MigrationIssues.md`, and the four
  tracking docs written.
- 2026-04-17 (later) — `PITCH.md`, `TIMEZONE_CONSIDERATION.md`,
  `OPEN_ISSUES.md`, `BENCHMARK_RESULTS.md` written. Chinese and
  arithmetic-calendar perf benchmarks run against Foundation.
  Key finding: icu4swift wins 7× on Chinese (baked range), wins
  12× outside baked range on bulk spans, loses 1.3–1.7× on
  arithmetic calendars. Full icu4swift self-bench captured: 20 of
  22 calendars sub-3 µs, Hindu lunisolar is the slow tier. Scripts:
  `Scripts/FoundationChineseBench.swift`,
  `Scripts/FoundationCalBench.swift`.
- 2026-04-19 — `05-PerformanceParityGate.md` written.
  Three-level gate (PR merge, per-calendar port, per-release),
  per-metric thresholds (CPU mean ±10 %, P99 ±20 %, mallocs ≤ 0,
  throughput ±10 %), per-calendar rollout procedure, CI
  integration, rollback protocol, open questions for
  `swift-foundation` maintainers.
- 2026-04-19 PM — Hebrew optimization (2.9 µs → 1.65 µs pre-cleanup;
  later discovered to be 96 ns after removing `#expect` overhead).
  `#expect`-in-timed-loop issue discovered and documented. Benchmark
  harness refactored across all 5 bench files. Clean sweep across
  all 22 calendars: icu4swift is 17–285× faster than Foundation's
  public Calendar API. `BENCHMARK_RESULTS.md` updated. Stale perf
  numbers across all Docs/ and Docs-Foundation/ docs fixed with
  ⚠ notes pointing to the new clean numbers. Benchmark discipline
  rule added to `CLAUDE.md`, memory, and `05-PerformanceParityGate.md`.
  PIPELINE items 16 (clean bench) done; 17 (direct ICU4C comparison)
  queued for next session in `NEXT.md`; 18 (extreme-range arithmetic
  regression) added as backlog.
- 2026-04-20 — PIPELINE item 17 done. `Scripts/ICU4CCalBench.c`
  written and compiled against Homebrew ICU4C v78. Three-way table
  added to `BENCHMARK_RESULTS.md`. **Key finding: icu4swift beats
  raw ICU4C's own C API by 10–40× on arithmetic calendars and
  ~1,000× on Chinese.** Foundation adds ~800 ns of Swift/ObjC
  wrapper overhead on top of ICU4C per iteration. Anomaly noted:
  ICU4C Chinese (Homebrew v78) slower than Foundation's Chinese
  (41 µs vs 12 µs) — likely ICU-version or Apple-optimization
  difference, worth investigating but not blocking. Apples-to-oranges
  caveat substantially resolved; `PITCH.md` Beat 3 reworded.

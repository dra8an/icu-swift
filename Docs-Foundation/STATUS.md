# Foundation Calendar Port — Status

*Last updated 2026-04-17 (end-of-day). Update this file at every checkpoint.*

One-page snapshot of where the project stands. For the roadmap see
`PROJECT_PLAN.md`; for immediate next steps see `NEXT.md`.

## Stage status

| Stage | Title | Status |
|---|---|---|
| 0 | Performance parity gate (crosscuts) | not started |
| 1 | Extend icu4swift | not started |
| 2 | Plumbing in swift-foundation | not started |
| 3 | Port calendars in risk order | not started |
| 4 | Removal | not started |

**Current phase of active work:** planning / documentation.

## Documentation

Durable design + reference docs:

| File | Status |
|---|---|
| `MASTER.md` | written |
| `PROJECT_PLAN.md` | written |
| `STATUS.md` | written (this file) |
| `NEXT.md` | written |
| `OPEN_ISSUES.md` | written |
| `PITCH.md` | written |
| `TIMEZONE_CONSIDERATION.md` | written |
| `BENCHMARK_RESULTS.md` | written (Chinese only) |
| `00-Overview.md` | written |
| `MigrationIssues.md` | written |
| `01-FoundationCalendarSurface.md` | not started |
| `02-ICUSurfaceToReplace.md` | not started |
| `03-CoverageAndSemanticsGap.md` | not started |
| `04-icu4swiftGrowthPlan.md` | not started |
| `05-PerformanceParityGate.md` | not started |
| `06-FoundationPortPlan.md` | not started |
| `07-OpenQuestions.md` | not started |

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
| ethiopicAmeteAlem | — (missing variant) | — | — | — |
| indian | ✓ | — | — | — |
| hebrew | ✓ | — | — | — |
| islamic | — (astronomical variant missing) | — | — | — |
| islamicCivil | ✓ | — | — | — |
| islamicTabular | ✓ | — | — | — |
| islamicUmmAlQura | ✓ | — | — | — |
| chinese | ✓ | — | — | — |
| dangi | ✓ | — | — | — |
| vietnamese | — (missing) | — | — | — |
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
| Arithmetic (Hebrew, Persian, Coptic, Ethiopian, Indian, Japanese, Islamic×3) | 1.5–2.9 µs | 1.1–1.6 µs | ✓ (Foundation 1.3–1.7× faster) |
| Hindu lunisolar (Amanta, Purnimanta) | ~3,500 µs | ? (macOS 26.0+) | partial (icu4swift only) |

**icu4swift self-bench:** 20 of 22 calendars sub-3 µs; Hindu
lunisolar is the slow tier.

Formal Stage 0 (per-calendar ICU baseline capture within
`swift-foundation`'s benchmark harness) is still pending.

## Open blockers

None blocking further doc work. For project-level risks see
`OPEN_ISSUES.md`. The single most valuable next concrete action
is resolving Issue 4 (measure Gregorian pure-Swift vs. ICU perf)
— see `OPEN_ISSUES.md` § "Recommended sequencing".

## Recent checkpoints

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

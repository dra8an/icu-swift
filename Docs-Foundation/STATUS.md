# Foundation Calendar Port — Status

*Last updated 2026-04-17. Update this file at every checkpoint.*

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

| Identifier | ICU baseline captured | Notes |
|---|:-:|---|
| *(all)* | — | Stage 0 not started; current Foundation benchmarks are Gregorian-only. |

## Open blockers

None. Awaiting decision on doc ordering before continuing to the
numbered reference docs (`01`–`07`).

## Recent checkpoints

- 2026-04-17 — Project started. Agents mapped swift-foundation and
  ICU surfaces. `00-Overview.md`, `MigrationIssues.md`, and the four
  tracking docs written.

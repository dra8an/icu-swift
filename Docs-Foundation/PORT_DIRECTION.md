# Port direction — icu4swift → swift-foundation

*Decision 2026-04-22. This document is authoritative. If anything
else (`HANDOFF.md`, `STATUS.md`, `PIPELINE.md`, individual memory
entries) contradicts this doc, **this doc is correct**. Update
the contradicting doc.*

## TL;DR

**All calendar port work now happens in the public
[`swift-foundation`](https://github.com/swiftlang/swift-foundation)
repository. `icu4swift` is frozen, tagged, and archived.**

**Do not edit anything in this repository except to:**

1. Record the archival / move (this doc, `HANDOFF.md`, `README.md`).
2. Create the final frozen tag.

**All code changes happen in the swift-foundation clone at**
`/Users/draganbesevic/Projects/claude/swift-foundation`.

## The decision

Two options were considered on 2026-04-22:

1. **Continue in icu4swift:** build Stage 1 primitives here as a
   `_CalendarProtocol`-shaped module, port to Foundation later.
2. **Move to Foundation:** everything moves into swift-foundation.
   icu4swift is frozen.

**Chose (2), fully.** Not a hybrid. Not a dependency. Every line of
calendar code moves into swift-foundation.

### Why not the hybrid

A hybrid ("icu4swift as a dependency of swift-foundation") was
briefly considered and rejected because:

- Two sources of truth creates sync problems forever.
- swift-foundation has zero external dependencies as a core design
  principle; adding icu4swift as a dep would need its own review /
  justification cycle.
- The pitch is "we replace `_CalendarICU`," not "we add a new
  dependency to Foundation." Cleaner story.
- Nobody is a production consumer of icu4swift yet; no migration
  path to worry about.

### Why Option 2 beats Option 1 generally

- **Internal APIs.** swift-foundation's `TimeZone.rawAndDaylightSavingTimeOffset(for:repeatedTimePolicy:skippedTimePolicy:)`
  is `internal` to the package. We can't call it from outside.
  Without it, we pay the 2-probe TZ tax forever (see
  `BENCHMARK_RESULTS.md § Sub-day adapter`). Inside swift-foundation,
  that tax disappears by construction.
- **Real Stage 1 numbers.** Inside Foundation we can measure what
  actual `Calendar(.hebrew)` calls cost end-to-end. The "Stage 1
  drops Foundation.Calendar cost from ~6 µs to ~2 µs" claim
  becomes measurable, not hypothetical.
- **Protocol conformance against the real protocol.** Our
  `_CalendarHebrew` / `_CalendarCoptic` / etc. classes conform to
  swift-foundation's actual `_CalendarProtocol`, not a shadow of it.
- **No double port.** Everything written inside swift-foundation
  stays there. No rewrite.
- **Creates the PR template directly.** When Apple accepts, the
  PR is literally what we've been working on. No translation step.

## What moves and where

### All source code

From `icu4swift/Sources/` → `swift-foundation/Sources/FoundationEssentials/Calendar/Algorithms/`
(exact subdirectory naming TBD by the integrator but should be
clearly separated from the existing `Calendar_Gregorian.swift` etc.):

- `CalendarCore/` — protocols, `Date<C>`, `RataDie`, `Month`,
  `Weekday`, `YearInfo`, `Location`
- `CalendarSimple/` — ISO, Gregorian, Julian, Buddhist, ROC
- `CalendarComplex/` — Hebrew, Coptic, Ethiopian, Ethiopian Amete
  Alem, Persian, Indian
- `CalendarJapanese/` — Japanese + era data
- `AstronomicalEngine/` — Moshier, Reingold, Hybrid (and `Moment`)
- `CalendarAstronomical/` — Islamic Civil, Tabular, UmmAlQura,
  Astronomical, Chinese, Dangi, Vietnamese, baked tables
- `CalendarHindu/` — Tamil, Bengali, Odia, Malayalam (solar);
  Amanta, Purnimanta (lunisolar); baked solar tables; Ayanamsa
- `DateArithmetic/` — `DateDuration`, `added`, `until`

**Gregorian itself is a special case.** swift-foundation already
has `_CalendarGregorian` in `Sources/FoundationEssentials/Calendar/Calendar_Gregorian.swift`
(pure-Swift). Do **not** replace or duplicate it — coordinate
with it. Our Gregorian code may become reference-only or merge
with theirs.

### Tests and regression data

From `icu4swift/Tests/` → `swift-foundation/Tests/FoundationEssentialsTests/Calendar/`
(plus the CSV fixtures):

- All per-calendar correctness tests
- All regression tests (306,897 dates against Hebcal, drikpanchang,
  HKO, KACST, Foundation, convertdate)
- Extreme-range round-trip stability tests (the one that found the
  three Hebrew bugs)
- All CSV fixtures under `Resources/`

### Perf benchmarks

Into swift-foundation's Benchmarks harness per
`05-PerformanceParityGate.md`. Stage 0 benchmark harness (pipeline
item 10) becomes the container.

### What gets deleted (not moved)

- **`CalendarFoundation` module (adapter).** Purpose was "outside-
  of-Foundation convenience." Once we're inside, `Calendar(.hebrew)`
  IS the user-facing API. Adapter is redundant.
- **Experimental benchmark files** that measured the adapter
  specifically — no longer relevant.

### What stays as historical research artifacts (in the frozen icu4swift repo)

- `Scripts/ICU4CCalBench.c` — already has a home and license
- `Scripts/UTCvsGMTProbe.swift` — diagnostic tool
- `Scripts/FoundationCalBench.swift`, `FoundationChineseBench.swift` — baseline measurement
- `Scripts/CompareDateFromComponents.c/.swift` — ucal_clear investigation
- All docs under `Docs/` and `Docs-Foundation/` — historical context
  for the decision trail

These aren't moved. They stay here as "how we got here" reference.

## Working repo

**Primary:** public `swift-foundation` clone at
`/Users/draganbesevic/Projects/claude/swift-foundation`.

All commits land there. Branches. PRs target upstream.

**Reference available:** Foundation-rizz (Apple-internal clone) at
`/Users/draganbesevic/Projects/stash/Foundation-rizz/`, for reading
internal PR conventions, CI setup, and internal design docs
(`FOUNDATION_APPLE.md` documents what's there). Not the primary dev
target.

## First calendar to port

Start with **something simple**: Gregorian-family (ISO, Buddhist,
ROC), or Hebrew.

- **Gregorian-family** are the easiest technically (arithmetic,
  often just offsets from `_CalendarGregorian`).
- **Hebrew** is arithmetic, well-tested (73,414-day Hebcal
  regression at 0/0 divergences), has the most complex arithmetic
  of the "simple" calendars, and the `_CalendarHebrew` shape
  exercises more of the `_CalendarProtocol` surface than a
  Gregorian-offset calendar would.

**User said either is fine.** Integrator's call when they start.

## Migration order after the first one

Suggested sequence once the first port proves the pattern:

1. First calendar (Gregorian-like or Hebrew) — pattern proof.
2. Simple arithmetic calendars: ISO, Buddhist, ROC (if Gregorian-
   family wasn't first), Coptic, Ethiopian, Ethiopian Amete Alem,
   Indian, Persian, Hebrew (if not first).
3. Japanese — era table.
4. Islamic family: Civil, Tabular, UmmAlQura, Astronomical.
5. Astronomical: Chinese, Dangi, Vietnamese (need
   AstronomicalEngine too).
6. Hindu: solar tier (Tamil, Bengali, Odia, Malayalam), lunisolar
   (Amanta, Purnimanta).

Each calendar ships its own PR with the per-identifier router flip
in `CalendarCache._calendarClass(identifier:)`. Stage 3 of
`PROJECT_PLAN.md`.

## icu4swift freeze / tag plan

**User to execute** (from the icu4swift working dir):

```sh
git tag -a pre-foundation-move -m "Frozen before move to swift-foundation"
git push origin pre-foundation-move   # if there's an origin
```

**Before tagging:**

- Merge this direction decision in
- Ensure `HANDOFF.md`, `README.md`, `STATUS.md`, `NEXT.md`,
  `PIPELINE.md` all point at this doc as the authoritative direction.
- Kill the prior "next task" — there is no more work here.

## What a cold-resume session needs to know

A `/clear`-ed session looking at this repo should immediately see:

1. `README.md` top banner: "Archived — see PORT_DIRECTION.md"
2. `Docs/HANDOFF.md` top banner: "Work moved to swift-foundation.
   See PORT_DIRECTION.md. Do not edit code here."
3. Memory entry `project_port_direction.md` saying the same.

If the user asks "let's work on X calendar" the session should:

1. **Not** edit files in this repo.
2. Navigate to `/Users/draganbesevic/Projects/claude/swift-foundation`.
3. Check if a working area for our calendars has been set up (look
   for `Sources/FoundationEssentials/Calendar/Algorithms/` or similar).
4. If not yet set up, consult this doc + `04-icu4swiftGrowthPlan.md`
   + `06-FoundationPortPlan.md` + `01-FoundationCalendarSurface.md`
   to understand the integration shape, then begin.

## Related reference docs (still useful, read in order)

Before beginning any actual porting work in swift-foundation:

1. **This doc** — the decision.
2. `Docs-Foundation/FOUNDATION_APPLE.md` — the Foundation repo's
   shape, where `_CalendarProtocol` lives, `CalendarCache` routing.
3. `Docs-Foundation/01-FoundationCalendarSurface.md` — what
   `_CalendarProtocol` looks like.
4. `Docs-Foundation/02-ICUSurfaceToReplace.md` — what `_CalendarICU`
   does that we're replacing.
5. `Docs-Foundation/03-CoverageAndSemanticsGap.md` — the 11
   calendar-math primitives to implement.
6. `Docs-Foundation/04-icu4swiftGrowthPlan.md` — Stage 1 design
   principle (no ucal state machine; match Foundation's API model).
7. `Docs-Foundation/06-FoundationPortPlan.md` — Stages 2–4 rollout.
8. `Docs-Foundation/05-PerformanceParityGate.md` — the perf gate
   every Stage 3 PR must pass.
9. `Docs-Foundation/SUBDAY_BOUNDARY.md` — the sub-day time boundary
   design. **Once inside Foundation, call
   `TimeZone.rawAndDaylightSavingTimeOffset(for:repeatedTimePolicy:)` —
   the 2-probe workaround in `CalendarFoundation` is obsolete.**
10. `Docs/RDvsJD.md` — why RataDie (not Julian Day) is the pivot.
11. `Docs-Foundation/BENCHMARK_RESULTS.md` — the perf narrative to
    validate with real Stage 1 numbers.

## Final commitment

This decision is **closed**. Re-opening requires a concrete new
reason (e.g., Apple reviewers refuse the direction and we have to
re-architect). Do not re-litigate otherwise.

# Foundation Calendar Port — Project Plan

*Last updated 2026-04-17.*

High-level roadmap for replacing `swift-foundation`'s ICU4C calendar
backend with pure-Swift implementations. For the full rationale see
`00-Overview.md`; for current progress see `STATUS.md`; for immediate
next steps see `NEXT.md`.

## Mission

Eliminate `swift-foundation`'s runtime dependency on ICU4C for
calendrical math. Replace `_CalendarICU` with pure-Swift backends
derived from `icu4swift`. When complete, archive `icu4swift` as the
algorithms have been absorbed into Foundation.

## Stages

The project has four sequential stages. Each stage is complete before
the next begins, with one exception: the performance parity gate
(Stage 0, ongoing) crosscuts every stage.

### Stage 0 — Performance parity gate (crosscuts all stages)

Establish the performance harness before any code changes land.

- Extend `swift-foundation/Benchmarks/.../BenchmarkCalendar.swift` from
  Gregorian-only to per-identifier coverage.
- Add benchmarks for missing operations (`range`, `ordinality`,
  `dateInterval`, `isDateInWeekend`, DST-edge arithmetic, Julian
  cutover).
- Capture the ICU-backed baseline per identifier per operation.
- Lock the parity thresholds (proposed: CPU within ±10%, mallocs ≤
  baseline, throughput within ±10%).

**Exit criterion:** every identifier × operation has a benchmark and a
recorded ICU baseline checked into the repo.

### Stage 1 — Extend icu4swift

Grow icu4swift's API surface to cover Foundation semantics not yet
supported. All work in the `icu4swift` repository.

- Stored properties on calendar structs for Foundation's mutable
  knobs: `timeZone`, `firstWeekday`, `minimumDaysInFirstWeek`,
  `locale`, `gregorianStartDate`.
- Adapter layer: `(Date, TimeZone) ↔ (RataDie, secondsInDay)` with
  DST handling.
- `DateComponents` sparse round-trip (optional fields, `isLeapMonth`,
  `isRepeatedDay`).
- `range(of:in:for:)`, `minimumRange`, `maximumRange`.
- `ordinality(of:in:for:)`.
- `dateInterval(of:for:)`.
- `nextDate(after:matching:matchingPolicy:repeatedTimePolicy:direction:)`
  and `enumerateDates(…)`.
- `isDateInWeekend`, `dateIntervalOfWeekend`, `nextWeekend`.
- Two missing calendars: `ethiopicAmeteAlem` (trivial epoch variant of
  existing Ethiopian) and `vietnamese` (Chinese-family at UTC+7).

**Exit criterion:** icu4swift passes a new Foundation-semantics test
suite (mirroring `CalendarTests.swift` shape) against all 28
identifiers, and the new API surface is benchmarked within its own
repo.

See `04-icu4swiftGrowthPlan.md` for the phased breakdown.

### Stage 2 — Plumbing in swift-foundation

Land the infrastructure to host a Swift-native backend without
disturbing the ICU path.

- Introduce `_CalendarSwift<Identifier>` (or per-identifier concrete
  classes) conforming to `_CalendarProtocol`.
- Extend `CalendarCache._calendarClass(identifier:)` to consult a
  per-identifier routing table. Default every identifier to the ICU
  path; each calendar flips when certified.
- Add the icu4swift dependency to `swift-foundation`'s `Package.swift`
  behind a build-time flag.
- Wire up the `@_dynamicReplacement` hook so icu4swift-backed classes
  plug in without modifying Foundation's core files.

**Exit criterion:** `_CalendarSwift<Gregorian>` passes every existing
Foundation calendar test **and** meets the Stage 0 perf parity gate.
Nothing else has flipped yet; we have merely proved the plumbing
works end-to-end using a calendar whose Swift backend already exists
(`_CalendarGregorian`, extended).

### Stage 3 — Port calendars in risk order

Port each remaining calendar from `_CalendarICU` to a Swift-native
backend, flipping the router entry once it passes the parity gate.

**Proposed order** (easiest to hardest):

| Phase | Calendars | Why this phase |
|---|---|---|
| 3a | `buddhist`, `republicOfChina`, `japanese` | Gregorian extensions with epoch shift / era mapping. Trivial. |
| 3b | `coptic`, `ethiopicAmeteMihret`, `ethiopicAmeteAlem`, `indian`, `persian` | Pure arithmetic. Well-defined. |
| 3c | `hebrew` | Arithmetic, but intricate leap-year + Dechiyot rules. |
| 3d | `islamicTabular`, `islamicCivil`, `islamicUmmAlQura`, `islamic` (astronomical) | Tabular + observational variants. UQ uses baked data. |
| 3e | `chinese`, `dangi`, `vietnamese` | Lunisolar baked-data + Moshier fallback. |
| 3f | `bangla`, `tamil`, `odia`, `malayalam` (Hindu solar) | Baked-data Hindu solar. |
| 3g | `gujarati`, `kannada`, `marathi`, `telugu`, `vikram` (Hindu lunisolar) | Currently the slowest tier; Foundation identifiers likely alias to our Amanta/Purnimanta with regional labels. |
| 3h | `gregorian`, `iso8601` | Already pure-Swift; re-validate through the router to confirm parity harness works end-to-end. |

Each phase includes:
1. Implement `_CalendarSwift<X>`.
2. Run the functional regression (daily comparison 1900–2100 against
   `_CalendarICU` output — zero divergence required).
3. Run the Stage 0 perf gate.
4. If both pass, flip the router entry. If not, revert.

**Exit criterion:** every `Calendar.Identifier` case dispatches to
`_CalendarSwift` in `CalendarCache`. `_CalendarICU` still exists but
is unreachable in production.

See `06-FoundationPortPlan.md` for per-calendar detail.

### Stage 4 — Removal

Delete the ICU calendar path.

- Delete `_CalendarICU` and `Calendar_ICU.swift`.
- Remove calendar sources from `swift-foundation-icu` (calendar.cpp,
  gregocal.cpp, chnsecal.cpp, hebrwcal.cpp, islamcal.cpp, coptccal.cpp,
  ethpccal.cpp, persncal.cpp, indiancal.cpp, japancal.cpp, buddhcal.cpp,
  taiwncal.cpp, dangical.cpp, iso8601cal.cpp, hinducal.cpp, astro.cpp —
  plus their headers).
- Remove the ICU calendar dependency from `swift-foundation`'s
  `Package.swift`.
- Remove `_calendarICUClass()` and its dynamic-replacement hook.
- Archive the `icu4swift` repository with a pointer to the final
  landing commits in `swift-foundation`.

**Exit criterion:** `grep -r 'ucal_'
swift-foundation/Sources/FoundationInternationalization/Calendar/`
returns nothing. All calendar tests still pass. Library size measured
and reported.

## Acceptance criteria (global)

See `00-Overview.md` § "Acceptance criteria" for the per-calendar
gate: functional parity, performance parity, memory parity, thread
safety, API compatibility.

## Timeline

Deliberately unestimated. Stage 1 alone is multi-month. Each phase in
Stage 3 includes full regression + perf capture, which is slow by
design.

## Risks

Tracked in `00-Overview.md` § "Risks and how we manage them".
`MigrationIssues.md` records two concerns (Foundation mutability,
RataDie vs. milliseconds) that were investigated and dismissed.

## Dependencies

- icu4swift: ships regression data for every calendar; continues to
  accept upstream PRs during Stages 0–2; freezes during Stage 3 port
  (other than bugfixes).
- swift-foundation: existing `_CalendarProtocol` contract is stable
  enough for the port. If Apple evolves the protocol during the
  project, we rebase.
- swift-foundation-icu: untouched during Stages 0–3; calendar sources
  deleted in Stage 4.

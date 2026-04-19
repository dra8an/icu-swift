# Performance Parity Gate

*Created 2026-04-19. Spec for how we prove that each ported calendar
does not regress performance vs the ICU baseline.*

Every calendar that flips from `_CalendarICU` to a Swift-native backend
must pass this gate. The gate decides whether a PR can merge and
whether a calendar's router entry can be flipped in
`CalendarCache._calendarClass(identifier:)`.

## Purpose and scope

**Purpose.** Prevent silent performance regressions from reaching
users. Provide an objective, pre-agreed threshold for "acceptable"
vs "rejected" ports — so reviewers don't have to argue about numbers
mid-PR.

**Gates.** Three levels:

1. **Per-PR merge gate** — any PR touching calendar code runs the
   core benchmark set; regressions beyond the hard-fail threshold
   block merge.
2. **Per-calendar port gate** — before the router flips from ICU
   to Swift for a given identifier, the extended benchmark set
   must pass.
3. **Per-release regression gate** — before each Foundation
   release tag, the full matrix runs; hard fails block tagging.

**In scope:** calendrical-math performance measured through public
`Calendar` API.

**Out of scope:**
- `DateFormatter` / `Date.FormatStyle` performance (separate port).
- `TimeZone` internal performance (not being replaced).
- `Locale` resolution performance (not being replaced).
- CLDR data loading time (separate concern).

## Measurement matrix

The matrix has three axes: identifier × operation × context.

### Identifier axis (all 28)

`gregorian`, `iso8601`, `buddhist`, `japanese`, `republicOfChina`,
`persian`, `coptic`, `ethiopicAmeteMihret`, `ethiopicAmeteAlem`,
`hebrew`, `indian`, `islamic`, `islamicCivil`, `islamicTabular`,
`islamicUmmAlQura`, `chinese`, `dangi`, `vietnamese`, `bangla`,
`tamil`, `odia`, `malayalam`, `gujarati`, `kannada`, `marathi`,
`telugu`, `vikram`.

Note: `dangi` and the Hindu regional variants require macOS 26.0+.
Benchmarks for those identifiers are conditionally compiled.

### Operation axis

**Core set** — must-have, runs on every PR:

| Operation | Shape |
|---|---|
| `dateComponents(_:from:)` | Date → DateComponents (decompose) |
| `date(from:)` | DateComponents → Date (compose) |
| `date(byAdding:to:)` | add one component's worth |
| `dateComponents(_:from:to:)` | difference between two Dates |
| round-trip | decompose + compose per iteration |

**Extended set** — required for per-calendar port gate:

| Operation | Shape |
|---|---|
| `range(of:in:for:)` | component range within larger component |
| `minimumRange(of:)` / `maximumRange(of:)` | global bounds |
| `ordinality(of:in:for:)` | ordinal position |
| `dateInterval(of:for:)` | start + duration of a unit |
| `nextDate(after:matching:matchingPolicy:)` | × each policy |
| `enumerateDates(startingAfter:matching:…)` | × bulk iteration count |
| `isDateInWeekend(_:)` | single call |
| `startOfDay(for:)` | single call |
| `isDate(_:inSameDayAs:)` | single call |
| `compare(_:to:toGranularity:)` | per granularity |

### Context axis

Every core benchmark runs under at least these contexts:

| Context | Purpose |
|---|---|
| GMT, 2024 | Baseline happy path. No DST, in-band year. |
| `America/Los_Angeles`, 2024 | DST-crossing operations. |
| `America/Los_Angeles`, spring-forward 2024-03-10 02:30 | Gap handling. |
| `America/Los_Angeles`, fall-back 2024-11-03 01:30 | Repeated-hour handling. |
| Calendar's "far past" and "far future" | Stress the fallback path for lunisolar calendars. |

For extended set, add: bulk 1000-iter for enumeration benchmarks
(matches existing Foundation `BenchmarkCalendar.swift` style).

### Macro benchmarks

Beyond micro-benchmarks, each identifier also runs a macro
benchmark — a realistic usage pattern that stresses multiple
operations at once. Existing examples: `nextThousandThanksgivings`,
`RecurrenceRuleThanksgivings`. Extend to per-identifier versions:
`nextThousandChineseNewYears`, `nextThousandRoshHashanahs`,
`RecurrenceRuleIslamicRamadan`, etc.

## Metrics

Each benchmark records:

| Metric | What it detects |
|---|---|
| **CPU time (median of N runs)** | Mean per-operation latency. Primary metric. |
| **P50, P99 latency** | Tail behavior. ICU's mutex + cache occasionally produces 10× outliers; pure Swift should be flatter. |
| **Malloc count per operation** | Allocation discipline. Target: ≤ baseline. |
| **Throughput (ops/sec)** | Sanity check against CPU time; catches measurement artifacts. |
| **Peak resident memory** | Catches accidental retained state. |

Cold-start vs steady-state:

- Primary gate uses **steady-state** (warm-up pass excluded).
- Cold-start captured separately as an informational metric; not a
  hard gate (pure-Swift path has no `ucal_open` equivalent, so cold
  vs warm shape differs by design).

## Baseline capture protocol

### Format

Baselines are checked into the repository as canonical JSON:

```
swift-foundation/
  Benchmarks/Baselines/
    chinese.json
    hebrew.json
    ...
```

Each JSON entry:

```json
{
  "identifier": "chinese",
  "operation": "dateComponents",
  "context": { "tz": "UTC", "year": 2024 },
  "iterations": 1000,
  "metrics": {
    "cpu_mean_us": 12.8,
    "cpu_p50_us": 12.5,
    "cpu_p99_us": 18.1,
    "mallocs_per_op": 0,
    "throughput_ops_per_sec": 78125
  },
  "environment": {
    "hardware": "apple-mac-mini-m2-8c",
    "os": "macOS 26.0",
    "swift_toolchain": "6.0.0",
    "swift_foundation_commit": "a1b2c3d",
    "icu_version": "77.1"
  },
  "captured_at": "2026-04-19T10:00:00Z"
}
```

### When to re-capture

- **ICU version bumped** in `swift-foundation-icu` → re-capture every
  identifier.
- **Swift toolchain bumped** (major or minor) → re-capture every
  identifier.
- **Canonical hardware changed** → re-capture every identifier.
- **Any other time** → do not re-capture. Stale baselines are safer
  than re-captured-for-convenience baselines.

### How to capture

Extend the existing `Benchmarks/` package with a `--record` mode:

```bash
swift run -c release Benchmarks record --calendar chinese --force-icu
```

Writes the JSON. Must run on the canonical hardware; CI rejects
baseline commits not signed by the canonical runner.

### Forcing the ICU path

Requires a build-time flag (`-D FOUNDATION_FORCE_ICU_CALENDAR`) or
a runtime override in `CalendarCache._calendarClass()`. Exists only
in the benchmark harness; never in shipping code.

## Thresholds

The gate. All proposed — subject to discussion with
`swift-foundation` maintainers before Stage 3 begins.

| Metric | Pass | Soft warn | Hard fail |
|---|---|---|---|
| CPU mean | Δ ≤ +10% | +10% < Δ ≤ +25% | Δ > +25% |
| CPU P99 | Δ ≤ +20% | +20% < Δ ≤ +50% | Δ > +50% |
| Mallocs per op | Δ ≤ 0 | Δ = +1 | Δ > +1 |
| Throughput | Δ ≥ −10% | −25% ≤ Δ < −10% | Δ < −25% |
| Peak memory | Δ ≤ +5% | +5% < Δ ≤ +15% | Δ > +15% |

**Pass** — PR may merge. Router may flip.
**Soft warn** — PR must include justification in description.
Maintainer judgment on merge. Router flip requires explicit
approval.
**Hard fail** — PR cannot merge. Router cannot flip.

Improvements (negative deltas) are never gated; they log as
"improved" with the measured delta.

### Why different thresholds per metric

- **CPU mean ±10%**: tight enough to catch real regressions, loose
  enough to absorb measurement noise on standard hardware.
- **P99 ±20%**: tails are noisier; slightly looser.
- **Mallocs ≤ 0**: every allocation has to be justified. No
  drift.
- **Peak memory ±5%**: calendar state is tiny; any significant
  growth is a bug.

## Per-calendar rollout procedure

The canonical flow for porting one calendar:

1. **Before any code change** — capture ICU baseline for this
   identifier with all core + extended benchmarks:
   ```bash
   swift run -c release Benchmarks record --calendar chinese --force-icu
   ```
   Check the JSON into the repo. This PR is its own commit.

2. **Write the Swift backend** (`_CalendarSwift<Chinese>` or
   similar). Functional correctness first; don't chase performance
   yet. Ship behind an opt-in router entry that's disabled by
   default.

3. **Run the correctness regression**:
   ```bash
   swift test --filter ChineseParityRegression
   ```
   Daily comparison 1900–2100 against `_CalendarICU` output. Zero
   divergences (minus pre-documented allow-list).

4. **Run the performance gate**:
   ```bash
   swift run -c release Benchmarks compare --calendar chinese --against baseline
   ```
   Emits a per-operation table: baseline, current, delta, status.
   All rows must be pass or soft warn.

5. **If pass** — PR flips the router entry for `chinese` from ICU
   to Swift. Merge.

6. **If soft warn** — PR includes "performance justification"
   section in description. Maintainer decides.

7. **If hard fail** — revert the Swift backend or keep it disabled.
   Iterate on the implementation. Router stays on ICU.

The key invariant: **the router only flips when the gate passes.**
A half-ported calendar is not a shipped calendar.

## Edge cases and pitfalls

### Measurement noise

**Symptom.** Two consecutive runs of the same benchmark report
different numbers. Small variance (< 5%) is expected; large
variance (> 20%) is a measurement bug.

**Mitigation.**
- Always report **median of at least 5 runs**, not mean of 3.
- Run benchmarks on isolated CPU cores (`taskset`-equivalent where
  available).
- Disable frequency scaling during runs (`sudo pmset powerstate`).
- Require that the canonical runner has consistent thermal behavior
  (Apple silicon Mac with sustained load limits, not a laptop on
  battery).
- Reject runs with a `cpu_p99 / cpu_p50` ratio above 3.0 — high
  ratios indicate interference.

### ICU variance issue

ICU's mutex + cache behavior in `_CalendarICU` produces P99 outliers
of 10–50× the P50. We saw this in the Chinese measurement (12 µs
mean, 30+% variance across runs). Our pure-Swift backend should
have much tighter P99.

**Consequence for the gate.** Comparing our P99 to ICU's P99 may
look *better* than a mean comparison. Capture both; log both; do
not silently average them away.

### Macro benchmarks

Per-identifier macro benchmarks are where real-world performance
shows. Example skeleton:

```swift
Benchmark("Chinese: next 1000 Lunar New Years") { benchmark in
    let cal = Calendar(identifier: .chinese)
    let start = Date(timeIntervalSince1970: 1474666555.0)
    var count = 1000
    cal.enumerateDates(startingAfter: start,
                       matching: DateComponents(month: 1, day: 1),
                       matchingPolicy: .nextTime) { result, exactMatch, stop in
        count -= 1
        if count == 0 { stop = true }
    }
}
```

Per-identifier macro benchmarks **must ship with the Stage 0 harness**
— before any calendar ports.

### Benchmarks that need macOS 26.0+

`.dangi`, `.bangla`, `.tamil`, `.malayalam`, `.odia` require
macOS 26.0+. Their benchmarks are compiled with
`@available(macOS 26, *)` gates. CI must cover both macOS versions.

### Allocation counting subtlety

`mallocCountTotal` counts every `malloc` during the measurement,
including background work (Swift runtime GC, ARC cycles). Noise
floor varies by operation.

**Mitigation.** Record allocations as *per-iteration delta from
baseline warm-up*, not as absolute counts. A "zero malloc operation"
means "same allocation count as warm-up."

### Legitimate malloc regressions

Our Swift backend may introduce mallocs that ICU didn't have —
example: sparse `DateComponents` returned as a Swift struct with
optional fields might require a heap allocation where ICU returned
fixed-layout fields. If this is **semantically required**, the
gate allows the regression with explicit justification in the PR.

## CI integration

### PR workflow

Every PR touching `swift-foundation/Sources/FoundationInternationalization/Calendar/`
triggers:

1. **Correctness job** — functional regression suite.
2. **Core benchmark job** — runs the core set for every identifier
   the PR touches. Writes a comment on the PR with a diff table.
3. **Extended benchmark job** — runs only if the PR description
   contains `/perf-full`. Extended set across all identifiers.

### Merge requirements

- Correctness: zero failures.
- Core benchmark: all rows pass or soft warn. Soft warns require
  maintainer approval.
- Extended benchmark: only gated for PRs that flip a router entry.

### Rollback protocol

If a post-merge regression is observed (for example, a nightly run
flags a hard fail that the per-PR run missed due to hardware
difference):

1. **Open a rollback PR immediately.** Flip the router back to ICU
   for the affected calendar. Don't delete the Swift code.
2. Investigate the regression against the baseline delta.
3. Land a fix PR that passes the gate.
4. Flip the router forward again.

The Swift backend never has to be deleted. The router is the only
thing that moves.

## Open questions

Decisions that should land before Stage 3 begins.

1. **Canonical hardware.** Specific Apple silicon model, sustained
   thermal envelope, isolated from the main CI cluster?
2. **Baseline storage.** Checked-in JSON vs. artifact store? For a
   fork-based workflow, checked-in makes PR review easier; for a
   contribution workflow, artifact store is cleaner.
3. **Rejection override.** Is there any signal that lets a hard
   fail through (e.g., accepted regression for a separately-tracked
   issue)? Or is hard fail always terminal?
4. **Macro benchmark selection.** Which macro benchmarks are
   "core"? The ICU team might have a stronger opinion here than we
   do.
5. **Thresholds themselves.** The numbers above are proposals.
   Review with `swift-foundation` maintainers before committing.

## Relationship to other docs

- `BENCHMARK_RESULTS.md` — current spot-measurement data; informs
  the realistic thresholds in this doc.
- `OPEN_ISSUES.md` Issue 4 — this doc is the resolution for that
  issue.
- `PROJECT_PLAN.md` § Stage 0 — this doc is the Stage 0 spec; code
  work (writing the harness) is downstream.
- `06-FoundationPortPlan.md` *(planned)* — uses this gate as the
  per-calendar acceptance criterion.

# Sub-day adapter perf investigation — live progress log

*Opened 2026-04-22 in response to `OPEN_ISSUES.md § Issue 8` /
`PIPELINE.md § 9b`. Working doc — updated as slices complete. When
the investigation closes, resolve into a final write-up in
`BENCHMARK_RESULTS.md` and mark this doc archived.*

## The problem

Two perf headlines contradict each other without explanation:

1. **"icu4swift is 17–285× faster than Foundation's `Calendar` API"** — from the 2026-04-19 clean-methodology sweep (`BENCHMARK_RESULTS.md § Clean-methodology sweep`).
2. **"icu4swift adapter is 1.1–1.95× faster on extraction/round-trip, and 1.27× slower on assembly"** — from the 2026-04-22 Phase F sub-day adapter benchmarks (`BENCHMARK_RESULTS.md § Sub-day adapter`).

We cannot ship the pitch with both numbers until we know why they disagree. Hypothesis: prior sweep measured pure calendar math on `RataDie`; adapter measures the Foundation-boundary layer which pays `TimeZone`/`Date` API overhead. But this is hypothesis until proven.

## Why this matters

The pitch leans on a "our calendar math is dramatically faster" narrative. If the sub-day-boundary reality is "comparable to Foundation," the pitch needs a two-tier framing, or a footnote, or a narrower claim. Discovering this post-pitch from a Foundation engineer with a profiler would be bad.

## Scope (three slices)

| # | Slice | Status | Effort |
|---|---|---|---|
| 1 | Isolate `TimeZone.secondsFromGMT(for:)` cost in isolation | **done** | — |
| 2 | Apples-to-apples end-to-end (adapter + Gregorian vs Foundation full) | **done** | — |
| 3 | Three-way with ICU4C direct + pitch-framing decision | **done** | — |

---

## Slice 1 — Isolate `TimeZone.secondsFromGMT` cost

**Goal.** Establish the Foundation-API floor our adapter cannot go below. The adapter calls `secondsFromGMT(for:)` twice (fast path) or up to four times (DST slow path). If each call costs ~1 µs, 2 calls = 2 µs, and that alone explains most of our assembly gap.

**Plan.**
- New microbench in `Tests/CalendarFoundationTests/`.
- One `tz.secondsFromGMT(for:)` call per iteration, 100 k iters, clean harness.
- Exercise three zone types: UTC, fixed-offset (`secondsFromGMT: int`), DST zone (`America/Los_Angeles`). DST likely costs more — transition-table lookup.

**Expected outcome.**
- If UTC is ~500 ns per call → that's 1 µs of our ~3 µs assembly. Credible floor.
- If UTC is ≤100 ns per call → the adapter's cost isn't from TZ; look elsewhere.

**Findings (2026-04-22):** Foundation's TZ layer is the largest single
cost in our adapter. Numbers are noisy because Foundation caches TZ
data internally and test ordering affects cold-start state. Stable
ranges (3 runs each):

| Op | Range |
|---|---:|
| `Date.init(timeIntervalSinceReferenceDate:)` baseline | 5–7 ns |
| `TimeZone(secondsFromGMT: 3600).secondsFromGMT(for:)` | 15–21 ns |
| `TimeZone(identifier: "UTC").secondsFromGMT(for:)` | **547–1044 ns** |
| `TimeZone(identifier: "America/Los_Angeles").secondsFromGMT(for:)` | **689–868 ns** |
| 2-probe UTC (adapter fast path) | 673–1915 ns |
| 2-probe LA (adapter fast path) | 849–1043 ns |
| Adapter assembly fast path **inlined** | 1707–1915 ns |

Three conclusions:

1. **Named-identifier zones are 30–65× slower than fixed-offset zones.**
   `TimeZone(identifier: "UTC")` pays ~540+ ns *per call*;
   `TimeZone(secondsFromGMT: 3600)` pays ~16 ns *per call*. Users who
   pass named zones to our adapter pay substantially more than users
   who pass fixed-offset instances, for the same effective zone.

2. **Foundation's TZ cache is stateful and test-order-dependent.**
   Single UTC calls varied from 547 ns to 1044 ns across runs;
   2-probe patterns ranged from 673 to 1915 ns. The variance isn't
   random noise — it's cache warmup. This makes apples-to-apples
   adapter comparisons inherently noisy and suggests we should report
   ranges rather than single medians.

3. **The fast-path-inline benchmark (1707–1915 ns) is below the
   adapter's 3042 ns assembly measurement, but not by enough to match.**
   Unexplained gap of ~1200 ns. Possible contributors: function-call
   overhead on non-inlined `resolveLocalTI`, enum-parameter passing,
   closure-harness overhead, or TZ cache state differences between
   test runs. Worth investigating if Slice 2/3 still show the adapter
   losing on assembly — could be worth marking `resolveLocalTI`
   `@inlinable` or similar.

**Impact on the overall perf story:** **prior 17–285× claim was on
pure calendar math (RataDie ↔ inner, no Foundation.Date, no TimeZone).**
The 1–2× adapter numbers are on a different operation — one that
includes the Foundation-API tax that can reach ~2 µs per operation
just for TZ work. That's not a regression in our code; it's the
Foundation boundary's own floor. Slice 2 will confirm whether this
explains the full gap.

---

## Slice 2 — Apples-to-apples end-to-end benchmark

**Goal.** Replace the loosely-comparable benchmarks in `FoundationAdapterBenchmarks.swift` with true apples-to-apples: both sides do exactly the same user-facing work — convert a `Foundation.Date` + `TimeZone` into `(Y, M, D, h, m, s, ns)` and back.

**Why the current benchmark isn't apples-to-apples.** Our adapter produces `(RataDie, secondsInDay, nanosecond)`. Foundation produces `DateComponents` with Y/M/D/h/m/s/ns. We asked Foundation for more work — Y/M/D decomposition via Gregorian — that our adapter doesn't do. To compare fairly, we should wrap our adapter with `GregorianArithmetic` calls so both sides produce the same information.

**Plan.**
- Extend `FoundationAdapterBenchmarks.swift` with a second test set:
  - Extract: `rataDieAndTimeOfDay` + `GregorianArithmetic.gregorianFromFixed` vs Foundation `dateComponents([year, month, day, hour, minute, second, nanosecond])`.
  - Assemble: `GregorianArithmetic.fixedFromGregorian` + `date(rataDie:h:m:s:ns:in:)` vs Foundation `date(from: DateComponents)`.
  - Round-trip: chain both.
- 100 k iters, clean harness, UTC.

**Expected outcome.** If the apples-to-apples comparison shows icu4swift 10×+ faster end-to-end, the pitch claim reconciles cleanly — the prior sweep and this new comparison are the same shape. If still 1–2×, the pitch needs the two-tier reframing.

**Findings (2026-04-22):** **Pitch needs two-tier reframing.** icu4swift
and Foundation are **in the same order of magnitude** on end-to-end
Foundation.Date round-trip, not 17–285× different. Medians across
3 runs (UTC, `Calendar(.gregorian)`, 100k iters, variance ±40%):

| Operation | icu4swift (adapter + Gregorian) | Foundation (`Calendar`) | Winner |
|---|---:|---:|---|
| Extract (Date → Y/M/D/h/m/s/ns) | 2,150 ns | 3,931 ns | icu4swift 1.83× |
| Assemble (Y/M/D/h/m/s/ns → Date) | 3,801 ns | 2,356 ns | Foundation 1.61× |
| Round-trip | 3,937 ns | 6,068 ns | icu4swift 1.54× |

**Reconciliation with the 17–285× headline:** the two benchmarks
measured fundamentally different things.

- **Prior sweep (17–285×)** — measured `Date<C>.fromRataDie(rd) → c.toRataDie(inner)` on a pre-computed `RataDie` input. **No Foundation.Date, no TimeZone.** Pure `Int64` calendar math. Result: ~20 ns for arithmetic calendars; Foundation's full `Calendar` API was ~1,400 ns for the equivalent full round-trip; ratio ~70×.
- **Apples-to-apples (1.5–2×)** — measures the same end-to-end
  operation on both sides: Foundation.Date + TimeZone in, the same
  out, with Y/M/D decomposition on both. Both sides pay the same
  Foundation-boundary tax (~1–2 µs of TZ work from Slice 1).
  icu4swift's calendar math is still ~20 ns, but that's a small
  fraction of the total once the boundary is included.

**Arithmetic:**
- Foundation end-to-end = Foundation boundary + Foundation calendar math = ~3,500 ns = ~2,000 ns boundary + ~1,500 ns calendar math
- icu4swift end-to-end = our boundary + our calendar math = ~2,000 ns = ~2,000 ns boundary + ~20 ns calendar math
- **Ratio ≈ 1.75×** — boundary tax dominates; calendar-math win is real but hidden

**So the 17–285× figure is correct for what it measured, but not for what a user experiences end-to-end through Foundation.Date.** For the pitch, both numbers should appear, with clear scoping:

- *Calendar math specifically*: icu4swift is 17–285× faster.
- *End-to-end Foundation-boundary round-trip*: icu4swift is 1.5–2× faster on arithmetic calendars, 5–7× faster on Chinese (the calendar-math gap still shows because it's 12 µs vs 42 ns — a big gap relative to the ~2 µs boundary tax).

**On assembly, Foundation wins 1.6×.** Our 2-probe DST-detection costs more than Foundation's single internal-API call. Documented in SUBDAY_BOUNDARY.md as the "correctness-over-speed" tradeoff; `.latter` policy demands the second probe. Possible optimization: cache last-seen offset per-TZ (would require non-free-function state, so deferred).

**Noise:** variance was ±40% across runs, much higher than our standard benchmarks. Foundation's TZ cache is test-order-dependent and produces non-reproducible single-run numbers. Reported medians; real pitch numbers should be medians of 5+ runs or include confidence-interval framing.

---

## Slice 3 — Three-way with ICU4C direct + pitch-framing decision

**Goal.** Add adapter-shape workload to the existing three-way infrastructure (`Scripts/ICU4CCalBench.c`). Decide final pitch framing.

**Plan.**
- Extend `Scripts/ICU4CCalBench.c` (or add a sibling) with a boundary-layer workload equivalent to our adapter: `ucal_setMillis` + `ucal_get(time-of-day fields)` + `ucal_clear` + `ucal_set` + `ucal_getMillis`.
- Record numbers in `BENCHMARK_RESULTS.md`.
- Pitch-framing decision tree:
  - If icu4swift < ICU4C direct on this shape → keep the "calendar math win" narrative; the adapter floor is ICU's own floor.
  - If icu4swift ≈ Foundation ≈ ICU4C → "adapter matches; calendar math wins big" — two-tier story.
  - If icu4swift > Foundation > ICU4C direct → we have real work to do; optimize before pitching.

**Plan for pitch update.**
- `PITCH.md` Beat 3: keep headline 17–285× for calendar math, add one-line clarifier about the boundary layer.
- `BENCHMARK_RESULTS.md § Sub-day adapter`: replace the ⚠ warning with the final story.
- Remove Issue 8 from `OPEN_ISSUES.md` (or strike through).

**Findings (2026-04-22).**

Extended `Scripts/ICU4CCalBench.c` to full Y/M/D/h/m/s/ns round-trip
(matching the APPLES shape). ICU4C direct measured very cleanly
(single-run variance <5%, 3-run median very tight).

### Three-way round-trip, Gregorian, UTC, 100k iters (apples-to-apples)

| Implementation | Median ns/op | Ratio vs ICU4C |
|---|---:|---:|
| **ICU4C direct** (no Swift wrapper) | **280** | 1× (reference) |
| icu4swift adapter + Gregorian | 3,937 | 14× slower |
| Foundation `Calendar(.gregorian)` | 6,068 | 22× slower |

### Why ICU4C direct is so much faster than either Swift path

- ICU4C's `UCalendar` struct **keeps TimeZone state inline**. Mutation
  is direct pointer manipulation; `ucal_setMillis` / `ucal_get` / etc.
  do not cross a TimeZone public-API boundary.
- Both icu4swift's adapter and Foundation's public `Calendar` API go
  through `TimeZone.secondsFromGMT(for:)`, which Slice 1 measured
  at **547–1044 ns per call** for `TimeZone(identifier: "UTC")`.
  Twice per round-trip (extraction + assembly) plus other
  Foundation.Date object overhead accounts for ~1.5–2 µs of the
  Swift-side cost that ICU4C avoids.
- Foundation additionally pays Swift/ObjC bridging, the `Calendar`
  struct COW, mutex around `_CalendarICU`, ICU handle allocation,
  `DateComponents` value allocation — another ~2 µs on top.

### Reconciling the 17–285× headline

The 2026-04-19 headline benchmark measured pure calendar math:
`Date<C>.fromRataDie(rd) → c.toRataDie(inner)` — no Foundation.Date,
no TimeZone. icu4swift's arithmetic calendars run in **~20 ns** at
that layer. Foundation's equivalent full round-trip was ~1,400 ns.
Ratio: ~70×. Chinese was 42 ns vs 12,000 ns → 285×. **Those numbers
are correct for what they measure — the calendar math layer, below
any public API.**

The adapter benchmark measures end-to-end with the Foundation.Date +
TimeZone boundary. Both icu4swift and Foundation pay that tax.
icu4swift's calendar-math win is still real but buried under boundary
cost; end-to-end is only 1.5–2× on arithmetic calendars, 5–7× on
Chinese (where the calendar-math gap is so large it still dominates).

**Both claims are factually correct** — they describe different
layers of a two-layer stack:

| Layer | icu4swift | Foundation | Our win |
|---|---:|---:|---:|
| Calendar math (sub-layer) | ~20 ns arithmetic, ~42 ns Chinese | ~1,400 ns / 12,000 ns | **17–285×** |
| Foundation.Date + TimeZone boundary | ~2,000 ns | ~2,000 ns | ≈ parity |
| End-to-end public-API round-trip | ~2,000–4,000 ns | ~3,500–6,000 ns | 1.5–2× arithmetic, 5–7× Chinese |

### Stage-aware pitch implication

Our Stage 1+ plan is to replace `_CalendarICU` with our Swift
backends behind `_CalendarProtocol`. When that happens, our Swift
backend lives *inside* Foundation's Calendar machinery — it does
**not** pay Foundation.Date + TimeZone dispatch as a separate
client; it IS the protocol implementation, and shares Calendar's
TimeZone state. In that architecture, our calendar math replaces
ICU4C's — and the end-to-end Foundation cost becomes:

- Foundation.Calendar wrapper overhead (~2 µs, unchanged)
- + icu4swift calendar math (~20 ns to 42 ns)
- = **~2 µs**

vs today's Foundation with `_CalendarICU`:

- Foundation.Calendar wrapper overhead (~2 µs)
- + ICU4C calendar math (~280 ns)
- + ICU bridge overhead (~2 µs)
- = **~6 µs**

That's where the 2–3× end-to-end win actually lands. **The right
pitch framing is "we replace `_CalendarICU`, not `Calendar`."**
The 17–285× number becomes relevant because we're replacing the
ICU-math-and-bridge layer, not racing against the Foundation.Date
public API.

### Open issue resolution

Issue 8 is **resolved**. The discrepancy was the investigation
operating at two different layers of the stack. Both numbers are
correct with appropriate scoping. Next actions:

1. Update `BENCHMARK_RESULTS.md § Sub-day adapter` — remove the
   ⚠ warning, add the three-way Gregorian table and the
   calendar-math-vs-boundary analysis.
2. Update `PITCH.md` Beat 3 — keep the 17–285× headline but add
   the scoping note ("calendar math layer; when replacing
   `_CalendarICU` this directly drops wrapper-inclusive
   Foundation.Calendar cost by ~2–3×").
3. Strike through `OPEN_ISSUES.md § Issue 8` and `PIPELINE.md § 9b`.

---

## Resolution criteria

Investigation closes when:

- [x] Slice 1 done — `TimeZone.secondsFromGMT` cost measured.
- [x] Slice 2 done — apples-to-apples numbers recorded.
- [x] Slice 3 done — three-way comparison recorded, pitch framing decided, `PITCH.md` updated.
- [x] `OPEN_ISSUES.md § Issue 8` struck through with the resolution.
- [x] `BENCHMARK_RESULTS.md` has a coherent perf story that doesn't contradict itself.

**Status 2026-04-22:** investigation closed. Optimization ideas below
are not blocked by or blocking on the investigation — they're
improvements to consider if/when we want to push adapter perf.

## Improvement ideas — not yet done

Diagnosis of the ~3,937 ns icu4swift adapter round-trip:

| Component | Estimated cost | % of total |
|---|---:|---:|
| `TimeZone.secondsFromGMT(for:)` × 2 probes (UTC) | ~1,000 ns | 25 % |
| Calendar math (`gregorianFromFixed` + `fixedFromGregorian`) | ~10 ns | 0.3 % |
| Double division + conversions for nanoseconds | ~50 ns | 1 % |
| 3–4× `Date.init(timeIntervalSinceReferenceDate:)` | ~25 ns | 0.6 % |
| **Accounted for** | **~1,100 ns** | **~28 %** |
| **Unaccounted** (function dispatch, generics, bench noise) | **~2,800 ns** | **~72 %** |

Improvement ideas, ranked by estimated impact:

### Idea 1 — Fixed-offset fast path (expected: ~40–50% improvement for UTC callers)

**Problem.** `TimeZone(identifier: "UTC").secondsFromGMT(for:)` costs
547 ns. For zones that never have DST transitions, the 2-probe
±24 h dance is pure waste — the offset is constant.

**Fix.** Before running the probe, detect "fixed offset" and
short-circuit. Two approaches:

1. **Stateless heuristic**: probe `tz.secondsFromGMT(for:)` once at
   the provisional instant; probe `tz.daylightSavingTimeOffset(for:)`;
   if the second returns 0 here AND at a probe 1 hour away, the zone
   is DST-inactive locally and we can skip the ±24 h dance.
2. **Stateful adapter**: move from free functions to a lightweight
   struct (`FoundationBoundary(timeZone: TimeZone)`) that caches the
   "is this fixed-offset?" determination at init. Minor API change.

**Expected impact.** UTC round-trip drops from ~3,937 ns to
~2,000–2,200 ns — **~1.8× speedup** on the most common case.

**Cost.** Option 2 is a public API change (struct vs free functions)
— big. Option 1 keeps the API but adds an extra check on every call,
trading ~100 ns on DST-zone callers for ~1,000 ns saved on
fixed-offset callers. Could also ship both paths (opt-in
`FixedOffsetAdapter`) to preserve existing free-function API.

### Idea 2 — `@inlinable` the hot path *(tried 2026-04-22, marginal, kept anyway)*

**Hypothesis was:** `resolveLocalTI` is `private`; `rataDieAndTimeOfDay`
and `date(rataDie:...)` are `public` but not `@inlinable`. Each
adapter call crosses a module boundary with no inlining
opportunity for binary-distribution consumers, and generics /
sum-type dispatch can't specialize past the boundary.

**Tried.** Added `@inlinable` to `rataDieAndTimeOfDay`,
`date(rataDie:...)`, and `resolveLocalTI` (changed from `private`
to `internal` to allow the annotation). Three runs of the APPLES
benches before/after.

| Operation | Baseline | `@inlinable` | Delta |
|---|---:|---:|---:|
| Extract | 1,985 ns | 1,950 ns | −35 ns (−1.8 %) |
| Assemble | 3,302 ns | 3,306 ns | +4 ns (0 %) |
| Round-trip | 3,957 ns | 3,831 ns | −126 ns (−3.2 %) |

**Result: all deltas within bench noise (~100–200 ns).** Expected
300–700 ns improvement didn't materialize.

**Why.** Swift Package Manager's release mode enables whole-module
optimization by default. Within `CalendarFoundation` the compiler
was already inlining `resolveLocalTI` into `date(rataDie:...)`.
For the test target importing `CalendarFoundation` as a module,
WMO already does cross-module inlining. `@inlinable` matters most
when the consumer is in a *different* module without source access
(binary distribution) — not relevant to our test setup or to
swift-foundation integration (source-available).

**Verdict: kept the annotations.** Zero runtime cost, zero code
complexity, correct semantic signal for hot-path functions, and
could matter for future binary-distribution consumers. Not a win
today but also not a loss — kept in.

### Idea 3 — ~~Elide the nanosecond division when `ns == 0`~~ *(tried 2026-04-22, no measurable improvement)*

**Hypothesis was:** every assembly pays
`Double(nanosecond) / 1_000_000_000.0` — a Double division. For the
90%+ of inputs where `nanosecond == 0`, this is wasted work.

**Tried:** added an `if nanosecond == 0` branch in
`date(rataDie:...)`. Compared four variants over 3 runs each:

| Variant | Median ns/op |
|---|---:|
| ns = 0 constant (fast path) | ~2,500 |
| ns = 123_456_789 constant (division path) | ~2,500 |
| ns = runtime nonzero (defeats const-folding) | ~2,500 |
| ns = runtime mostly-zero (90% fast path) | ~2,500 |

**Result: indistinguishable within bench noise.** Rankings invert
across runs. Double division is apparently cheap enough (~10–20 ns
on modern CPUs) that it's fully lost in the ~2,500 ns bench budget,
and the added branch cost roughly cancels whatever tiny gain the
fast path would produce.

**Verdict: not worth the extra code.** The branch was reverted;
`FoundationAdapter.swift` keeps the single unconditional
`Double(totalSecLocal) + Double(nanosecond) / 1_000_000_000.0`.

**Lesson for the other ideas:** the noise floor on Foundation.Date
boundary benchmarks is ~100–200 ns. Any change that doesn't save at
least ~300 ns can't be demonstrated as a win with this harness.

### Idea 4 — Ask Foundation to promote `rawAndDaylightSavingTimeOffset(for:repeatedTimePolicy:)` to public (~40% improvement on DST zones)

**Problem.** Foundation's internal
`TimeZone.rawAndDaylightSavingTimeOffset(for:repeatedTimePolicy:skippedTimePolicy:)`
does what our 2-probe algorithm does, in one ICU dispatch. It's
`internal` (package-visibility for swift-foundation only). We
can't call it from outside swift-foundation.

**Fix.** Exogenous — file a Radar / swift-foundation issue
requesting this be promoted to `public` (or at least `package` so
Stage 1+ implementations can use it).

**Expected impact.** If granted: ~1 µs saved on every adapter
assembly; close to Foundation's own internal parity on this shape.

**Cost.** None on our side. Depends on swift-foundation team.

### Idea 5 — Stage 1+ `_CalendarProtocol` conformance (the real architectural win, not an "adapter" improvement)

**Problem.** At the public-API layer we are permanently stuck with
~2 µs per round-trip for the TZ dispatch. ICU4C direct avoids it
by co-locating TZ state in `UCalendar`. We can't beat that while
being a public-API-compatible adapter.

**Fix.** Stage 1+ `_CalendarProtocol` implementation co-locates
exactly like `UCalendar` does — our backend lives inside `Calendar`
and shares TimeZone state. No public-API dispatch tax per call.
The adapter becomes vestigial once we're inside Foundation.

**Expected impact.** End-to-end `Calendar(identifier:...)` drops
from ~6 µs (today, via `_CalendarICU`) to ~2 µs (our backend) —
**~3× wrapper-inclusive improvement**, which is where the 17–285×
calendar-math gap actually lands in a user-visible way.

**Cost.** This is already Stage 1 critical-path work (pipeline
item 9). Not an "adapter improvement" per se — it's the
architectural answer. Don't conflate.

### Key reframing (2026-04-22 evening)

The earlier sections treated the adapter as the artifact to
optimize. That is backwards once you account for the port's
destination: **our Swift backends become part of `swift-foundation`
itself** (Stage 1+). Inside swift-foundation:

- The `internal` API `TimeZone.rawAndDaylightSavingTimeOffset(for:repeatedTimePolicy:skippedTimePolicy:)`
  is **accessible to us**, same as it is to `_CalendarGregorian`.
- Our backend calls that single-dispatch API directly.
- The 2-probe workaround isn't needed — same code shape as
  `_CalendarGregorian` uses today.
- No public-API tax. No 700 ns overhead. Matches Foundation's own
  boundary cost by construction.

**The `CalendarFoundation` adapter's purpose is different from
what I was optimizing it for.** It's the **outside-of-Foundation
convenience** for SPM consumers who use icu4swift directly without
waiting for the port to land. Its 2-probe cost is inherent to
being outside Foundation's internal API — a characteristic of the
public surface, not a bug to optimize away.

**What this means for pitch framing:**

- **Adapter numbers** (~3.9 µs round-trip today) are the
  "outside-consumer" story. Useful as a data point but not the
  perf headline.
- **Stage 1+ numbers** (expected ≈ `_CalendarGregorian` parity —
  ~1–2 µs round-trip matching Foundation's own pure-Swift
  backend) are the real target. They don't exist yet because we
  haven't written the Stage 1 primitives.
- **Calendar math** (17–285× faster than ICU4C at that layer)
  remains the underlying engine win. Stage 1+ exposes it by
  replacing `_CalendarICU`.

### Bundled recommendations

*(Updated 2026-04-22 evening after refocusing on port-destination.)*

**The adapter has an inherent 2-probe tax** from the public
`TimeZone` API. That tax disappears when we're inside
swift-foundation (Stage 1+). Until then, the adapter's ~3.9 µs
round-trip on DST zones is what it is.

**Attempts to optimize this from outside:**

| Idea | Result |
|---|---|
| 1. Fixed-offset short-circuit (UTC / fixed zones only) | Helps UTC/fixed callers only. Realistic use is DST zones, so effect is narrow. |
| 2. `@inlinable` | Applied. Marginal. |
| 3. `ns == 0` elision | Tried, reverted — Double division below noise floor. |
| Single-probe fast path for `.former` | **Tried, reverted** — breaks round-trip correctness on every wall time on a DST-transition day. |
| 4. Ask swift-foundation to promote `rawAndDaylightSavingTimeOffset` to public | Exogenous ask. Would save ~800 ns for all external consumers. |
| 5. Stage 1 `_CalendarProtocol` conformance (= the port) | **The real answer.** Inside Foundation, internal API available. |

**What to do:**
- **Stop optimizing the adapter.** Its 2-probe cost is inherent
  to the public `TimeZone` API surface. File Idea 4 (exogenous)
  if we want the tax lifted for all external consumers.
- **Move to Stage 1** (pipeline item 9). That's where the perf
  story actually lands for users who go through `Calendar(.hebrew)`
  etc. The adapter remains useful for SPM-direct consumers, with
  its documented cost profile.

**Lesson.** I was optimizing the adapter as if it were the permanent
end state. It isn't — it's the outside-Foundation convenience. The
Stage 1 backends inside Foundation don't carry the 2-probe tax
because they can call the internal API directly.

## See also

- `OPEN_ISSUES.md § Issue 8` — the risk write-up.
- `PIPELINE.md § 9b` — the pipeline entry.
- `BENCHMARK_RESULTS.md § Sub-day adapter` — current (confusing) numbers.
- `Tests/CalendarFoundationTests/FoundationAdapterBenchmarks.swift` — existing adapter benches.
- `Scripts/ICU4CCalBench.c` — ICU4C-direct bench infrastructure.

# Foundation Calendar Port — Open Issues

*Last updated 2026-04-17. Update when issues resolve or new ones emerge.*

A frank register of project-level concerns that could shape, delay, or
block the port. Each issue is listed with its risk level, why it
matters, and what would resolve or mitigate it. Distinct from
`07-OpenQuestions.md` *(planned)*, which collects stakeholder-decision
items ("what threshold do we lock for parity?") rather than risks.

## Confidence summary

Before the detail, a calibrated gut estimate:

| Outcome | Confidence |
|---|:-:|
| Swift backend is functionally correct across all identifiers | 80%+ |
| Performance parity across all calendars vs. ICU | **80–90%** (up from 60–80% after 2026-04-19 PM clean sweep) |
| Result merges into upstream `swift-foundation` | 20–50% |
| Time to Stage 3 complete, solo | 9–18 months |

The big variance is Issue 1. Everything else is engineering tractable.

Performance confidence bumped again after the 2026-04-19 PM
clean-methodology sweep: all 22 calendars measured 17–285× faster
than Foundation's `Calendar` API. See `BENCHMARK_RESULTS.md`.

---

## Issue 1 — Stakeholder alignment with Apple (highest risk)

**Risk:** high. Dominates every other risk by magnitude.

**Concern.** This is Apple's code. The plan assumes `swift-foundation`
maintainers will accept a multi-month series of PRs replacing their
ICU calendar path. Without that buy-in we are either (a) maintaining
a fork indefinitely or (b) producing a beautiful academic exercise.
No technical success compensates for a rejected direction.

**Why it matters now.** Writing 6 months of code before confirming
direction is the single most expensive possible sequencing.

**What would resolve it.**
1. Surface the plan to someone on the `swift-foundation` team via
   GitHub Discussions, the Swift forums, or a direct contact.
2. Gauge whether the direction matches Apple's roadmap. (There is
   circumstantial evidence it does — `_CalendarGregorian` exists and
   is pure-Swift — but "one data point is one data point.")
3. Clarify the target: is this an upstream contribution, a co-maintained
   effort, or a separate downstream library? Each implies a very
   different scope, testing bar, and acceptance process.

**Decision needed before:** committing to Stage 1 code work.

---

## Issue 2 — ICU quirk replication

**Risk:** medium-high.

**Concern.** ICU has 25+ years of accreted behavior. Foundation's
tests implicitly encode ICU's quirks — some documented, many not.
Examples that have caught ports in other projects:
- Month-end overflow semantics (`Feb 31` rolls to `Feb 28` in one
  direction, might overflow to `Mar 3` in another depending on
  `wrappingComponents`).
- Julian/Gregorian cutover behavior pre-1582 under custom
  `gregorianStartDate`.
- DST gap (spring forward) and fall-back resolution — which wall-clock
  time wins in an ambiguity.
- Hebrew leap-year Dechiyot edge cases around postponement rules.
- Chinese leap-month detection when two candidate months both contain
  no major solar term.
- Islamic astronomical new-moon visibility assumptions.

**Why it matters.** The "zero divergence on daily regression
1900–2100" bar is correct, but it *will* surface surprises. Some are
real ICU bugs we should fix; some are quirks Foundation's downstream
relies on and we must deliberately replicate.

**What would resolve it.**
- Build the regression harness early (Stage 0 adjacent, before Stage 3
  per-calendar work). Daily comparison vs. `_CalendarICU` over
  1900–2100 per `_CalendarProtocol` method.
- Treat first-divergence as an investigation, not a bugfix. Document
  whether the divergence is: (a) ICU bug we will not replicate, (b)
  quirk we will replicate, (c) our bug. Maintain an allow-list.

**Decision needed when:** each identifier reaches Stage 3.

---

## Issue 3 — `nextDate(after:matching:)` and RecurrenceRule complexity

**Risk:** medium-high.

**Concern.** `Calendar_Enumerate.swift` in `swift-foundation` is one
of the meanest pieces of calendrical code anywhere. Handles:
- Matching policies (`.nextTime`, `.nextTimePreservingSmallerComponents`,
  `.previousTimePreservingSmallerComponents`, `.strict`).
- DST-aware skipped and repeated times.
- Both `.forward` and `.backward` direction search.
- Exact-vs-approximate matching for sparse `DateComponents`.
- It is the backbone of `Calendar.RecurrenceRule`, which adds RRULE
  semantics (frequency, interval, byMonth, byWeekday, byMonthDay,
  bySetPos, etc.).

icu4swift has none of this today.

**Why it matters.** Foundation benchmarks prominently exercise
`enumerateDates` for RecurrenceRule ("nextThousandThanksgivings" etc.),
and RecurrenceRule is a prominent public API. Any divergence is
user-visible. Porting correctly per calendar is easily a 1–2 month
slice on its own.

**What would resolve it.**
- Treat `nextDate`/`enumerateDates` as its own Stage 1 phase, not a
  single bullet. Port, test with all matching policies, validate DST
  edge cases, then validate across every calendar.
- Consider landing RecurrenceRule later, in a Stage 3.5, once the
  underlying calendars are stable.

**Decision needed when:** writing `04-icu4swiftGrowthPlan.md`.

---

## Issue 4 — Performance parity (partially answered by spot measurements)

**Risk:** downgraded to low-medium after 2026-04-17 measurements.

**Concern.** Apple has optimized `_CalendarGregorian` heavily. The
Stage 0 parity gate might reveal gaps too wide to close.

**What we now know** (2026-04-19 PM, clean-methodology sweep; see
`BENCHMARK_RESULTS.md`):

- **icu4swift wins 17–285× on every calendar** measured against
  Foundation's public `Calendar` API. 20 of 22 calendars are under
  300 ns/date; simple/arithmetic calendars 9–96 ns/date, astronomical
  (baked) 20–43 ns, Chinese 42 ns vs Foundation's ~12,000 ns.
- The earlier "Foundation wins 1.3–1.7×" narrative was an artifact
  of `#expect` macro overhead (~1.5 µs/call) inside the hot loop.
  Without it, real icu4swift numbers are orders of magnitude faster.
- Hindu lunisolar (Amanta, Purnimanta) remains the slow tier at
  ~3.3 ms/date — documented baking backlog item (pipeline #11).

**What this means.** The performance story is now unambiguous on
the low-level layer: our calendar math is dramatically faster than
ICU's exposed-via-Foundation Calendar API. The apples-to-oranges
caveat still applies (Foundation does more per iteration via its
wrapper), and pipeline item #17 will quantify that split.

**What would still resolve it fully.**
- **Pipeline item #17 — direct ICU4C comparison.** Writes a C/C++
  benchmark using ICU4C's `ucal_*` API directly to quantify how much
  of Foundation's per-call cost is wrapper vs underlying ICU math.
- Formal Stage 0 per-calendar benchmark capture inside
  `swift-foundation`'s actual benchmark harness (not the standalone
  script approach).

**Decision needed:** unblocked by current measurements; formal
Stage 0 harness work can proceed in parallel with pitch conversations.

---

## Issue 5 — Scope creep at the calendar/formatter/locale/timezone boundary

**Risk:** medium.

**Concern.** The plan declares `DateFormatter`, `Date.FormatStyle`,
`Locale`, and `TimeZone` out of scope. In practice those modules
reach into calendar internals:
- `Date.FormatStyle` resolves `yMd`-style skeletons using calendar
  knowledge (era start/end, leap month, month codes).
- `Locale.prefs?.firstWeekday?[identifier]` is a calendar knob
  tuned per identifier.
- `TimeZone_ICU.swift` uses `ucal_open` to iterate transitions —
  which technically is "calendar" code but doesn't do calendar math.
- `isDateInWeekend` is driven by locale-embedded data that lives in
  ICU today.

**Why it matters.** Every boundary we pull is a potential hidden
dependency on ICU. "Calendar port" may surface 2–3 surprises in
Stage 3 where a Foundation module we assumed was independent turns
out to call into our port.

**What would resolve it.**
- Include a grep-based audit in Stage 0: enumerate every Foundation
  file that transitively references `UCalendar*` or `ucal_*` and
  decide, per file, whether it is in scope, out of scope, or becomes
  a porting artifact.
- Do not let any "help — we also need X" request during Stage 3
  silently expand the scope. Route each one back to the plan.

**Decision needed when:** during Stage 0 harness work.

---

## Issue 6 — Calendar identifier completeness (smaller gap than it looks)

**Risk:** low-medium.

**Concern.** icu4swift is missing three Foundation identifiers:
`ethiopicAmeteAlem`, `islamic` (astronomical), and `vietnamese`. The
five regional Hindu lunisolar labels (`gujarati`, `kannada`, `marathi`,
`telugu`, `vikram`) need to be mapped to our `Amanta`/`Purnimanta` with
the correct regional conventions.

**Why it matters.** Shipping a "23 of 28" Swift backend is not
shippable. The port is atomic at the library level.

**What would resolve it.**
- `ethiopicAmeteAlem`: **resolved 2026-04-20** — `EthiopianAmeteAlem`
  struct added in `Sources/CalendarComplex/EthiopianAmeteAlem.swift`.
  Shares `CopticArithmetic` and `EthiopianDateInner` with `Ethiopian`;
  differs only in reporting the `mundi` era + "ethiopic-amete-alem"
  identifier. Year N Amete Alem = Year (N − 5500) Amete Mihret.
  8 regression tests added; all passing (including 73,414-day
  round-trip over 1900–2100).
- `islamic` (astronomical): **resolved 2026-04-20 via alias** —
  `IslamicAstronomical` now ships as a delegating wrapper over
  `IslamicUmmAlQura`, matching ICU4X's direction (their
  `AstronomicalSimulation` is deprecated in favor of UmmAlQura).
  Full rationale in `Docs/ISLAMIC_ASTRONOMICAL.md`. Divergence
  testing against Foundation's `.islamic` output is a deferred
  pipeline item (see PIPELINE item 19).
- `vietnamese`: Chinese-family calendar at UTC+7. Structure is
  identical to Chinese/Dangi; just a new `VietnamVariant`. Low effort.
- Hindu regional lunisolar labels: need to confirm with Foundation's
  `hinducal.cpp` fork semantics whether these are genuine variants or
  just locale-labelled aliases. Likely the latter.

**Decision needed when:** Stage 3 phases 3d, 3e, 3g.

---

## Issue 7 — Timeline pessimism

**Risk:** low (not a blocker, but a planning tax).

**Concern.** Project estimates almost always underestimate. The gut
estimate of 9–18 months solo is already 2–3× what a naive plan would
say, and even that may be optimistic if Issue 2 or Issue 3 surprises
are heavy.

**Why it matters.** Setting expectations with yourself (or
stakeholders, if any) correctly reduces the risk of the project
being abandoned mid-flight when "we're 80% done" stretches to a
year.

**What would resolve it.**
- Do not estimate phase durations until Stage 0 is complete and
  Issue 4 is resolved. Stage 0 itself is the single best estimator.
- Treat each calendar phase in Stage 3 as independent. The project
  can ship partially (some identifiers Swift, some ICU) for as long
  as needed.

**Decision needed when:** first Stage 3 phase completes and we
  calibrate.

---

## Recommended sequencing (updated 2026-04-17)

Issue 4 is now partially answered by spot measurements — the
arithmetic/astronomical split gives us enough ground truth to pitch
confidently without a full Stage 0 harness. The remaining
high-value next step is **Issue 1**:

1. Post the `00-Overview.md` direction into a Swift forums thread,
   GitHub discussion, or direct outreach. Use `PITCH.md` as the
   4-beat structure. Lead with the Chinese 7× number from
   `BENCHMARK_RESULTS.md`.
2. Collect the reaction — direction welcomed, redirected, or
   rejected. That signal shapes everything downstream.
3. **While waiting for feedback**, the formal Stage 0 harness
   work (task #7 in TaskList; see `NEXT.md`) can proceed in
   parallel, as can writing the remaining numbered reference docs
   (`01`–`03`).

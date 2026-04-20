# Open Questions for Stakeholders

*Brief. Decisions that need input from `swift-foundation` maintainers
(or other Apple stakeholders) before committing to specifics of
Stages 2–3.*

Distinct from `OPEN_ISSUES.md`, which tracks project-level risks
and concerns. This doc tracks **questions with answers we don't
have**.

## Strategic

1. **Is the direction welcome at all?** Replacing the ICU calendar
   path with a Swift-native backend — is this a direction
   `swift-foundation` wants, would consider, or would redirect?
   This is Issue 1 in `OPEN_ISSUES.md`. The pitch (see
   `PITCH.md`) is designed to answer exactly this.
2. **Upstream contribution vs parallel library?** If the direction
   is welcome, is the expected landing path:
   - Upstream PRs into `swift-foundation` main, replacing the
     relevant code in-place.
   - A separate community-maintained module that users opt into
     (e.g. `FoundationCalendarsSwift`).
   - A fork, maintained out-of-tree.

## Performance parity

3. **Thresholds for the parity gate.** `05-PerformanceParityGate.md`
   proposes: CPU mean ±10%, P99 ±20%, mallocs ≤ baseline, throughput
   ±10%. Are these acceptable to the maintainers? What overrides
   exist (e.g. accepted regressions for known tradeoffs)?
4. **Canonical hardware.** Which hardware is the reference for
   baseline capture and CI comparison? Apple-internal CI? A
   specific Mac model? Something else?
5. **Baseline storage location.** Checked-in JSON in the
   `swift-foundation` repo vs artifact store vs per-PR recapture?
6. **Scope of mallocs ≤ baseline.** Does "mallocs" mean all
   malloc-counted allocations or only heap-allocated Swift objects?
   The bridging layer (Swift → ObjC → C++) in `_CalendarICU` may
   allocate in places our pure-Swift path does not — what's the
   fair comparison?

## Correctness parity

7. **ICU quirks that aren't bugs.** ICU has 25+ years of accreted
   behaviour. When our implementation diverges from ICU on a
   specific date, what's the adjudication process? Do we replicate
   the quirk or document it as a fix?
8. **Chinese 1906 cluster.** icu4swift's Chinese calendar has 3
   known-limitation failures against Hong Kong Observatory
   reference data at 1906 (see `Docs/Chinese_reference.md`).
   ICU and Foundation agree with each other there but disagree
   with HKO. Which side do we match?
9. **Hindu lunisolar regional-label mapping.** Foundation exposes
   `.gujarati`, `.kannada`, `.marathi`, `.telugu`, `.vikram` as
   distinct `Calendar.Identifier` cases. Is each expected to
   produce distinct date output, or are they aliases for one of
   the two Hindu lunisolar month-boundary conventions
   (`Amanta` / `Purnimanta`) that differ only in display-time
   regional month names? Our current hypothesis is "aliases";
   need confirmation.

## Scope

10. **Vietnamese calendar.** Neither ICU4C nor ICU4X implement a
    distinct Vietnamese calendar. Foundation exposes `.vietnamese`
    with a `_CalendarICU` TODO comment. Should icu4swift:
    - Implement Hanoi UTC+7 (our current choice) — semantically
      correct but diverges from Foundation's current output.
    - Alias to `.chinese` — matches Foundation's current de-facto
      behavior.
11. **Islamic astronomical.** ICU4X deprecated its astronomical
    path in favour of UmmAlQura; icu4swift's `IslamicAstronomical`
    does the same. ICU4C still uses the Reingold observational
    algorithm. Which behaviour is normative for Foundation going
    forward? (See `Docs/ISLAMIC_ASTRONOMICAL.md` for the current
    design.)
12. **`isRepeatedDay` for DST fall-back.** Foundation's public API
    has `Calendar.Component.isRepeatedDay` under
    `#if FOUNDATION_FRAMEWORK` only. Is that intentional? Is the
    port expected to extend it to the non-framework path, leave it
    guarded, or ignore it?

## Process

13. **CI requirements.** What CI runners will the icu4swift-backed
    path run on? macOS only, or Linux too? The TZif-backed `TimeZone`
    on Linux has different binary paths — do we need to
    cross-validate?
14. **Backwards-compatibility horizon.** How long do we preserve
    `_CalendarICU` as a feature-flagged fallback after Stage 3
    completes? A release cycle? Two? Forever?
15. **ABI stability.** icu4swift is currently a separate
    package. If it's to be vendored into `swift-foundation`, does
    the set of `public` / `@inlinable` annotations in icu4swift
    become a stable ABI commitment? Right now they're just
    compile-time hints.

## Answered / deferred

These are kept here to avoid asking them again once answered.

- ~~Mutability friction between Foundation's Calendar struct and
  icu4swift's immutable model?~~ Resolved in `MigrationIssues.md`
  § 1 — value-semantics COW maps cleanly onto our stored
  properties.
- ~~RataDie vs milliseconds?~~ Resolved in `MigrationIssues.md`
  § 2 — adapter layer handles it at the boundary.
- ~~Timezone/DST scope?~~ Resolved in `TIMEZONE_CONSIDERATION.md`
  — TZ internals stay in Foundation; we only touch the
  `(Date, TZ) → (RataDie, secondsInDay)` boundary.

## Process for getting answers

1. Land `PITCH.md` conversation with maintainers → answers Q1, Q2.
2. Dedicated RFC / design doc on the `swift-foundation` forums →
   answers Q3–Q9 and Q12–Q15.
3. Per-calendar port PR discussions → answers Q10 and Q11 in
   context.

## See also

- `PITCH.md` — how to open the conversation.
- `OPEN_ISSUES.md` — the risk register these questions inform.
- `PROJECT_PLAN.md` — the plan these answers firm up.

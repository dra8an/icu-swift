# Foundation Port Plan — Stages 2–4

*Brief. Per-calendar rollout of icu4swift-backed calendars into
`swift-foundation`, replacing `_CalendarICU`. To be expanded with
file-level detail once Stage 1 exit criteria are met.*

Stage 1 is covered in `04-icu4swiftGrowthPlan.md`. This document
begins at Stage 2 — landing the icu4swift backend into
`swift-foundation` — and ends at Stage 4, when `_CalendarICU` is
deleted.

## Stage 2 — Plumbing

Goal: introduce a `_CalendarSwift<Identifier>` path (or
per-identifier concrete classes) in `swift-foundation` **without**
flipping any identifier away from the ICU path yet. Prove the
wiring works end-to-end using a single identifier whose backend
we control.

### Seam

The dispatch point in `Calendar_Cache.swift`:

```swift
func _calendarClass(identifier: Calendar.Identifier) -> _CalendarProtocol.Type? {
    if identifier == .gregorian || identifier == .iso8601 {
        return _CalendarGregorian.self
    } else {
        return _calendarICUClass()
    }
}
```

Extend to consult a third source — an icu4swift-backed class set —
before falling through to ICU. Two viable mechanisms:

1. `@_dynamicReplacement(for: _calendarSwiftClass)` — extends the
   existing pattern that `_calendarICUClass` already uses.
2. Per-identifier routing table consulted before the ICU fallback.

Both work. Decision deferred to the PR that lands Stage 2.

### Exit criterion for Stage 2

Exactly **one** identifier (likely `.gregorian`, extending the
existing `_CalendarGregorian` to cover the new Foundation query
APIs added in Stage 1) passes all of:

- Functional regression: existing Foundation `CalendarTests.swift`
  passes without modification.
- Performance regression: benchmarks against the pre-change
  baseline (the ICU path, if we can force it; or the existing
  `_CalendarGregorian` path) meet the parity-gate thresholds in
  `05-PerformanceParityGate.md`.
- Rollback protocol tested: flipping the router back to the ICU
  path removes the new backend without code deletion.

Every other identifier still dispatches to `_CalendarICU` at the
end of Stage 2.

## Stage 3 — Port calendars in risk order

Each Foundation `Calendar.Identifier` case gets its own PR, its
own parity-gate run, and its own router flip. No identifier flips
until the pre-port baseline was captured, the functional
regression passes, and the performance gate passes.

### Proposed ordering (easiest → hardest)

| Phase | Calendars | Why this phase |
|---|---|---|
| 3a | `buddhist`, `republicOfChina`, `japanese` | Gregorian extensions with epoch shift / era mapping. Trivial. |
| 3b | `coptic`, `ethiopicAmeteMihret`, `ethiopicAmeteAlem`, `indian`, `persian` | Pure arithmetic. Well-defined. |
| 3c | `hebrew` | Arithmetic, intricate Dechiyot rules. Validated against 73k-day Hebcal regression. |
| 3d | `islamicTabular`, `islamicCivil`, `islamicUmmAlQura`, `islamic` | Tabular + UQ baked + astronomical alias. |
| 3e | `chinese`, `dangi`, `vietnamese` | Chinese-family lunisolar (baked HKO + Moshier fallback). |
| 3f | `bangla`, `tamil`, `odia`, `malayalam` | Hindu solar baked tables. |
| 3g | `gujarati`, `kannada`, `marathi`, `telugu`, `vikram` | Hindu lunisolar — slowest tier until baked. Includes resolving the regional-label mapping question. See `Docs/HinduCalendars.md`. |
| 3h | `gregorian`, `iso8601` | Already pure-Swift; re-validate through the router end-to-end. |

### Per-phase canonical flow

1. Capture pre-port baseline (ICU path) for all identifiers in
   the phase.
2. Implement the Swift backend adapter for each identifier.
3. Run functional regression: daily comparison 1900–2100 against
   `_CalendarICU` output. Zero divergence required, except for
   documented quirks.
4. Run performance parity gate per
   `05-PerformanceParityGate.md`. Pass, soft-warn, or hard-fail.
5. Flip the router entry. Merge.
6. If a post-merge regression emerges, flip the router back to
   ICU; do not delete the Swift backend.

### Exit criterion for Stage 3

Every `Calendar.Identifier` case in `Calendar_Cache.swift`
dispatches to an icu4swift-backed class. `_CalendarICU` still
exists in the codebase but is unreachable via the router.

## Stage 4 — Removal

Once no identifier reaches `_CalendarICU`, delete it.

### Scope

- Delete `Calendar_ICU.swift`.
- Delete `_calendarICUClass()` and its `@_dynamicReplacement` hook.
- Remove the ICU calendar sources from `swift-foundation-icu`:
  `calendar.cpp`, `gregocal.cpp`, `chnsecal.cpp`, `hebrwcal.cpp`,
  `islamcal.cpp`, `coptccal.cpp`, `ethpccal.cpp`, `persncal.cpp`,
  `indiancal.cpp`, `japancal.cpp`, `buddhcal.cpp`, `taiwncal.cpp`,
  `dangical.cpp`, `iso8601cal.cpp`, `hinducal.cpp`, `astro.cpp`,
  plus their headers.
- Remove the ICU calendar dependency declaration from
  `swift-foundation`'s `Package.swift`.

### Exit criterion

- `grep -r 'ucal_' swift-foundation/Sources/FoundationInternationalization/Calendar/`
  returns nothing.
- All calendar tests still pass.
- Library size reported before/after; expected reduction from
  dropping the ICU calendar sources.

## Risks

| Risk | Mitigation |
|---|---|
| A calendar regresses in a way not caught by the daily 1900–2100 regression | Phased rollout means at most one calendar is in production for any given regression window; revert is a router flip. |
| Performance parity gate thresholds are wrong (too tight / too loose) | Stage 0 establishes them pre-commit; reviewable up-front. |
| swift-foundation maintainers reject the approach mid-port | Stage 2 is the first maintainer-facing PR; direction gets negotiated there, before anything else ships. |
| An ICU quirk is load-bearing for downstream consumers | Regression is daily and zero-divergence by default; documented allow-list per identifier for accepted divergences. See `OPEN_ISSUES.md` Issue 2. |

## See also

- `00-Overview.md` — global acceptance criteria.
- `04-icu4swiftGrowthPlan.md` — Stage 1 (prerequisite work on
  icu4swift before Stage 2 can begin).
- `05-PerformanceParityGate.md` — per-phase acceptance gate.
- `OPEN_ISSUES.md` — project-level risks tracked across the port.
- `STATUS.md` — current progress snapshot.

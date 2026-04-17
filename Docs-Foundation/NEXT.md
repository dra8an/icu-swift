# Foundation Calendar Port — Next

*Last updated 2026-04-17. Update whenever work shifts.*

Near-term pipeline. For the full roadmap see `PROJECT_PLAN.md`; for
current snapshot see `STATUS.md`.

## Immediate next (this week or next session)

1. **Write `01-FoundationCalendarSurface.md`** — concrete map of
   `_CalendarProtocol`, the three existing backends, dispatch via
   `CalendarCache`, and the integration seam. Source material is the
   exploration-agent report from 2026-04-17; distilling it into
   durable form.
2. **Write `02-ICUSurfaceToReplace.md`** — the 17 `ucal_*` functions,
   their Foundation call sites, the C++ classes behind each, and
   what each semantic means for a Swift reimplementation.
3. **Write `03-CoverageAndSemanticsGap.md`** — identifier map and
   capability gap table (most of the raw material is already in
   `00-Overview.md` § scope and in the agent reports; needs
   organizing into one reference).

## Short-term (next few sessions)

4. **Write `04-icu4swiftGrowthPlan.md`** — Stage 1 roadmap. Break
   down the icu4swift capability additions into phases with
   acceptance criteria and a test strategy. This is the doc that
   unblocks actual code work.
5. **Write `05-PerformanceParityGate.md`** — design the parity
   harness. Decide thresholds. Specify how baselines are captured,
   stored, and compared.
6. **Write `06-FoundationPortPlan.md`** — per-calendar port detail
   for Stage 3. Order, gates, rollback policy.
7. **Write `07-OpenQuestions.md`** — collect alignment items for
   stakeholders before Stage 1 code work begins.

## Medium-term (once docs are complete)

8. **Begin Stage 0** — extend `BenchmarkCalendar.swift` in
   `swift-foundation` to cover every identifier × operation. Capture
   the ICU baseline. Check in results.
9. **Begin Stage 1, Phase 1** — TBD; defined in
   `04-icu4swiftGrowthPlan.md` once written.

## Deferred / parked

- Actual code in `swift-foundation` — blocked until Stage 0 baselines
  are in the repo.
- `icu4swift` archival — Stage 4 only.
- Hindu lunisolar baked data in `icu4swift` — already documented
  in `icu4swift/Docs/BakedDataStrategy.md` as a backlog item;
  orthogonal to the Foundation port.

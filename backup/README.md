# backup/ — Local Snapshot Strategy

This directory holds **temporary local snapshots** of work-in-progress code that is not yet stable enough to commit to git. It exists so we can experiment freely while still being able to roll back to a known state if a refactor goes wrong.

## When to snapshot

Take a snapshot whenever:
- You reach a state that is measurably better than the current best (fewer failures, faster, etc.) but still not commit-ready.
- You are about to attempt a significant refactor that may make things worse.
- You want to compare two competing approaches side-by-side.

**Do not** use this for permanent history — that's what git is for. Snapshots are throwaway and may be deleted at any time once the work lands in git.

## Naming convention

`snapNN_<short-status>_<short-description>/`

- `NN` is a zero-padded sequence number.
- `<short-status>` describes the measurable quality (e.g. `22fail`, `0fail`, `passing`).
- `<short-description>` describes the approach being tried.

Each snapshot directory contains:
- The modified source/test files (preserving their relative paths is optional — pick a flat layout if there are only a few files).
- A `NOTES.md` describing what's in the snapshot, what works, what doesn't, and the path forward.

## How to roll back

```bash
cp backup/snapNN_<name>/<file>.swift Sources/.../<file>.swift
```

Re-run tests to confirm you're back at the snapshot's known state.

---

## Snapshot log

### snap00_22fail_baseline/

**Date:** 2026-04-08
**Test state:** 22 regression failures (out of 2461 month-rows checked) against `chinese_months_1901_2100_hko.csv`.

The Chinese calendar with the **`nm11 = newMoonOnOrBefore(solstice)`** fix applied. This is the best-known stable state. The single-pass algorithm with the `hasLeapMonth` gate is robust against false-positive leap detection at boundary precision cases, but it cannot detect M11L-style leaps (e.g. year 2033) because those leaps fall in the *next* sui.

Failure clusters: 2033-2035 (rare leap M11), 2057, 2052-2053.

### snap01_51fail_rewrite/

**Date:** 2026-04-08
**Test state:** 51 regression failures.

Rewrite of `compute()` to use a `findNewYear` helper, calling it for both the current and next year, then iterating exactly 12 months and applying the "13th month is leap if no leap detected" fallback (matching ICU4X's `month_structure_for_year`). This **does** correctly handle M11L cases (year 2033 leap is now structurally findable), but removing the `hasLeapMonth` gate exposed a class of false-positive leap detections at boundary-precision cases (notably year 2033 month 7, where the autumnal equinox falls just after local midnight in Beijing and Moshier's high precision puts it in the wrong 30° bucket compared to HKO).

Strictly worse than snap00 in failure count, but structurally closer to the right algorithm. Superseded by snap02.

### snap03_3fail_epsilon/

**Date:** 2026-04-08
**Test state:** 3 regression failures. Current best known state.

Adds a sub-10-second midnight epsilon snap to `newMoonOnOrAfter`: when the new moon's local moment falls within `1e-4` days (~8.6 s) AFTER local midnight, snap it back to the previous day. This fixes the 2057 M08→M09 cluster (Moshier placed that new moon 3.5 seconds past midnight Beijing) with no other regressions. Only the 1906 M03→M04 cluster remains, which is an 8-minute discrepancy in the opposite direction (not a rounding issue — a real Moshier-vs-HKO model disagreement).

### snap02_6fail_lastmatch/

**Date:** 2026-04-08
**Test state:** 6 regression failures. Best known state. All 23 unit tests still pass.

Builds on snap01 by adding two guards: (1) take the **last** same-term pair in the 12-iter loop instead of the first (real leap is typically later than any boundary-precision false positive), (2) only commit a leap if `current != nextNewYear` after 12 iterations (a 12-month year cannot have a leap, so any detected match is dropped).

Remaining failures are in two clusters (1906 and 2057), both showing month-length 29-vs-30 + 1-day-shift patterns that look like new-moon RataDie rounding at midnight boundaries — a different bug class from the leap-month detection issue this snapshot fixed.

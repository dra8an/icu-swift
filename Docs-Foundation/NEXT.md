# Foundation Calendar Port — Next

> **⚠ 2026-04-22 evening: icu4swift frozen. Port moved to public `swift-foundation`.**
> See `PORT_DIRECTION.md`. All new "next task" tracking happens inside
> swift-foundation, not here. The single-next-task box below is FROZEN
> and no longer applicable.

## The single next task

**Resume at:** `/Users/draganbesevic/Projects/claude/swift-foundation`.

**First step:** set up a working area for our calendar backends. Port one
calendar end-to-end (Gregorian-family or Hebrew — either works) as a
`_CalendarProtocol` conformance inside swift-foundation. Wire it into
`CalendarCache._calendarClass(identifier:)` behind a build flag. Run
Foundation's own test suite against it.

Detailed shape in `PORT_DIRECTION.md`. Reference reading order listed
in `Docs/HANDOFF.md` top banner.

---

*Pre-freeze content below (kept for historical reference).*

---

*Originally last updated 2026-04-19 PM (session end). Single focused next task.
Pulls from `PIPELINE.md`.*

**Updated only at session end.** This file holds the one task to
pick up when resuming work. Do not update during the session —
track in-flight progress in `PIPELINE.md` instead.

## The single next task (pre-freeze, superseded)

### Direct ICU4C benchmark for apples-to-apples comparison
*(pipeline item 17)*

**Why now:** Today's clean-methodology sweep showed icu4swift at
17–285× faster than Foundation's public `Calendar` API. The number
is real but carries an apples-to-oranges asterisk — Foundation's
API does more per iteration (TZ conversion, sparse `DateComponents`,
mutex, ICU state machine) than our raw RataDie round-trip. The
honest comparison is against **ICU4C's calendar math directly**,
skipping the Swift/Foundation wrapper. That's the last credibility
piece before the pitch conversation.

**What to build:**

A small C (or C++) benchmark program that uses ICU4C's `ucal_*` C
API directly:

- Source: `/Users/draganbesevic/Projects/claude/icu/icu4c/` (already
  cloned); alternatively the swift-foundation-icu fork at
  `/Users/draganbesevic/Projects/claude/swift-foundation-icu/icuSources/`.
- Link against the ICU library. Typical flags:
  `-licuuc -licui18n` (verify on macOS build).
- Same shape as existing benches: warm-up excluded, checksum,
  release-equivalent optimization (`-O2` or `-O3`).
- Iteration count: start with 100,000 for fast calendars, scale
  down for astronomical if needed.
- Start date: 2024-01-01 UTC (match our existing benchmarks).

Per-iteration shape — full round-trip mirroring what Foundation
does internally, minus the Swift/ObjC bridge:

```c
ucal_setMillis(cal, millis, &status);
UChar32 era   = ucal_get(cal, UCAL_ERA, &status);
UChar32 year  = ucal_get(cal, UCAL_YEAR, &status);
UChar32 month = ucal_get(cal, UCAL_MONTH, &status);
UChar32 day   = ucal_get(cal, UCAL_DATE, &status);
UChar32 leap  = ucal_get(cal, UCAL_IS_LEAP_MONTH, &status);
ucal_clear(cal);
ucal_set(cal, UCAL_ERA, era);
ucal_set(cal, UCAL_YEAR, year);
ucal_set(cal, UCAL_MONTH, month);
ucal_set(cal, UCAL_DATE, day);
if (leap) ucal_set(cal, UCAL_IS_LEAP_MONTH, leap);
UDate back = ucal_getMillis(cal, &status);
checksum += back;
```

**Coverage (minimum):** gregorian, hebrew, chinese, coptic, persian,
islamic, japanese. Extend to all 28 identifiers if feasible.

**Output:** three-way table in
`Docs-Foundation/BENCHMARK_RESULTS.md`:

| Calendar | icu4swift (our math) | ICU4C direct (their math) | Foundation Calendar (their math + Swift/ObjC wrapper) |

The gap between column 2 and column 3 is the wrapper cost
Foundation pays. The gap between column 1 and column 2 is the
genuine calendar-math speedup.

**Scope of work (rough):**

1. Set up build environment for ICU4C from the cloned source
   (configure + make, or Xcode project, or CMake). About an hour.
2. Write the bench program (~200 lines of C). An hour.
3. Run for each calendar, median of 3 runs. Half hour.
4. Update `BENCHMARK_RESULTS.md` with the three-way table and
   interpretation. An hour.
5. Reframe the pitch numbers in `PITCH.md` Beat 3 if the split is
   surprising.

Total: **1–2 days**. The ICU4C build setup is the unknown; the
bench code is straightforward.

**Exit criterion:** three-way table in `BENCHMARK_RESULTS.md`,
`PITCH.md` Beat 3 updated with the clean story, pipeline item 17
struck through.

## How this doc is used

- Holds exactly **one** active next task.
- **Updated at session end only** — reflects what the next session
  should pick up.
- For in-flight work and candidate list, see `PIPELINE.md` (updated
  freely during a session).
- For stage-level roadmap, see `PROJECT_PLAN.md`.
- For current-state snapshot, see `STATUS.md`.

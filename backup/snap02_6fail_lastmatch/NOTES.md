# snap02_6fail_lastmatch

**Date:** 2026-04-08
**Test state:** 6 regression failures (out of 2461 month-rows). All 23 Chinese/Dangi unit tests pass.

## Approach

Builds on snap01's `findNewYear`-helper rewrite (which correctly handles M11L cases like year 2033) by adding two guards that suppress the false-positive leap detection problem snap01 introduced:

1. **Take the LAST same-term pair** in the 12-iteration loop, not the first. When boundary precision causes a false positive (typically earlier in the year, when a zhōngqì falls within ~1 hour of local midnight in Beijing), the *real* leap is later in the year, so the last match wins.
2. **Only commit a leap if there's actually a 13th month** (`current != nextNewYear` after 12 iterations). 12-month years can't have a leap, so any same-term pair detected in a 12-month year is necessarily a false positive and is dropped.

## Remaining failures (6 total, 2 clusters)

Both are **astronomical precision boundaries** at the limit of Moshier-vs-HKO agreement:

- **1906 M03→M04 boundary** (3 failures): Moshier puts the April 1906 new moon at LMT moment `695899.9945` = **Apr 23 23:52:04 LMT** — 8 minutes before midnight. HKO puts it on Apr 24. Our code (and ICU4X qing_data which is HKO-derived) disagree by 8 minutes.

- **2057 M08→M09 boundary** (3 failures): Moshier puts the September 2057 new moon at Beijing moment `751211.0000403` = **Sep 29 00:00:03 Beijing** — 3.5 seconds after midnight. HKO puts it on Sep 28.

The two cases require **opposite** rounding directions (1906 needs round-up, 2057 needs round-down), so no simple snap-to-nearest tolerance rule fixes both. The actual root cause is sub-minute-level differences between Moshier (VSOP87 / DE404, ±1 arcsec) and HKO's astronomical model (likely Purple Mountain Observatory's high-precision JPL-based ephemeris). Both new moons fall within ~8 minutes of local midnight in their respective time zones, where any precision difference flips the day.

Tried but did not work:
- Switching pre-1929 from Beijing LMT to UTC+8 — fixed 1906 but broke 1914, 1916, 1920 (net 6 → 13).
- Snap-to-nearest-day rounding — only one direction works for each case.

These 6 failures represent the practical floor of what's achievable with Moshier vs HKO. To reach 0 failures we would need to either (a) embed a JPL-grade ephemeris matching HKO's source, or (b) hand-correct these specific years.

## Why this is a substantial improvement over snap00

snap00 (22 failures): single-pass algorithm with `hasLeapMonth` gate. Cannot detect M11L-style leaps because they fall in a different sui from the year being computed. The 2033-2035 cluster (16 of the 22 failures) was unfixable in that architecture.

snap02 (6 failures): structurally correct algorithm (compute newYear and nextNewYear separately, iterate between them) that handles M11L. The remaining 6 failures are unrelated boundary-precision issues, not architectural.

## Path forward

The remaining 1906 and 2057 failures need investigation of `newMoonOnOrAfter` / `newMoonOnOrBefore` precision at the day boundary. Likely fix: when the new moon Moment is within ~1 minute of midnight Beijing, audit which day it belongs to using a more precise check, rather than naively truncating to RataDie.

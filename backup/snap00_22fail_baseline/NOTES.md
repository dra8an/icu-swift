# snap00_22fail_baseline

**Status:** Best known state. 22 regression failures vs HKO CSV.

## Key fix
- `nm11 = newMoonOnOrBefore(solsticeRd)` (was `newMoonOnOrAfter` — that was off by one new moon).
- `nextNm11 = newMoonOnOrBefore(nextSolsticeRd)`.
- `hasLeapMonth = (moonsBetweenSolstices == 13)`.
- `newYearIndex = 2` default, 3 if leap M11/M12 detected.
- 16 new moons enumerated.

## Remaining failure clusters
- 2033-2035 (16 failures): rare leap M11 of Chinese year 2033. Algorithm doesn't handle M11L because M11L falls in the *next* sui (sui 2033-2034), not the sui used to compute year 2033.
- 2057 (3 failures): one month length 29 vs 30 + day shift.
- 2052-2053 (3 failures): residual.

## Why the rewrite (snap01) was worse
The rewrite computes `newYear` and `nextNewYear` separately and iterates between them, properly handling the M11L case. But it removes the `hasLeapMonth` gate, exposing **false-positive leap detection** at boundary precision cases (e.g., year 2033 month 7 — autumnal equinox 2033 falls at ~03:51 Beijing on Sep 23, after midnight, so Moshier returns same major term for Aug 25 and Sep 23 lunar months, falsely flagging Aug 25 as leap).

## Path forward
The right fix is to sample solar longitude at the **new moon's actual moment** (not its local-midnight RD). That requires extending the engine API to return the new moon as a Moment, not just a RataDie, then sampling longitude at that exact moment.

# Test Coverage and Documentation Status

*Last updated: 2026-04-22*

This is the master index of per-calendar documentation and regression-test
coverage. Update it whenever a new calendar doc, regression test, or
reference CSV lands. The intent is for any future contributor (human or
agent) to see at a glance which calendars are deeply validated and which
still rely only on hand-picked unit tests.

## Per-Calendar Status

| Calendar | `Docs/X.md` | `Docs/X_reference.md` | Regression Test | Reference Source |
|---|:---:|:---:|:---:|---|
| **ISO** | – | – | n/a | Trivial arithmetic; unit-tested, no regression needed |
| **Gregorian** | – | – | n/a | ISO + era labels; unit-tested, no regression needed |
| **Julian** | – | – | n/a | Single leap rule (`y%4==0`); unit-tested, no regression needed |
| **Buddhist** | – | – | n/a | ISO + 543 offset; unit-tested, no regression needed |
| **ROC** | – | – | n/a | ISO − 1911 offset; unit-tested, no regression needed |
| **Hebrew** | ✅ [`Hebrew.md`](Hebrew.md) | ✅ [`Hebrew_reference.md`](Hebrew_reference.md) | ✅ 73,414 / 0 | Hebcal (`@hebcal/core`) |
| **Coptic** | – | – | ✅ 3,266 / 0 | Foundation + convertdate |
| **Ethiopian** | – | – | ✅ 3,266 / 0 | Foundation + convertdate |
| **Persian** | ✅ [`Persian.md`](Persian.md) | ✅ [`Persian_reference.md`](Persian_reference.md) | ✅ 3,064 / 0 | Foundation + convertdate |
| **Indian (Saka)** | – | – | ✅ 3,216 / 0 | Foundation + convertdate |
| **Japanese** | ✅ [`CalendarJapanese.md`](CalendarJapanese.md) | – | ✅ 2,744 / 0 | Foundation (era mapping, 1873–2100) |
| **Islamic Tabular** | ✅ [`Islamic.md`](Islamic.md) | ✅ [`Islamic_reference.md`](Islamic_reference.md) | ✅ 73,414 / 0 | Foundation + convertdate |
| **Islamic Civil** | ✅ shared | ✅ shared | ✅ 73,414 / 0 | Foundation + convertdate |
| **Islamic Umm al-Qura** | ✅ shared | ✅ shared | ✅ 4,380 / 0 | Foundation (baked KACST data, 1300–1600 AH) |
| **Islamic (astronomical)** | ✅ [`ISLAMIC_ASTRONOMICAL.md`](ISLAMIC_ASTRONOMICAL.md) | – | – (delegates to UmmAlQura) | Deferred: divergence test vs Foundation's `.islamic` (PIPELINE item 19) |
| **Ethiopian Amete Alem** | – (shares `Ethiopian.md` scope) | – | ✅ 73,414 / 0 | Internal round-trip (shares arithmetic with `Ethiopian`, era surface-differs) |
| **Vietnamese** | – (shares `Chinese.md` scope) | – | ✅ 1,045 / 0 round-trip | Internal consistency (shares `ChineseCalendar<V>` generic; neither ICU4C nor ICU4X implement Vietnamese, so no external reference) |
| **Chinese** | ✅ [`Chinese.md`](Chinese.md) | ✅ [`Chinese_reference.md`](Chinese_reference.md) | ⚠️ 2,461 / 3 | Hong Kong Observatory |
| **Dangi** | ✅ [`Dangi.md`](Dangi.md) | – | deferred | Structurally identical to Chinese (different longitude only); KASI data available via `korean_lunar_calendar_py` if needed |
| **Hindu Tamil** (solar) | ✅ [`HinduCalendars.md`](HinduCalendars.md) | – | ✅ 1,811 / 0 | built-in CSV |
| **Hindu Bengali** (solar) | ✅ shared | – | ✅ 1,811 / 0 | built-in CSV |
| **Hindu Odia** (solar) | ✅ shared | – | ✅ 1,811 / 0 | built-in CSV |
| **Hindu Malayalam** (solar) | ✅ shared | – | ✅ 1,811 / 0 | built-in CSV |
| **Hindu Amanta** (lunisolar) | ✅ shared | – | ✅ 55,152 / 0 | built-in CSV |
| **Hindu Purnimanta** (lunisolar) | ✅ shared | – | ✅ 55,152 / 0 | built-in CSV |

Legend: regression `✅ N / F` = N rows checked, F failures.

## Cross-calendar extreme-range coverage

Two complementary exhaustive suites in `Tests/ExtremeRangeTests/`:

**`ExtremeRataDieTests.swift`** — two-point smoke test at `RataDie(±10_000_000_000)` (~±27 M years, ~27× past `RataDie.validRange`). Proves `fromRataDie → toRataDie` doesn't overflow Int64 at endpoints. Astronomical calendars (Chinese, Dangi, Vietnamese, Hindu) excluded — Moshier's precision envelope is ~±3,000 years.

**`RoundTripStabilityTests.swift`** (added 2026-04-22) — **every day** across ±10,000 ISO years (7,305,216 days × 16 arithmetic calendars = 116,883,456 round-trips), all zero-divergence, runs in ~1.1 s in release mode.

**All 16 covered arithmetic calendars pass both suites**: ISO, Gregorian, Julian, Buddhist, ROC, Coptic, Ethiopian, Ethiopian Amete Alem, Persian, Indian, Hebrew, Japanese, Islamic Civil, Islamic Tabular, Islamic Umm al-Qura (exercises both baked table and fallback to Islamic Civil), Islamic Astronomical.

The extreme-range exercise surfaced **three Hebrew bugs** at negative RDs, all fixed 2026-04-22. Each was caused by Swift's `/` truncating toward zero where the R&D algorithms assume floor division, and each manifested at a different negative-RD scale:

1. **`hebrewFromFixed` year approximation** — truncating division in the year estimate skewed one year high at extreme negatives, stranding the forward-only search loop past the true year and producing a negative day-of-year remainder that trapped a later `UInt8` init. Fixed by routing through a `floorDiv` helper. (Trap at ~−365 M RD.)
2. **`calendarElapsedDays` return type** — `Int32`, but intermediate `days` scales as ~365 × year and overflowed Int32 at year ≈ ±5.88 M. Widened to `Int64`. (Trap at ~±2.2 B RD.)
3. **`calendarElapsedDays` internal divisions** — `(235·year − 234) / 19` and `partsElapsed / 25920` still used truncating `/`, producing a ~29-day offset at year ≈ −6,223 and below. Fixed by floor-div on both. (Silent bug surfaced by the exhaustive ±10k-year test.)

Hebrew 1900–2100 Hebcal regression (73,414 days) remained zero-divergence through all three fixes — modern-range behaviour was never affected.

## Coverage Gaps Worth Closing

**Deferred:**

- **Dangi** — structurally identical to Chinese (same algorithm, same leap rules), differing only in reference longitude (Seoul UTC+9 vs Beijing UTC+8). Differences only appear when a new moon falls in the ~1-hour window between Korean and Chinese midnight. KASI (Korea Astronomy and Space Science Institute) has an Open API and the Python `korean_lunar_calendar_py` library embeds KASI-sourced lookup tables for 1000–2050. No Foundation `.korean` calendar exists. Low priority — can be revisited if Dangi-specific bugs surface.

**No regression needed:**

- ISO / Gregorian / Julian / Buddhist / ROC — trivial arithmetic (same in every implementation); unit tests are sufficient. Marked `n/a` in the table above.

## Adding a New Regression — Pattern

When a new calendar regression is added, follow the existing convention so
the suite stays uniform:

1. **Pick at least one independent reference source.** Foundation
   (`Calendar(identifier:)`) is convenient; pair it with something
   non-ICU-derived (Hebcal, convertdate, HKO, etc.) for true independence.
2. **Generate a CSV** in `Tests/<TargetTests>/<calendar>_<range>.csv`.
   Use `iso_year,iso_month,iso_day,...` as the leading columns.
3. **Cross-validate the two reference sources** before writing the test —
   if Foundation and the independent source disagree, *that* is the first
   thing to investigate, not your implementation.
4. **Write a regression test** in `Tests/<TargetTests>/<Calendar>RegressionTests.swift`,
   gated by `FileManager.default.fileExists` so check-outs without the CSV
   still build.
5. **Document it** in `Docs/<Calendar>_reference.md` (data sources,
   regenerate scripts, cross-validation procedure).
6. **Update this file** — add or upgrade the row in the table above.

### Performance note

For purely arithmetic calendars, Foundation's `dateComponents` in a tight
loop is slow due to Swift→ObjC→ICU bridging cost. A daily corpus (~73k
rows) takes minutes. Prefer a sparse sample (first-of-month, year
boundaries) when month lengths are fixed and the only variable is leap-year
placement — see `Persian_reference.md` for the rationale.

## Maintenance

This document must be updated whenever:

- A new `Docs/X.md` or `Docs/X_reference.md` is added.
- A new regression test or reference CSV lands.
- An existing regression's pass count changes materially (e.g. a known
  limitation is fixed or a new failure cluster appears).

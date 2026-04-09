# Test Coverage and Documentation Status

*Last updated: 2026-04-08*

This is the master index of per-calendar documentation and regression-test
coverage. Update it whenever a new calendar doc, regression test, or
reference CSV lands. The intent is for any future contributor (human or
agent) to see at a glance which calendars are deeply validated and which
still rely only on hand-picked unit tests.

## Per-Calendar Status

| Calendar | `Docs/X.md` | `Docs/X_reference.md` | Regression Test | Reference Source |
|---|:---:|:---:|:---:|---|
| **ISO** | – | – | – | (trivial, unit-tested) |
| **Gregorian** | – | – | – | (trivial, unit-tested) |
| **Julian** | – | – | – | (unit-tested) |
| **Buddhist** | – | – | – | (Gregorian + offset) |
| **ROC** | – | – | – | (Gregorian + offset) |
| **Hebrew** | ✅ [`Hebrew.md`](Hebrew.md) | ✅ [`Hebrew_reference.md`](Hebrew_reference.md) | ✅ 73,414 / 0 | Hebcal (`@hebcal/core`) |
| **Coptic** | – | – | – | unit-tested only |
| **Ethiopian** | – | – | – | unit-tested only |
| **Persian** | ✅ [`Persian.md`](Persian.md) | ✅ [`Persian_reference.md`](Persian_reference.md) | ✅ 3,064 / 0 | Foundation + convertdate |
| **Indian (Saka)** | – | – | – | unit-tested only |
| **Japanese** | ✅ [`CalendarJapanese.md`](CalendarJapanese.md) | – | – | unit-tested with era data |
| **Islamic Tabular** | ✅ [`Islamic.md`](Islamic.md) | ✅ [`Islamic_reference.md`](Islamic_reference.md) | ✅ 73,414 / 0 | Foundation + convertdate |
| **Islamic Civil** | ✅ shared | ✅ shared | ✅ 73,414 / 0 | Foundation + convertdate |
| **Chinese** | ✅ [`Chinese.md`](Chinese.md) | ✅ [`Chinese_reference.md`](Chinese_reference.md) | ⚠️ 2,461 / 3 | Hong Kong Observatory |
| **Dangi** | ✅ [`Dangi.md`](Dangi.md) | – | – | unit-tested only |
| **Hindu Tamil** (solar) | ✅ [`HinduCalendars.md`](HinduCalendars.md) | – | ✅ 1,811 / 0 | built-in CSV |
| **Hindu Bengali** (solar) | ✅ shared | – | ✅ 1,811 / 0 | built-in CSV |
| **Hindu Odia** (solar) | ✅ shared | – | ✅ 1,811 / 0 | built-in CSV |
| **Hindu Malayalam** (solar) | ✅ shared | – | ✅ 1,811 / 0 | built-in CSV |
| **Hindu Amanta** (lunisolar) | ✅ shared | – | ✅ 55,152 / 0 | built-in CSV |
| **Hindu Purnimanta** (lunisolar) | ✅ shared | – | ✅ 55,152 / 0 | built-in CSV |

Legend: regression `✅ N / F` = N rows checked, F failures.

## Coverage Gaps Worth Closing

**Quick wins (pure arithmetic, Foundation + convertdate available):**

- **Coptic** — Foundation has `.coptic`. Pure arithmetic, leap rule is `year % 4 == 3`.
- **Ethiopian** — Foundation has `.ethiopicAmeteMihret` and `.ethiopicAmeteAlem`. Same arithmetic family as Coptic.
- **Indian (Saka)** — Foundation has `.indian`; convertdate has `indian_civil`. Pure arithmetic, Gregorian-tied.

**Harder:**

- **Dangi** — astronomical, structurally Chinese with a Korean reference longitude. KASI (Korean Astronomy and Space Science Institute) publishes lunisolar tables but they're less accessible than HKO. Would parallel the Chinese regression with potentially the same kind of model-vs-observed precision issues.

**Don't need anything:**

- ISO / Gregorian / Julian / Buddhist / ROC — arithmetic is identical across every implementation in existence; unit tests are sufficient.

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

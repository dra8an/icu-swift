# Hong Kong Observatory Reference Data

This document describes the **authoritative Chinese calendar reference data** we use for regression testing the Chinese (and by extension Dangi) calendar implementation.

## Source

The Hong Kong Observatory (HKO) publishes a Gregorian-Lunar Calendar Conversion Table for every year from **1901 through 2100** as plain-text files:

```
https://www.hko.gov.hk/en/gts/time/calendar/text/files/T{YEAR}e.txt
```

For example: <https://www.hko.gov.hk/en/gts/time/calendar/text/files/T2023e.txt>

Years outside `[1901, 2100]` return HTTP 404. HKO is widely regarded as authoritative for the modern Chinese calendar (along with Purple Mountain Observatory in Mainland China and KASI in Korea), and their data has been cross-checked against Swiss Ephemeris (JPL DE431) for the cases we have spot-verified.

## File format

Each file is a daily table. The relevant rows for our purposes are the lines that mark the start of a new lunar month:

```
2023/2/20         2nd Lunar Month         Monday
2023/3/22         2nd Lunar Month         Wednesday
2023/4/20         3rd Lunar Month         Thursday       Corn Rain
```

**Leap month convention:** HKO does **not** use the words "leap" or "intercalary" anywhere in the file. Instead, **a leap month is encoded as the same ordinal number appearing twice in a row**. In the example above, "2nd Lunar Month" appears at both 2023/2/20 and 2023/3/22 — the second occurrence is the **leap 2nd month** (M02L). The next month (2023/4/20) is then labelled "3rd Lunar Month".

Older files (pre-1990s) use slightly different formatting: lowercase "month", zero-padded dates (`1944/01/25`), but the same leap convention.

## How we downloaded the data

```bash
mkdir -p Data/hko_raw
for y in $(seq 1901 2100); do
  curl -s -o "Data/hko_raw/T${y}e.txt" \
    "https://www.hko.gov.hk/en/gts/time/calendar/text/files/T${y}e.txt"
done
```

Result: 200 files, ~5.7 MB total. The raw files are preserved verbatim under `Data/hko_raw/` so we can re-derive any computed view from them without re-fetching.

## How we transform it for tests

The script `Data/build_hko_csv.py` parses every file in `Data/hko_raw/`, extracts the lunar month start events, and emits a single CSV at `Data/chinese_months_1901_2100_hko.csv` with columns:

```
related_iso,month_number,is_leap,month_length,greg_year,greg_month,greg_day
```

- `related_iso` — the Gregorian year in which the lunar year's 1st month begins (i.e. the year of Chinese New Year for that lunar year).
- `month_number` — the 1-indexed lunar month number (1-12). Leap months keep the same number as the regular month they follow (HKO convention).
- `is_leap` — `1` if this row is a leap month (the second consecutive same-numbered month in HKO), else `0`.
- `month_length` — number of days in the month, derived from the difference between consecutive new moon start dates. Always 29 or 30.
- `greg_year`, `greg_month`, `greg_day` — Gregorian start date of this lunar month.

The generator skips Chinese years that aren't fully bounded in the HKO data (it needs the next year's first month to compute the final month's length), so the CSV covers Chinese years **1901 through 2099** — 199 years, 2,461 month rows, of which 73 are leap months (~36.7%, matching the expected 7-leaps-per-19-year metonic cycle).

To regenerate after any change to the raw files or the script:

```bash
python3 Data/build_hko_csv.py
```

## How tests use it

`Tests/CalendarAstronomicalTests/ChineseRegressionTests.swift` reads `chinese_months_1901_2100_hko.csv` (currently a copy lives at `Tests/CalendarAstronomicalTests/chinese_months_1901_2100_hko.csv`) and, for every row, computes the corresponding Chinese date from the Gregorian start day and asserts:

- `month.number` matches `month_number`
- `month.isLeap` matches `is_leap`
- `dayOfMonth` is 1 (the row should land exactly on the month start)
- `extendedYear` matches `related_iso`
- `daysInMonth` matches `month_length`

Each disagreement is counted; the test fails if any disagreements remain.

## Why HKO and not ICU4X's precomputed tables

We originally used a CSV derived from ICU4X's `china_data.rs` precomputed table. That CSV had a generator bug (off-by-one in interpreting ICU4X's `Some(N)` ordinal-position encoding as a display number) that produced ~121 false failures. Switching to HKO eliminated that entire class of false alarms and gave us a primary source rather than a downstream-derived one.

The remaining real disagreements (post-HKO-switch) are precision issues in the Chinese calendar implementation, not data issues. As of 2026-04-08 the regression test is at **3 failures out of 2,461 month rows** (~99.88% accuracy), all in a single 1906 cluster that represents a real Moshier-vs-HKO astronomical model disagreement. See `backup/snap03_3fail_epsilon/NOTES.md` for details and the progression through snap00-snap03.

## Verifying against HKO manually

To check what HKO says about a specific year:

```bash
grep "Lunar [Mm]onth" Data/hko_raw/T2023e.txt
```

The output is the chronological list of lunar month starts in that Gregorian year. Look for repeated month numbers to spot leap months.

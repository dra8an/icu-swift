# Hebrew Calendar Regression Testing

## Background

Unlike the Chinese calendar, the modern rabbinical Hebrew calendar involves
**no astronomical calculations**. Since Hillel II fixed the calendar (~358 CE),
it is fully deterministic — based on:

- A fictional **mean molad** (29d 12h 793 halakim ≈ 29.530594 days), constant.
- The **19-year metonic leap cycle** (years 3, 6, 8, 11, 14, 17, 19 are leap).
- Four **dehiyyot** (postponement rules) for Rosh Hashanah.
- Six possible year lengths: 353, 354, 355, 383, 384, 385 days (14 keviyot).

Every correct implementation should agree bit-for-bit with every other correct
implementation. Any disagreement is a plain bug — there are no precision or
ephemeris caveats as with Chinese.

## Reference Source: Hebcal

We use [**@hebcal/core**](https://www.npmjs.com/package/@hebcal/core), the
open-source JavaScript library behind hebcal.com — the canonical online Hebrew
calendar. ICU4X itself cites hebcal.com/converter in its Hebrew tests.

The package is installed **outside** the project to keep `icu4swift/` clean:

```
/Users/draganbesevic/Projects/claude/CalendarAPI/
├── node_modules/@hebcal/core   ← installed here
├── package.json
└── icu4swift/                   ← our Swift project
```

`@hebcal/core` is ESM-only, so scripts must use `node --input-type=module` (or
a `.mjs` file) and must be run from the parent directory so Node finds the
module — `node -e` does **not** walk parent directories looking for
`node_modules`.

## Generated Reference Data

**File:** `Tests/CalendarComplexTests/hebrew_1900_2100_hebcal.csv`
**Rows:** 73,414 (every Gregorian day from 1900-01-01 to 2100-12-31)
**Format:**

```
iso_year,iso_month,iso_day,heb_year,heb_month_name,heb_day
1900,1,1,5660,Sh'vat,1
...
```

`heb_month_name` is Hebcal's English month name, including the leap-year
distinction `Adar I` / `Adar II`. Month names found in the dataset:

```
Tishrei, Cheshvan, Kislev, Tevet, Sh'vat,
Adar (common years), Adar I, Adar II (leap years),
Nisan, Iyyar, Sivan, Tamuz, Av, Elul
```

### Regenerating the CSV

```bash
cd /Users/draganbesevic/Projects/claude/CalendarAPI
node --input-type=module -e "
import {HDate} from '@hebcal/core';
import {writeFileSync} from 'fs';
const start = new Date(Date.UTC(1900,0,1));
const end   = new Date(Date.UTC(2100,11,31));
const out = ['iso_year,iso_month,iso_day,heb_year,heb_month_name,heb_day'];
for (let t=start.getTime(); t<=end.getTime(); t+=86400000) {
  const d = new Date(t);
  const gy=d.getUTCFullYear(), gm=d.getUTCMonth()+1, gd=d.getUTCDate();
  const h = new HDate(new Date(gy, gm-1, gd));
  out.push(\`\${gy},\${gm},\${gd},\${h.getFullYear()},\${h.getMonthName()},\${h.getDate()}\`);
}
writeFileSync('icu4swift/Tests/CalendarComplexTests/hebrew_1900_2100_hebcal.csv', out.join('\n')+'\n');
"
```

## The Regression Test

**File:** `Tests/CalendarComplexTests/HebrewRegressionTests.swift`
**Suite:** `Hebrew Regression`

For each row the test:

1. Converts ISO → `RataDie` via `GregorianArithmetic`.
2. Builds `Date<Hebrew>.fromRataDie(rd, calendar: hebrew)`.
3. Maps Hebcal's month name → our **civil** month ordinal (Tishrei = 1) using
   the year's leap status:
   - Common: Tishrei=1 … Sh'vat=5, Adar=6, Nisan=7 … Elul=12
   - Leap:   Tishrei=1 … Sh'vat=5, Adar I=6, Adar II=7, Nisan=8 … Elul=13
4. Asserts year, civil month ordinal, and day-of-month all match.

The test is gated by file existence — if the CSV is absent it prints `SKIP`
and passes, so check-outs without the fixture still build.

## Result

```
Hebrew regression: checked 73414 days, failures 0
✔ Test "Hebrew daily conversions: 1900-2100 vs Hebcal" passed after 0.287s
```

**0 disagreements over ~201 years of daily data.** Our Hebrew implementation
(ported from ICU4X's Reingold/Dershowitz arithmetic) matches Hebcal's
independent implementation bit-for-bit. As expected for a purely arithmetic
calendar, there is no ambiguity to investigate.

## Comparison with ICU4X's Hebrew Tests

ICU4X (`components/calendar/src/cal/hebrew.rs`) ships only ~4 Hebrew test
functions and **no precomputed tables** — they rely on the algorithm being
provably correct. Our 73k-row regression is therefore stricter than the
upstream test suite while remaining cheap (0.29s).

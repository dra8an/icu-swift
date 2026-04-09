# Persian Calendar Regression Testing

## Background

The Persian (Solar Hijri) calendar can be implemented two ways:

- **Astronomical** — leap years derived from the actual vernal equinox in
  Tehran. This is the *official* civil definition used in Iran and
  Afghanistan.
- **33-year arithmetic rule** with a correction table — a fast tabular
  approximation. icu4swift uses this approach (matching ICU4X / ICU4C).

Across the modern era the two algorithms produce identical Nowruz dates;
divergences only appear far in the future. Validating against an
*astronomical* reference therefore proves both that our 33-year rule is
implemented correctly **and** that it agrees with the official calendar
where it matters.

## Reference Sources

### 1. Foundation `Calendar(identifier: .persian)`

```swift
var p = Calendar(identifier: .persian)
p.timeZone = TimeZone(identifier: "UTC")!
```

Foundation wraps ICU4C, which uses the **same 33-year rule + correction
table** as us. This validates our porting accuracy.

### 2. Python [`convertdate.persian`](https://pypi.org/project/convertdate/)

```bash
pip3 install --user convertdate
python3 -c "from convertdate import persian; print(persian.from_gregorian(2025,3,21))"
# (1404, 1, 1)
```

`convertdate.persian` computes the **actual** vernal equinox for each year
using astronomical formulas. This is a genuinely independent implementation
in a different language with a different algorithmic approach.

The fact that Foundation and convertdate agree across the full 1900–2100
range is a strong indication that the 33-year arithmetic rule (Foundation /
us) and the astronomical Solar Hijri (convertdate) are bit-identical
throughout the modern era.

## Why a Sparse Sample, Not a Daily Corpus

Persian has fixed month lengths (six 31-day months, five 30-day months, and
either 29 or 30 days for Esfand). Once two implementations agree on:

1. The Nowruz date (year boundary), and
2. The leap-year flag (length of Esfand)

…they automatically agree on every other day of the year. There is no
internal day-by-day variation to catch.

Additionally, calling Foundation's `dateComponents` in a 73,414-iteration
tight loop is **extremely slow** because each call traverses the
Swift→ObjC→ICU bridge. Persian doesn't compute astronomy inside ICU, but
the bridging cost alone makes a daily corpus take minutes.

A sparse sample of ~15 days per year covers all observable behavior at a
fraction of the cost.

## Generated Reference Data

**File:** `Tests/CalendarComplexTests/persian_1900_2100.csv`
**Rows:** 3,064
**Format:**

```
g_year,g_month,g_day,p_year,p_month,p_day
1900,3,21,1279,1,1
1900,3,22,1279,1,2
1900,4,21,1279,2,1
...
```

For each Persian year 1279..1479 AP (≈ Gregorian 1900..2100), the corpus
emits:

- 12 first-of-month days (Nowruz covered as M1 D1)
- Day 2 of Farvardin (extra new-year boundary)
- Last days of Esfand: 28, 29, 30 (exercises common-vs-leap year length —
  day 30 only emitted for leap years where Foundation accepts it)

≈ 15 samples × 201 years ≈ 3,000.

### Regenerating the CSV

```swift
// gen_persian.swift
import Foundation
var iso = Calendar(identifier: .gregorian); iso.timeZone = TimeZone(identifier: "UTC")!
var p = Calendar(identifier: .persian); p.timeZone = TimeZone(identifier: "UTC")!

var lines = ["g_year,g_month,g_day,p_year,p_month,p_day"]
for py in 1279...1479 {
    for pm in 1...12 {
        if let d = p.date(from: DateComponents(year: py, month: pm, day: 1)) {
            let g = iso.dateComponents([.year,.month,.day], from: d)
            lines.append("\(g.year!),\(g.month!),\(g.day!),\(py),\(pm),1")
        }
    }
    if let d = p.date(from: DateComponents(year: py, month: 1, day: 2)) {
        let g = iso.dateComponents([.year,.month,.day], from: d)
        lines.append("\(g.year!),\(g.month!),\(g.day!),\(py),1,2")
    }
    for testDay in [28, 29, 30] {
        if let d = p.date(from: DateComponents(year: py, month: 12, day: testDay)) {
            let back = p.dateComponents([.year,.month,.day], from: d)
            if back.year == py && back.month == 12 && back.day == testDay {
                let g = iso.dateComponents([.year,.month,.day], from: d)
                lines.append("\(g.year!),\(g.month!),\(g.day!),\(py),12,\(testDay)")
            }
        }
    }
}
try lines.joined(separator: "\n")
    .write(toFile: "Tests/CalendarComplexTests/persian_1900_2100.csv",
           atomically: true, encoding: .utf8)
```

```bash
swift gen_persian.swift   # ~1 second
```

### Cross-validating with `convertdate`

```bash
python3 -c "
from convertdate import persian
mismatches = 0
total = 0
with open('Tests/CalendarComplexTests/persian_1900_2100.csv') as f:
    next(f)
    for line in f:
        gy,gm,gd,py,pm,pd = [int(x) for x in line.strip().split(',')]
        cy,cm,cda = persian.from_gregorian(gy,gm,gd)
        total += 1
        if (cy,cm,cda) != (py,pm,pd):
            mismatches += 1
            print(f'{gy}-{gm}-{gd}: F={py}-{pm}-{pd} C={cy}-{cm}-{cda}')
print(f'total {total}, mismatches {mismatches}')
"
# total 3064, mismatches 0
```

## The Regression Test

**File:** `Tests/CalendarComplexTests/PersianRegressionTests.swift`
**Suite:** `Persian Regression`

For each row the test:

1. Parses ISO and Persian triples.
2. Converts ISO → `RataDie` via `GregorianArithmetic`.
3. Builds `Date<Persian>.fromRataDie(rd, calendar: persian)`.
4. Asserts `extendedYear`, `month.ordinal`, and `dayOfMonth` all match.

The test is gated by file existence — if the CSV is missing it prints
`SKIP` and passes, so check-outs without the fixture still build.

## Result

```
Persian regression: checked 3064 sample points, failures 0
✔ Test "Persian 1900-2100 sample vs Foundation+convertdate" passed after 0.007 seconds
```

**0 disagreements.** Three independent implementations (icu4swift,
ICU4C/Foundation, convertdate) agree exactly on every Nowruz, every month
boundary, and every leap-year flag across 200+ years.

## Diagnostic Background

This regression suite was added after the Hebrew and Islamic Tabular suites
caught real bugs that hand-picked unit tests had missed for months. Persian
came up clean — no bugs found — but the suite is in place for the same
reason: it's the only check that exercises *every* leap year in the modern
era and would catch any future regression in either the 33-year formula or
the correction table.

# RataDie vs. Julian Day — why icu4swift uses RD as its pivot

*Closed decision. Written 2026-04-20 in response to "is there any
reason to work with RD and not JD?" Kept here so the next time it
comes up, this doc is the answer.*

## The question

icu4swift's universal pivot is `RataDie` (midnight-based, epoch
1 January year 1 ISO). Astronomical code in `AstronomicalEngine`
works in Julian Day (JD, noon-based, epoch 1 January 4713 BCE
Julian). Would the library be simpler or better if **RD were
replaced by JD throughout**?

## The answer

**No.** Several concrete reasons to keep RD; no concrete reason to
switch.

## Why RD is the right primitive for a calendar library

### 1. Reingold & Dershowitz's "Calendrical Calculations" uses RD

Every calendar algorithm in icu4swift — Hebrew, Coptic, Ethiopian,
Persian, Islamic, Chinese, Hindu, etc. — was ported from R&D or from
ICU4X, which itself ports from R&D. The formulas are published in
terms of R.D. Switching to JD would mean re-deriving every formula
with a `−1,721,424.5` offset folded in, or applying the offset in
every conversion path. Zero functional benefit; ample opportunity for
a sign-flip bug.

### 2. ICU4X uses RD

Our other reference implementation (`icu4x/components/calendar`) uses
RataDie as its fixed-day primitive. Matching lets us port
line-for-line. Switching to JD would be copy-with-translation plus
offset-rewriting on top.

### 3. Civil-day boundaries

Every civil calendar — Gregorian, Hebrew, Chinese, Islamic, you name
it — defines "this day" as a 24-hour block starting at civil
midnight (in some timezone). **RD integers map 1:1 to civil days.**
JD integers land at noon; they straddle two civil days. For a
library whose job is calendar arithmetic, JD is the wrong-shape
primitive — you would constantly `floor(jd + 0.5)` to recover a
civil day, which is RD with a constant offset in disguise.

### 4. Foundation's adapter internals don't leak

`_CalendarGregorian` inside swift-foundation uses JD as a scratch
representation. Its **public `Date` API does not expose JD** — it
exposes `timeIntervalSinceReferenceDate`. Our Foundation adapter
talks to `Foundation.Date`, not to `_CalendarGregorian`'s scratch
variables. Matching Foundation's internal JD choice buys us nothing
at the API boundary; it would just be picking up their scratch
representation for fashion. See
`Docs-Foundation/SUBDAY_BOUNDARY.md` for the adapter-shape decision.

### 5. Precision

- `RataDie` is `Int64` day count — exact at any era.
- JD-as-`Double` at 2024 (JD ≈ 2,460,310) loses ~4 fractional
  decimal digits vs RD-as-Int64.

Not a functional problem, but a real loss — once you commit to JD
as your primitive, you have to carry it as Double to keep fractional
days representable, and Double precision degrades with magnitude.

## Why the RD/JD split hasn't caused bugs

Astronomy in icu4swift happens in JD, calendar math happens in RD,
and the two meet at exactly one place: `Moment.jdOffset`.

```swift
// Sources/AstronomicalEngine/Moment.swift
private static let jdOffset: Double = 1_721_424.5

public static func fromJulianDay(_ jd: Double) -> Moment {
    Moment(jd - jdOffset)
}
public func toJulianDay() -> Double {
    inner + Self.jdOffset
}
```

The flow:

```
RataDie  ──►  Moment (midnight-based Double fractional RD)
                │
                ▼  .toJulianDay()  (adds 1,721,424.5)
              Double JD (noon-based)  ──►  Moshier / sunrise / VSOP
                │
                ▼  result as JD
              .fromJulianDay(_:)
                │
                ▼  .rataDie  (floor)
             civil day returned
```

**Most astronomical formulas are differential** — they work with
`T = (JD − 2451545.0) / 36525.0`, centuries since J2000. A constant
epoch offset drops out of any difference. Whether you carry RD or JD
internally doesn't affect the *astronomy*, only the *boundary
conversion constant*. So we carry whichever representation is right
for each layer, and convert once at the seam.

The `+0.5`, `−0.5`, `jd0h + 0.5`, etc. that appear in astronomy
source files are Julian Day's **internal** noon/midnight convention
(JD integers are noons; `jd + 0.5` is "noon of that JD day" — a
half-day adjustment *within* JD, unrelated to RD).

## What switching would cost

- **All 28 calendars** touch RataDie directly — every
  `fromRataDie` / `toRataDie` path. All would need rewriting.
- **338 tests** assert RataDie values. All would need updating.
- **`Moment`** would need inverted conversion. Same CPU cost,
  opposite sign — zero net benefit.
- **`DateArithmetic`** extends `Date<C>` through `toRataDie` /
  `fromRataDie`. All would need updating.
- **Sub-day boundary doc** (`Docs-Foundation/SUBDAY_BOUNDARY.md`) —
  would need revising because the "no `-43200` noon-nudge" remark
  is RD-specific.

**What we'd gain:** nothing. The `jdOffset` add is a single
`Double + Double` at the astronomical-engine boundary; its CPU cost
is essentially zero.

## Where the question might plausibly come up again

- A new contributor sees `Moment.jdOffset = 1_721_424.5` and wonders
  why it's there. Answer: because JD is noon-based and RD is
  midnight-based; the constant reconciles them.
- Someone wants to match Foundation's `_CalendarGregorian`
  internally. Answer: Foundation's **public** API is `Date`, not JD;
  the adapter matches the public surface, not the internals.
- An astronomer wants an API in JD directly. Answer: use
  `Moment.fromJulianDay(_:)` / `.toJulianDay()` — they exist for
  exactly this.

## Summary

| Factor | RD (current) | JD (hypothetical) |
|---|---|---|
| Matches R&D book | ✓ | — |
| Matches ICU4X | ✓ | — |
| Civil-day alignment | ✓ | — (noon-straddled) |
| Foundation-boundary compatibility | ✓ (same-cost adapter) | — (same-cost adapter) |
| Int64 precision at any era | ✓ | — (Double-bounded) |
| Astronomy cost | 1 constant add | 0 |
| Calendar cost | 0 | 1 constant subtract per formula |
| Porting tax | 0 | very high |

RD is not a historical accident — it's the right primitive for a
calendar library. It's called "calendar math" for a reason; JD is
astronomy math.

## Cross-references

- `CLAUDE.md § Key Design Decisions` — declares RataDie as "the
  universal day-count pivot" for all calendar conversions.
- `Sources/CalendarCore/RataDie.swift` — the type itself.
- `Sources/AstronomicalEngine/Moment.swift` — the RD↔JD bridge.
- `Docs-Foundation/SUBDAY_BOUNDARY.md` — Foundation-adapter decision;
  references RD's midnight alignment as the reason we skip the
  `−43200` noon-nudge `_CalendarGregorian` needs.

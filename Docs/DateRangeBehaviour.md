# Date Range Behaviour

*Written 2026-04-22. How each calendar family behaves as dates move
far from the modern era. Complements `Docs/BakedDataStrategy.md`
(which documents baked-table ranges) by focusing on what happens
**outside** those ranges — including the astronomical-engine
fallbacks and where precision degrades vs stays stable.*

## TL;DR

- `RataDie.validRange` is **±365,000,000 days** (≈ ±1 million
  years) from R.D. 1 — a documentation marker, not an enforced
  guard. Matches ICU4X's range and comfortably brackets ECMAScript
  Temporal's stated validity (±100M days from 1970-01-01).
- Nothing prevents constructing a `RataDie` outside that range.
  `Int64` holds values up to ~9.2 × 10^18; `RataDie(10_000_000_000)`
  compiles and runs without complaint.
- **What happens when you *use* it depends on the calendar family.**
  Three tiers:
  - **Arithmetic calendars** — stable across essentially `Int64`.
  - **Astronomical calendars using `HybridEngine`** — degrade
    gracefully to Meeus-polynomial precision across ±10,000 years.
  - **Astronomical calendars using `MoshierEngine` directly** —
    silently divergent once past ~1700–2150 CE.
- One concrete **backlog item**: Hindu calendars use `MoshierEngine`
  directly. Switching them to `HybridEngine` would unlock
  ±10,000-year graceful degradation at ~1 hour of work.

## `RataDie.validRange` — the documented envelope

From `Sources/CalendarCore/RataDie.swift:35–39`:

```swift
/// The valid range for dates (~±999,999 ISO years).
///
/// This matches ICU4X's range, which is guaranteed to be at least as large as
/// the Temporal specification's validity range (±100,000,000 days from 1970-01-01).
public static let validRange: ClosedRange<RataDie> =
    RataDie(-365_000_000)...RataDie(365_000_000)
```

- **Introduced:** first commit (`fc44b59` "Init") — inherited from
  the ICU4X-shaped initial port, not added in response to a bug.
- **Used as:** a contract marker only. Referenced in the doc
  comment on `CalendarProtocol.fromRataDie(_:)` ("the `RataDie` is
  assumed to be within `RataDie.validRange`") but not checked.
- **Temporal alignment:** Temporal's spec defines `nsMaxInstant =
  10⁸ × nsPerDay` (spec/instant.html) and `CheckISODaysRange` as
  "within the range of 10⁸ days from the epoch" (spec/abstractops.html).
  Our range is ~3.65× larger.

## Per-family range behaviour

### Tier 1 — Arithmetic calendars (stable across essentially `Int64`)

Round-trip correctness only requires `Int64` arithmetic. Year
values fit in `Int32` out to ~±2 billion years.

| Calendar | Notes |
|---|---|
| Gregorian | `yearFromFixed` uses 400/100/4/1-year cycle divisions; intermediates stay well inside `Int64`. |
| Julian | Same shape as Gregorian. |
| ISO 8601 | Gregorian-backed, identical range. |
| Buddhist | Gregorian-backed with era shift. |
| Republic of China (ROC) | Gregorian-backed with era shift. |
| Coptic | `CopticArithmetic` — integer arithmetic. |
| Ethiopian Amete Mihret + Amete Alem | Coptic-backed with era offset. |
| Indian (Śaka) | Pure arithmetic. |
| Hebrew | Metonic-cycle + molad integer math; at astronomical year counts (10⁶+) coefficients stay inside `Int64`. |
| Persian | 33-year cycle + 78-entry leap correction table; binary search stable. |
| Islamic Civil | `floor((30 × diff + 10646) / 10631)`. `Int64`-stable. |
| Islamic Tabular | Same formula as Civil, different epoch. |
| Islamic Umm al-Qura | Baked data 1300–1600 AH (~1882–2174 CE); **outside the baked range, falls back to Islamic Civil's pure arithmetic** → stable across all of `Int64`. |

Year numbering may become semantically meaningless far from the
calendar's historical era (no one cares what Hebrew year 10,000,000
is), but the conversion is *arithmetically* correct — round-trip
stable, no overflow, no NaN.

### Tier 2 — Astronomical calendars using `HybridEngine` (graceful ±10,000-year degradation)

| Calendar | Engine | Inside 1700–2150 | Outside |
|---|---|---|---|
| Chinese | `HybridEngine` via `ChineseCalendar.swift:381` | Moshier — JPL DE431 parity, ~1″ | Reingold (Meeus) — ±10,000 years at lower precision |
| Dangi (Korean) | Same | Same | Same |
| Vietnamese (`ChineseCalendar<Vietnam>`) | Same | Same | Same |

`HybridEngine` is in `Sources/AstronomicalEngine/HybridEngine.swift`.
It dispatches by `Moment` value:

```swift
// RD for Jan 1, 1700 and Jan 1, 2150
private static let modernStart: Double = 620654.0   // ~1700-01-01
private static let modernEnd:   Double = 785010.0   // ~2150-01-01
```

Every one of the six operations (`solarLongitude`,
`lunarLongitude`, `newMoonBefore`, `newMoonAtOrAfter`, `sunrise`,
`sunset`) branches on `isModern(moment)`. Outside the modern
window, calls route to `ReingoldEngine` which uses the Meeus
polynomial approximations from *Calendrical Calculations*
(~±10,000 years of useful accuracy).

Chinese / Dangi / Vietnamese also have a **baked-data fast path**
for 1901–2099 via `ChineseYearTable` (packed UInt32 per year).
Inside that range, no astronomical computation at all; outside,
`ChineseYearCache` calls `HybridEngine` directly. So the full
degradation curve is:

1. **1901–2099:** table lookup, sub-100 ns.
2. **1700–1900 and 2100–2150:** HybridEngine → Moshier,
   microseconds.
3. **Outside 1700–2150:** HybridEngine → Reingold, microseconds
   at lower precision.
4. **Outside ±10,000 years:** Reingold's polynomial accuracy
   degrades; results are *formally* stable but no longer
   authoritative.

### Tier 3 — Astronomical calendars using `MoshierEngine` directly (silent divergence)

| Calendar | Engine | Range behaviour |
|---|---|---|
| Hindu solar (Tamil / Bengali / Odia / Malayalam) | `MoshierEngine` (`HinduSolar.swift:218, 223`) | Inside ~1700–2150: accurate. Outside: silently divergent. |
| Hindu lunisolar (Amanta / Purnimanta) | Same pattern | Same |

`HinduSolar.swift` plumbs `engine: MoshierEngine` through every
critical-time calculation:

```swift
static func criticalTimeJd(_ jdMidnightUt: Double, _ loc: Location,
                           engine: MoshierEngine) -> Double
```

No fallback, no branching. Outside the validated Moshier window,
the truncated VSOP87 coefficients diverge silently — no NaN, no
error, just wrong. The daily 1900–2100 regression vs the Hindu
reference data sits comfortably inside the modern window, so this
gap is invisible in testing.

### Tier 4 — Era-overlay calendars

| Calendar | Behaviour far from historical range |
|---|---|
| Japanese | Era table (Meiji → Reiwa) stops at Reiwa (2019-05-01). Before Meiji and after the last era entry, falls through to Gregorian (era-less). Arithmetic-stable for all of `Int64`. |

## The Hindu gap — backlog item

Hindu calendars *could* use `HybridEngine` the same way Chinese
does. Current state (`HinduSolar.swift:218, 223`):

```swift
private let engine: MoshierEngine
...
self.engine = MoshierEngine()
```

Changing those two lines and the `engine:` parameter declarations
(~10 sites in `HinduSolar.swift`, similar count in the lunisolar
sources) to `HybridEngine` should be ~1 hour of mechanical work
plus a re-run of the 1900–2100 regression tests. The regression
sits inside the modern window, so it shouldn't move — the win is
purely outside the window.

**Payoff:**

- Every astronomical calendar becomes valid across ±10,000 years
  at Meeus precision.
- Enables the "every astronomical calendar stable to ±10,000 years"
  pitch line.
- Matches the symmetry principle — treat astronomical calendars
  uniformly via `HybridEngine`, no calendar-specific engine choice.

**Why it wasn't done originally:** when Hindu landed (Phase 5,
before `HybridEngine` was introduced in Phase 4a) the code took
`MoshierEngine` explicitly. Not re-plumbed since.

Tracked as a candidate item in this doc rather than pipeline —
small enough to do opportunistically when next touching Hindu
code.

## Implications for the Foundation port

1. **`validRange` is a doc marker, matching ICU's own contract.**
   ICU doesn't trap out-of-range `UCalendar*` inputs either; it
   just returns whatever its algorithms produce. Foundation is
   silent on the subject. Our behaviour is consistent with the
   contract we're replacing.

2. **Arithmetic-calendar stability across ±1M years is a strong
   pitch point.** Pipeline item 18(a) (round-trip stability for
   arithmetic calendars) is ~1 hour of work per calendar and
   delivers a "we're correct outside the historical range too"
   talking point for the pitch.

3. **Astronomical calendars have a two-tier accuracy story.** If
   the Hindu backlog item lands:
   - Modern (1700–2150): JPL-grade accuracy for all astronomical
     calendars.
   - ±10,000 years outside modern: Meeus accuracy for all.
   - Uniform story across Chinese / Dangi / Vietnamese / Hindu.

4. **ICU has the same asymmetry.** ICU4C's `CalendarAstronomer`
   (`astro.cpp`) is validated over a similar modern window; far
   outside, it drifts too. Not a new problem icu4swift introduces
   — and not one the port is expected to solve.

## What to add to Stage 1 docs (if anything)

- `03-CoverageAndSemanticsGap.md` — no change needed; range
  behaviour is an implementation detail, not a Foundation contract
  gap.
- `04-icu4swiftGrowthPlan.md` — no change needed; the 11 primitives
  are orthogonal to engine choice.
- `PITCH.md` / `PRESENTATION.md` — once the Hindu HybridEngine
  refactor lands, update the "risk register" slide to include
  "every astronomical calendar valid to ±10,000 years."
- `Docs/BakedDataStrategy.md` — complements this doc (inside the
  baked range is fast; this doc describes outside). No overlap.

## See also

- `Sources/CalendarCore/RataDie.swift` — the `validRange` constant.
- `Sources/AstronomicalEngine/HybridEngine.swift` — the mechanism.
- `Sources/AstronomicalEngine/MoshierEngine.swift` — the modern
  engine with its own documented range (`~1700–2150`).
- `Sources/AstronomicalEngine/ReingoldEngine.swift` — the wide-range
  fallback (Meeus polynomials, ±10,000 years).
- `Sources/CalendarAstronomical/ChineseCalendar.swift:381` —
  Chinese/Dangi/Vietnamese using HybridEngine.
- `Sources/CalendarHindu/HinduSolar.swift` — Hindu solar wired
  directly to MoshierEngine (the backlog gap).
- `Docs/BakedDataStrategy.md` — what's precomputed and what's
  astronomical.
- `Docs/RDvsJD.md` — why RataDie is the pivot (related but
  distinct topic).
- `Docs/Chinese_reference.md` — the 1906 cluster, a Moshier-vs-HKO
  precision disagreement inside the modern range (separate issue
  from engine-range degradation).

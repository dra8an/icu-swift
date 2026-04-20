# Islamic Astronomical Calendar — Design Note

*Created 2026-04-20. Captures the reasoning behind icu4swift's
implementation of the `.islamic` identifier as a delegating alias
for `IslamicUmmAlQura`.*

## TL;DR

For Foundation's `.islamic` `Calendar.Identifier` (CLDR type `islamic`,
"observational / astronomical Islamic"), icu4swift ships
`IslamicAstronomical` as a thin delegating wrapper over
`IslamicUmmAlQura`. The type exists for identifier routing only and
currently produces identical output to `IslamicUmmAlQura`.

This matches the direction taken by **ICU4X** (Rust), which
deprecated its own `AstronomicalSimulation` rule in favor of
`UmmAlQura` as of version 2.2.0. ICU4C (C++) still uses an
observational new-moon algorithm for `.islamic`, so Foundation's
current `.islamic` output may diverge from ours outside the
UmmAlQura baked range. Divergence testing is a deferred pipeline
item.

## Background

### The three ways to compute Islamic months

| Approach | How months are determined | Identifier (CLDR) |
|---|---|---|
| **Tabular** | Fixed 30-year cycle; 11 leap years per cycle. Stable, predictable. | `islamic-tbla`, `islamic-civil` |
| **Umm al-Qura** | Saudi government tables based on astronomical predictions for Mecca; adjusted by observation committee. | `islamic-umalqura` |
| **Observational** | Astronomical new-moon detection with a visibility criterion (age, altitude, elongation from Mecca). Produces the "canonical" observational Islamic calendar. | `islamic` |

### What each reference implementation does

- **ICU4C** (the C++ library Foundation's `.islamic` currently wires
  through): implements the observational approach in `islamcal.cpp`
  using `CalendarAstronomer::getMoonPhase` — real astronomical
  calculation per month.
- **ICU4X** (Rust): used to implement the observational approach via
  the Reingold & Dershowitz algorithm in
  `calendrical_calculations::islamic::observational_islamic_from_fixed`.
  **As of ICU4X 2.2.0, that path is deprecated.** The public
  `Hijri<AstronomicalSimulation>` struct now delegates all queries
  to `Hijri<UmmAlQura>`. From ICU4X's `hijri.rs`:
  
  ```rust
  #[deprecated(since = "2.2.0", note = "use `UmmAlQura`")]
  pub struct AstronomicalSimulation;
  
  impl Rules for AstronomicalSimulation {
      fn year(&self, extended_year: i32) -> HijriYear {
          UmmAlQura.year(extended_year)
      }
      fn year_containing_rd(&self, rd: RataDie) -> HijriYear {
          UmmAlQura.year_containing_rd(rd)
      }
      // ...
  }
  ```
  
  ICU4X's own doc comment says: *"Currently, this uses simulation
  results published by the KACST, making it identical to
  `UmmAlQura`."*

## The design space for icu4swift

We had three options.

### Option 1 — Alias to `IslamicUmmAlQura` (chosen)

- **Implementation:** `IslamicAstronomical` struct that delegates
  every `CalendarProtocol` method to an internal
  `IslamicUmmAlQura` instance. Zero new algorithmic code.
- **Effort:** ~1 hour (written 2026-04-20).
- **Upside:** matches ICU4X's current direction. Zero maintenance.
  Completes identifier coverage (26 of 28 → 27 of 28; only
  `ethiopicAmeteAlem` and `vietnamese` remain).
- **Downside:** produces different output from Foundation's
  current `.islamic` (which uses ICU4C's Reingold algorithm) in the
  fallback range where UmmAlQura falls back to tabular.
  Specifically:
    - Inside 1300 AH – 1600 AH (~1882–2174 CE): both use
      KACST-derived / observation-aligned data — expected to
      agree within a day.
    - Outside that range: we fall through to Type-II tabular;
      ICU4C computes Reingold observational.

### Option 2 — Port the Reingold observational algorithm

- **Implementation:** port
  `calendrical_calculations/src/islamic.rs`'s
  `observational_islamic_from_fixed` and companion helpers.
  Build a new `IslamicAstronomicalArithmetic` enum; wire
  `IslamicAstronomical` to it.
- **Effort:** ~1–2 days (algorithm + regression data + tests).
- **Upside:** produces bit-exact parity with Foundation's current
  `.islamic` output (assuming Apple's ICU is close to upstream
  ICU4C's observational code, which it should be for
  stability-sensitive code).
- **Downside:** duplicates logic ICU4X has explicitly deprecated.
  Higher maintenance. More surface area to validate.

### Option 3 — Ship both

- Default `IslamicAstronomical` aliases to UmmAlQura; expose
  `IslamicAstronomicalLegacy` or similar as an opt-in that uses
  Reingold observational.
- **Effort:** same as Option 2 plus a small amount of surface.
- **Upside:** lets users pick the semantic they need.
- **Downside:** API bloat for a small audience; moves the problem
  instead of resolving it.

### Why we chose Option 1

1. **Alignment with ICU4X.** When both ICU reference implementations
   disagree, the newer one (Rust, still actively evolving) is the
   better signal for future direction. ICU4X already made the call
   that observational = UmmAlQura for practical purposes; we follow.
2. **Minimal code risk.** No new algorithm, no new regression data,
   nothing to maintain.
3. **Faster path to full identifier coverage.** Stage 3 of the
   Foundation port needs every identifier to have a Swift-native
   backend before `_CalendarICU` can be deleted. A 1-hour alias
   gets us there for `.islamic`.
4. **Reversible.** If the deferred divergence test (below) shows
   meaningful Foundation parity issues for the range of real-world
   usage, we can swap the implementation behind `IslamicAstronomical`
   without touching its public API.

## Deferred work

### Divergence test

Measure how far `IslamicAstronomical` output (our current alias
behavior) drifts from Foundation's `.islamic` output across a
meaningful date range. Plan:

1. Pick a range. Start with 1900–2100 CE to cover the common case.
   Later, extend to pre-1882 and post-2174 where the fallback kicks
   in to see the worst case.
2. Daily conversion comparison:
   - Foundation's `.islamic` via `Calendar(identifier: .islamic)`
     → `dateComponents([.year, .month, .day], from: Date)`
   - Ours via `IslamicAstronomical().fromRataDie(rd)`
3. Tolerance: ideally zero divergence in the baked range; document
   any divergence outside it.
4. Decision based on results:
   - **Zero divergence:** keep the alias, no further work.
   - **Small divergence inside baked range:** investigate. Likely
     a mismatch between KACST sources or a one-day shift.
   - **Large divergence outside baked range:** that's expected; a
     decision point for whether to port the Reingold algorithm.

### Reingold observational port (conditional)

Only if the divergence test shows meaningful issues for real usage.
Source material:

- `calendrical_calculations/src/islamic.rs` in ICU4X repo (local at
  `/Users/draganbesevic/Projects/claude/CalendarAPI/icu4x/utils/calendrical_calculations/src/islamic.rs`).
- The deprecated `AstronomicalSimulation` impl in
  `components/calendar/src/cal/hijri.rs` shows how to wire rules to
  the low-level functions.

## Implementation notes

Current `IslamicAstronomical` shape (see
`Sources/CalendarAstronomical/IslamicAstronomical.swift`):

- `public struct IslamicAstronomical: CalendarProtocol, Sendable`
- Wraps `let backing: IslamicUmmAlQura`
- Every protocol method is a 1-line delegation, all `@inlinable`
  so the backing call can be inlined at use sites.
- `static let calendarIdentifier = "islamic"` — matches CLDR.
- `DateInner = IslamicTabularDateInner` — identical to
  `IslamicUmmAlQura`, so dates are mutually convertible if
  anyone needs to bridge.

## References

- ICU4X `hijri.rs`: `/Users/draganbesevic/Projects/claude/CalendarAPI/icu4x/components/calendar/src/cal/hijri.rs`
- ICU4X `islamic.rs`: `/Users/draganbesevic/Projects/claude/CalendarAPI/icu4x/utils/calendrical_calculations/src/islamic.rs`
- ICU4C `islamcal.cpp`: `/Users/draganbesevic/Projects/claude/icu/icu4c/source/i18n/islamcal.cpp`
- CLDR BCP-47 calendar types:
  <https://github.com/unicode-org/cldr/blob/main/common/bcp47/calendar.xml>

# Hindu calendars — engine-switch plan (deferred)

*Written 2026-04-22. Documents what "switching Hindu calendars from
`MoshierEngine` to `HybridEngine`" actually entails, after a code
inspection surfaced that the original ~1-hour estimate in
`DateRangeBehaviour.md` was based on an incorrect assumption about how
the engine is plumbed. Kept as a reference for when this item is
picked up for real.*

## TL;DR

- `DateRangeBehaviour.md` described the switch as *"~1 hour of
  mechanical work"* — changing the type of an `engine:` parameter at
  ~10 call sites.
- That estimate was wrong. The `engine: MoshierEngine` parameter on
  the Hindu code path is **vestigial — declared but never dereferenced**.
  Changing its type is cosmetic; it does not change runtime behaviour.
- The real work is replacing 9 direct `MoshierSunrise.*` /
  `MoshierSolar.*` / `MoshierLunar.*` **static calls** with
  hybrid-dispatching equivalents. That is **2–6 hours** of real
  refactoring depending on approach, not 1 hour of mechanical edits.
- No user-visible functionality lives behind this switch; it's a
  pitch talking-point item ("every astronomical calendar stable to
  ±10,000 years"). Deferred until we're ready to do the real work.

## What's actually in the code

### The vestigial `engine:` parameter

`Sources/CalendarHindu/HinduSolar.swift:218` has:

```swift
public struct HinduSolar<V: HinduSolarVariant>: CalendarProtocol, Sendable {
    // ...
    private let engine: MoshierEngine   // ← stored
    // ...
    public init(location: Location = .newDelhi) {
        // ...
        self.engine = MoshierEngine()   // ← assigned
    }
}
```

`engine` is declared on the struct and assigned in `init`. Then a
grep for `engine\.` inside `HinduSolar.swift` returns **zero hits**.
It is never dereferenced. Same pattern in `HinduLunisolar.swift`.

The `HinduSolarVariant` protocol declares:

```swift
static func criticalTimeJd(_ jdMidnightUt: Double, _ loc: Location,
                            engine: MoshierEngine) -> Double
```

Every concrete variant (`Tamil`, `Bengali`, `Odia`, `Malayalam`)
ignores the `engine` parameter and calls `MoshierSunrise.sunset` /
`MoshierSunrise.sunrise` directly.

### Where the astronomy actually happens

`MoshierSunrise`, `MoshierSolar`, `MoshierLunar` are all **types with
static methods**. The Hindu code calls them as `MoshierSunrise.sunrise(...)`
etc. Nine call sites across three files:

```
Sources/CalendarHindu/HinduSolar.swift      — 4 calls
Sources/CalendarHindu/HinduLunisolar.swift  — 3 calls
Sources/CalendarHindu/Ayanamsa.swift        — 2 calls
```

Example (`HinduSolar.swift:66`):

```swift
public static func criticalTimeJd(_ jdMidnightUt: Double, _ loc: Location,
                                   engine: MoshierEngine) -> Double {
    let ss = MoshierSunrise.sunset(jdMidnightUt - loc.utcOffset,
                                   loc.longitude, loc.latitude, loc.elevation)
    // ... `engine` parameter unused
}
```

The `engine` parameter is accepted but never used; the real dispatch
is `MoshierSunrise.sunset(...)` — a hard-coded call to Moshier.

### Why this matters

`HybridEngine` (Chinese / Dangi / Vietnamese) is a struct whose
instance methods dispatch by `Moment` range:

```swift
public func solarLongitude(at moment: Moment) -> Double {
    if isModern(moment) { return moshier.solarLongitude(at: moment) }
    return reingold.solarLongitude(at: moment)
}
```

Chinese reaches this via an instance: `self.engine.solarLongitude(at: moment)`.
The dispatch happens because Chinese calls the engine's **instance
method**, not `MoshierEngine.solarLongitude(...)` statically.

Hindu bypasses this whole layer — it calls `MoshierSunrise.sunrise`
directly, which unconditionally runs Moshier VSOP87 math no matter
what era the date is in. There is no range check, no fallback.

## Mismatch with `DateRangeBehaviour.md`

That doc (§ "The Hindu gap — backlog item") reads:

> *"Changing those two lines and the `engine:` parameter declarations
> (~10 sites in `HinduSolar.swift`, similar count in the lunisolar
> sources) to `HybridEngine` should be ~1 hour of mechanical work
> plus a re-run of the 1900–2100 regression tests."*

The author was looking at the declared `engine:` parameter and
assuming it fed into the actual astronomical calls. It doesn't. A
find-and-replace of `MoshierEngine` → `HybridEngine` in those
declarations compiles and runs, but produces **bit-identical
behaviour** because the parameter is inert.

## Two real options (paths forward when this is picked up)

### Option A — Hybrid-prefixed static shim layer (2–3 hours)

Introduce `HybridSunrise`, `HybridSolar`, `HybridLunar` as types with
static methods that **take JD**, range-check, and dispatch internally.

Example:

```swift
public enum HybridSunrise {
    public static func sunrise(_ jdUt: Double, _ lon: Double,
                                _ lat: Double, _ alt: Double) -> Double {
        if isModernJd(jdUt) {
            return MoshierSunrise.sunrise(jdUt, lon, lat, alt)
        }
        // Route through Reingold's sunrise, converting Moment ↔ JD.
        // ...
    }
}
```

Then replace 9 call sites: `MoshierSunrise.sunrise` →
`HybridSunrise.sunrise`, etc. No signature changes. Callers don't care.

**Caveat:** `Reingold*` engines operate on `Moment`, not JD. The shim
must convert at each call. `ReingoldSolar.solarLongitude` takes
`julianCenturies: Double` (not JD) and returns longitude differently.
`ReingoldSunrise` exists as an instance of `ReingoldEngine`, not as a
static-method collection matching Moshier's shape. The shim has to
bridge these representation gaps.

Rough size: 3 new files (~50 lines each), 9 call-site edits, 1
regression rerun.

### Option B — Refactor Hindu to use `HybridEngine` instances (4–6 hours)

Replace every `MoshierSunrise.sunrise(jd, lon, lat, alt)` with
`engine.sunrise(at: moment, location: loc)` using a real
`HybridEngine` instance. Plumb the engine **through** the static
variant protocol methods instead of leaving it as a dead parameter.

This requires:

- Changing the `HinduSolarVariant` protocol's `criticalTimeJd`
  signature (or adding a sibling method) to actually use the engine.
- Converting between `Double` JD and `Moment` at each call site.
- Verifying the `sunrise(at:) -> Moment?` return shape interoperates
  with Hindu's existing `Double`-JD pipelines.

Cleaner long-term. Matches Chinese's pattern exactly. But every call
site is an edit, every signature is a change, and the test surface
becomes the whole Hindu regression.

### Option C — Remove vestigial `engine:` parameter as a cleanup (~30 min)

Zero functional change. Deletes dead code. Does **not** deliver the
±10,000-year degradation claim; we're still using raw Moshier
everywhere. Worth doing anyway whenever we next touch these files,
but doesn't buy the pitch line.

## Recommendation

When we're ready to land the hybrid switch for real, go with **Option A**.
It gets the correctness win with the smallest scope, and the resulting
`Hybrid*` shim types mirror the `Moshier*` shape callers already use.

In the meantime:

1. **Defer Option B.** It's the right long-term structure but not the
   right shape for a single "small" win.
2. **Do Option C opportunistically** the next time someone touches
   `HinduSolar.swift` or `HinduLunisolar.swift` for unrelated reasons.
3. **Do not present "Hindu astronomical calendars work across
   ±10,000 years" in the pitch** until Option A lands. They don't,
   today.

## Pitch framing correction

Keep the claim realistic:

- **Chinese / Dangi / Vietnamese** — yes, ±10,000 years via
  `HybridEngine` already.
- **Hindu solar + lunisolar** — accurate only in the Moshier modern
  window (~1700–2150). Silently divergent outside.

Once Option A lands, this simplifies to: *"every astronomical
calendar accurate to 1″ inside the modern window and stable to
±10,000 years outside."*

## See also

- `Docs/DateRangeBehaviour.md` — the original (incorrect-scope)
  backlog description, updated to point at this doc.
- `Sources/AstronomicalEngine/HybridEngine.swift` — the existing
  engine the Hindu code should eventually use.
- `Sources/CalendarHindu/HinduSolar.swift` lines 218, 223 — the
  vestigial `engine` property.
- `Sources/CalendarAstronomical/ChineseCalendar.swift` — the
  reference for how an engine is actually plumbed through.

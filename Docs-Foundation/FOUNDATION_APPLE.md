# FOUNDATION_APPLE — Apple-Internal Foundation Repo Orientation

*Written 2026-04-21. Companion to `01-FoundationCalendarSurface.md` (which
references the public `swift-foundation` mirror). This doc captures the
internal repo layout, the additional context it provides, and a few
concrete findings that strengthen the Stage 1 plan and the pitch.*

## Repo overview

**Foundation-rizz** is Apple's internal Foundation + CoreFoundation repo.
Three components:

- **Foundation/** — the framework (ObjC + Swift)
- **CoreFoundation/** — the C/ObjC framework
- **FoundationPreview/** — mirror of open-source `swift-foundation`,
  compiled directly into Foundation.framework

Path on disk: `/Users/dragan/Projects/stash/Foundation-rizz/`.

### How the FoundationPreview mirror integrates

The `Foundation` Xcode target compiles FoundationPreview sources
directly into the framework binary via build settings:

- `SWIFT_ACTIVE_COMPILATION_CONDITIONS = FOUNDATION_FRAMEWORK`
- `SWIFT_PACKAGE_NAME = "FoundationPreview"`
- Availability mapping in
  `Foundation/Config/FoundationPreviewSwiftSettings.xcconfig` maps
  FoundationPreview versions (6.0.2–6.4) to OS versions.

Code uses `#if FOUNDATION_FRAMEWORK` to conditionally include
framework-specific behaviour vs. the open-source Swift Package shape.

### FoundationPreview module structure

| Module | Contents |
|---|---|
| `FoundationEssentials` | Core types: `Data`, `URL`, `Date`, `Calendar`, `Locale`, `TimeZone`, `UUID`, `IndexPath`, `Decimal`, `JSONEncoder/Decoder`, `PropertyListEncoder/Decoder`, `FileManager`, `Predicate`, `AttributedString`, `FormatStyle`, `ProcessInfo`, `NotificationCenter`, `ProgressManager`, `Bundle` |
| `FoundationInternationalization` | ICU-dependent: locale-aware formatting, calendar calculations, time zone lookups. Depends on `swift-foundation-icu`. |
| `FoundationMacros` | Swift compiler macros (`#bundle`, `#Predicate`) using SwiftSyntax. |

## Calendar surface — file inventory with sizes

Concrete sizes, useful for scoping Stage 1/2 work. Confirms that
the `_CalendarProtocol` seam is small and tractable, and that
Foundation already ships ~3,500 lines of generic logic *on top of*
the protocol that we do not need to reimplement.

| File | Lines | Purpose |
|---|---:|---|
| `FoundationEssentials/Calendar/Calendar.swift` | 1,819 | Public `struct Calendar` — value-type wrapper around `_CalendarProtocol`. |
| `FoundationEssentials/Calendar/Calendar_Protocol.swift` | 73 | `_CalendarProtocol` declaration — ~17 required methods. **The Stage 1 surface.** |
| `FoundationEssentials/Calendar/Calendar_Cache.swift` | 115 | `CalendarCache._calendarClass(identifier:)` — the routing seam where ICU↔Swift flips per identifier. Small. |
| `FoundationEssentials/Calendar/Calendar_Gregorian.swift` | 3,246 | `_CalendarGregorian` — the only existing pure-Swift backend. Reference for the sub-day adapter pattern (see `SUBDAY_BOUNDARY.md`). |
| `FoundationEssentials/Calendar/Calendar_Enumerate.swift` | 2,488 | High-level enumeration / `nextDate` / `enumerateDates` built generically on `_CalendarProtocol`. **Comes for free.** |
| `FoundationEssentials/Calendar/Calendar_Recurrence.swift` | 987 | `RecurrenceRule` engine, also generic on `_CalendarProtocol`. **Comes for free.** |
| `FoundationEssentials/Calendar/Calendar_Autoupdating.swift` | 129 | Autoupdating-locale wrapper. |
| `FoundationEssentials/Calendar/DateComponents.swift` | 771 | `DateComponents` value type. |
| `FoundationEssentials/Calendar/RecurrenceRule.swift` | 533 | `RecurrenceRule` value type. |
| `FoundationInternationalization/Calendar/Calendar_ICU.swift` | 2,332 | `_CalendarICU` — the bridge we eventually replace identifier-by-identifier. |
| `FoundationInternationalization/Calendar/Calendar_Bridge.swift` | 235 | NSCalendar bridge for `FOUNDATION_FRAMEWORK` builds. Out of scope. |
| `FoundationInternationalization/Calendar/Calendar_ObjC.swift` | 659 | ObjC interop. |

### The "comes for free" surface, sized

`Calendar_Enumerate.swift` (2,488 lines) + `Calendar_Recurrence.swift`
(987 lines) = **~3,475 lines of generic logic** built on top of
`_CalendarProtocol`'s ~17 primitives. Stage 1 does not reimplement
any of it — once a Swift backend conforms to `_CalendarProtocol`,
all of `nextDate`, `enumerateDates`, `dateInterval`, weekend
queries, and `RecurrenceRule` resolution come along automatically.

This is the concrete number behind the claim in
`04-icu4swiftGrowthPlan.md` § "What needs to be added in Stage 1"
that the Stage 1 surface is ~10 protocol primitives, not ~41 public
methods.

## Issue swiftlang/swift-foundation#1842 — `ucal` performance overhead

A swift-foundation maintainer has filed an issue documenting three
specific `ucal_*` overhead concerns. Captured in
`Docs-claude/swift-foundation-1842-ucal-performance.md` inside the
Foundation-rizz repo. The three issues:

1. **`ucal_getTimeZoneDisplayName`** — creates a numbering system
   object per call even when the display-name path doesn't need it.
2. **`ucal_getGregorianChange`** — requires full `ucal_open` +
   `ucal_close` to retrieve what is essentially a constant.
3. **`ucal_setAttribute` / `ucal_getAttribute` / `ucal_getLimit`** —
   string-based attribute switching internally instead of direct
   property access. The C++ `Calendar` class has direct accessors;
   the C API layer adds enum-to-string translation.

### Why this matters for the pitch

The three complaints are textbook examples of the **API-shape cost**
that `04-icu4swiftGrowthPlan.md` § "The guiding design principle"
argues we sidestep entirely by not implementing ICU's
`ucal_set`/`add`/`roll` stateful contract. We are not pitching a
foreign idea — Foundation maintainers already see this overhead and
have documented it. The pitch lands on a known concern with a
demonstrated fix (icu4swift's clean-room calendar math).

Foundation cannot fix #1842 from its side: it accesses ICU
exclusively through the public `ucal_*` C API. The fix has to come
either from ICU itself (new lightweight C APIs) or from replacing
the dependency — which is exactly what we propose.

**Cite this in:** `PITCH.md` Beat 3 (perf), `02-ICUSurfaceToReplace.md`
§ "Why ICU's API looks the way it does", and `OPEN_ISSUES.md` as
external validation.

## How `Calendar` is structured (struct + class-backed protocol)

`Calendar` itself is a `public struct` — value semantics — wrapping
a class instance that conforms to `_CalendarProtocol`. From
`FoundationEssentials/Calendar/Calendar.swift:36`:

```swift
public struct Calendar : Hashable, Equatable, Sendable {
    private var _calendar: any _CalendarProtocol & AnyObject
    ...
}
```

That `_calendar` is the **only stored field** on the struct.
Everything else (`identifier`, `locale`, `timeZone`, `firstWeekday`,
`minimumDaysInFirstWeek`, etc.) is a computed property that forwards
to the inner class.

Two things matter for our port:

1. **`_CalendarProtocol` is `AnyObject`-constrained** (declared
   `package protocol _CalendarProtocol: AnyObject, Sendable, ...`
   in `Calendar_Protocol.swift:14`). The protocol is class-only so
   that the struct can dispatch through a cheap existential without
   boxing value types per call. Our Stage 1 Swift backends must be
   **classes**, not structs.

2. **Heavy mutable state lives on the class.** Locale, time zone,
   ICU handles (today), per-instance caches all sit on the class
   instance. The struct holds one reference. Mutation via
   `firstWeekday=` / `timeZone=` / etc. forks a fresh class
   instance via `_calendar.copy(changingLocale:...)`.

   **Caveat on COW:** the setters currently always copy on every
   mutation. From the in-source TODO at `Calendar.swift:514` and
   the parallel sites for `timeZone`/`firstWeekday`/`minimumDaysInFirstWeek`:

   > // TODO: We can't use `isKnownUniquelyReferenced` on an
   > existential. For now we must always copy. n.b. we must also
   > always copy if `_calendar.isAutoupdating` is true.

   So `Calendar` is structurally COW-shaped, but the
   uniqueness-check optimisation hasn't been wired up because
   `isKnownUniquelyReferenced` doesn't accept an `any
   _CalendarProtocol` existential. Until that's resolved, every
   mutation pays for a class allocation. Documented in
   `Docs/Calendar_Swift.md` § "Mutation" as the intended design;
   the implementation just hasn't caught up.

### Relationship to the stale `Docs/Calendar_Swift.md`

`Calendar_Swift.md` describes the inner type as *"an enum with
one of three choices for core implementation: Fixed / Autoupdating
/ NSCalendar."* That enum has been refactored away. Today the
polymorphism is achieved by which class conforms to
`_CalendarProtocol`:

- `_CalendarGregorian` (FoundationEssentials, ICU-free)
- `_CalendarICU` (FoundationInternationalization, the bridge we're
  replacing identifier-by-identifier)
- `_CalendarBridged` (FOUNDATION_FRAMEWORK only — wraps custom
  `NSCalendar` subclasses for ObjC compatibility)
- `_CalendarAutoupdating` (the autoupdating-locale wrapper)

The struct/class split itself is the same shape the design doc
describes; only the discriminator moved (from a Fixed/Auto/NS enum
to existential dispatch on `any _CalendarProtocol`).

### Why this matters for the port

Our Stage 1 Swift backends only need to be classes that conform
to `_CalendarProtocol`. Stage 2 plumbing flips
`CalendarCache._calendarClass(identifier:)` per identifier to
return the new Swift backend instead of `_CalendarICU`. The struct
layer above them — `Calendar`, COW, mutation semantics, the
`Hashable`/`Equatable`/`Sendable` conformances, the public API —
is **unchanged** by our work. We slot a new class under the
existing struct and let the rest stay as it is.

## `Docs/Calendar_Swift.md` — alignment with our port plan

Foundation-rizz ships an internal design doc at
`Docs/Calendar_Swift.md` describing how `Calendar` is implemented
across Swift / ObjC / ICU. The doc predates today's
`_CalendarProtocol` split — it still talks about a single inner
class called `_Calendar` — but its design intent maps cleanly onto
our plan and gives us pitch material.

### Strong alignments

1. **The doc's mission statement is our mission.** Opening line:

   > The overall goal is to put as much of the implementation of
   > `NSCalendar` into Swift as possible.

   Our port is the natural continuation. Foundation has already
   landed `_CalendarGregorian` (the only pure-Swift backend today);
   every other identifier still routes to `_CalendarICU`. We're
   offering to finish what that initiative started — not introducing
   a new direction.

2. **They already acknowledge the ICU cost.** Direct quote:

   > ICU's calendrical calculations are stateful, and initializing
   > the data structures is expensive. The class wraps these
   > mutating operations with a lock.

   This is exactly the cost that `04-icu4swiftGrowthPlan.md`
   § "The guiding design principle" says we sidestep, and that
   issue swiftlang/swift-foundation#1842 documents in concrete
   `ucal_*` overhead terms. The Foundation team already knows the
   cost is there. **Strong pitch hook** — we're not introducing a
   foreign concern.

3. **"Convenience vs. required" is the formal name for our "comes
   for free" claim.** The doc says:

   > The choice of which implementations are in `struct Calendar` vs
   > `_Calendar` is not too dissimilar from the breakdown of
   > convenience versus required methods in the `NSCalendar` class
   > cluster. For example, the convenience
   > `compare(_:to:toGranularity:)` method … is implemented in
   > `Calendar` but calls into `_Calendar`'s required implementation
   > of `dateInterval(of:for:)`.

   That is the same split we measured concretely — ~3,475 lines of
   generic logic on top of ~17 protocol primitives. Use **their
   terminology** in pitch beats: "Foundation already separates
   convenience from required; Stage 1 only needs to provide
   required-side primitives."

4. **No conflicts on surfaces we don't touch.** The doc covers
   NSCalendar custom-subclass support, the `_NSSwiftCalendar` /
   `_NSCalendarBridge` / `_NSCalendar` hierarchy for ObjC interop,
   autoupdating "disconnect on mutation" semantics, archiving via
   `NSKeyedArchiver`, and the unimplemented "Create from C"
   (CoreFoundation upcalls into Foundation) story. **All of these
   sit above `_CalendarProtocol`.** Our Swift backends slot in
   below the protocol; none of this changes.

5. **`copy(changingLocale:...)` and COW participation are documented
   expectations.** The doc spells out:

   > `struct Calendar` checks to see if the `_Calendar` it holds is
   > unique, and if so mutates it directly. Otherwise, it calls a
   > specific `copy` function which mutates the requested property
   > and returns a new instance.

   Our Stage 1 backends must implement `_CalendarProtocol.copy(...)`
   correctly to participate. Already in the protocol; no design
   surprise, just an implementation reminder.

### Things to surface

- **The doc is stale** — uses old `_Calendar` naming, predates
  the `_CalendarProtocol` / `_CalendarGregorian` / `_CalendarICU` /
  `_CalendarBridged` split. Not a blocker for us. If Stage 3 lands,
  the doc deserves a refresh; offering to do that as part of the
  port could be a polite gesture in the pitch.
- **"Create from C" is unimplemented.** *"The idea is that
  CoreFoundation will simply upcall into Foundation, which will
  call out to Swift."* Not in scope for our port, but worth knowing
  if a Foundation engineer brings it up — our backends would be
  reachable via the same upcall path once it lands.

### Pitch hooks distilled

- *"You already wrote that the goal is to put as much of NSCalendar
  into Swift as possible. I'd like to help with the part beyond
  Gregorian."* — Beat 2 reframing, in their own words.
- *"You already wrote that ICU's calendrical calculations are
  stateful and expensive. I have a Swift backend that doesn't pay
  that cost — here are the numbers."* — Beat 3 setup.
- The "convenience vs. required" wording — adopt it.

## Foundation's public API already diverges from `ucal_set`

A separate finding, important enough to call out on its own:
`Calendar.date(bySetting:value:of:)` — the method whose name reads
most like a ucal-set wrapper — is implemented as a forward search
via `enumerateDates`, not as a field swap.

`cal.date(bySetting: .year, value: 2027, of: <Apr 21, 2026>)` returns
**January 1, 2027 00:00:00**, not April 21, 2027. The implementation
at `Calendar.swift:1362` builds a sparse `DateComponents(year: 2027)`
and forwards to `enumerateDates(matchingPolicy: .nextTime)`. The
search machinery in `Calendar_Enumerate.swift` (specifically
`_adjustedComponents:649` and `dateAfterMatchingYear:1446`) does
not carry over the original date's other fields when `.year` is the
highest set unit, so the "next date with year=2027" is interpreted
as the start of 2027.

This matters for three reasons:

1. **The divergence between Foundation and `ucal_set` predates
   us.** It is a design choice baked into Foundation since the
   NSCalendar era — not a regression we introduce. Foundation
   never exposed ucal-set's "swap and reconcile" contract through
   this method.
2. **`date(bySetting:)` does not route through any ucal-mutation
   primitive.** It is implemented above `_CalendarProtocol` using
   only `dateComponents(_:from:)`, `setValue(_:for:)`, and
   `enumerateDates`. The cost of `_CalendarICU`'s `ucal_set` /
   `ucal_get` reconciliation is paid by other primitives, not by
   this method.
3. **Zero porting risk on this surface.** Our Swift backends only
   need to implement the same `_CalendarProtocol` primitives
   `_CalendarICU` does; the search-based contract above is
   preserved by construction.

This is the cleanest concrete evidence for the design principle
in `04-icu4swiftGrowthPlan.md`. **Full trace, code citations, and
the idiomatic field-swap pattern (decompose / mutate / recompose
via `dateComponents(_:from:)` + `date(from:)`) are documented
there** in § "Worked example: `date(bySetting:)` already diverges
from `ucal_set`". Cite this when the question of "but doesn't
removing ucal break code that depends on its mutation contract?"
comes up — it doesn't, because the contract was never plumbed
through.

## Empirical: what `ucal_clear` actually does, and what `date(from:)` produces for sparse input

*Settled 2026-04-21 by running
`Scripts/CompareDateFromComponents.c` (raw ICU4C via Homebrew
icu4c 77.1) alongside `Scripts/CompareDateFromComponents.swift`
(Foundation's public `Calendar` API). Run both to reproduce.*

### Question

`Calendar.date(from: DateComponents(year: 2026, day: 21))` — what
comes out? The components specify year and day-of-month; month,
era, and all time fields are nil. Two sub-questions:

1. What does `_CalendarICU`'s `ucal_clear` + selective-`ucal_set`
   sequence actually produce at the ICU level?
2. Are Foundation's explicit-defaults (`YEAR=1 MONTH=0 DAY=1 HOUR=MIN=SEC=MS=0`
   right after `ucal_clear`, at `Calendar_ICU.swift:1168-1180`)
   load-bearing, or belt-and-suspenders?

### Empirical results

Five scenarios exercised against raw ICU4C (Gregorian, UTC),
compared to Foundation's output:

| Scenario | Result |
|---|---|
| A. `ucal_open` only (no clear, no set) | **current wall-clock** (e.g. `2026-04-21 19:28:22.026 UTC`) |
| B. `ucal_open` + `ucal_set(YEAR=2026, DAY=21)` — no clear | **current wall-clock** (YEAR and DAY were already those values) |
| C. `ucal_open` + `ucal_clear` only | **`1970-01-01 00:00:00.000 UTC`** |
| D. `ucal_open` + `ucal_clear` + `set(YEAR=2026, DAY=21)` | **`2026-01-21 00:00:00.000 UTC`** |
| E. `ucal_open` + `ucal_clear` + Foundation defaults + `set(YEAR=2026, DAY=21)` | **`2026-01-21 00:00:00.000 UTC`** |
| Foundation `.gregorian` (`_CalendarGregorian`) | **`2026-01-21 00:00:00.000 UTC`** |
| Foundation `.hebrew` (`_CalendarICU`) | **`1736-10-19 00:00:00.000 UTC`** (era=0 BCE) |

### Conclusions

1. **`ucal_clear` resets the calendar to the Unix epoch**
   (Jan 1, 1970 00:00:00 UTC), not "all fields unset." Scenario C
   proves this directly — no sets at all after clear, yet the
   result is 0 ms. Every unset field is already taking an
   epoch-derived value.

2. **A freshly `ucal_open`-ed handle with no clear holds the
   current wall-clock time.** Scenarios A and B confirm: the
   handle is initialized to *now*, which is why setting fields
   that happen to already equal *now* is a no-op.

3. **Foundation's explicit-defaults block is belt-and-suspenders
   for the Gregorian case.** Scenarios D and E produce identical
   results: `2026-01-21 00:00:00.000 UTC`. After `ucal_clear`,
   MONTH is already 0 (January), DAY is already 1, time fields
   are already 0 — the very values Foundation re-sets explicitly.

4. **But the explicit defaults still earn their keep for
   non-Gregorian calendars and forward-compatibility.** Three
   reasons:
   - Jan 1, 1970 in *Gregorian* maps to some *other* month/day in
     a non-Gregorian calendar's field system. Setting `MONTH=0`
     explicitly says "Month 1 of the target calendar," not
     "whatever the epoch happens to resolve to in this calendar."
   - `UCAL_IS_LEAP_MONTH = 0` matters for Chinese / Hebrew /
     Hindu lunisolar.
   - Defensive against future ICU version changes to
     `ucal_clear` semantics.

5. **Both Foundation backends agree on the Gregorian
   result.** `_CalendarGregorian` (pure Swift) and `_CalendarICU`
   (ucal-backed) both produce `2026-01-21 00:00:00.000 UTC` for
   `DateComponents(year: 2026, day: 21)`. Foundation maintains
   this consistency as a cross-backend contract, not by accident.

6. **Year numbering is calendar-relative.** `.hebrew` with the
   same `DateComponents(year: 2026, day: 21)` lands at **Gregorian
   1736 BCE** (era=0). Year 2026 means very different things
   depending on the target calendar. Relevant for the Stage 1
   spec of `date(from:)` — era + year interact on sparse input
   and need explicit handling rules for each backend.

### Foundation's defaulting contract (stated)

Distilled from both backends' implementations:

- `era` defaults to **1 (AD/CE)** if unset.
- `year` defaults to **1** if unset.
- `month` defaults to **January / Month 1** if unset.
- `day` (day-of-month) defaults to **1** if unset.
- `hour`, `minute`, `second`, `nanosecond` default to **0** if unset.

This is a Foundation-level contract, not an ICU-level one. Our
Stage 1 Swift backends must implement the same defaulting rules
to preserve cross-backend consistency.

### Reproducing

```bash
# Raw ICU4C
cc -O2 -o /tmp/cmpdate Scripts/CompareDateFromComponents.c \
   -I/opt/homebrew/opt/icu4c/include \
   -L/opt/homebrew/opt/icu4c/lib \
   -Wl,-rpath,/opt/homebrew/opt/icu4c/lib \
   -licui18n -licuuc
/tmp/cmpdate

# Foundation
swift Scripts/CompareDateFromComponents.swift
```

Both scripts are committed for long-term reference — see
`Scripts/CompareDateFromComponents.{c,swift}`.

## Build & test workflow

Useful when we eventually start submitting changes.

### Workspaces

| Workspace | Purpose |
|---|---|
| `Foundation.xcworkspace` | Primary shared workspace (Foundation + CF + Tests + Fuzzing). Do not modify for personal use. |
| `FCF.xcworkspace` | Personal copy (gitignored) — copy `Foundation.xcworkspace` to this for local customization. |
| `FoundationPreview.xcworkspace` | For working purely on the swift-foundation Swift Package. |

### Xcode schemes

| Scheme | Purpose |
|---|---|
| `FCF` | Main development scheme — builds Foundation + CF + runs tests. |
| `FCF.ASAN` | AddressSanitizer build. |
| `FCF.TSAN` | ThreadSanitizer build. |
| `FCF.Leaks` | Leaks detection build. |
| `FCF.Perf` | Performance test build. |
| `FCF.CheckABI` | ABI compatibility checker. |

### Two distinct test paths

- **Framework tests:** Open `Foundation.xcworkspace`, select `FCF`,
  Cmd+U. Tests live in `Tests/Tests.xcodeproj` with two bundles:
  `Unit` (main suite) and `Performance`. Test plans:
  `Default.xctestplan`, `ASAN.xctestplan`, `TSAN.xctestplan`,
  `Leaks.xctestplan`, `Performance.xctestplan`.
- **Swift Package tests:** `cd FoundationPreview && swift test`
  runs `FoundationEssentialsTests`, `FoundationInternationalizationTests`,
  and `FoundationMacrosTests`. Requires Swift 6.2+ toolchain. Builds
  two products: `FoundationEssentials` and
  `FoundationInternationalization`.

### Known gotcha

If Xcode tests fail with "Could not launch 'Unit' — Runningboard has
returned error 5":

```bash
sudo defaults write /Library/Preferences/com.apple.security.coderequirements Entitlements -string always
```

## PR conventions

### Branch naming

- Release branches: `release/${RELEASE}.${SU}-${COHORT}` (e.g.,
  `release/27.A-Rizz`). PRs auto-forward to downstream release
  branches.
- PR branches: `pr/<radar_number>` (e.g., `pr/31350168`).

### Commit subject

```
rdar://problem/123456789 Radar Title
```

or

```
rdar://123456789 (Description) (#PR_number)
```

All code changes require accompanying unit tests.

### swift-foundation PR description format

```
[One line description of your change.]

### Motivation:
[Context, why you're making the change, what problem you're solving.]

### Modifications:
[The modifications.]

### Result:
[Behaviour change.]

### Testing:
[Specific testing done or needed to validate impact.]
```

**Important:** swift-foundation PR descriptions must not include
internal codenames, app names, or references to internal OS
timelines. For 3rd-party crash fixes, describe the crashing input
generally without naming the app.

## CI

- **ATP (Apple Test Platform)** — primary CI. Runs automatically on
  all PRs. Builds all major platforms; runs tests on iOS and macOS.
- **rio.yml** — runs `swift test` on FoundationPreview in a Docker
  container.
- **Capsules:** Pull-Request, Pull-Request ASAN, Post-Merge,
  Nightly, Nightly Perf, Guardian, Canary, CheckABI.

The CheckABI capsule consults
`Foundation/ABIBaseline/ABI/{arm64-ios,arm64e-macos,x86_64-macos,...}.json`.
Every Stage 3 ICU→Swift flip needs to leave these baselines stable
(or update them deliberately).

## Platform support

macOS, iOS, watchOS, tvOS, visionOS, bridgeOS, ExclaveKit, DriverKit
(and their simulators). The Stage 1 work in icu4swift only needs to
run on macOS for development; Stage 3 lands code that needs to build
clean on every platform above.

## Key reference files inside Foundation-rizz

| File | Purpose |
|---|---|
| `CLAUDE.md` | Repo-level Claude orientation. |
| `Responsibilities.md` | Component owners (DRIs). |
| `Pipelines.md` | CI capsule documentation. |
| `SharedCache.md` | How to rebuild the iOS shared cache. |
| `CODEOWNERS` | `@Cocoa/Foundation-Core` owns all. |
| `Scripts/fcf.sh` | Shell aliases for daily development. |
| `Scripts/git-public-*` | Scripts for syncing with public swift-foundation GitHub. |
| `Docs-claude/` | Internal Claude-written notes; `swift-foundation-1842-ucal-performance.md` lives here. |

## See also

- `01-FoundationCalendarSurface.md` — the Foundation-side shape and
  the `_CalendarProtocol` seam (references the public
  `swift-foundation` mirror).
- `02-ICUSurfaceToReplace.md` — the 17 `ucal_*` functions we
  remove.
- `04-icu4swiftGrowthPlan.md` § "The guiding design principle" — why
  we don't implement ICU's `ucal_set`/`add`/`roll` contract.
- `06-FoundationPortPlan.md` — Stages 2–4 rollout, including the
  per-identifier router flip.
- `PITCH.md` Beat 3 — perf story; cite issue #1842 here.

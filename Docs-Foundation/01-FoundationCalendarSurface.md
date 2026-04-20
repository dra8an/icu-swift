# Foundation Calendar Surface

*Brief. Captures how `swift-foundation`'s calendar layer is shaped
today. To be expanded later with file/line references for every
seam once Stage 2 plumbing work begins.*

Source material: exploration-agent report 2026-04-17, cross-checked
against the swift-foundation repo at
`/Users/draganbesevic/Projects/claude/swift-foundation/`.

## The public Calendar type

`Calendar` is a struct (value semantics, COW-backed). It holds a
reference to an internal `_calendar: any _CalendarProtocol`
(class-based, for cheap existential dispatch). Mutating
`Calendar`'s knobs (`firstWeekday`, `timeZone`, etc.) either
mutates in-place if the backend is uniquely-owned or swaps for a
fresh backend otherwise.

Location on disk:
`swift-foundation/Sources/FoundationEssentials/Calendar/Calendar.swift`.

## `_CalendarProtocol`

The internal contract every backend must satisfy. Declared in
`Calendar_Protocol.swift`. 16 required methods, 2 optional with
defaults. Requires `AnyObject & Sendable`. Stored-property shape:

- `identifier: Calendar.Identifier`
- `locale: Locale?`
- `timeZone: TimeZone`
- `firstWeekday: Int`
- `minimumDaysInFirstWeek: Int`
- `gregorianStartDate: Date?`
- `isAutoupdating: Bool`
- `isBridged: Bool`
- Plus locale-preference hooks: `preferredFirstWeekday`,
  `preferredMinimumDaysInFirstweek`

Methods: `minimumRange(of:)`, `maximumRange(of:)`, `range(of:in:for:)`,
`ordinality(of:in:for:)`, `dateInterval(of:for:)`,
`isDateInWeekend(_:)`, `date(from:)`, `dateComponents(_:from:)`,
`date(byAdding:to:wrappingComponents:)`, `dateComponents(_:from:to:)`,
`copy(changingLocale:...)`, `hash(into:)`.

## The three existing backends

`CalendarCache._calendarClass(identifier:)` in `Calendar_Cache.swift`
lines 30–36 picks a backend by identifier:

| Backend | Identifier coverage | Kind |
|---|---|---|
| `_CalendarGregorian` | `.gregorian`, `.iso8601` | Pure-Swift. No ICU calls. Proof that Foundation already wants this pattern. Lives in `FoundationEssentials/Calendar/Calendar_Gregorian.swift`. |
| `_CalendarICU` | Every other identifier | Wraps `UCalendar*` (C API from `swift-foundation-icu`). Mutex-gated. Lives in `FoundationInternationalization/Calendar/Calendar_ICU.swift`. |
| `_CalendarBridged` | `FOUNDATION_FRAMEWORK` only | Wraps legacy `NSCalendar` subclasses for Apple-internal framework builds. Out of scope for this port. |

## Dispatch and the integration seam

The integration seam is `CalendarCache._calendarClass(identifier:)`
which today reads roughly:

```swift
if identifier == .gregorian || identifier == .iso8601 {
    return _CalendarGregorian.self
} else {
    return _calendarICUClass()
}
```

`_calendarICUClass()` is backed by `@_dynamicReplacement` when the
`_FoundationICU` module is available — the dynamic-replacement
pattern is already in the codebase and is the natural seam to
extend for a new `_CalendarSwift<Identifier>` path.

Two plausible plumbing approaches for Stage 2:

1. **Add a second dynamic-replacement hook** — `_calendarSwiftClass()`
   that returns a Swift backend when the icu4swift module is
   available; extends the existing pattern.
2. **Per-identifier routing table** — small mutable registry of
   `[Calendar.Identifier: _CalendarProtocol.Type]` consulted before
   the ICU fallback.

See `06-FoundationPortPlan.md` for the decision plan.

## Tests

Located in:

- `Tests/FoundationEssentialsTests/GregorianCalendarTests.swift` —
  the ICU-free Gregorian path.
- `Tests/FoundationInternationalizationTests/CalendarTests.swift` —
  the full suite across all identifiers.
- `Tests/FoundationInternationalizationTests/CalendarPerformanceTests.swift` —
  XCTest-based performance subset.
- `Benchmarks/Benchmarks/Internationalization/BenchmarkCalendar.swift` —
  the real performance harness (swift-benchmark). Today almost
  entirely Gregorian; extending this to per-identifier coverage is
  an explicit Stage 0 deliverable.

## What this document is not

A line-by-line dissection of `_CalendarICU.swift`. That belongs in
`02-ICUSurfaceToReplace.md`, which focuses on what ICU does (and
hence what we are *not* porting). This doc is only about the
Foundation-side shape and the seam we'll land on.

## See also

- `00-Overview.md` § "Integration seam" in the mission section.
- `02-ICUSurfaceToReplace.md` — the other side of the boundary.
- `04-icu4swiftGrowthPlan.md` § "What needs to be added in Stage 1"
  — matches the missing-capability surface this doc describes.
- `06-FoundationPortPlan.md` — how we actually land the new
  backend into this seam.

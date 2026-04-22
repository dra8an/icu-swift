# ICU Surface to Replace

*Brief. The `ucal_*` C API surface that `_CalendarICU` uses today,
and — importantly — why that API has the shape it does. We are
removing this dependency, not matching its shape.*

Source material: exploration-agent report 2026-04-17, cross-checked
against `/Users/draganbesevic/Projects/claude/swift-foundation-icu/`
and upstream ICU at `/Users/draganbesevic/Projects/claude/icu/icu4c/`.

## Why ICU's API looks the way it does

Read this first. It frames everything below.

ICU's `UCalendar*` is a **stateful state machine**. Its contract:

> You can mutate any field with `ucal_set(field, value)` and
> subsequently read any other field. All fields will be mutually
> consistent.

Consequence: every field read has to resolve from whatever's been
set — julian day, day-of-week, day-of-year, week-of-year, is-leap,
era, zone-offset, dst-offset are all recomputed. For Chinese,
"resolve" means astronomical calculation for lunar month
boundaries. For everything else it's still a lot of work.

The measured consequence is visible in
`BENCHMARK_RESULTS.md`: raw `ucal_*` round-trip for Chinese is
~41 µs per iteration; arithmetic calendars are ~270 ns per
iteration. The minimal `ucal_setMillis`-only bench is ~6 ns —
confirming nearly all the cost is in field get/set resolution,
not in the bare ucal scaffolding.

**icu4swift does not implement that contract.** See
`04-icu4swiftGrowthPlan.md` § "The guiding design principle" for
the full argument.

## The 17 ucal functions `_CalendarICU` calls

Every call is gated by `_mutex` in `_CalendarICU`.

### Lifecycle

- `ucal_open(zoneID, zoneIDLength, locale, type, &status)` — create
  a calendar instance. `locale` is often
  `"en_US@calendar=<identifier>"`.
- `ucal_close(calendar)` — destroy.

### State manipulation

- `ucal_clear(calendar)` — reset all fields to the Unix epoch
  (Jan 1, 1970 00:00:00 UTC). Empirically verified — see
  `FOUNDATION_APPLE.md` § "Empirical: what `ucal_clear` actually
  does" and `Scripts/CompareDateFromComponents.c`.
- `ucal_set(calendar, field, value)` — set one field.
- `ucal_setMillis(calendar, millis, &status)` — set absolute time
  (lazy — field computation deferred until the first `ucal_get`).
- `ucal_getMillis(calendar, &status)` — resolve fields → absolute
  time.
- `ucal_get(calendar, field, &status)` — read one field (triggers
  full resolution if needed).

### Field arithmetic

- `ucal_add(calendar, field, amount, &status)` — add with carry.
- `ucal_roll(calendar, field, amount, &status)` — add with
  wrapping.
- `ucal_getFieldDifference(calendar, targetMillis, field, &status)`
  — difference between two times in field units.

### Range queries

- `ucal_getLimit(calendar, field, limitType, &status)` — field
  min/max; limitType is `UCAL_MINIMUM`,
  `UCAL_MAXIMUM`, `UCAL_GREATEST_MINIMUM`, `UCAL_LEAST_MAXIMUM`,
  `UCAL_ACTUAL_MINIMUM`, `UCAL_ACTUAL_MAXIMUM`.

### Attributes

- `ucal_getAttribute(calendar, attribute)` — read
  `UCAL_FIRST_DAY_OF_WEEK` or `UCAL_MINIMAL_DAYS_IN_FIRST_WEEK`.
- `ucal_setAttribute(calendar, attribute, value)` — set same.

### Gregorian-specific

- `ucal_getGregorianChange(calendar, &status)` — cutover date.
- `ucal_setGregorianChange(calendar, date, &status)` — set cutover.

### Weekend test

- `ucal_isWeekend(calendar, date, &status)` — bool.

## The C++ classes behind them

Each `ucal_open` with `calendar=<identifier>` dispatches to a
specific C++ `Calendar` subclass in `icu4c/source/i18n/`:

| Identifier | C++ class | File |
|---|---|---|
| gregorian | `GregorianCalendar` | `gregocal.cpp` |
| japanese | `JapaneseCalendar` (subclass of Gregorian) | `japancal.cpp` |
| buddhist | `BuddhistCalendar` (subclass of Gregorian) | `buddhcal.cpp` |
| roc | `TaiwanCalendar` (subclass of Gregorian) | `taiwncal.cpp` |
| persian | `PersianCalendar` | `persncal.cpp` |
| islamic | `IslamicCalendar` (astronomical) | `islamcal.cpp` |
| islamic-civil | `IslamicCivilCalendar` | `islamcal.cpp` |
| islamic-tbla | `IslamicTBLACalendar` | `islamcal.cpp` |
| islamic-umalqura | `IslamicUmalquraCalendar` | `islamcal.cpp` |
| hebrew | `HebrewCalendar` | `hebrwcal.cpp` |
| chinese | `ChineseCalendar` (uses `CalendarAstronomer`) | `chnsecal.cpp` |
| dangi | `DangiCalendar` (subclass of Chinese) | `dangical.cpp` |
| indian | `IndianCalendar` | `indiancal.cpp` |
| coptic | `CopticCalendar` (subclass of `CECalendar`) | `coptccal.cpp` |
| ethiopic | `EthiopicCalendar` | `ethpccal.cpp` |
| ethiopic-amete-alem | `EthiopicAmeteAlemCalendar` (subclass of Ethiopic) | `ethpccal.cpp` |
| iso8601 | `ISO8601Calendar` (subclass of Gregorian) | `iso8601cal.cpp` |

Calendars **not in upstream ICU4C**:

- The Hindu regional variants (`bangla`, `tamil`, `odia`,
  `malayalam`, `gujarati`, `kannada`, `marathi`, `telugu`,
  `vikram`) live in `hinducal.{cpp,h}` in the
  **swift-foundation-icu fork**, not in upstream ICU.
- `vietnamese` — exposed as an identifier in Foundation but
  Foundation's own `_CalendarICU` treats it with a TODO comment
  noting it's "copied from `.chinese` and needs to be revisited."
  No real Vietnamese implementation in ICU.

## Hidden astronomy

`astro.cpp` is ICU's `CalendarAstronomer` — used by `IslamicCalendar`
(astronomical) and `ChineseCalendar`. We do **not** port this —
icu4swift ships a validated Moshier ephemeris engine
(`AstronomicalEngine` module) that replaces it. See
`00-Overview.md` § "Out of scope" for the explicit exclusion.

## Field semantics worth preserving

- Leap-month representation via `UCAL_IS_LEAP_MONTH` — applicable
  to Chinese, Dangi, Vietnamese, and the Hindu lunisolar variants.
- Repeated-day detection via `UCAL_IS_REPEATED_DAY` — used for
  fall-back DST hours. Only wrapped under `#if FOUNDATION_FRAMEWORK`
  in swift-foundation; pure-Swift Foundation does not currently
  expose it.
- `ucal_getLimit(...)` field limits — vary per calendar (Hebrew's
  month count varies, Islamic month lengths follow year structure,
  etc.).
- DST offset + zone offset composition (`UCAL_DST_OFFSET` +
  `UCAL_ZONE_OFFSET`) for wall-clock arithmetic.

## What we are NOT porting

This document describes ICU's surface so that the reader
understands what we are removing. We are specifically NOT porting:

- The `ucal_set`/`ucal_add`/`ucal_roll` mutation contract.
- Cross-field consistency via eager recomputation.
- The `UCalendar*` stateful object model.
- `astro.cpp`'s calendar-astronomer routines.
- The per-identifier C++ class hierarchy.

What we **do** implement is the subset of behaviour that Foundation's
**public** `Calendar` API exposes, in Swift-native shape, on top
of our existing calendar-math core. See `04-icu4swiftGrowthPlan.md`.

### Foundation's public API already diverges from `ucal_set`

Worth highlighting because it's the strongest evidence that the
ucal mutation contract isn't load-bearing for users:
`Calendar.date(bySetting:value:of:)` — a method whose name reads
like a field setter — is implemented as a forward search via
`enumerateDates`, not as a `ucal_set` + reconcile. Calling
`cal.date(bySetting: .year, value: 2027, of: <Apr 21, 2026>)`
returns **January 1, 2027 00:00:00**, not April 21, 2027.

The implication: Foundation chose the search-based contract long
ago, and `_CalendarICU` does **not** route this method through
`ucal_set`. Removing the ucal mutation contract from the
implementation does not change any user-visible Foundation
behavior on this surface. Full trace and code citations are in
`04-icu4swiftGrowthPlan.md` § "Worked example: `date(bySetting:)`
already diverges from `ucal_set`".

## See also

- `04-icu4swiftGrowthPlan.md` — the design principle (what we
  replace ICU's API with).
- `BENCHMARK_RESULTS.md` — measured performance consequence of
  ICU's eager-resolution model vs our value-oriented one.
- `01-FoundationCalendarSurface.md` — the Foundation-side shape
  we're landing into.
- `03-CoverageAndSemanticsGap.md` — identifier-level coverage
  comparison.

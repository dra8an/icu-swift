# Coverage and Semantics Gap

*Brief. Identifier-level coverage and capability-level gap between
icu4swift and Foundation's public `Calendar` API. Snapshot as of
2026-04-20.*

## Identifier coverage

Foundation exposes 28 `Calendar.Identifier` cases. icu4swift has
Swift-native backends for **all 28** as of 2026-04-20.

| Foundation identifier | icu4swift backend | Notes |
|---|---|---|
| `.gregorian` | `Gregorian` | arithmetic |
| `.iso8601` | `Iso` | Gregorian with ISO week rules |
| `.buddhist` | `Buddhist` | Gregorian + 543-year offset |
| `.japanese` | `Japanese` | Gregorian + imperial era table |
| `.republicOfChina` | `Roc` | Gregorian + ROC era (1912) |
| `.persian` | `Persian` | 33-year rule + correction table |
| `.coptic` | `Coptic` | shared `CopticArithmetic` |
| `.ethiopicAmeteMihret` | `Ethiopian` | shared `CopticArithmetic` |
| `.ethiopicAmeteAlem` | `EthiopianAmeteAlem` | same arithmetic, +5500 era offset |
| `.hebrew` | `Hebrew` | Reingold & Dershowitz |
| `.indian` | `Indian` | Saka arithmetic |
| `.islamic` (astronomical) | `IslamicAstronomical` | delegates to `IslamicUmmAlQura` — see `Docs/ISLAMIC_ASTRONOMICAL.md` |
| `.islamicCivil` | `IslamicCivil` | 30-year tabular, Friday epoch |
| `.islamicTabular` | `IslamicTabular` | 30-year tabular, Thursday epoch |
| `.islamicUmmAlQura` | `IslamicUmmAlQura` | 301-entry KACST baked table |
| `.chinese` | `Chinese = ChineseCalendar<China>` | 199-entry HKO baked table + Moshier |
| `.dangi` | `Dangi = ChineseCalendar<Korea>` | shares Chinese baked table (approximation) |
| `.vietnamese` | `Vietnamese = ChineseCalendar<Vietnam>` | UTC+7 variant; shares Chinese baked table (approximation) |
| `.bangla` (Hindu solar Bengali) | `HinduBengali` | 150-entry Moshier baked table |
| `.tamil` (Hindu solar Tamil) | `HinduTamil` | 150-entry Moshier baked table |
| `.odia` (Hindu solar Odia) | `HinduOdia` | 150-entry Moshier baked table |
| `.malayalam` (Hindu solar Malayalam) | `HinduMalayalam` | 150-entry Moshier baked table |
| `.gujarati` (Hindu lunisolar) | *see below* | |
| `.kannada` (Hindu lunisolar) | *see below* | |
| `.marathi` (Hindu lunisolar) | *see below* | |
| `.telugu` (Hindu lunisolar) | *see below* | |
| `.vikram` (Hindu lunisolar) | *see below* | |

### The five Hindu lunisolar regional labels

Foundation treats `.gujarati`, `.kannada`, `.marathi`, `.telugu`,
and `.vikram` as distinct identifiers. icu4swift has
`HinduAmanta` and `HinduPurnimanta` — the two month-boundary
conventions. The regional labels are almost certainly meant to
alias one of those two (likely `Amanta` for most, `Purnimanta`
for a subset) with different regional month names used at display
time.

**This mapping is not yet pinned down.** Treat as an open item;
will be resolved during the Hindu-calendar phase of the port. See
`OPEN_ISSUES.md` Issue 6 for context and `Docs/HinduCalendars.md`
for the algorithmic details.

## Capability gap (Foundation API surface)

What icu4swift already provides (from `CalendarProtocol` and
`DateArithmetic`):

- Atomic `fromRataDie` / `toRataDie`
- Field accessors: year, month, day, era, leap flags
- `Date.added(.days, N)` and related Temporal-spec arithmetic
- `DateStatus` / `alternativeDate` for non-bijective days

### What the actual gap is

Foundation's public `Calendar` API has ~41 public methods plus
`Calendar.RecurrenceRule`. **icu4swift does not need to implement
41 things.** `_CalendarProtocol` — the backend contract that
`swift-foundation`'s 41 public methods route through — has only
**10 primitive methods** and a small set of stored properties.
Every other Foundation method (including `nextDate`,
`enumerateDates`, the sequence APIs, and `RecurrenceRule`) is
implemented generically in `swift-foundation` on top of that
protocol and comes along for free.

The Stage 1 gap, in three tiers:

**Tier 1 — The 10 `_CalendarProtocol` primitives icu4swift must
provide:**

| Method | Status in icu4swift |
|---|---|
| `date(from: DateComponents) -> Date?` | not present |
| `dateComponents(_: Set<Component>, from: Date)` | not present (our fields are strict) |
| `dateComponents(_: Set<Component>, from: Date, to: Date)` | not present |
| `date(byAdding: DateComponents, to: Date, wrappingComponents:)` | derivable from `DateArithmetic`, needs binding |
| `minimumRange(of:)`, `maximumRange(of:)`, `range(of:in:for:)` | not present |
| `ordinality(of:in:for:)` | not present |
| `dateInterval(of:for:)` | not present |
| `isDateInWeekend(_:)` | not present |
| `copy(changingLocale:...)` | not present (no state to copy today) |
| `hash(into:)` | trivial |

**Tier 2 — Stored state on calendar structs:**

- `timeZone: TimeZone` — not present
- `firstWeekday: Int` — not present
- `minimumDaysInFirstWeek: Int` — not present
- `locale: Locale?` — not present
- `gregorianStartDate: Date?` — not present (Gregorian only)

**Tier 3 — Shared adapter infrastructure:**

- New `CivilInstant` boundary type in `CalendarCore`:
  `(RataDie, Int64 nanosecondsInDay)`. Exact nanosecond precision,
  strictly better than Foundation's own `Date` (~100 ns at 2024).
  Distinct from existing `Moment` (Double fractional RataDie, ~8 µs
  precision at 2024) — `Moment` stays in `AstronomicalEngine` for
  astronomy; `CivilInstant` is the Foundation boundary. See
  `MigrationIssues.md` § 2.
- `(Date, TimeZone) ↔ CivilInstant` adapter with DST gap / fall-back
  handling — not present
- Sparse `DateComponents` bridging — not present
- `isRepeatedDay` for DST fall-back — partial (`DateStatus.repeated`
  exists for Hindu; needs DST extension)

### What comes along for free once Tier 1–3 ship

The following Foundation public methods do **not** need
icu4swift-specific implementation. They live in
`swift-foundation` above `_CalendarProtocol` and route to Tier 1:

- `nextDate(after:matching:...)` and `enumerateDates(...)`
- `dates(byAdding:...)`, `dates(byMatching:...)` — sequence APIs
- `Calendar.RecurrenceRule` — RRULE-shaped iteration
- `startOfDay`, `isDateInToday`, `isDateInYesterday`,
  `isDateInTomorrow`, `isDate(_:inSameDayAs:)`,
  `isDate(_:equalTo:toGranularity:)`
- `compare(_:to:toGranularity:)`
- `date(bySetting:value:of:)`, `date(bySettingHour:...)`
- `date(_:matchesComponents:)`
- `dateIntervalOfWeekend(containing:)` and the non-inout
  `nextWeekend(startingAfter:direction:)` return variants
- `component(_ Component, from: Date)`
- `date(byAdding: Component, value:, to:, wrappingComponents:)`
  — single-component overload

**This is the key scope correction.** Earlier drafts of this doc
implied icu4swift had to build ~15–20 surface methods. The real
Stage 1 surface is 10 primitives + state + adapter. See
`04-icu4swiftGrowthPlan.md` § "What needs to be added in Stage 1"
for the full three-tier breakdown and phasing.

## Explicit non-gaps

Items that *look* like gaps but are intentionally out of scope
(see `00-Overview.md` § "Out of scope"):

- **ucal-style per-field mutation** (`ucal_set(field, value)` +
  eager recalculation) — not in Foundation's public API, not
  ported. See `04-icu4swiftGrowthPlan.md` § "The guiding design
  principle".
- `DateFormatter` / `Date.FormatStyle` — separate port, depends
  on CLDR.
- `TimeZone` internals (TZif parsing, historical transitions) —
  Foundation's existing TZ backend is consumed unchanged.
- `Locale` internals — only locale preferences for first-weekday /
  min-days are read; the rest is not ported.
- `astro.cpp` — icu4swift ships Moshier ephemeris as the
  replacement.

## Semantic parity risks to track

- Leap-month naming conventions (our month codes vs ICU's
  `UCAL_IS_LEAP_MONTH`).
- Week-of-year formulas that depend on `firstWeekday` +
  `minimumDaysInFirstWeek`.
- DST gap / fall-back resolution policies (Foundation's
  `matchingPolicy` + `repeatedTimePolicy`).
- Pre-1582 Gregorian / Julian cutover via configurable
  `gregorianStartDate`.
- ICU quirks we may have to replicate even if they disagree with
  reference algorithms — see `OPEN_ISSUES.md` Issue 2.

## See also

- `00-Overview.md` — scope and acceptance.
- `04-icu4swiftGrowthPlan.md` — what the Stage 1 code does to
  close this gap.
- `OPEN_ISSUES.md` Issue 6 — running log of the three now-resolved
  missing identifiers plus the Hindu regional-label mapping
  question.
- `Docs/ISLAMIC_ASTRONOMICAL.md` and `HinduCalendars.md` — design
  notes on the ambiguous identifiers.

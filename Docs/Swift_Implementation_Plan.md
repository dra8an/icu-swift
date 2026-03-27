# Swift Calendar & DateFormat Library: Implementation Plan

## Swift Package Manager Structure

Single Swift package with multiple library targets — users depend on only what they need.

```
SwiftICU/
  Package.swift
  Sources/
    CalendarCore/          -- Target 1: protocols, RataDie, Date<C>, error types
    CalendarSimple/        -- Target 2: ISO, Gregorian, Julian, Buddhist, ROC
    CalendarComplex/       -- Target 3: Hebrew, Persian, Coptic, Ethiopian, Indian
    AstronomicalEngine/    -- Target 4: Moshier + Reingold hybrid engine
    CalendarAstronomical/  -- Target 5: Chinese, Dangi, Islamic variants
    CalendarHindu/         -- Target 6: all Hindu calendar systems
    CalendarJapanese/      -- Target 7: Japanese (needs era data)
    CalendarAll/           -- Target 8: umbrella re-export + AnyCalendar
    DateArithmetic/        -- Target 9: DateDuration, add/roll/difference
    DateFormat/            -- Target 10: formatters, skeletons, field sets
    DateParse/             -- Target 11: parsers
    DateFormatInterval/    -- Target 12: interval + relative formatting
  Tests/
    CalendarCoreTests/
    CalendarSimpleTests/
    CalendarComplexTests/
    AstronomicalEngineTests/
    CalendarAstronomicalTests/
    CalendarHinduTests/
    CalendarJapaneseTests/
    DateArithmeticTests/
    DateFormatTests/
    DateParseTests/
    DateFormatIntervalTests/
```

**Rationale:** SPM supports target-level dependency granularity — a consumer can depend on `CalendarSimple` without pulling in `CalendarHindu` or `DateFormat`. Single package means coordinated versioning.

**Dependency DAG:**

```
CalendarCore
  |
  +-- CalendarSimple
  |     |
  |     +-- CalendarComplex
  |     |     |
  |     |     +-- CalendarJapanese
  |     |
  |     +-- AstronomicalEngine
  |           |
  |           +-- CalendarAstronomical
  |           |
  |           +-- CalendarHindu
  |
  +-- DateArithmetic (depends on CalendarCore)
  |
  +-- CalendarAll (depends on all calendar targets)
        |
        +-- DateFormat (depends on CalendarAll + DateArithmetic)
              |
              +-- DateParse
              |
              +-- DateFormatInterval
```

---

## Phase 1: Foundation (CalendarCore)

**Complexity: Medium | Dependencies: None**

### Core Types

**`RataDie`** — Universal day-count representation (day 1 = January 1, year 1 ISO).

```swift
public struct RataDie: Comparable, Hashable, Sendable {
    public let dayNumber: Int64

    public init(_ dayNumber: Int64)
    public static func fromUnixEpoch(days: Int64) -> RataDie  // 1970-01-01 = RD 719163
    public func toUnixEpochDays() -> Int64

    public static func + (lhs: RataDie, rhs: Int64) -> RataDie
    public static func - (lhs: RataDie, rhs: RataDie) -> Int64
}
```

**`Calendar` protocol** — Every calendar system conforms to this.

```swift
public protocol Calendar: Sendable {
    associatedtype DateInner: Equatable, Comparable, Sendable

    func newDate(year: YearInput, month: Month, day: UInt8) throws -> DateInner
    func dateToRataDie(_ inner: DateInner) -> RataDie
    func dateFromRataDie(_ rd: RataDie) -> DateInner

    func yearInfo(_ inner: DateInner) -> YearInfo
    func monthInfo(_ inner: DateInner) -> MonthInfo
    func dayOfMonth(_ inner: DateInner) -> UInt8
    func dayOfYear(_ inner: DateInner) -> UInt16
    func daysInMonth(_ inner: DateInner) -> UInt8
    func daysInYear(_ inner: DateInner) -> UInt16
    func monthsInYear(_ inner: DateInner) -> UInt8
    func weekday(_ inner: DateInner) -> Weekday

    static var calendarIdentifier: String { get }
}
```

**`Date<C: Calendar>`** — Generic, immutable date value type.

```swift
public struct Date<C: Calendar>: Equatable, Comparable, Sendable {
    public let inner: C.DateInner
    public let calendar: C

    public var year: YearInfo { get }
    public var month: MonthInfo { get }
    public var dayOfMonth: UInt8 { get }
    public var dayOfYear: UInt16 { get }
    public var weekday: Weekday { get }
    public var daysInMonth: UInt8 { get }
    public var daysInYear: UInt16 { get }
    public var monthsInYear: UInt8 { get }

    public var rataDie: RataDie { get }
    public static func fromRataDie(_ rd: RataDie, calendar: C) -> Date<C>

    // Calendar conversion — all goes through RataDie
    public func converting<T: Calendar>(to targetCalendar: T) -> Date<T>
}
```

**Supporting types:**

```swift
public enum YearInput: Sendable {
    case extended(Int32)
    case eraYear(era: String, year: Int32)
}

public struct Month: Sendable, Hashable {
    public let code: MonthCode
    public let ordinal: UInt8       // 1-indexed

    public static func new(_ ordinal: UInt8) -> Month
    public static func leap(_ ordinal: UInt8) -> Month  // e.g., "M05L"
}

public struct MonthCode: Sendable, Hashable, CustomStringConvertible {
    // "M01"-"M13", optional "L" suffix (Temporal-compatible)
}

public struct YearInfo: Sendable {
    public func era() -> EraYear?
    public func cyclic() -> CyclicYear?
    public func extendedYear() -> Int32
}

public struct EraYear: Sendable {
    public let era: String
    public let year: Int32
    public let extendedYear: Int32
    public let ambiguity: YearAmbiguity
}

public struct CyclicYear: Sendable {
    public let cycle: Int32
    public let yearOfCycle: UInt8   // 1-60
    public let relatedIso: Int32
}

public struct MonthInfo: Sendable {
    public let ordinal: UInt8
    public let code: MonthCode
    public let isLeap: Bool
}

public enum Weekday: Int, Sendable, CaseIterable {
    case monday = 1, tuesday, wednesday, thursday, friday, saturday, sunday
}

public enum YearAmbiguity: Sendable {
    case unambiguous, centuryRequired, eraRequired, eraAndCenturyRequired
}
```

**Error types:**

```swift
public enum DateNewError: Error {
    case invalidDay(max: UInt8)
    case monthNotInCalendar
    case monthNotInYear
    case invalidEra(String)
    case invalidYear
    case overflow
}
```

**Source:** Adapted from ICU4X `calendar.rs`, `date.rs`, `types.rs`, `error.rs`.

**Note on `AsCalendar`:** ICU4X has an `AsCalendar` indirection trait to support `Date<Rc<C>>` and `Date<Arc<C>>`. Not needed in Swift — structs have value semantics by default. For calendars with data (Japanese, Chinese), use a struct with internal class storage or make them classes.

**Testing:** Unit tests for RataDie arithmetic, date construction edge cases (year 0, negative years). Property-based: `Date.fromRataDie(d.rataDie, calendar) == d`.

---

## Phase 2: Simple Calendars (CalendarSimple)

**Complexity: Medium | Dependencies: Phase 1**

### ISO Calendar

The pivot calendar — all inter-calendar conversion goes through ISO RataDie.

```swift
public struct Iso: Calendar {
    public typealias DateInner = IsoDateInner
    public static let calendarIdentifier = "iso8601"
}

public struct IsoDateInner: Equatable, Comparable, Sendable {
    let year: Int32, month: UInt8, day: UInt8
}
```

### Gregorian Calendar

Identical arithmetic to ISO, different era mapping (CE/BCE).

```swift
public struct Gregorian: Calendar {
    public typealias DateInner = GregorianDateInner
    public static let calendarIdentifier = "gregorian"
    // year > 0 -> CE, year <= 0 -> BCE (year 0 = 1 BCE)
}
```

Both `Iso` and `Gregorian` share an internal `GregorianArithmetic` helper (from ICU4X's `AbstractGregorian` pattern).

### Julian Calendar

```swift
public struct Julian: Calendar {
    public typealias DateInner = JulianDateInner
    public static let calendarIdentifier = "julian"
    // Leap year: divisible by 4 (no century exception)
}
```

Important for historical dates before Oct 15, 1582.

### Buddhist Calendar

```swift
public struct Buddhist: Calendar {
    public typealias DateInner = GregorianDateInner  // shares Gregorian storage
    public static let calendarIdentifier = "buddhist"
    // Buddhist year = Gregorian year + 543, single era "be"
}
```

Zero-size type — delegates everything to Gregorian with year offset.

### ROC (Taiwan) Calendar

```swift
public struct Roc: Calendar {
    public typealias DateInner = GregorianDateInner
    public static let calendarIdentifier = "roc"
    // ROC year = Gregorian year - 1911, eras "minguo" / "before-minguo"
}
```

Same pattern as Buddhist.

### Calendar Conversion

```swift
extension Date {
    public func converting<T: Calendar>(to targetCalendar: T) -> Date<T> {
        let rd = self.calendar.dateToRataDie(self.inner)
        let targetInner = targetCalendar.dateFromRataDie(rd)
        return Date<T>(inner: targetInner, calendar: targetCalendar)
    }
}
```

**Source:** Adapted from ICU4X `cal/iso.rs`, `cal/gregorian.rs`, `cal/julian.rs`, `cal/buddhist.rs`, `cal/roc.rs`, `abstract_gregorian.rs`. Hindu project's `JulianDay.swift` has existing JD<->Gregorian conversion to reuse.

**Testing:** Round-trip: ISO -> Gregorian -> ISO, Julian -> ISO -> Julian for thousands of dates. Known equivalences (Julian Oct 4, 1582 = Gregorian Oct 14, 1582). Buddhist/ROC year offsets.

---

## Phase 3: Complex Calendars (CalendarComplex)

**Complexity: Large | Dependencies: Phase 2**

### Hebrew Calendar

```swift
public struct Hebrew: Calendar {
    public typealias DateInner = HebrewDateInner
    public static let calendarIdentifier = "hebrew"
}
```

Key algorithms:
- 19-year Metonic cycle: leap years at positions 3,6,8,11,14,17,19
- Four dechiyot (postponement rules) for Tishrei 1
- Year types: deficient (353/383), regular (354/384), complete (355/385)
- 12 months in common year, 13 in leap year (Adar I inserted)

### Persian (Solar Hijri) Calendar

```swift
public struct Persian: Calendar {
    public typealias DateInner = PersianDateInner
    public static let calendarIdentifier = "persian"
}
```

2820-year grand cycle for leap year determination. 6x31 + 5x30 + 1x29/30 months.

### Coptic Calendar

```swift
public struct Coptic: Calendar {
    public typealias DateInner = CopticDateInner
    public static let calendarIdentifier = "coptic"
}
```

13 months: 12x30 + 1x5 (or 6 in leap year). Epoch: August 29, 284 CE (Julian).

### Ethiopian Calendar

```swift
public struct Ethiopian: Calendar {
    public typealias DateInner = EthiopianDateInner
    public static let calendarIdentifier = "ethiopian"
}
```

Same month structure as Coptic. Two eras: Amete Mihret (default), Amete Alem (+5500). Both Coptic and Ethiopian share an internal `CopticEthiopianArithmetic` helper.

### Indian (Saka) Calendar

```swift
public struct Indian: Calendar {
    public typealias DateInner = IndianDateInner
    public static let calendarIdentifier = "indian"
}
```

Follows Gregorian leap year rule. Epoch: March 22, 79 CE.

**Source:** All adapted from ICU4X `cal/hebrew.rs`, `cal/persian.rs`, `cal/coptic.rs`, `cal/ethiopian.rs`, `cal/indian.rs`.

**Testing:** Exhaustive round-trip against ICU4X reference outputs. Verify Hebrew Tishrei 1 for years 5700-5900. Verify Persian Nowruz dates. Cross-check known historical conversions.

---

## Phase 4: Astronomical Calendars

**Complexity: Large | Dependencies: Phase 2 + Hindu calendar project**

### Phase 4a: Hybrid Astronomical Engine (AstronomicalEngine)

```swift
public protocol AstronomicalEngine: Sendable {
    func solarLongitude(at jd: Double) -> Double
    func lunarLongitude(at jd: Double) -> Double
    func newMoonBefore(_ jd: Double) -> Double
    func newMoonAtOrAfter(_ jd: Double) -> Double
    func sunrise(at jd: Double, location: Location) -> Double
    func sunset(at jd: Double, location: Location) -> Double
}

public struct HybridEngine: AstronomicalEngine {
    // Modern range: ~JD 2341973.5 (1700-01-01) to ~JD 2469807.5 (2150-01-01)
    // Inside range: MoshierEngine
    // Outside range: ReingoldEngine
}

public struct MoshierEngine: AstronomicalEngine {
    // VSOP87 solar + DE404 lunar
    // Port from hindu-calendar/swift/Sources/HinduCalendar/Ephemeris/
}

public struct ReingoldEngine: AstronomicalEngine {
    // Meeus polynomial approximations
    // Port from ICU4X calendrical_calculations/src/astronomy.rs
}
```

**Moshier integration:** Existing Swift code in `hindu-calendar/swift/Sources/HinduCalendar/Ephemeris/`:
- `Sun.swift` (620 lines) — VSOP87 solar longitude, nutation, deltaT
- `Moon.swift` (644 lines) — DE404 lunar perturbations
- `Rise.swift` (128 lines) — Sunrise/sunset
- `Ayanamsa.swift` (91 lines) — Lahiri ayanamsa
- `JulianDay.swift` (58 lines) — JD<->Gregorian
- `Ephemeris.swift` (68 lines) — Facade

Refactor: the existing `Sun` and `Moon` classes use mutable scratch arrays. Convert to local variables for thread safety (arrays are small: 9x24 and 5x8 doubles).

**Reingold engine:** Port from ICU4X `calendrical_calculations/src/astronomy.rs` (~2,632 lines Rust -> Swift). Key functions: `solarLongitude()`, `lunarLongitude()`, `nthNewMoon()`, `newMoonBefore()`, `newMoonAtOrAfter()`.

**Crossover validation:** Both engines for every day in 1700-1750 and 2050-2150 must agree on: new moon dates (same day), solar longitude at noon (within 0.01 degrees), sunrise times (within 2 minutes).

### Phase 4b: Chinese and Korean Calendars (CalendarAstronomical)

```swift
public protocol EastAsianVariant: Sendable {
    static var calendarIdentifier: String { get }
    static var referenceLocation: Location { get }
    static var cycleYearOffset: Int { get }
}

public struct ChineseTraditional<V: EastAsianVariant>: Calendar {
    public typealias DateInner = ChineseDateInner
    public let engine: HybridEngine
}

public enum China: EastAsianVariant {
    public static let calendarIdentifier = "chinese"
    // Beijing reference
}

public enum Korea: EastAsianVariant {
    public static let calendarIdentifier = "dangi"
    // Seoul reference
}
```

Algorithms: winter solstice detection, new moon enumeration between solstices, major solar term checking (30-degree boundaries), leap month identification (month without major solar term).

**Source:** ICU4X `cal/east_asian_traditional/`.

### Phase 4c: Islamic Calendar Variants (CalendarAstronomical)

```swift
public protocol HijriVariant: Sendable { ... }

public struct Hijri<V: HijriVariant>: Calendar {
    public typealias DateInner = HijriDateInner
}

public enum TabularAlgorithm: HijriVariant { ... }   // 30-year cycle, pure arithmetic
public enum UmmAlQura: HijriVariant { ... }           // KACST lookup table
public enum ObservationalIslamic: HijriVariant { ... } // Astronomical new moon
```

**Source:** ICU4X `cal/hijri/`.

**Testing:** Chinese calendar against published lunisolar tables. Islamic Tabular against known conversion tables. Umm al-Qura against Saudi KACST published data.

---

## Phase 5: Hindu Calendars (CalendarHindu)

**Complexity: Large | Dependencies: Phase 4a**

### Integration Strategy

Adapt existing validated code from `hindu-calendar/swift/` to conform to the `Calendar` protocol. Do not rewrite — adapt.

### Lunisolar Calendars

```swift
public protocol LunisolarVariant: Sendable { ... }

public struct HinduLunisolar<V: LunisolarVariant>: Calendar {
    public typealias DateInner = HinduLunisolarDateInner
    public let engine: HybridEngine
    public let location: Location  // Default: New Delhi
}

public enum Amanta: LunisolarVariant {
    public static let calendarIdentifier = "hindu-lunar-amanta"
}

public enum Purnimanta: LunisolarVariant {
    public static let calendarIdentifier = "hindu-lunar-purnimanta"
}
```

`DateInner` stores: Saka year, masa (month), is_adhika_masa, paksha, tithi.

Adapter: convert RataDie -> Gregorian -> JD -> call existing `Masa.masaForDate()` / `Tithi.tithiAtSunrise()`.

### Solar Calendars

```swift
public protocol HinduSolarVariant: Sendable { ... }

public struct HinduSolar<V: HinduSolarVariant>: Calendar {
    public typealias DateInner = HinduSolarDateInner
    public let engine: HybridEngine
    public let location: Location
}

public enum Tamil: HinduSolarVariant { ... }      // Sunset - 9.5 min critical time
public enum Bengali: HinduSolarVariant { ... }     // Midnight + per-rashi tuning
public enum Odia: HinduSolarVariant { ... }        // Fixed 22:12 IST
public enum Malayalam: HinduSolarVariant { ... }   // End of madhyahna - 9.5 min
```

### Engine Connection

Replace existing `Ephemeris` calls with `HybridEngine`:
- `Ephemeris.solarLongitude()` -> `engine.solarLongitude()`
- `Ephemeris.lunarLongitude()` -> `engine.lunarLongitude()`
- `Ephemeris.sunriseJd()` -> `engine.sunrise()`
- Ayanamsa stays in CalendarHindu (Hindu-specific concept)

**Testing:** Run full existing test suite (62 tests, 59,497 assertions). The 99.971% accuracy must be preserved exactly. Additional round-trip tests through RataDie.

---

## Phase 6: Japanese Calendar (CalendarJapanese)

**Complexity: Medium | Dependencies: Phase 2**

```swift
public struct Japanese: Calendar {
    public typealias DateInner = JapaneseDateInner
    public static let calendarIdentifier = "japanese"

    public let eraData: JapaneseEraData  // NOT zero-size
    public init()  // loads built-in era data
}

public struct JapaneseEraData: Sendable {
    // [(eraCode: String, eraName: String, startDate: RataDie)]
    // Sorted by startDate descending for lookup
}
```

**Built-in eras:** Meiji (1868-01-25), Taisho (1912-07-30), Showa (1926-12-25), Heisei (1989-01-08), Reiwa (2019-05-01).

**Future extensibility:** `JapaneseEraData` can be updated without code changes.

The calendar is Gregorian with era overlay — no different arithmetic, just era resolution.

**Source:** ICU4X `cal/japanese.rs`.

**Testing:** Era boundaries, year-of-era for all modern eras, dates before Meiji, dates on exact era boundaries.

---

## Phase 7: Date Arithmetic (DateArithmetic)

**Complexity: Medium | Dependencies: Phase 1**

```swift
public struct DateDuration: Sendable, Equatable {
    public var years: Int32
    public var months: Int32
    public var weeks: Int32
    public var days: Int32
    public var isNegative: Bool

    public init(years: Int32 = 0, months: Int32 = 0, weeks: Int32 = 0,
                days: Int32 = 0, isNegative: Bool = false)
}

public enum Overflow: Sendable {
    case constrain   // Jan 31 + 1 month = Feb 28
    case reject      // Jan 31 + 1 month = error
}

public enum DateDurationUnit: Sendable {
    case years, months, weeks, days
}
```

**Methods on `Date<C>`:**

```swift
extension Date {
    // Add (non-mutating, ICU4X style)
    public func added(_ duration: DateDuration,
                      overflow: Overflow = .constrain) throws -> Date<C>

    // Roll (from ICU4C — wraps within field, no carry)
    public func rolled(_ field: DateDurationUnit, by amount: Int32) -> Date<C>

    // Difference
    public func until(_ other: Date<C>,
                      largestUnit: DateDurationUnit = .days) -> DateDuration
}
```

**Add algorithm:** Add years -> constrain month -> add months -> constrain day -> convert to RataDie -> add (weeks*7 + days) -> convert back.

**Roll algorithm:** Roll month wraps 1-12 (or 1-13) without changing year. Roll day wraps 1-daysInMonth without changing month.

**Source:** ICU4X `duration.rs` for `DateDuration`. ICU4C `ucal_roll` specification for `roll()`.

**Testing:** Property-based: `date.added(d).added(d.negated) == date`. Edge cases: Feb 29 arithmetic, month-end clamping, cross-year addition. Roll: month past December wraps to January (same year).

---

## Phase 8: Date Formatting (DateFormat)

**Complexity: Very Large | Dependencies: All calendar phases + Phase 7**

### Formatter Types (Three-Tier Model)

```swift
// Tier 1: Fixed calendar — minimal data, best performance
public struct FixedCalendarDateFormatter<C: Calendar, F: DateFieldSet> {
    public init(calendar: C, locale: Locale, fieldSet: F) throws
    public func format(_ date: Date<C>) -> FormattedDate
}

// Tier 2: Any calendar — converts at format time
public struct DateFormatter<F: DateFieldSet> {
    public init(locale: Locale, fieldSet: F) throws
    public func format<C: Calendar>(_ date: Date<C>) throws -> FormattedDate
}

// Tier 3: Time only — no calendar
public struct TimeFormatter<F: TimeFieldSet> {
    public init(locale: Locale, fieldSet: F) throws
    public func format(_ time: TimeComponents) -> FormattedTime
}
```

### Semantic Skeletons (Primary API)

```swift
public struct YMD: DateFieldSet {
    public static func short() -> YMD
    public static func medium() -> YMD
    public static func long() -> YMD
}

public struct YMDE: DateFieldSet { ... }
public struct MD: DateFieldSet { ... }
public struct DE: DateFieldSet { ... }
// ... all combinations
```

### Raw Pattern Support (Power-User API)

```swift
public struct PatternDateFormatter<C: Calendar> {
    public init(pattern: String, calendar: C, locale: Locale) throws
    public func format(_ date: Date<C>) -> FormattedDate
}
```

### Name Resolution

```swift
public struct DateSymbols: Sendable {
    public func monthName(month: MonthCode, context: NameContext, width: NameWidth) -> String
    public func weekdayName(weekday: Weekday, context: NameContext, width: NameWidth) -> String
    public func eraName(era: String, width: NameWidth) -> String
}

public enum NameContext: Sendable { case format, standalone }
public enum NameWidth: Sendable { case wide, abbreviated, narrow, short }
```

### Formatted Output

```swift
public struct FormattedDate: CustomStringConvertible {
    public var description: String
    public var parts: [FormattedPart] { get }
    public func writeTo<W: TextOutputStream>(_ stream: inout W)
}

public struct FormattedPart: Sendable {
    public let field: DateField
    public let range: Range<String.Index>
    public let value: String
}

public enum DateField: Sendable {
    case year, month, day, weekday, era, dayPeriod, hour, minute, second
}
```

### Number System

```swift
public struct DateFormatterPreferences: Sendable {
    public var locale: Locale
    public var numberingSystem: NumberingSystem?
    public var calendar: CalendarIdentifier?
}
```

### CLDR Data Strategy

**Phase 8 v1:** Embed CLDR data as generated Swift source for a core set of locales (en, ja, ar, he, hi, zh, ko, fa, th, de, fr, es, pt, ru — covering all calendar systems).

**Future:** External data files or build-time code generation for locale subsetting.

**Source:** ICU4X `fieldsets.rs`, `pattern/`, `format/`, skeleton matching from `provider/skeleton/helpers.rs`. CLDR data extraction.

**Testing:** Golden-file tests: format known dates in known locales, compare against ICU4C/ICU4X output. All calendar x locale x field-set combinations. Field position tracking verification.

---

## Phase 9: Date Parsing (DateParse)

**Complexity: Medium | Dependencies: Phase 8**

```swift
public struct DateParser<C: Calendar> {
    public init(pattern: String, calendar: C, locale: Locale) throws

    public func parse(_ string: String) throws -> Date<C>
    public func parse(_ string: String, position: inout String.Index) throws -> Date<C>
}

public enum ParseMode: Sendable {
    case strict    // Exact match required
    case lenient   // Flexible whitespace, partial matches
}
```

Pattern-based parsing (not skeleton-based — you need the exact pattern to parse).

**Source:** ICU4C's `SimpleDateFormat::parse()` logic adapted to Swift idioms (`throws` instead of `ParsePosition` + `UErrorCode`).

**Testing:** Round-trip: `parse(format(date)) == date` for many dates. Lenient mode edge cases. Locale-specific parsing (month names in various languages).

---

## Phase 10: Interval & Relative Formatting (DateFormatInterval)

**Complexity: Medium | Dependencies: Phase 8**

### DateIntervalFormatter

```swift
public struct DateIntervalFormatter<F: DateFieldSet> {
    public init(locale: Locale, fieldSet: F) throws
    public func format<C: Calendar>(from: Date<C>, to: Date<C>) -> FormattedDateInterval
}
```

Algorithm: identify greatest differing field, select interval pattern from CLDR, format omitting redundant components. "Jan 10-20, 2007" instead of "Jan 10, 2007 - Jan 20, 2007".

### RelativeDateTimeFormatter

```swift
public struct RelativeDateTimeFormatter {
    public init(locale: Locale, width: RelativeWidth = .long) throws

    public func formatNumeric(_ value: Int, unit: RelativeUnit) -> String  // "in 2 days"
    public func format(_ value: Int, unit: RelativeUnit) -> String         // "yesterday"
    public func formatAbsolute(_ unit: AbsoluteUnit, direction: Direction) -> String  // "next Tuesday"
}

public enum RelativeUnit: Sendable {
    case seconds, minutes, hours, days, weeks, months, years
}

public enum RelativeWidth: Sendable { case long, short, narrow }
public enum Direction: Sendable { case last, this, next }
```

**Source:** ICU4C `DateIntervalFormat` and `RelativeDateTimeFormatter`. Requires CLDR relative time data and plural rules.

**Testing:** Known locale outputs for various values/units. Plural rule verification (English "1 day" vs "2 days"; Arabic dual forms; etc.).

---

## Phase Summary

| Phase | Target | Complexity | Dependencies | Source |
|-------|--------|------------|--------------|--------|
| 1 | CalendarCore | Medium | None | ICU4X `calendar.rs`, `date.rs`, `types.rs` |
| 2 | CalendarSimple | Medium | Phase 1 | ICU4X `cal/iso.rs`, `gregorian.rs`, `julian.rs`, `buddhist.rs`, `roc.rs` |
| 3 | CalendarComplex | Large | Phase 2 | ICU4X `cal/hebrew.rs`, `persian.rs`, `coptic.rs`, `ethiopian.rs`, `indian.rs` |
| 4a | AstronomicalEngine | Large | Phase 2 | Hindu project `Ephemeris/` + ICU4X `astronomy.rs` |
| 4b+c | CalendarAstronomical | Large | Phase 4a | ICU4X `cal/east_asian_traditional/`, `cal/hijri/` |
| 5 | CalendarHindu | Large | Phase 4a | Hindu project adapted to Calendar protocol |
| 6 | CalendarJapanese | Medium | Phase 2 | ICU4X `cal/japanese.rs` |
| 7 | DateArithmetic | Medium | Phase 1 | ICU4X `duration.rs` + ICU4C `ucal_roll` |
| 8 | DateFormat | Very Large | All above | ICU4X `fieldsets.rs`, `pattern/`, `format/` + CLDR data |
| 9 | DateParse | Medium | Phase 8 | ICU4C `SimpleDateFormat::parse()` |
| 10 | DateFormatInterval | Medium | Phase 8 | ICU4C `DateIntervalFormat`, `RelativeDateTimeFormatter` |

### Parallelization

After Phase 2 completes, **four workstreams can proceed in parallel:**
- Workstream A: Phase 3 (Complex calendars)
- Workstream B: Phase 4a -> 4b/c -> 5 (Astronomical engine -> astronomical calendars -> Hindu)
- Workstream C: Phase 6 (Japanese)
- Workstream D: Phase 7 (Date arithmetic)

Phase 8 (formatting) is the bottleneck — it depends on all calendar phases. Phases 9 and 10 depend on 8 but can run in parallel with each other.

### Calendar Count: 22 Systems

| Category | Calendars |
|----------|-----------|
| Gregorian-based (5) | ISO, Gregorian, Julian, Buddhist, ROC |
| Complex algorithmic (5) | Hebrew, Persian, Coptic, Ethiopian, Indian |
| Astronomical (5) | Chinese, Dangi, Islamic Tabular, Islamic Umm al-Qura, Islamic Observational |
| Hindu (6) | Lunisolar Amanta, Lunisolar Purnimanta, Solar Tamil, Solar Bengali, Solar Odia, Solar Malayalam |
| Era-based (1) | Japanese |

More than either ICU4C (15) or ICU4X (16), with better astronomical accuracy for the modern period.

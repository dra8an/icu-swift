# ICU4C vs ICU4X: Date Formatting Complete Analysis

## 1. Architecture & Type System

| Aspect | ICU4C (C++) | ICU4X (Rust) |
|--------|-------------|--------------|
| **Core type** | `SimpleDateFormat` (concrete class inheriting `DateFormat`) | `DateTimeFormatter<FSet>` / `FixedCalendarDateTimeFormatter<C, FSet>` |
| **Paradigm** | OOP — abstract `DateFormat` base, `SimpleDateFormat` implementation, `DateFormatSymbols` for names | Trait-based generics — `FSet` (field set) type parameter selects which components to format |
| **Pattern model** | Mutable — `applyPattern()` changes the pattern at runtime | Immutable — formatter is constructed once with a specific field set and length |
| **Calendar coupling** | Formatter holds a `Calendar*` internally, mutates it during formatting | Three tiers: `DateTimeFormatter` (any calendar, converts at format time), `FixedCalendarDateTimeFormatter<C>` (compile-time calendar), `NoCalendarFormatter` (time only) |
| **Parsing** | Built-in — `parse()` methods on `SimpleDateFormat` | **Not included** — ICU4X formatters are format-only, no parsing |
| **Output type** | `UnicodeString&` (mutated in place) | `FormattedDateTime` implementing `Writeable` — lazy, writes to any `fmt::Write` sink |

**Key difference:** ICU4C's `SimpleDateFormat` is a do-everything mutable object: it formats, parses, holds a calendar, holds a number formatter, and allows runtime pattern changes. ICU4X splits these concerns across separate types and doesn't support parsing at all.

## 2. Formatter Construction

### ICU4C — Factory Methods + Mutable Configuration

```cpp
// Style-based
DateFormat* df = DateFormat::createDateInstance(DateFormat::kLong, Locale("ja_JP"));

// Skeleton-based
DateTimePatternGenerator* dtpg = DateTimePatternGenerator::createInstance(locale, status);
UnicodeString pattern = dtpg->getBestPattern("yMMMMd", status);
SimpleDateFormat sdf(pattern, locale, status);

// Direct pattern
SimpleDateFormat sdf("yyyy-MM-dd HH:mm:ss", locale, status);

// Then mutate as needed
sdf.adoptCalendar(Calendar::createInstance(Locale("ja_JP@calendar=japanese"), status));
sdf.adoptNumberFormat(new ArabicNumberFormat(...));
```

Three separate steps: create generator, get pattern, create formatter. Or use factory + mutate.

### ICU4X — Declarative, One-Step Construction

```rust
// Static field set (compile-time known)
let formatter = DateTimeFormatter::try_new(prefs, YMD::long())?;

// Fixed calendar (no conversion overhead)
let formatter = FixedCalendarDateTimeFormatter::<Gregorian, _>::try_new(prefs, YMD::medium())?;

// Dynamic field set (runtime)
let mut builder = FieldSetBuilder::default();
builder.date_fields = Some(DateFields::YMD);
builder.length = Some(Length::Long);
let field_set = builder.build_date()?;
let formatter = DateTimeFormatter::try_new(prefs, field_set)?;
```

One call loads patterns, names, and decimal formatter all at once. No mutation after construction.

## 3. Pattern System

### ICU4C — Raw LDML Patterns

ICU4C works directly with LDML/UTS#35 pattern strings:

```
"EEEE, MMMM d, y"     -> "Friday, March 15, 2024"
"yyyy-MM-dd"           -> "2024-03-15"
"h:mm a"               -> "3:45 PM"
```

Full pattern character set (30+ characters): `G y Y u U Q q M L l w W d D F g E e c a b B h H K k m s S A z Z O v V X x`.

Developers can write arbitrary patterns — powerful but error-prone (locale-inappropriate patterns are common).

### ICU4X — Semantic Skeletons (No Raw Patterns in Public API)

ICU4X deliberately hides raw pattern strings. Instead you specify **what** to format and **how long**:

```rust
YMD::long()     // Year + Month + Day, long style
YMDT::medium()  // Year + Month + Day + Time, medium style
T::short()      // Time only, short style
```

The system maps this to locale-appropriate patterns internally. You never see `"MMMM d, yyyy"` — that's an implementation detail.

There is a lower-level `DateTimePatternFormatter` for power users who need raw patterns, but it's not the primary API.

| | ICU4C | ICU4X |
|--|-------|-------|
| Raw pattern strings | Primary API | Hidden/power-user only |
| Skeleton -> pattern | Via `DateTimePatternGenerator` (separate step) | Built into formatter construction |
| Pattern mutation | `applyPattern()` at any time | Not supported — construct a new formatter |
| Invalid patterns | Runtime errors or silent wrong output | Compile-time type errors (wrong field set) |

## 4. Field Sets (ICU4X) vs Styles (ICU4C)

### ICU4C Styles

```cpp
DateFormat::kShort    // "12/13/52"
DateFormat::kMedium   // "Jan 12, 1952"
DateFormat::kLong     // "January 12, 1952"
DateFormat::kFull     // "Tuesday, April 12, 1952"
```

Four lengths, applied to date and/or time independently:

```cpp
DateFormat::createDateTimeInstance(kLong, kShort, locale);  // long date + short time
```

### ICU4X Field Sets

Field sets are **type-level** — the compiler knows what fields are being formatted:

| Field Set | Components |
|-----------|-----------|
| `D` | Day only |
| `MD` | Month + Day |
| `YMD` | Year + Month + Day |
| `DE` | Day + Weekday |
| `MDE` | Month + Day + Weekday |
| `YMDE` | Year + Month + Day + Weekday |
| `T` | Time only |
| `DT` | Day + Time |
| `MDT` | Month + Day + Time |
| `YMDT` | Year + Month + Day + Time |
| `ET` | Weekday + Time |
| ... | (many more combinations) |

Each has `.short()`, `.medium()`, `.long()` methods. This is more granular than ICU4C — you can say "month + day, no year" directly, rather than relying on skeleton matching to strip the year.

## 5. DateTimePatternGenerator Comparison

### ICU4C — Explicit, Stateful Generator

```cpp
DateTimePatternGenerator* dtpg = DateTimePatternGenerator::createInstance(locale, status);

// Get best pattern for skeleton
UnicodeString pattern = dtpg->getBestPattern("yMMMd", status);
// -> "MMM d, y" for en_US, "d MMM y" for en_GB

// Customize
dtpg->addPattern("dd/MM/yyyy", true, conflicting, status);
dtpg->setAppendItemFormat(UDATPG_ERA_FIELD, "{0} ({2}: {1})");
dtpg->setDateTimeFormat("{1} 'at' {0}");

// Enumerate available skeletons
StringEnumeration* skeletons = dtpg->getSkeletons(status);
```

Full API for customization: add patterns, change append formats, modify date-time glue patterns.

### ICU4X — Implicit, Built Into Formatter

No separate `DateTimePatternGenerator` type. The skeleton matching algorithm exists internally in `provider/skeleton/helpers.rs` using the same distance scoring:

| Match Quality | ICU4C | ICU4X |
|---------------|-------|-------|
| Exact match | Distance 0 | `NO_DISTANCE` |
| Width mismatch (M vs MM) | Low penalty | `WIDTH_MISMATCH_DISTANCE` (1) |
| Text vs numeric (MMM vs MM) | Medium penalty | `TEXT_VS_NUMERIC_DISTANCE` (100) |
| Missing field | High penalty | `REQUESTED_SYMBOL_MISSING` (100000) |

Same algorithm, but in ICU4X it's only used at data build time to pre-compute pattern selections. At runtime, the formatter just looks up the pre-resolved pattern. No customization API.

## 6. Non-Gregorian Calendar Formatting

### ICU4C

```cpp
Calendar* cal = Calendar::createInstance(Locale("ar_SA@calendar=islamic"), status);
DateFormat* df = DateFormat::createDateInstance(DateFormat::kLong, Locale("ar_SA@calendar=islamic"));
UnicodeString result;
df->format(cal->getTime(status), result, status);
```

- `DateFormatSymbols` loads calendar-type-specific strings (e.g., `"Eras_japanese"`, `"MonthNames_hebrew"`)
- Falls back to Gregorian names if specialized ones aren't available
- Calendar type is set via locale keyword `@calendar=xxx`

### ICU4X

```rust
// Compile-time calendar (only loads Hebrew data)
let formatter = FixedCalendarDateTimeFormatter::<Hebrew, _>::try_new(prefs, YMD::long())?;
let date = Date::try_new_hebrew(5784, 7, 15)?;
let result = formatter.format(&date);

// Runtime calendar (loads all calendar data)
let formatter = DateTimeFormatter::try_new(prefs, YMD::long())?;
let date = Date::try_new_hebrew(5784, 7, 15)?.to_any();
let result = formatter.format(&date)?;
```

- Each calendar has **separate data markers**: `DatetimeNamesMonthGregorianV1`, `DatetimeNamesMonthHebrewV1`, etc.
- `FixedCalendarDateTimeFormatter<Hebrew>` only links Hebrew data — binary size optimization
- `DateTimeFormatter` converts the input calendar to the formatter's calendar before formatting

**Key difference:** ICU4C loads calendar-specific names at runtime via resource bundle fallback. ICU4X resolves them at compile time through separate data marker types per calendar — this means unused calendar data can be tree-shaken out of the binary.

## 7. Name Resolution (Months, Weekdays, Eras)

### ICU4C — `DateFormatSymbols`

```cpp
DateFormatSymbols symbols(Locale("en_US"), "gregorian", status);

// Month names by context x width
const UnicodeString* months = symbols.getMonths(count,
    DateFormatSymbols::FORMAT, DateFormatSymbols::WIDE);
// -> ["January", "February", ..., "December"]

const UnicodeString* months = symbols.getMonths(count,
    DateFormatSymbols::STANDALONE, DateFormatSymbols::ABBREVIATED);
// -> ["Jan", "Feb", ..., "Dec"]

// Eras
const UnicodeString* eras = symbols.getEras(count);        // "BC", "AD"
const UnicodeString* eraNames = symbols.getEraNames(count); // "Before Christ", "Anno Domini"

// Special: Chinese zodiac, cyclic year names
const UnicodeString* zodiac = symbols.getZodiacNames(count);
```

Two dimensions: **context** (format vs standalone) x **width** (wide, abbreviated, narrow, short).

### ICU4X — Loaded Per Name Type Into `RawDateTimeNames`

```rust
// Name lengths map to CLDR attributes
YearNameLength::Wide        // "Anno Domini"
YearNameLength::Abbreviated // "AD"
YearNameLength::Narrow      // "A"

MonthNameLength::Wide             // "January" (format context)
MonthNameLength::Abbreviated      // "Jan"
MonthNameLength::StandaloneWide   // "January" (standalone context)
```

Same context x width matrix, but names are loaded as typed data payloads during construction, not as mutable arrays. The formatter's `FSet` type parameter determines which name lengths are needed, so only the required widths are loaded.

## 8. Number System Integration

| | ICU4C | ICU4X |
|--|-------|-------|
| **Per-field override** | `adoptNumberFormat("yM", arabicFormatter)` — different number systems for year vs month | Not supported — single `DecimalFormatter` for all fields |
| **Global numbering** | Constructor override: `SimpleDateFormat(pattern, "d=hebrew;y=thai", locale)` | Via `DateTimeFormatterPreferences { numbering_system: ... }` |
| **Supported systems** | Arabic, Thai, Devanagari, etc. via `NumberFormat` | Same, via `DecimalFormatter` |

ICU4C's per-field number format override is unique — you can format the year in Thai digits and the month in Arabic digits in the same output. ICU4X doesn't support this.

## 9. Date Interval Formatting

### ICU4C — `DateIntervalFormat`

```cpp
DateIntervalFormat* dif = DateIntervalFormat::createInstance("yMMMd", locale, status);
DateInterval interval(date1, date2);
UnicodeString result;
dif->format(&interval, result, pos, status);
// -> "Jan 10 - 20, 2007" (omits redundant year/month)
```

- Automatically identifies the **largest differing field** and minimizes redundancy
- Skeleton-based (shares pattern logic with `DateTimePatternGenerator`)
- Supports all calendar types

### ICU4X — **Not implemented**

No `DateIntervalFormatter` exists in the current ICU4X datetime component.

## 10. Relative Date/Time Formatting

### ICU4C — `RelativeDateTimeFormatter`

```cpp
RelativeDateTimeFormatter fmt(locale, status);
fmt.formatNumeric(2, UDAT_RELATIVE_DAYS, result, status);  // "in 2 days"
fmt.format(-1, UDAT_RELATIVE_DAYS, result, status);        // "yesterday"
fmt.formatAbsolute(UDAT_ABSOLUTE_TUESDAY, UDAT_DIRECTION_NEXT, result, status); // "next Tuesday"
```

- `formatNumeric()` — always uses numbers: "2 days ago"
- `format()` — uses names when available: "yesterday" instead of "1 day ago"
- `formatAbsolute()` — named references: "next Tuesday", "this month"

### ICU4X — `RelativeTimeFormatter` (Experimental)

```rust
let formatter = RelativeTimeFormatter::try_new_long_day(prefs)?;
formatter.format(FixedDecimal::from(2))   // "in 2 days"
formatter.format(FixedDecimal::from(-1))  // "1 day ago" or "yesterday" depending on Numeric option
```

- Located in `components/experimental/` — not yet stable
- Uses `PluralRules` for grammatical number
- Supports `Numeric::Always` vs `Numeric::Auto` (like ICU4C's `formatNumeric` vs `format`)
- Pre-configured constructors per unit and length: `try_new_long_day()`, `try_new_short_year()`, etc.
- No `formatAbsolute()` equivalent for named days like "next Tuesday"

## 11. Field Position / Parts Tracking

### ICU4C

```cpp
FieldPosition pos(UDAT_YEAR_FIELD);
formatter->format(date, result, pos, status);
int32_t yearStart = pos.getBeginIndex();
int32_t yearEnd = pos.getEndIndex();

// Or iterate all fields:
FieldPositionIterator iter;
formatter->format(date, result, &iter, status);
while (iter.next(pos)) { /* process each field */ }
```

### ICU4X

```rust
let formatted = formatter.format(&date);

// Write with parts tracking
let mut sink = PartsWriteSink::new();
formatted.write_to_parts(&mut sink)?;
// Parts: datetime::YEAR, datetime::MONTH, datetime::DAY, etc.
```

Both support identifying field boundaries in the output. ICU4C uses index pairs; ICU4X uses the `Writeable::write_to_parts()` protocol with typed `Part` constants.

## 12. Summary of Key Differences

| Dimension | ICU4C | ICU4X |
|-----------|-------|-------|
| **Primary type** | `SimpleDateFormat` — mutable, all-in-one | `DateTimeFormatter<FSet>` — immutable, field-set-typed |
| **Pattern API** | Raw LDML strings as primary API | Semantic skeletons (field set + length), patterns hidden |
| **Pattern generator** | Explicit `DateTimePatternGenerator` with customization | Implicit, built into data pipeline, no customization |
| **Parsing** | Built-in `parse()` | Not supported |
| **Calendar handling** | One formatter, swap calendar at runtime | Three formatter tiers with different calendar flexibility |
| **Name loading** | `DateFormatSymbols` — runtime, all names loaded | Per-type data markers — compile-time, only needed names loaded |
| **Number systems** | Per-field overrides possible | Single number system for all fields |
| **Interval formatting** | `DateIntervalFormat` | Not implemented |
| **Relative time** | Stable `RelativeDateTimeFormatter` | Experimental `RelativeTimeFormatter` (subset of features) |
| **Data model** | ResourceBundle — runtime locale data loading | Data providers — compile-time baked, buffer, or custom |
| **Binary size** | All data linked | Tree-shakeable per calendar, per name width |

### Bottom Line

**ICU4C** gives you a maximally flexible formatting toolkit: raw patterns, mutable configuration, built-in parsing, interval formatting, per-field number systems, and 25 years of edge cases handled. The trade-off is a complex, stateful API with lots of ways to misuse it (locale-inappropriate patterns being the classic mistake).

**ICU4X** trades flexibility for correctness-by-construction: semantic skeletons prevent locale-inappropriate patterns, typed field sets catch errors at compile time, and separate formatter tiers let you pay only for the calendar flexibility you need. But it's still incomplete — no parsing, no interval formatting, experimental relative time, and no per-field number customization.

# ICU4C vs ICU4X: Calendar API Complete Analysis

## 1. Architecture & Type System

| Aspect | ICU4C (C++) | ICU4X (Rust) |
|--------|-------------|--------------|
| **Paradigm** | OOP inheritance — abstract `Calendar` base class, virtual methods | Trait-based generics — `Calendar` sealed trait, `Date<A: AsCalendar>` generic type |
| **Polymorphism** | Runtime only — `Calendar*` pointers, `clone()`, `getDynamicClassID()` | Compile-time **and** runtime — monomorphized `Date<Gregorian>` or erased `Date<AnyCalendar>` |
| **Ownership** | Raw pointers (`Calendar* createInstance(...)`) — caller must `delete` | Rust ownership — `Copy` types for simple calendars, `Clone` for data-heavy ones (Japanese, Chinese) |
| **Error handling** | `UErrorCode&` out-parameter on every call | `Result<T, E>` return types — errors are typed (`DateError`, `DateAddError`, `CompatibilityError`) |
| **Internal representation** | Milliseconds since Unix epoch (`UDate` = `double`) | `RataDie` — integer day count from Jan 1, year 1 ISO (no time component) |

**Key difference:** ICU4C is a mutable, stateful object — you create a `Calendar*`, then `set()` fields and `get()` them. ICU4X `Date<C>` is an immutable value type — you construct it, query it, or produce a new one via arithmetic.

## 2. Supported Calendar Systems

| Calendar | ICU4C | ICU4X | Notes |
|----------|:-----:|:-----:|-------|
| ISO 8601 | `ISO8601Calendar` | `Iso` | ICU4C inherits from Gregorian; ICU4X uses it as the conversion pivot |
| Gregorian | `GregorianCalendar` | `Gregorian` | Both have CE/BCE eras |
| Julian | — | `Julian` | **ICU4X only** — ICU4C has no Julian calendar |
| Buddhist | `BuddhistCalendar` | `Buddhist` | Both offset from Gregorian by 543 years |
| Japanese | `JapaneseCalendar` | `Japanese` | Both support era-based years (Meiji->Reiwa) |
| ROC/Taiwan | `TaiwanCalendar` | `Roc` | Both offset from 1912 |
| Hebrew | `HebrewCalendar` | `Hebrew` | Both implement Metonic cycle |
| Islamic (Civil) | `IslamicCivilCalendar` | `Hijri<TabularAlgorithm>` | ICU4X has configurable Type I/II + epoch variants |
| Islamic (Umm al-Qura) | `IslamicUmalquraCalendar` | `Hijri<UmmAlQura>` | Saudi Arabia official |
| Islamic (TBLA) | `IslamicTBLACalendar` | (via TabularAlgorithm config) | |
| Islamic (RGSA) | `IslamicRGSACalendar` | `Hijri<AstronomicalSimulation>` (deprecated) | |
| Chinese | `ChineseCalendar` | `EastAsianTraditional<China>` | Both handle 60-year cycles and leap months |
| Dangi (Korean) | `DangiCalendar` | `EastAsianTraditional<Korea>` | ICU4C inherits from Chinese; ICU4X uses shared generic |
| Persian | `PersianCalendar` | `Persian` | Solar Hijri |
| Indian (Saka) | `IndianCalendar` | `Indian` | |
| Coptic | `CopticCalendar` | `Coptic` | Both use CECalendar/AbstractGregorian base |
| Ethiopian | `EthiopicCalendar` | `Ethiopian` | Both support Amete Mihret + Amete Alem eras |
| Ethiopic Amete Alem | `EthiopicAmeteAlemCalendar` | (via Ethiopian style flag) | |

**Score: ICU4C = 15 systems, ICU4X = 16 systems** (ICU4X adds Julian; ICU4C has a slightly different Islamic variant breakdown).

## 3. Field Model

### ICU4C: Mutable Field Array

```cpp
// 24 fields via UCalendarDateFields enum
cal->set(UCAL_YEAR, 2024);
cal->set(UCAL_MONTH, 2);       // 0-indexed! March = 2
cal->set(UCAL_DAY_OF_MONTH, 15);
int32_t dow = cal->get(UCAL_DAY_OF_WEEK, status);
```

- **24 fields** including time-of-day (HOUR, MINUTE, SECOND, MILLISECOND), week fields, zone offsets, JULIAN_DAY
- **0-indexed months** (January = 0) — a notorious footgun
- Fields are lazily resolved — setting one field doesn't immediately recompute others
- Field resolution priority tables decide conflicts (e.g., MONTH+DAY vs DAY_OF_YEAR)

### ICU4X: Typed Accessors

```rust
let date = Date::try_new_gregorian(2024, 3, 15)?;  // 1-indexed months!
let dow: Weekday = date.weekday();
let month: MonthInfo = date.month();    // includes ordinal, code, leap status
let year: YearInfo = date.year();       // Era or Cyclic variant
```

- **No field enum** — individual typed methods instead
- **1-indexed months** (January = 1)
- No time-of-day fields — this is a pure date library
- `MonthInfo` bundles ordinal + month code + leap status
- `YearInfo` is an enum: `Era(EraYear)` or `Cyclic(CyclicYear)`

**Key difference:** ICU4C gives you a bag of 24 mutable integer fields. ICU4X gives you strongly-typed, read-only accessors. ICU4X is safer but less flexible for partial/ambiguous date construction.

## 4. Date Arithmetic

### ICU4C

```cpp
cal->add(UCAL_MONTH, 3, status);      // mutates in-place, carries overflow
cal->roll(UCAL_MONTH, 3, status);     // wraps within field, no carry
int32_t diff = cal->fieldDifference(targetDate, UCAL_MONTH, status);
```

- `add()` — carries between fields (adding months can change year)
- `roll()` — wraps within a single field (unique to ICU4C)
- `fieldDifference()` — difference in a single field unit
- All operations are **stable API**

### ICU4X

```rust
// Unstable feature!
let duration = DateDuration { years: 0, months: 3, weeks: 0, days: 0, is_negative: false };
let new_date = date.try_added_with_options(duration, options)?;
let diff = date1.try_until_with_options(&date2, options)?;  // returns DateDuration
```

- `DateDuration` struct with years/months/weeks/days (ISO 8601 style)
- `try_add_with_options` (mutating) / `try_added_with_options` (non-mutating)
- `try_until_with_options` — returns a full `DateDuration`, configurable largest unit
- **No `roll()` equivalent**
- **Entire arithmetic API is unstable** (feature-gated)
- Overflow handling: `Constrain` (clamp) or `Reject` (error)

## 5. Time & Timezone Integration

| | ICU4C | ICU4X |
|--|-------|-------|
| **Time-of-day** | Built-in (HOUR, MINUTE, SECOND, MILLISECOND fields) | **Not included** — separate `icu_datetime` crate |
| **Timezone** | Full integration — `adoptTimeZone()`, `setTimeZone()`, DST handling, ambiguous time resolution | **None** in calendar crate |
| **Internal epoch** | `UDate` = milliseconds since Unix epoch (includes time) | `RataDie` = day count only |

This is a **fundamental architectural difference**. ICU4C's `Calendar` is a date+time+timezone object. ICU4X's `Date` is purely a calendar date — time and timezone are separate concerns in separate crates.

## 6. Construction & Factory Patterns

### ICU4C — Factory + Locale

```cpp
// Factory creates heap-allocated polymorphic object
Calendar* cal = Calendar::createInstance(Locale("ja_JP@calendar=japanese"), status);
cal->set(2024, 2, 15);  // then mutate
```

- Always heap-allocated via `createInstance()`
- Locale string `@calendar=xxx` selects calendar type
- Returns `Calendar*` — caller manages lifetime

### ICU4X — Direct Construction or AnyCalendar

```rust
// Compile-time known calendar (zero-cost)
let date = Date::try_new_gregorian(2024, 3, 15)?;

// Runtime calendar selection
let cal = AnyCalendar::new(AnyCalendarKind::Japanese);
let date = Date::try_new(YearInput::Extended(2024), Month::march(), 15, cal)?;

// From locale
let kind = AnyCalendarKind::new(locale);
```

- Most calendars are zero-size `Copy` types (no heap allocation)
- `AnyCalendar` for runtime polymorphism (like ICU4C's approach)
- `try_new()` with `YearInput` enum supports era-based or extended year input

## 7. Month Code / Temporal Integration

| | ICU4C | ICU4X |
|--|-------|-------|
| Format | `"M01"` through `"M13"`, `"M05L"` for leap | Same: `"M01"`-`"M13"`, suffix `"L"` for leap |
| API | `getTemporalMonthCode()` / `setTemporalMonthCode()` | Built into `MonthInfo::month_code()` |
| Ordinal month | `UCAL_ORDINAL_MONTH` field (1-indexed) | `date.month().ordinal` (1-indexed) |

ICU4X has Temporal concepts baked in from the start. ICU4C added them later as additional methods.

## 8. Leniency & Overflow

| | ICU4C | ICU4X |
|--|-------|-------|
| Lenient mode | `setLenient(true/false)` — lenient accepts out-of-range values and rolls over | `Overflow::Constrain` (clamp to valid range) or `Overflow::Reject` (return error) |
| Default | Lenient by default | Reject by default |
| Granularity | Global toggle | Per-operation option |

## 9. Week Configuration

| | ICU4C | ICU4X |
|--|-------|-------|
| First day of week | `setFirstDayOfWeek()` / `getFirstDayOfWeek()` | Not configurable on `Date` — ISO weeks only (`week_of_year()` on Iso calendar) |
| Minimal days in first week | `setMinimalDaysInFirstWeek()` | Not exposed |
| Weekend info | `isWeekend()`, `getDayOfWeekType()`, `getWeekendTransition()` | Not in calendar crate |

ICU4C has significantly richer week/weekend configuration.

## 10. Summary of Key Differences

| Dimension | ICU4C | ICU4X |
|-----------|-------|-------|
| **Design era** | ~1999, evolved over 25 years | ~2020, clean-sheet Rust design |
| **Mutability** | Mutable stateful object | Immutable value types |
| **Type safety** | Runtime types, integer fields | Compile-time generics, typed accessors |
| **Month indexing** | 0-based (footgun) | 1-based |
| **Scope** | Date + Time + Timezone in one class | Date only (separation of concerns) |
| **Arithmetic** | Stable, mature (`add`/`roll`/`fieldDifference`) | Unstable, feature-gated, no `roll()` |
| **Memory model** | Heap-allocated, pointer-based | Stack-allocated for most calendars, zero-cost (see below) |
| **Calendar count** | 15 | 16 (adds Julian) |
| **Data dependencies** | All calendars need ICU data | Most calendars are code-only; Japanese/Chinese/Hijri need data |
| **Temporal alignment** | Retrofitted | Native |
| **Week/weekend** | Rich configuration | Minimal |

### What "Stack-Allocated, Zero-Cost" Means for ICU4X

In ICU4C, every `Calendar::createInstance()` call allocates a `Calendar` object on the heap (via `new`). When you call a method like `cal->add(...)`, the CPU follows a pointer to the heap object, looks up the method in a hidden function-pointer table (the "vtable"), and jumps to whichever implementation matches the runtime type (e.g., `GregorianCalendar::add`). The compiler cannot see through this indirection, so it cannot inline or optimize the call.

In ICU4X, most calendar types are empty structs with no data — for example, `pub struct Gregorian;` is literally zero bytes. They exist only as type-level markers that tell the compiler which calendar math to use. A `Date<Gregorian>` struct contains just the date's inner data (year, month, day — roughly 12 bytes) plus the calendar type (zero bytes, optimized away entirely). The whole thing lives on the stack, not the heap.

When the Rust compiler sees `Date<Gregorian>`, it generates a completely separate, specialized copy of every `Date` method hardcoded for `Gregorian` — as if you had hand-written a dedicated `GregorianDate` type with non-generic methods. This process is called "monomorphization." Because the compiler knows exactly which calendar's code to call at compile time, it can inline the calendar methods directly, eliminate any indirection, and optimize aggressively. There is no pointer to follow, no vtable to consult, and no runtime decision about which implementation to use. That is the "zero-cost" part — the generic abstraction compiles away entirely, producing code as efficient as if no abstraction existed.

The exceptions are calendars that need runtime data: `Japanese` stores era information loaded from a data provider, and `EastAsianTraditional<China/Korea>` needs precomputed leap month tables. These are still small and stack-friendly, but they are `Clone` rather than `Copy` and require a data provider to construct.

For cases where the calendar type is not known at compile time (e.g., it comes from user input or a locale setting), ICU4X provides `Date<AnyCalendar>`, which uses runtime dispatch similar to ICU4C's approach. You choose the model that fits your use case: compile-time generics for performance, or `AnyCalendar` for flexibility.

### Bottom Line

**ICU4C** is a battle-tested, feature-complete date+time+timezone+calendar monolith. Its mutable field-bag design gives maximum flexibility but less safety.

**ICU4X** is a modern, type-safe, modular redesign that separates date from time from timezone. It's safer and more efficient (zero-cost abstractions, no heap allocation for most calendars) but its arithmetic API is still unstable and it lacks ICU4C's time-of-day and timezone integration within the calendar type itself.

They support nearly identical calendar systems and are converging on Temporal-compatible month codes, but the programming models are fundamentally different — reflecting the 20+ year gap in language and API design philosophy between them.

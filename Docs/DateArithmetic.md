# DateArithmetic — Phase 7

*Completed: 2026-03-29*

## Overview

DateArithmetic adds date addition and difference operations to `Date<C>`. It depends only on CalendarCore and works generically with all 10 calendar systems (and any future ones). The algorithms implement the TC39 Temporal specification's abstract operations, ported from ICU4X's `calendar_arithmetic.rs`.

## API

```swift
import DateArithmetic

// Addition: returns a new date
let result = try date.added(duration, overflow: .constrain)

// Difference: returns a duration
let diff = date1.until(date2, largestUnit: .years)
```

### DateDuration

```swift
public struct DateDuration: Sendable, Equatable {
    public var isNegative: Bool       // all fields share this sign
    public var years: UInt32
    public var months: UInt32
    public var weeks: UInt32
    public var days: UInt64
}
```

Fields are unsigned; `isNegative` applies to all fields (mixed signs are not permitted). Factory methods accept signed values:

```swift
DateDuration.forYears(3)       // +3 years
DateDuration.forMonths(-5)     // -5 months
DateDuration.forDays(100)      // +100 days
DateDuration.forWeeks(-2)      // -2 weeks
DateDuration.zero              // zero duration
```

### Overflow

```swift
public enum Overflow {
    case constrain   // clamp to nearest valid value (default)
    case reject      // throw DateAddError
}
```

Examples:
- Jan 31 + 1 month with `.constrain` → Feb 28 (or 29 in leap year)
- Jan 31 + 1 month with `.reject` → throws `DateAddError.invalidDay(max: 28)`
- Feb 29 + 1 year with `.constrain` → Feb 28

### DateDurationUnit

```swift
public enum DateDurationUnit {
    case years, months, weeks, days
}
```

Used as `largestUnit` parameter in `until()` to control result granularity.

## Algorithms

### Addition: NonISODateAdd (Temporal spec)

The `Date.added(_:overflow:)` method follows this sequence:

1. **Add years** to the date's extended year
2. **Constrain month** — if the original month exceeds the new year's month count, clamp it
3. **Get end-of-month** — `balance(y0, m0 + months + 1, 0)` gives the last day of the target month
4. **Regulate day** — if the original day exceeds end-of-month, either constrain or reject per `overflow`
5. **Add weeks and days** — `regulatedDay + weeks*7 + days`
6. **Balance** — overflow/underflow of days ripples into months, which ripples into years

### Difference: NonISODateUntil (Temporal spec)

The `Date.until(_:largestUnit:)` method:

1. **Fast path**: for `.days` or `.weeks`, compute RataDie difference directly (O(1))
2. **Determine sign**: which date is later?
3. **Find years**: iteratively increment candidate years until adding them would surpass the target
4. **Find months**: same iterative approach, starting from the frozen year value
5. **Find days**: same approach for remaining days (at most 31 iterations)

The "surpasses" check compares the result of adding a candidate duration to the start date against the target date, using lexicographic (year, month, day) comparison.

### Balance: BalanceNonISODate (Temporal spec)

`DateArithmeticHelper.balance(year:month:day:calendar:)` handles out-of-range months and days:

- **Month underflow** (month ≤ 0): decrement year, add monthsInYear, repeat
- **Month overflow** (month > monthsInYear): subtract monthsInYear, increment year, repeat
- **Day underflow** (day ≤ 0): decrement month, add daysInMonth, repeat
- **Day overflow** (day > daysInMonth): subtract daysInMonth, increment month, repeat

This is calendar-generic — it queries `monthsInYear` and `daysInMonth` through the `CalendarProtocol`, so it automatically handles 13-month calendars (Hebrew, Coptic, Ethiopian) and variable month lengths.

## Design Decisions

### Why unsigned fields + isNegative?

Follows ICU4X/Temporal convention. Prevents mixed-sign durations which would create ambiguous arithmetic (e.g., +1 month -5 days). The `isNegative` flag makes the sign explicit and shared.

### Why no roll()?

The implementation plan included `roll()` (ICU4C's field-wrapping operation), but we deferred it. `roll()` is less commonly needed than `added()` and `until()`, and can be implemented later as a convenience on top of the existing infrastructure. The core algorithms (balance, surpasses) don't need it.

### Why does DateArithmetic depend only on CalendarCore?

The arithmetic is fully generic over `CalendarProtocol`. It queries the calendar for `monthsInYear` and `daysInMonth` but doesn't need to know which specific calendar it's working with. This means:
- Users can add DateArithmetic without pulling in CalendarSimple/Complex
- Future calendars automatically get arithmetic support
- The dependency graph stays clean

### Why iterative surpasses instead of direct computation?

Month and year arithmetic in non-ISO calendars is inherently non-uniform (Hebrew months vary 29-30 days depending on year type, some years have 13 months). There's no closed-form solution for "how many months between two dates in the Hebrew calendar." The iterative approach with the surpasses check is correct for all calendars. ICU4X uses the same approach, with performance optimizations (year-diff pre-guess, SurpassesChecker caching) that we partially implement.

## Source

- **ICU4X** `components/calendar/src/calendar_arithmetic.rs` — NonISODateAdd (line 845), NonISODateUntil (line 933), BalanceNonISODate (line 580)
- **ICU4X** `components/calendar/src/duration.rs` — DateDuration type
- **ICU4X** `components/calendar/src/options.rs` — Overflow, DateAddOptions, DateDifferenceOptions
- **TC39 Temporal** — abstract operations specification

## Test Coverage

24 tests covering:
- `DateDuration` factory methods and weeks/days decomposition
- Day addition: ±5000 days, Feb boundary in leap/non-leap years, backward from Mar 1
- Month arithmetic: negative month offsets crossing year boundaries
- Month-end clamping: constrain and reject overflow modes
- Combined durations: 1Y2M3W4D forward and reverse
- Year arithmetic: Feb 29 + 1 year (constrain), Feb 29 + 4 years (preserves)
- Difference: days, weeks, year+month, negative, round-trip verification
- Exhaustive: every day in 2000-2001 × 5 day offsets (730 dates × 5 = 3,650 assertions)

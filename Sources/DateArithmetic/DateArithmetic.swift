// Date arithmetic: addition, difference, and balancing.
//
// Implements the Temporal abstract operations NonISODateAdd, NonISODateUntil,
// and BalanceNonISODate. Ported from ICU4X calendar_arithmetic.rs (Unicode License).

import CalendarCore

// MARK: - Date Addition

extension Date {
    /// Returns a new date by adding the given duration.
    ///
    /// The algorithm follows the Temporal specification's NonISODateAdd:
    /// 1. Add years → constrain month to the new year
    /// 2. Add months → balance into year
    /// 3. Constrain day to the resulting month
    /// 4. Add weeks and days → balance into month/year
    ///
    /// - Parameters:
    ///   - duration: The duration to add.
    ///   - overflow: How to handle out-of-range values (default: `.constrain`).
    /// - Returns: A new date with the duration applied.
    /// - Throws: `DateAddError` if the result overflows or if `.reject` is used and a field is out of range.
    public func added(
        _ duration: DateDuration,
        overflow: Overflow = .constrain
    ) throws -> Date<C> {
        let inner = self.inner
        let cal = self.calendar

        // Extract current ordinal month and day
        let curMonth = cal.monthInfo(inner).ordinal
        let curDay = cal.dayOfMonth(inner)
        let curYear = self.extendedYear

        // Step 1: Add years
        let y0 = duration.addYearsTo(curYear)

        // Step 2: Constrain month to new year
        let monthsInY0 = monthsInYearForExtended(y0, calendar: cal)
        let m0 = min(curMonth, monthsInY0)

        // Step 3: Get end-of-month for the target month
        // balance(y0, m0 + months + 1, 0) = last day of month (m0 + months)
        let endOfMonth = DateArithmeticHelper.balance(
            year: y0,
            month: duration.addMonthsTo(m0) + 1,
            day: 0,
            calendar: cal
        )

        // Step 4: Regulate day
        let regulatedDay: UInt8
        if curDay <= endOfMonth.day {
            regulatedDay = curDay
        } else {
            if overflow == .reject {
                throw DateAddError.invalidDay(max: endOfMonth.day)
            }
            regulatedDay = endOfMonth.day
        }

        // Step 5: Add weeks and days, then balance
        let finalDay = duration.addWeeksAndDaysTo(regulatedDay)
        let result = DateArithmeticHelper.balance(
            year: endOfMonth.year,
            month: Int64(endOfMonth.month),
            day: finalDay,
            calendar: cal
        )

        // Convert back to Date
        let resultInner = try cal.newDate(
            year: .extended(result.year),
            month: .new(result.month),
            day: result.day
        )
        return Date(inner: resultInner, calendar: cal)
    }
}

// MARK: - Date Difference

extension Date {
    /// Computes the duration from this date to another date.
    ///
    /// The result, when added to `self`, produces `other`.
    ///
    /// - Parameters:
    ///   - other: The target date.
    ///   - largestUnit: The largest unit to include in the result (default: `.days`).
    /// - Returns: A `DateDuration` representing the difference.
    public func until(
        _ other: Date<C>,
        largestUnit: DateDurationUnit = .days
    ) -> DateDuration {
        // Fast path for days/weeks: use RataDie difference
        if largestUnit == .days {
            return DateDuration.forDays(other.rataDie.dayNumber - self.rataDie.dayNumber)
        }
        if largestUnit == .weeks {
            return DateDuration.forWeeksAndDays(other.rataDie.dayNumber - self.rataDie.dayNumber)
        }

        // Determine sign
        let cal = self.calendar
        if self == other {
            return .zero
        }
        let sign: Int64 = other > self ? 1 : -1

        let selfYear = self.extendedYear
        let selfMonth = cal.monthInfo(self.inner).ordinal
        let selfDay = cal.dayOfMonth(self.inner)

        let otherYear = other.extendedYear
        let otherMonth = cal.monthInfo(other.inner).ordinal
        let otherDay = cal.dayOfMonth(other.inner)

        // Step 1: Find years
        var years: Int64 = 0
        if largestUnit == .years {
            let yearDiff = Int64(otherYear) - Int64(selfYear)
            let minYears: Int64 = yearDiff == 0 ? 0 : yearDiff - sign
            var candidateYears: Int64 = minYears != 0 ? minYears : sign

            while !surpassesAfterYears(
                sign: sign, baseYear: selfYear, baseMonth: selfMonth, baseDay: selfDay,
                years: candidateYears,
                targetYear: otherYear, targetMonth: otherMonth, targetDay: otherDay,
                calendar: cal
            ) {
                years = candidateYears
                candidateYears += sign
            }
        }

        // Step 2: Find months
        var months: Int64 = 0
        if largestUnit == .years || largestUnit == .months {
            var candidateMonths = sign
            while !surpassesAfterYearsMonths(
                sign: sign, baseYear: selfYear, baseMonth: selfMonth, baseDay: selfDay,
                years: years, months: candidateMonths,
                targetYear: otherYear, targetMonth: otherMonth, targetDay: otherDay,
                calendar: cal
            ) {
                months = candidateMonths
                candidateMonths += sign
            }
        }

        // Step 3: Find days
        // Compute the intermediate date after adding years+months
        var days: Int64 = 0
        var candidateDays = sign
        while !surpassesAfterYearsMonthsDays(
            sign: sign, baseYear: selfYear, baseMonth: selfMonth, baseDay: selfDay,
            years: years, months: months, days: candidateDays,
            targetYear: otherYear, targetMonth: otherMonth, targetDay: otherDay,
            calendar: cal
        ) {
            days = candidateDays
            candidateDays += sign
        }

        return DateDuration.fromSigned(years: years, months: months, weeks: 0, days: days)
    }

    // MARK: - Surpasses Helpers

    private func surpassesAfterYears(
        sign: Int64, baseYear: Int32, baseMonth: UInt8, baseDay: UInt8,
        years: Int64,
        targetYear: Int32, targetMonth: UInt8, targetDay: UInt8,
        calendar: C
    ) -> Bool {
        let y = baseYear &+ Int32(years)
        return compareSurpasses(
            sign: sign, year: y, month: baseMonth, day: baseDay,
            targetYear: targetYear, targetMonth: targetMonth, targetDay: targetDay
        )
    }

    private func surpassesAfterYearsMonths(
        sign: Int64, baseYear: Int32, baseMonth: UInt8, baseDay: UInt8,
        years: Int64, months: Int64,
        targetYear: Int32, targetMonth: UInt8, targetDay: UInt8,
        calendar: C
    ) -> Bool {
        let y0 = baseYear &+ Int32(years)
        let monthsInY0 = monthsInYearForExtended(y0, calendar: calendar)
        let m0 = min(baseMonth, monthsInY0)

        let endOfMonth = DateArithmeticHelper.balance(
            year: y0, month: Int64(m0) + months + 1, day: 0, calendar: calendar
        )
        let regulatedDay = min(baseDay, endOfMonth.day)

        return compareSurpasses(
            sign: sign,
            year: endOfMonth.year, month: endOfMonth.month, day: regulatedDay,
            targetYear: targetYear, targetMonth: targetMonth, targetDay: targetDay
        )
    }

    private func surpassesAfterYearsMonthsDays(
        sign: Int64, baseYear: Int32, baseMonth: UInt8, baseDay: UInt8,
        years: Int64, months: Int64, days: Int64,
        targetYear: Int32, targetMonth: UInt8, targetDay: UInt8,
        calendar: C
    ) -> Bool {
        let y0 = baseYear &+ Int32(years)
        let monthsInY0 = monthsInYearForExtended(y0, calendar: calendar)
        let m0 = min(baseMonth, monthsInY0)

        let endOfMonth = DateArithmeticHelper.balance(
            year: y0, month: Int64(m0) + months + 1, day: 0, calendar: calendar
        )
        let regulatedDay = min(baseDay, endOfMonth.day)
        let finalDay = Int64(regulatedDay) + days

        let result = DateArithmeticHelper.balance(
            year: endOfMonth.year, month: Int64(endOfMonth.month), day: finalDay, calendar: calendar
        )

        return compareSurpasses(
            sign: sign,
            year: result.year, month: result.month, day: result.day,
            targetYear: targetYear, targetMonth: targetMonth, targetDay: targetDay
        )
    }

    private func compareSurpasses(
        sign: Int64,
        year: Int32, month: UInt8, day: UInt8,
        targetYear: Int32, targetMonth: UInt8, targetDay: UInt8
    ) -> Bool {
        if year != targetYear {
            return sign * (Int64(year) - Int64(targetYear)) > 0
        } else if month != targetMonth {
            return sign * (Int64(month) - Int64(targetMonth)) > 0
        } else if day != targetDay {
            return sign * (Int64(day) - Int64(targetDay)) > 0
        }
        return false
    }

    private func monthsInYearForExtended(_ extYear: Int32, calendar: C) -> UInt8 {
        if let inner = try? calendar.newDate(year: .extended(extYear), month: .new(1), day: 1) {
            return calendar.monthsInYear(inner)
        }
        return 12
    }
}

// MARK: - Balance Helper

enum DateArithmeticHelper {
    struct BalancedDate {
        var year: Int32
        var month: UInt8
        var day: UInt8
    }

    /// Balances overflow/underflow in month and day fields.
    ///
    /// Implements the Temporal BalanceNonISODate operation.
    static func balance<C: CalendarProtocol>(
        year: Int32, month: Int64, day: Int64, calendar: C
    ) -> BalancedDate {
        var resolvedYear = year
        var resolvedMonth = month

        // Balance months (underflow)
        var monthsInYear = monthsInYearFor(resolvedYear, calendar: calendar)
        while resolvedMonth <= 0 {
            resolvedYear -= 1
            monthsInYear = monthsInYearFor(resolvedYear, calendar: calendar)
            resolvedMonth += Int64(monthsInYear)
        }

        // Balance months (overflow)
        monthsInYear = monthsInYearFor(resolvedYear, calendar: calendar)
        while resolvedMonth > Int64(monthsInYear) {
            resolvedMonth -= Int64(monthsInYear)
            resolvedYear += 1
            monthsInYear = monthsInYearFor(resolvedYear, calendar: calendar)
        }

        var rm = UInt8(resolvedMonth)
        var resolvedDay = day

        // Balance days (underflow)
        var daysInMonth = daysInMonthFor(resolvedYear, month: rm, calendar: calendar)
        while resolvedDay <= 0 {
            rm -= 1
            if rm == 0 {
                resolvedYear -= 1
                monthsInYear = monthsInYearFor(resolvedYear, calendar: calendar)
                rm = monthsInYear
            }
            daysInMonth = daysInMonthFor(resolvedYear, month: rm, calendar: calendar)
            resolvedDay += Int64(daysInMonth)
        }

        // Balance days (overflow)
        daysInMonth = daysInMonthFor(resolvedYear, month: rm, calendar: calendar)
        while resolvedDay > Int64(daysInMonth) {
            resolvedDay -= Int64(daysInMonth)
            rm += 1
            if rm > monthsInYearFor(resolvedYear, calendar: calendar) {
                resolvedYear += 1
                rm = 1
            }
            daysInMonth = daysInMonthFor(resolvedYear, month: rm, calendar: calendar)
        }

        return BalancedDate(year: resolvedYear, month: rm, day: UInt8(resolvedDay))
    }

    private static func monthsInYearFor<C: CalendarProtocol>(_ year: Int32, calendar: C) -> UInt8 {
        guard let inner = try? calendar.newDate(year: .extended(year), month: .new(1), day: 1) else {
            return 12
        }
        return calendar.monthsInYear(inner)
    }

    private static func daysInMonthFor<C: CalendarProtocol>(_ year: Int32, month: UInt8, calendar: C) -> UInt8 {
        guard let inner = try? calendar.newDate(year: .extended(year), month: .new(month), day: 1) else {
            return 30
        }
        return calendar.daysInMonth(inner)
    }
}

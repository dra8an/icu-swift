import Testing
@testable import CalendarCore
@testable import CalendarSimple
@testable import DateArithmetic

@Suite("DateDuration")
struct DateDurationTests {

    @Test("Factory methods")
    func factoryMethods() {
        let d1 = DateDuration.forYears(3)
        #expect(d1.years == 3 && !d1.isNegative)

        let d2 = DateDuration.forMonths(-5)
        #expect(d2.months == 5 && d2.isNegative)

        let d3 = DateDuration.forDays(100)
        #expect(d3.days == 100 && !d3.isNegative)

        let d4 = DateDuration.forWeeks(-2)
        #expect(d4.weeks == 2 && d4.isNegative)

        let d5 = DateDuration.zero
        #expect(d5.years == 0 && d5.months == 0 && d5.weeks == 0 && d5.days == 0 && !d5.isNegative)
    }

    @Test("Weeks and days decomposition")
    func weeksAndDays() {
        let d = DateDuration.forWeeksAndDays(17)
        #expect(d.weeks == 2)
        #expect(d.days == 3)
        #expect(!d.isNegative)

        let neg = DateDuration.forWeeksAndDays(-10)
        #expect(neg.weeks == 1)
        #expect(neg.days == 3)
        #expect(neg.isNegative)
    }
}

@Suite("Date Addition")
struct DateAdditionTests {

    let iso = Iso()

    // MARK: - Basic Day Offsets (from ICU4X iso.rs test_offset)

    @Test("Add 5000 days")
    func add5000Days() throws {
        let today = try Date(year: 2021, month: 6, day: 23, calendar: iso)
        let expected = try Date(year: 2035, month: 3, day: 2, calendar: iso)
        let result = try today.added(.forDays(5000))
        #expect(result == expected)
    }

    @Test("Subtract 5000 days")
    func subtract5000Days() throws {
        let today = try Date(year: 2021, month: 6, day: 23, calendar: iso)
        let expected = try Date(year: 2007, month: 10, day: 15, calendar: iso)
        let result = try today.added(.forDays(-5000))
        #expect(result == expected)
    }

    // MARK: - Month Boundary Tests (from ICU4X iso.rs)

    @Test("Feb 28 + 2 days = Mar 1 (leap year)")
    func leapYearFebBoundary() throws {
        let date = try Date(year: 2020, month: 2, day: 28, calendar: iso)
        let result = try date.added(.forDays(2))
        #expect(try result == Date(year: 2020, month: 3, day: 1, calendar: iso))
    }

    @Test("Feb 28 + 1 day = Feb 29 (leap year)")
    func leapYearFeb29() throws {
        let date = try Date(year: 2020, month: 2, day: 28, calendar: iso)
        let result = try date.added(.forDays(1))
        #expect(try result == Date(year: 2020, month: 2, day: 29, calendar: iso))
    }

    @Test("Feb 28 + 1 day = Mar 1 (non-leap year)")
    func nonLeapYearFebBoundary() throws {
        let date = try Date(year: 2019, month: 2, day: 28, calendar: iso)
        let result = try date.added(.forDays(1))
        #expect(try result == Date(year: 2019, month: 3, day: 1, calendar: iso))
    }

    @Test("Mar 1 - 1 day = Feb 29 (leap year)")
    func leapYearBackward() throws {
        let date = try Date(year: 2020, month: 3, day: 1, calendar: iso)
        let result = try date.added(.forDays(-1))
        #expect(try result == Date(year: 2020, month: 2, day: 29, calendar: iso))
    }

    // MARK: - Month Arithmetic (from ICU4X iso.rs)

    @Test("Negative month offsets")
    func negativeMonthOffsets() throws {
        let date = try Date(year: 2020, month: 3, day: 1, calendar: iso)

        let minus2m = try date.added(.forMonths(-2))
        #expect(try minus2m == Date(year: 2020, month: 1, day: 1, calendar: iso))

        let minus4m = try date.added(.forMonths(-4))
        #expect(try minus4m == Date(year: 2019, month: 11, day: 1, calendar: iso))

        let minus24m = try date.added(.forMonths(-24))
        #expect(try minus24m == Date(year: 2018, month: 3, day: 1, calendar: iso))

        let minus27m = try date.added(.forMonths(-27))
        #expect(try minus27m == Date(year: 2017, month: 12, day: 1, calendar: iso))
    }

    // MARK: - Month-End Clamping (from ICU4X iso.rs)

    @Test("Jan 31 + 1 month = Feb 28 (constrain)")
    func monthEndConstrain() throws {
        let date = try Date(year: 2021, month: 1, day: 31, calendar: iso)
        let result = try date.added(.forMonths(1), overflow: .constrain)
        #expect(try result == Date(year: 2021, month: 2, day: 28, calendar: iso))
    }

    @Test("Jan 31 + 1 month = error (reject)")
    func monthEndReject() throws {
        let date = try Date(year: 2021, month: 1, day: 31, calendar: iso)
        #expect(throws: DateAddError.self) {
            try date.added(.forMonths(1), overflow: .reject)
        }
    }

    @Test("Jan 31 + 1 month + 1 day = Mar 1 (constrain)")
    func monthEndConstrainPlusDay() throws {
        let date = try Date(year: 2021, month: 1, day: 31, calendar: iso)
        let duration = DateDuration(years: 0, months: 1, days: 1)
        let result = try date.added(duration, overflow: .constrain)
        #expect(try result == Date(year: 2021, month: 3, day: 1, calendar: iso))
    }

    // MARK: - Combined Duration (from ICU4X duration.rs doctest)

    @Test("1992-09-02 + 1Y2M3W4D = 1993-11-27")
    func combinedDuration() throws {
        let date = try Date(year: 1992, month: 9, day: 2, calendar: iso)
        let duration = DateDuration(years: 1, months: 2, weeks: 3, days: 4)
        let result = try date.added(duration)
        #expect(result.extendedYear == 1993)
        #expect(result.month.number == 11)
        #expect(result.dayOfMonth == 27)
    }

    @Test("1993-11-27 - 1Y2M3W4D = 1992-09-02 (reverse)")
    func combinedDurationReverse() throws {
        let date = try Date(year: 1993, month: 11, day: 27, calendar: iso)
        let duration = DateDuration(isNegative: true, years: 1, months: 2, weeks: 3, days: 4)
        let result = try date.added(duration)
        #expect(result.extendedYear == 1992)
        #expect(result.month.number == 9)
        #expect(result.dayOfMonth == 2)
    }

    // MARK: - Year Arithmetic

    @Test("Feb 29 + 1 year = Feb 28 (constrain)")
    func leapDayYearAdd() throws {
        let date = try Date(year: 2020, month: 2, day: 29, calendar: iso)
        let result = try date.added(.forYears(1), overflow: .constrain)
        #expect(try result == Date(year: 2021, month: 2, day: 28, calendar: iso))
    }

    @Test("Feb 29 + 4 years = Feb 29 (next leap)")
    func leapDayFourYears() throws {
        let date = try Date(year: 2020, month: 2, day: 29, calendar: iso)
        let result = try date.added(.forYears(4))
        #expect(try result == Date(year: 2024, month: 2, day: 29, calendar: iso))
    }
}

@Suite("Date Difference")
struct DateDifferenceTests {

    let iso = Iso()

    // MARK: - Day Differences

    @Test("Same date = zero duration")
    func sameDateZero() throws {
        let date = try Date(year: 2024, month: 3, day: 15, calendar: iso)
        let diff = date.until(date)
        #expect(diff == .zero)
    }

    @Test("Day difference via RataDie")
    func dayDifference() throws {
        let d1 = try Date(year: 2024, month: 1, day: 1, calendar: iso)
        let d2 = try Date(year: 2024, month: 1, day: 31, calendar: iso)
        let diff = d1.until(d2, largestUnit: .days)
        #expect(diff.days == 30)
        #expect(!diff.isNegative)
    }

    @Test("Negative day difference")
    func negativeDayDifference() throws {
        let d1 = try Date(year: 2024, month: 1, day: 31, calendar: iso)
        let d2 = try Date(year: 2024, month: 1, day: 1, calendar: iso)
        let diff = d1.until(d2, largestUnit: .days)
        #expect(diff.days == 30)
        #expect(diff.isNegative)
    }

    @Test("Week difference")
    func weekDifference() throws {
        let d1 = try Date(year: 2024, month: 1, day: 1, calendar: iso)
        let d2 = try Date(year: 2024, month: 1, day: 22, calendar: iso)
        let diff = d1.until(d2, largestUnit: .weeks)
        #expect(diff.weeks == 3)
        #expect(diff.days == 0)
    }

    // MARK: - Year/Month Differences (from ICU4X duration.rs doctest)

    @Test("2022-10-30 until 1992-09-02 = -30Y -1M -28D")
    func yearMonthDifference() throws {
        let newer = try Date(year: 2022, month: 10, day: 30, calendar: iso)
        let older = try Date(year: 1992, month: 9, day: 2, calendar: iso)
        let diff = newer.until(older, largestUnit: .years)
        #expect(diff.isNegative)
        #expect(diff.years == 30)
        #expect(diff.months == 1)
        #expect(diff.days == 28)
    }

    // MARK: - Round-Trip: add then until

    @Test("Round-trip: date + duration → until = original duration (day-level)")
    func roundTripDays() throws {
        let date = try Date(year: 2020, month: 6, day: 15, calendar: iso)
        for dayOffset: Int64 in [-365, -30, -1, 1, 30, 365, 1000] {
            let duration = DateDuration.forDays(dayOffset)
            let added = try date.added(duration)
            let recovered = date.until(added, largestUnit: .days)
            #expect(recovered == duration,
                    "Round-trip failed for \(dayOffset) days")
        }
    }

    @Test("Round-trip: add months then until recovers same months")
    func roundTripMonths() throws {
        // Only test dates where day doesn't need clamping (day 1)
        let date = try Date(year: 2020, month: 1, day: 1, calendar: iso)
        for monthOffset: Int32 in [-24, -12, -1, 1, 6, 12, 24] {
            let duration = DateDuration.forMonths(monthOffset)
            let added = try date.added(duration)
            let recovered = date.until(added, largestUnit: .months)
            #expect(recovered.months == UInt32(abs(monthOffset)),
                    "Round-trip failed for \(monthOffset) months: got \(recovered.months)")
            #expect(recovered.isNegative == (monthOffset < 0))
        }
    }
}

@Suite("Day Arithmetic Exhaustive")
struct DayArithmeticExhaustiveTests {

    let iso = Iso()

    @Test("Day add round-trip for every day in 2000-2001")
    func dayAddRoundTrip() throws {
        let startRd = GregorianArithmetic.fixedFromGregorian(year: 2000, month: 1, day: 1)
        let endRd = GregorianArithmetic.fixedFromGregorian(year: 2001, month: 12, day: 31)

        for rdOffset in stride(from: Int64(0), through: endRd.dayNumber - startRd.dayNumber, by: 1) {
            let date = Date<Iso>.fromRataDie(startRd + rdOffset, calendar: iso)

            // Check +/- 35 days
            for dayDelta: Int64 in [-35, -1, 0, 1, 35] {
                let duration = DateDuration.forDays(dayDelta)
                let added = try date.added(duration)
                let diff = date.until(added, largestUnit: .days)
                #expect(diff == duration,
                        "Day round-trip failed at RD \(startRd.dayNumber + rdOffset) + \(dayDelta)")
                #expect(added.rataDie.dayNumber - date.rataDie.dayNumber == dayDelta)
            }
        }
    }
}

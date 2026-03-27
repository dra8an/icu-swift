import Testing
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

@Suite("Hebrew Calendar")
struct HebrewTests {

    let hebrew = Hebrew()
    let iso = Iso()

    // MARK: - Epoch

    @Test("Hebrew epoch is RD -1373427")
    func epoch() {
        #expect(HebrewArithmetic.epoch == RataDie(-1373427))
    }

    // MARK: - Known Conversions from ICU4X / Reingold & Dershowitz

    @Test("Fixed date <-> Hebrew date pairs from Calendrical Calculations")
    func knownConversions() {
        // Test data from ICU4X calendrical_calculations/src/hebrew.rs (biblical months)
        // Each pair: (fixed_date, biblical_year, biblical_month, biblical_day)
        let cases: [(rd: Int64, year: Int32, bMonth: UInt8, day: UInt8)] = [
            (-214193, 3174, 5, 10),
            (-61387, 3593, 9, 25),
            (25469, 3831, 7, 3),
            (49217, 3896, 7, 9),
            (171307, 4230, 10, 18),
            (210155, 4336, 3, 4),
            (253427, 4455, 8, 13),
            (369740, 4773, 2, 6),
            (400085, 4856, 2, 23),
            (434355, 4950, 1, 7),
            (452605, 5000, 13, 8),
            (470160, 5048, 1, 21),
            (473837, 5058, 2, 7),
            (507850, 5151, 4, 1),
            (524156, 5196, 11, 7),
            (544676, 5252, 1, 3),
            (567118, 5314, 7, 1),
            (569477, 5320, 12, 27),
            (601716, 5408, 3, 20),
            (613424, 5440, 4, 3),
            (626596, 5476, 5, 5),
            (645554, 5528, 4, 4),
            (664224, 5579, 5, 11),
            (671401, 5599, 1, 12),
            (694799, 5663, 1, 22),
            (704424, 5689, 5, 19),
            (708842, 5702, 7, 8),
            (709409, 5703, 1, 14),
            (709580, 5704, 7, 8),
            (727274, 5752, 13, 12),
            (728714, 5756, 12, 5),
            (744313, 5799, 8, 12),
            (764652, 5854, 5, 5),
        ]

        for (rd, year, bMonth, day) in cases {
            // Test fixed_from_hebrew (biblical)
            let computed = HebrewArithmetic.fixedFromHebrew(year: year, month: bMonth, day: day)
            #expect(computed == RataDie(rd),
                    "fixedFromHebrew(\(year), \(bMonth), \(day)) = \(computed) != RD \(rd)")

            // Test hebrew_from_fixed
            let (ry, rm, rd2) = HebrewArithmetic.hebrewFromFixed(RataDie(rd))
            #expect(ry == year && rm == bMonth && rd2 == day,
                    "hebrewFromFixed(RD \(rd)) = (\(ry), \(rm), \(rd2)) != (\(year), \(bMonth), \(day))")
        }
    }

    // MARK: - Year Lengths (33 test cases from ICU4X)

    /// The 33 Hebrew years used throughout all ICU4X Hebrew arithmetic tests
    static let hebrewTestYears: [Int32] = [
        3174, 3593, 3831, 3896, 4230, 4336, 4455, 4773, 4856, 4950, 5000,
        5048, 5058, 5151, 5196, 5252, 5314, 5320, 5408, 5440, 5476, 5528,
        5579, 5599, 5663, 5689, 5702, 5703, 5704, 5752, 5756, 5799, 5854,
    ]

    @Test("Days in Hebrew year from ICU4X test data (33 years)")
    func yearLengths() {
        let expectedDays: [UInt16] = [
            354, 354, 355, 355, 355, 355, 355, 353, 383, 354, 383, 354, 354, 355, 353, 383, 353, 385,
            353, 383, 355, 354, 354, 354, 355, 385, 355, 383, 354, 385, 355, 354, 355,
        ]

        for (i, year) in Self.hebrewTestYears.enumerated() {
            #expect(HebrewArithmetic.daysInYear(year) == expectedDays[i],
                    "Year \(year): expected \(expectedDays[i]) days, got \(HebrewArithmetic.daysInYear(year))")
        }
    }

    // MARK: - Long Marheshvan (33 test cases from ICU4X)

    @Test("Long Marheshvan flags from ICU4X test data (33 years)")
    func longMarheshvan() {
        let expectedValues: [Bool] = [
            false, false, true, true, true, true, true, false, false, false, false, false, false, true,
            false, false, false, true, false, false, true, false, false, false, true, true, true,
            false, false, true, true, false, true,
        ]

        for (i, year) in Self.hebrewTestYears.enumerated() {
            #expect(HebrewArithmetic.isLongMarheshvan(year) == expectedValues[i],
                    "Year \(year): expected longMarheshvan=\(expectedValues[i])")
        }
    }

    // MARK: - Short Kislev (33 test cases from ICU4X)

    @Test("Short Kislev flags from ICU4X test data (33 years)")
    func shortKislev() {
        let expectedValues: [Bool] = [
            false, false, false, false, false, false, false, true, true, false, true, false, false,
            false, true, true, true, false, true, true, false, false, false, false, false, false,
            false, true, false, false, false, false, false,
        ]

        for (i, year) in Self.hebrewTestYears.enumerated() {
            #expect(HebrewArithmetic.isShortKislev(year) == expectedValues[i],
                    "Year \(year): expected shortKislev=\(expectedValues[i])")
        }
    }

    // MARK: - Leap Years

    @Test("Hebrew leap year rule: 19-year Metonic cycle")
    func leapYears() {
        // Leap years in cycle: 3, 6, 8, 11, 14, 17, 19
        let leapPositions: Set<Int32> = [3, 6, 8, 11, 14, 17, 19]
        for year: Int32 in 1...19 {
            let expected = leapPositions.contains(year)
            #expect(HebrewArithmetic.isLeapYear(year) == expected,
                    "Year \(year): expected leap=\(expected)")
        }
    }

    // MARK: - ICU Bug 22441

    @Test("ICU bug 22441: HebrewArithmetic.daysInYear(88369) == 383")
    func icuBug22441() {
        #expect(HebrewArithmetic.daysInYear(88369) == 383)
    }

    // MARK: - Weekday test from ICU4X #4893

    @Test("Hebrew 3760/Tishrei/1 is Saturday")
    func weekdays() throws {
        // https://github.com/unicode-org/icu4x/issues/4893
        // Tishrei = civil month 1 = Month.new(1)
        let date = try Date(year: 3760, month: Month.new(1), day: 1, calendar: hebrew)
        // Should be Saturday per: https://www.hebcal.com/converter?hd=1&hm=Tishrei&hy=3760&h2g=1
        #expect(date.weekday == .saturday)
    }

    // MARK: - Full 48 ISO <-> Hebrew Pairs from ICU4X

    @Test("All 48 ISO <-> Hebrew pairs from ICU4X hebrew.rs")
    func isoHebrewPairsFull() throws {
        // Hebrew month constants (civil ordering):
        // TISHREI=Month.new(1), HESHVAN=Month.new(2), KISLEV=Month.new(3),
        // TEVET=Month.new(4), SHEVAT=Month.new(5), ADARI=Month.leap(5),
        // ADAR=Month.new(6), NISAN=Month.new(7), IYYAR=Month.new(8),
        // SIVAN=Month.new(9), TAMMUZ=Month.new(10), AV=Month.new(11), ELUL=Month.new(12)

        let TEVET = Month.new(4)
        let SHEVAT = Month.new(5)
        let ADARI = Month.leap(5)
        let ADAR = Month.new(6)
        let NISAN = Month.new(7)
        let IYYAR = Month.new(8)
        let SIVAN = Month.new(9)
        let TAMMUZ = Month.new(10)
        let AV = Month.new(11)
        let ELUL = Month.new(12)
        let TISHREI = Month.new(1)
        let HESHVAN = Month.new(2)
        let KISLEV = Month.new(3)

        // Leap years in the test data (need to know for ordinal calculation)
        let leapYearsInTests: Set<Int32> = [5782]

        let cases: [((Int32, UInt8, UInt8), (Int32, Month, UInt8))] = [
            ((2021, 1, 10), (5781, TEVET, 26)),
            ((2021, 1, 25), (5781, SHEVAT, 12)),
            ((2021, 2, 10), (5781, SHEVAT, 28)),
            ((2021, 2, 25), (5781, ADAR, 13)),
            ((2021, 3, 10), (5781, ADAR, 26)),
            ((2021, 3, 25), (5781, NISAN, 12)),
            ((2021, 4, 10), (5781, NISAN, 28)),
            ((2021, 4, 25), (5781, IYYAR, 13)),
            ((2021, 5, 10), (5781, IYYAR, 28)),
            ((2021, 5, 25), (5781, SIVAN, 14)),
            ((2021, 6, 10), (5781, SIVAN, 30)),
            ((2021, 6, 25), (5781, TAMMUZ, 15)),
            ((2021, 7, 10), (5781, AV, 1)),
            ((2021, 7, 25), (5781, AV, 16)),
            ((2021, 8, 10), (5781, ELUL, 2)),
            ((2021, 8, 25), (5781, ELUL, 17)),
            ((2021, 9, 10), (5782, TISHREI, 4)),
            ((2021, 9, 25), (5782, TISHREI, 19)),
            ((2021, 10, 10), (5782, HESHVAN, 4)),
            ((2021, 10, 25), (5782, HESHVAN, 19)),
            ((2021, 11, 10), (5782, KISLEV, 6)),
            ((2021, 11, 25), (5782, KISLEV, 21)),
            ((2021, 12, 10), (5782, TEVET, 6)),
            ((2021, 12, 25), (5782, TEVET, 21)),
            ((2022, 1, 10), (5782, SHEVAT, 8)),
            ((2022, 1, 25), (5782, SHEVAT, 23)),
            ((2022, 2, 10), (5782, ADARI, 9)),
            ((2022, 2, 25), (5782, ADARI, 24)),
            ((2022, 3, 10), (5782, ADAR, 7)),
            ((2022, 3, 25), (5782, ADAR, 22)),
            ((2022, 4, 10), (5782, NISAN, 9)),
            ((2022, 4, 25), (5782, NISAN, 24)),
            ((2022, 5, 10), (5782, IYYAR, 9)),
            ((2022, 5, 25), (5782, IYYAR, 24)),
            ((2022, 6, 10), (5782, SIVAN, 11)),
            ((2022, 6, 25), (5782, SIVAN, 26)),
            ((2022, 7, 10), (5782, TAMMUZ, 11)),
            ((2022, 7, 25), (5782, TAMMUZ, 26)),
            ((2022, 8, 10), (5782, AV, 13)),
            ((2022, 8, 25), (5782, AV, 28)),
            ((2022, 9, 10), (5782, ELUL, 14)),
            ((2022, 9, 25), (5782, ELUL, 29)),
            ((2022, 10, 10), (5783, TISHREI, 15)),
            ((2022, 10, 25), (5783, TISHREI, 30)),
            ((2022, 11, 10), (5783, HESHVAN, 16)),
            ((2022, 11, 25), (5783, KISLEV, 1)),
            ((2022, 12, 10), (5783, KISLEV, 16)),
            ((2022, 12, 25), (5783, TEVET, 1)),
        ]

        for ((isoY, isoM, isoD), (hY, hMonth, hD)) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let hebrewDate = Date<Hebrew>.fromRataDie(rd, calendar: hebrew)

            // Verify year
            #expect(hebrewDate.extendedYear == hY,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected Hebrew year \(hY), got \(hebrewDate.extendedYear)")

            // Verify day
            #expect(hebrewDate.dayOfMonth == hD,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected day \(hD), got \(hebrewDate.dayOfMonth)")

            // Verify month code (number + leap flag)
            #expect(hebrewDate.month.number == hMonth.number,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected month number \(hMonth.number), got \(hebrewDate.month.number)")
            #expect(hebrewDate.month.isLeap == hMonth.isLeap,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected month isLeap=\(hMonth.isLeap), got \(hebrewDate.month.isLeap)")

            // Verify ordinal: in a leap year, ADARI and months after have ordinal = number + 1
            let expectedOrdinal: UInt8
            if leapYearsInTests.contains(hY) && (hMonth == ADARI || hMonth.number >= ADAR.number) {
                expectedOrdinal = hMonth.number + 1
            } else {
                expectedOrdinal = hMonth.number
            }
            #expect(hebrewDate.month.ordinal == expectedOrdinal,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected ordinal \(expectedOrdinal), got \(hebrewDate.month.ordinal)")

            // Verify round-trip
            #expect(hebrewDate.rataDie == rd,
                    "ISO \(isoY)-\(isoM)-\(isoD): RD round-trip failed")

            // Verify construction from month input round-trips
            let constructed = try Date(year: .extended(hY), month: hMonth, day: hD, calendar: hebrew)
            #expect(constructed.rataDie == rd,
                    "ISO \(isoY)-\(isoM)-\(isoD): construction round-trip failed")
        }
    }

    // MARK: - Round-Trip

    @Test("Round-trip RD -> Hebrew -> RD for range -1000..1000")
    func roundTrip() {
        for i in stride(from: Int64(-1000), through: 1000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Hebrew>.fromRataDie(rd, calendar: hebrew)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    // MARK: - Elapsed Days (33 test cases from ICU4X)

    @Test("Calendar elapsed days from ICU4X test data (33 years)")
    func elapsedDays() {
        let expectedValues: [Int32] = [
            1158928, 1311957, 1398894, 1422636, 1544627, 1583342, 1626812, 1742956, 1773254, 1807597,
            1825848, 1843388, 1847051, 1881010, 1897460, 1917895, 1940545, 1942729, 1974889, 1986554,
            1999723, 2018712, 2037346, 2044640, 2068027, 2077507, 2082262, 2082617, 2083000, 2100511,
            2101988, 2117699, 2137779,
        ]

        for (i, year) in Self.hebrewTestYears.enumerated() {
            #expect(HebrewArithmetic.calendarElapsedDays(year) == expectedValues[i],
                    "Year \(year): expected elapsed days \(expectedValues[i])")
        }
    }

    // MARK: - Year Length Correction (33 test cases from ICU4X)

    @Test("Year length correction from ICU4X test data (33 years)")
    func yearLengthCorrection() {
        let expectedValues: [UInt8] = [
            2, 0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
            0, 0, 0, 0,
        ]

        for (i, year) in Self.hebrewTestYears.enumerated() {
            #expect(HebrewArithmetic.yearLengthCorrection(year) == expectedValues[i],
                    "Year \(year): expected correction \(expectedValues[i])")
        }
    }

    // MARK: - Hebrew New Year Fixed Dates (33 test cases from ICU4X)

    @Test("Hebrew new year fixed dates from ICU4X test data (33 years)")
    func newYearDates() {
        let expectedValues: [Int64] = [
            -214497, -61470, 25467, 49209, 171200, 209915, 253385, 369529, 399827, 434172, 452421,
            469963, 473624, 507583, 524033, 544468, 567118, 569302, 601462, 613127, 626296, 645285,
            663919, 671213, 694600, 704080, 708835, 709190, 709573, 727084, 728561, 744272, 764352,
        ]

        for (i, year) in Self.hebrewTestYears.enumerated() {
            #expect(HebrewArithmetic.newYear(year).dayNumber == expectedValues[i],
                    "Year \(year): expected new year RD \(expectedValues[i])")
        }
    }

    // MARK: - Last Day of Month (33 test cases from ICU4X)

    @Test("Last day of biblical month from ICU4X test data (33 cases)")
    func lastDayOfMonth() {
        // Biblical months from the test data
        let biblicalMonths: [UInt8] = [
            5, 9, 7, 7, 10, 3, 8, 2, 2, 1, 13, 1, 2, 4, 11, 1, 7, 12, 3, 4, 5, 4, 5, 1, 1, 5, 7, 1, 7, 13, 12, 8, 5,
        ]

        let expectedDays: [UInt8] = [
            30, 30, 30, 30, 29, 30, 30, 29, 29, 30, 29, 30, 29, 29, 30, 30, 30, 30, 30, 29, 30, 29, 30,
            30, 30, 30, 30, 30, 30, 29, 29, 29, 30,
        ]

        for (i, year) in Self.hebrewTestYears.enumerated() {
            let result = HebrewArithmetic.lastDayOfMonth(year, month: biblicalMonths[i])
            #expect(result == expectedDays[i],
                    "Year \(year), biblical month \(biblicalMonths[i]): expected \(expectedDays[i]) days, got \(result)")
        }
    }

    // MARK: - Civil ↔ Biblical Conversion (33 test cases from ICU4X)

    @Test("Civil to biblical month conversion round-trip (33 cases)")
    func civilBiblicalConversion() {
        // Test data: fixed dates from the 33-case set
        let fixedDates: [Int64] = [
            -214193, -61387, 25469, 49217, 171307, 210155, 253427, 369740, 400085, 434355, 452605,
            470160, 473837, 507850, 524156, 544676, 567118, 569477, 601716, 613424, 626596, 645554,
            664224, 671401, 694799, 704424, 708842, 709409, 709580, 727274, 728714, 744313, 764652,
        ]

        for rd in fixedDates {
            let (year, biblicalMonth, day) = HebrewArithmetic.hebrewFromFixed(RataDie(rd))
            let civilMonth = HebrewArithmetic.biblicalToCivil(year: year, biblicalMonth: biblicalMonth)
            let recoveredBiblical = HebrewArithmetic.civilToBiblical(year: year, civilMonth: civilMonth)
            #expect(recoveredBiblical == biblicalMonth,
                    "RD \(rd): biblical \(biblicalMonth) → civil \(civilMonth) → biblical \(recoveredBiblical)")
        }
    }

    // MARK: - Last Month of Year (33 test cases from ICU4X)

    @Test("Last biblical month of year from ICU4X test data (33 years)")
    func lastMonthOfYear() {
        let expectedValues: [UInt8] = [
            12, 12, 12, 12, 12, 12, 12, 12, 13, 12, 13, 12, 12, 12, 12, 13, 12, 13, 12, 13, 12, 12, 12,
            12, 12, 13, 12, 13, 12, 13, 12, 12, 12,
        ]

        for (i, year) in Self.hebrewTestYears.enumerated() {
            #expect(HebrewArithmetic.lastMonthOfYear(year) == expectedValues[i],
                    "Year \(year): expected last month \(expectedValues[i])")
        }
    }

    // MARK: - Negative Era Years (from ICU4X hebrew.rs)

    @Test("Negative extended years: Gregorian -5000 → Hebrew -1240 AM")
    func negativeEraYears() {
        // From ICU4X: greg -5000/1/1 → hebrew extended year -1240
        let rd = GregorianArithmetic.fixedFromGregorian(year: -5000, month: 1, day: 1)
        let hebrewDate = Date<Hebrew>.fromRataDie(rd, calendar: hebrew)
        #expect(hebrewDate.extendedYear == -1240,
                "Gregorian -5000/1/1: expected Hebrew year -1240, got \(hebrewDate.extendedYear)")
        #expect(hebrewDate.year.eraYear?.era == "am")
        #expect(hebrewDate.year.eraYear?.year == -1240)
    }

    // MARK: - Directionality

    @Test("Directionality: RD ordering matches date ordering")
    func directionality() {
        for i: Int64 in -50...50 {
            for j: Int64 in -50...50 {
                let di = Date<Hebrew>.fromRataDie(RataDie(i), calendar: hebrew)
                let dj = Date<Hebrew>.fromRataDie(RataDie(j), calendar: hebrew)

                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }
}

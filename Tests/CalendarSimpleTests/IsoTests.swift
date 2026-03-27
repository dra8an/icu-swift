import Testing
@testable import CalendarCore
@testable import CalendarSimple

@Suite("ISO Calendar")
struct IsoTests {

    let iso = Iso()

    // MARK: - RataDie Round-Trip

    @Test("RD 1 = Jan 1, year 1")
    func rdEpoch() throws {
        let date = try Date(year: 1, month: 1, day: 1, calendar: iso)
        #expect(date.rataDie == RataDie(1))
    }

    @Test("Known RD ↔ YMD values from ICU4X test suite")
    func knownRdValues() {
        let cases: [(rd: Int64, y: Int32, m: UInt8, d: UInt8)] = [
            (-1828, -5, 12, 30),
            (-1827, -5, 12, 31),  // year -5 has 366 days (leap)
            (-1826, -4, 1, 1),
            (-1462, -4, 12, 30),
            (-1461, -4, 12, 31),
            (-1460, -3, 1, 1),
            (-732, -2, 12, 30),
            (-731, -2, 12, 31),
            (-730, -1, 1, 1),
            (-367, -1, 12, 30),
            (-366, -1, 12, 31),
            (-365, 0, 1, 1),      // year 0 = 1 BCE, leap year
            (-364, 0, 1, 2),
            (-1, 0, 12, 30),
            (0, 0, 12, 31),
            (1, 1, 1, 1),
            (2, 1, 1, 2),
            (364, 1, 12, 30),
            (365, 1, 12, 31),
            (366, 2, 1, 1),
            (1459, 4, 12, 29),
            (1460, 4, 12, 30),
            (1461, 4, 12, 31),    // year 4 is a leap year
            (1462, 5, 1, 1),
        ]

        for (rd, y, m, d) in cases {
            let fromRd = Date<Iso>.fromRataDie(RataDie(rd), calendar: iso)
            #expect(fromRd.extendedYear == y, "RD \(rd): expected year \(y), got \(fromRd.extendedYear)")
            #expect(fromRd.month.number == m, "RD \(rd): expected month \(m)")
            #expect(fromRd.dayOfMonth == d, "RD \(rd): expected day \(d)")
        }
    }

    @Test("Round-trip RD → ISO → RD for range -10000..10000")
    func roundTripLargeRange() {
        for i in stride(from: Int64(-10000), through: 10000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Iso>.fromRataDie(rd, calendar: iso)
            let recovered = date.rataDie
            #expect(recovered == rd, "Round-trip failed for RD \(i)")
        }
    }

    // MARK: - Leap Years

    @Test("Gregorian leap year rules")
    func leapYears() {
        // Divisible by 4 → leap
        #expect(GregorianArithmetic.isLeapYear(2024))
        #expect(GregorianArithmetic.isLeapYear(2000))
        #expect(GregorianArithmetic.isLeapYear(0))    // 1 BCE
        #expect(GregorianArithmetic.isLeapYear(-4))

        // Divisible by 100 but not 400 → not leap
        #expect(!GregorianArithmetic.isLeapYear(1900))
        #expect(!GregorianArithmetic.isLeapYear(2100))
        #expect(!GregorianArithmetic.isLeapYear(1800))

        // Not divisible by 4 → not leap
        #expect(!GregorianArithmetic.isLeapYear(2023))
        #expect(!GregorianArithmetic.isLeapYear(1))
    }

    // MARK: - Days in Month

    @Test("Days in each month")
    func daysInMonth() {
        let nonLeap: [UInt8] = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        let leapYear: [UInt8] = [31, 29, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

        for (i, expected) in nonLeap.enumerated() {
            #expect(GregorianArithmetic.daysInMonth(year: 2023, month: UInt8(i + 1)) == expected)
        }
        for (i, expected) in leapYear.enumerated() {
            #expect(GregorianArithmetic.daysInMonth(year: 2024, month: UInt8(i + 1)) == expected)
        }
    }

    // MARK: - Weekday

    @Test("Known weekdays")
    func weekdays() throws {
        // June 23, 2021 is Wednesday
        let date1 = try Date(year: 2021, month: 6, day: 23, calendar: iso)
        #expect(date1.weekday == .wednesday)

        // Feb 2, 1983 is Wednesday
        let date2 = try Date(year: 1983, month: 2, day: 2, calendar: iso)
        #expect(date2.weekday == .wednesday)

        // Jan 21, 2020 is Tuesday
        let date3 = try Date(year: 2020, month: 1, day: 21, calendar: iso)
        #expect(date3.weekday == .tuesday)
    }

    // MARK: - Day of Year

    @Test("Day of year")
    func dayOfYear() throws {
        let date1 = try Date(year: 2021, month: 6, day: 23, calendar: iso)
        #expect(date1.dayOfYear == 174)

        // Leap year: Jun 23 is day 175
        let date2 = try Date(year: 2020, month: 6, day: 23, calendar: iso)
        #expect(date2.dayOfYear == 175)

        let date3 = try Date(year: 1983, month: 2, day: 2, calendar: iso)
        #expect(date3.dayOfYear == 33)
    }

    // MARK: - Directionality

    @Test("Directionality: RD ordering matches YMD ordering")
    func directionality() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Iso>.fromRataDie(RataDie(i), calendar: iso)
                let dj = Date<Iso>.fromRataDie(RataDie(j), calendar: iso)

                if i < j {
                    #expect(di < dj, "RD \(i) < \(j) but Date not less")
                } else if i == j {
                    #expect(di == dj)
                } else {
                    #expect(di > dj)
                }
            }
        }
    }

    // MARK: - Validation

    @Test("Invalid date construction throws")
    func validation() {
        #expect(throws: DateNewError.self) {
            try Date(year: 2023, month: 2, day: 29, calendar: iso)
        }
        #expect(throws: DateNewError.self) {
            try Date(year: 2023, month: 13, day: 1, calendar: iso)
        }
        #expect(throws: DateNewError.self) {
            try Date(year: 2023, month: 0, day: 1, calendar: iso)
        }
        #expect(throws: DateNewError.self) {
            try Date(year: 2023, month: 1, day: 32, calendar: iso)
        }
    }

    @Test("Feb 29 valid in leap year, invalid in non-leap")
    func feb29() throws {
        let _ = try Date(year: 2024, month: 2, day: 29, calendar: iso)
        #expect(throws: DateNewError.self) {
            try Date(year: 2023, month: 2, day: 29, calendar: iso)
        }
    }
}

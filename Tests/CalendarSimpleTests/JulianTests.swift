import Testing
@testable import CalendarCore
@testable import CalendarSimple

@Suite("Julian Calendar")
struct JulianTests {

    let julian = Julian()
    let iso = Iso()

    // MARK: - Known Julian ↔ ISO Equivalences

    @Test("Known Julian dates from ICU4X test suite")
    func knownDates() {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, julY: Int32, julM: UInt8, julD: UInt8, era: String)] = [
            // March 1st 200 is same on both calendars
            (200, 3, 1, 200, 3, 1, "ce"),
            // Feb 28th, 200 (ISO) = Feb 29th, 200 (Julian) — Julian 200 is leap, Gregorian 200 is not
            (200, 2, 28, 200, 2, 29, "ce"),
            // March 1st, 400 (ISO) = Feb 29th, 400 (Julian)
            (400, 3, 1, 400, 2, 29, "ce"),
            // Jan 1st, 2022 (ISO) = Dec 19, 2021 (Julian)
            (2022, 1, 1, 2021, 12, 19, "ce"),
            // March 1st, 2022 (ISO) = Feb 16, 2022 (Julian)
            (2022, 3, 1, 2022, 2, 16, "ce"),
        ]

        for (isoY, isoM, isoD, julY, julM, julD, era) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Julian>.fromRataDie(rd, calendar: julian)

            #expect(date.year.eraYear?.year == julY,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected Julian year \(julY)")
            #expect(date.year.eraYear?.era == era)
            #expect(date.month.number == julM,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected Julian month \(julM)")
            #expect(date.dayOfMonth == julD,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected Julian day \(julD)")
            #expect(date.rataDie == rd, "Round-trip failed")
        }
    }

    // MARK: - Near Era Change

    @Test("Julian dates near BCE/CE boundary from ICU4X")
    func nearEraChange() {
        let cases: [(rd: Int64, era: String, year: Int32, m: UInt8, d: UInt8)] = [
            (1, "ce", 1, 1, 3),
            (0, "ce", 1, 1, 2),
            (-1, "ce", 1, 1, 1),
            (-2, "bce", 1, 12, 31),
            (-3, "bce", 1, 12, 30),
            (-367, "bce", 1, 1, 1),
            (-368, "bce", 2, 12, 31),
            (-1462, "bce", 4, 1, 1),
            (-1463, "bce", 5, 12, 31),
        ]

        for (rd, era, year, m, d) in cases {
            let date = Date<Julian>.fromRataDie(RataDie(rd), calendar: julian)
            #expect(date.year.eraYear?.era == era, "RD \(rd)")
            #expect(date.year.eraYear?.year == year, "RD \(rd)")
            #expect(date.month.number == m, "RD \(rd)")
            #expect(date.dayOfMonth == d, "RD \(rd)")
        }
    }

    // MARK: - Gregorian Calendar Cutover

    @Test("Julian Oct 4, 1582 is the day before Gregorian Oct 15, 1582")
    func gregorianCutover() throws {
        // The famous Gregorian cutover: Oct 4, 1582 Julian was followed by Oct 15, 1582 Gregorian
        let julianOct4 = try Date(year: 1582, month: 10, day: 4, calendar: julian)
        let gregOct15 = try Date(year: 1582, month: 10, day: 15, calendar: Gregorian())

        // They should be consecutive days
        #expect(gregOct15.rataDie - julianOct4.rataDie == 1)
    }

    // MARK: - Leap Years

    @Test("Julian leap year rule: every 4th year")
    func leapYears() {
        // Every 4th year is leap — including centuries
        #expect(JulianArithmetic.isLeapYear(4))
        #expect(JulianArithmetic.isLeapYear(100))   // Unlike Gregorian!
        #expect(JulianArithmetic.isLeapYear(200))
        #expect(JulianArithmetic.isLeapYear(1900))  // Unlike Gregorian!
        #expect(JulianArithmetic.isLeapYear(2000))
        #expect(JulianArithmetic.isLeapYear(0))      // 1 BCE
        #expect(JulianArithmetic.isLeapYear(-4))

        #expect(!JulianArithmetic.isLeapYear(1))
        #expect(!JulianArithmetic.isLeapYear(2023))
        #expect(!JulianArithmetic.isLeapYear(101))
    }

    @Test("Feb 29 valid in Julian leap years")
    func feb29() throws {
        let _ = try Date(year: 4, month: 2, day: 29, calendar: julian)
        let _ = try Date(year: 0, month: 2, day: 29, calendar: julian)
        let _ = try Date(year: -4, month: 2, day: 29, calendar: julian)
        let _ = try Date(year: 2020, month: 2, day: 29, calendar: julian)
        let _ = try Date(year: 100, month: 2, day: 29, calendar: julian)  // Julian: leap!
    }

    // MARK: - Round-Trip

    @Test("Round-trip RD → Julian → RD for range -10000..10000")
    func roundTrip() {
        for i in stride(from: Int64(-10000), through: 10000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Julian>.fromRataDie(rd, calendar: julian)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    @Test("Round-trip for negative years (ICU4X #2254)")
    func roundTripNegative() {
        let rd = GregorianArithmetic.fixedFromGregorian(year: -1000, month: 3, day: 3)
        let date = Date<Julian>.fromRataDie(rd, calendar: julian)
        #expect(date.rataDie == rd)
    }

    // MARK: - Directionality

    @Test("Directionality: RD ordering matches YMD ordering")
    func directionality() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Julian>.fromRataDie(RataDie(i), calendar: julian)
                let dj = Date<Julian>.fromRataDie(RataDie(j), calendar: julian)

                if i < j {
                    #expect(di < dj)
                } else if i == j {
                    #expect(di == dj)
                } else {
                    #expect(di > dj)
                }
            }
        }
    }

    // MARK: - Calendar Conversion

    @Test("Julian → ISO → Julian round-trip via converting(to:)")
    func calendarConversion() throws {
        let julDate = try Date(year: 1582, month: 10, day: 4, calendar: julian)
        let isoDate = julDate.converting(to: iso)
        let backToJulian = isoDate.converting(to: julian)

        #expect(backToJulian == julDate)
        #expect(isoDate.extendedYear == 1582)
        #expect(isoDate.month.number == 10)
        #expect(isoDate.dayOfMonth == 14)  // Oct 14, 1582 Gregorian
    }
}

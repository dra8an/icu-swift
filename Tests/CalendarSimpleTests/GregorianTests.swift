import Testing
@testable import CalendarCore
@testable import CalendarSimple

@Suite("Gregorian Calendar")
struct GregorianTests {

    let greg = Gregorian()

    // MARK: - CE Era

    @Test("CE dates from ICU4X test suite")
    func ceEra() {
        let cases: [(rd: Int64, extYear: Int32, eraYear: Int32, era: String, m: UInt8, d: UInt8)] = [
            (1, 1, 1, "ce", 1, 1),
            (181, 1, 1, "ce", 6, 30),
            (1155, 4, 4, "ce", 2, 29),
            (1344, 4, 4, "ce", 9, 5),
            (36219, 100, 100, "ce", 3, 1),
        ]

        for (rd, extYear, eraYear, era, m, d) in cases {
            let date = Date<Gregorian>.fromRataDie(RataDie(rd), calendar: greg)
            #expect(date.extendedYear == extYear, "RD \(rd)")
            #expect(date.year.eraYear?.year == eraYear, "RD \(rd)")
            #expect(date.year.eraYear?.era == era, "RD \(rd)")
            #expect(date.month.number == m, "RD \(rd)")
            #expect(date.dayOfMonth == d, "RD \(rd)")
            #expect(date.rataDie == RataDie(rd), "RD \(rd) round-trip")
        }
    }

    // MARK: - BCE Era

    @Test("BCE dates from ICU4X test suite")
    func bceEra() {
        let cases: [(rd: Int64, extYear: Int32, eraYear: Int32, era: String, m: UInt8, d: UInt8)] = [
            (0, 0, 1, "bce", 12, 31),
            (-365, 0, 1, "bce", 1, 1),      // year 0 is a leap year
            (-366, -1, 2, "bce", 12, 31),
            (-1461, -4, 5, "bce", 12, 31),
            (-1826, -4, 5, "bce", 1, 1),
        ]

        for (rd, extYear, eraYear, era, m, d) in cases {
            let date = Date<Gregorian>.fromRataDie(RataDie(rd), calendar: greg)
            #expect(date.extendedYear == extYear, "RD \(rd)")
            #expect(date.year.eraYear?.year == eraYear, "RD \(rd)")
            #expect(date.year.eraYear?.era == era, "RD \(rd)")
            #expect(date.month.number == m, "RD \(rd)")
            #expect(date.dayOfMonth == d, "RD \(rd)")
            #expect(date.rataDie == RataDie(rd), "RD \(rd) round-trip")
        }
    }

    // MARK: - Era Input

    @Test("Construct from era year input")
    func eraYearInput() throws {
        // CE year 2024
        let ce = try Date(year: .eraYear(era: "ce", year: 2024), month: 3, day: 15, calendar: greg)
        #expect(ce.extendedYear == 2024)

        // BCE year 1 = extended year 0
        let bce = try Date(year: .eraYear(era: "bce", year: 1), month: 1, day: 1, calendar: greg)
        #expect(bce.extendedYear == 0)

        // BCE year 5 = extended year -4
        let bce5 = try Date(year: .eraYear(era: "bce", year: 5), month: 6, day: 15, calendar: greg)
        #expect(bce5.extendedYear == -4)

        // AD alias
        let ad = try Date(year: .eraYear(era: "ad", year: 100), month: 1, day: 1, calendar: greg)
        #expect(ad.extendedYear == 100)

        // BC alias
        let bc = try Date(year: .eraYear(era: "bc", year: 3), month: 1, day: 1, calendar: greg)
        #expect(bc.extendedYear == -2)
    }

    // MARK: - Year Ambiguity

    @Test("Year ambiguity flags from ICU4X")
    func yearAmbiguity() {
        let cases: [(extYear: Int32, expected: YearAmbiguity)] = [
            (500, .eraAndCenturyRequired),
            (1000, .centuryRequired),
            (1900, .centuryRequired),
            (1949, .centuryRequired),
            (1950, .unambiguous),
            (2024, .unambiguous),
            (2049, .unambiguous),
            (2050, .centuryRequired),
            (3000, .centuryRequired),
            (0, .eraAndCenturyRequired),   // 1 BCE
            (-100, .eraAndCenturyRequired),
        ]

        for (extYear, expected) in cases {
            let date = Date<Gregorian>.fromRataDie(
                GregorianArithmetic.fixedFromGregorian(year: extYear, month: 6, day: 15),
                calendar: greg
            )
            #expect(date.year.eraYear?.ambiguity == expected, "Year \(extYear)")
        }
    }

    // MARK: - Directionality

    @Test("Directionality: RD ordering matches YMD ordering")
    func directionality() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Gregorian>.fromRataDie(RataDie(i), calendar: greg)
                let dj = Date<Gregorian>.fromRataDie(RataDie(j), calendar: greg)

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

    // MARK: - Round-Trip

    @Test("Round-trip RD → Gregorian → RD for range -10000..10000")
    func roundTrip() {
        for i in stride(from: Int64(-10000), through: 10000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Gregorian>.fromRataDie(rd, calendar: greg)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }
}

import Testing
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarJapanese

@Suite("Japanese Calendar")
struct JapaneseTests {

    let japanese = Japanese()
    let greg = Gregorian()
    let iso = Iso()

    // MARK: - Era Boundaries

    @Test("Reiwa starts 2019-05-01")
    func reiwaStart() throws {
        let date = try Date(year: .eraYear(era: "reiwa", year: 1), month: 5, day: 1, calendar: japanese)
        #expect(date.extendedYear == 2019)
        #expect(date.year.eraYear?.era == "reiwa")
        #expect(date.year.eraYear?.year == 1)
    }

    @Test("Heisei 31 = day before Reiwa 1")
    func heiseiToReiwa() throws {
        let lastHeisei = try Date(year: 2019, month: 4, day: 30, calendar: japanese)
        let firstReiwa = try Date(year: 2019, month: 5, day: 1, calendar: japanese)

        #expect(lastHeisei.year.eraYear?.era == "heisei")
        #expect(lastHeisei.year.eraYear?.year == 31)
        #expect(firstReiwa.year.eraYear?.era == "reiwa")
        #expect(firstReiwa.year.eraYear?.year == 1)
        #expect(firstReiwa.rataDie - lastHeisei.rataDie == 1)
    }

    @Test("Heisei starts 1989-01-08")
    func heiseiStart() throws {
        let date = try Date(year: .eraYear(era: "heisei", year: 1), month: 1, day: 8, calendar: japanese)
        #expect(date.extendedYear == 1989)

        // Day before is Showa 64
        let dayBefore = try Date(year: 1989, month: 1, day: 7, calendar: japanese)
        #expect(dayBefore.year.eraYear?.era == "showa")
        #expect(dayBefore.year.eraYear?.year == 64)
    }

    @Test("Showa starts 1926-12-25")
    func showaStart() throws {
        let date = try Date(year: .eraYear(era: "showa", year: 1), month: 12, day: 25, calendar: japanese)
        #expect(date.extendedYear == 1926)

        let dayBefore = try Date(year: 1926, month: 12, day: 24, calendar: japanese)
        #expect(dayBefore.year.eraYear?.era == "taisho")
        #expect(dayBefore.year.eraYear?.year == 15)
    }

    @Test("Taisho starts 1912-07-30")
    func taishoStart() throws {
        let date = try Date(year: .eraYear(era: "taisho", year: 1), month: 7, day: 30, calendar: japanese)
        #expect(date.extendedYear == 1912)
    }

    @Test("Meiji starts 1868-10-23, but Meiji 1-5 fall back to CE")
    func meijiStart() throws {
        // Meiji 6 (1873) is the first year that shows as Meiji
        let meiji6 = try Date(year: 1873, month: 1, day: 1, calendar: japanese)
        #expect(meiji6.year.eraYear?.era == "meiji")
        #expect(meiji6.year.eraYear?.year == 6)

        // Meiji 5 (1872) falls back to CE
        let meiji5 = try Date(year: 1872, month: 12, day: 31, calendar: japanese)
        #expect(meiji5.year.eraYear?.era == "ce")
        #expect(meiji5.year.eraYear?.year == 1872)

        // 1868-10-23 = Meiji 1, but displays as CE
        let meiji1 = try Date(year: 1868, month: 10, day: 23, calendar: japanese)
        #expect(meiji1.year.eraYear?.era == "ce")
        #expect(meiji1.year.eraYear?.year == 1868)
    }

    // MARK: - Era Input Round-Trips from ICU4X

    @Test("Era year input round-trips from ICU4X test_japanese")
    func eraInputRoundTrips() throws {
        let cases: [(era: String, eraYear: Int32, month: UInt8, day: UInt8, expectedEra: String, expectedEraYear: Int32)] = [
            // Heisei 12 Mar 1
            ("heisei", 12, 3, 1, "heisei", 12),
            // Taisho 3 Mar 1
            ("taisho", 3, 3, 1, "taisho", 3),
            // Heisei 1 Jan 1 → actually still Showa 64
            ("heisei", 1, 1, 1, "showa", 64),
            // BCE 100 Mar 1
            ("bce", 100, 3, 1, "bce", 100),
            // BCE 1 Mar 1
            ("bce", 1, 3, 1, "bce", 1),
            // CE 1 Mar 1
            ("ce", 1, 3, 1, "ce", 1),
            // CE 100 Mar 1
            ("ce", 100, 3, 1, "ce", 100),
            // CE 1000 Mar 1
            ("ce", 1000, 3, 1, "ce", 1000),
            // Reiwa 2 Mar 1
            ("reiwa", 2, 3, 1, "reiwa", 2),
        ]

        for (era, eraYear, m, d, expectedEra, expectedEraYear) in cases {
            let date = try Date(
                year: .eraYear(era: era, year: eraYear),
                month: .new(m), day: d,
                calendar: japanese
            )
            let info = date.year.eraYear!

            #expect(info.era == expectedEra,
                    "\(era) \(eraYear)/\(m)/\(d): expected era \(expectedEra), got \(info.era)")
            #expect(info.year == expectedEraYear,
                    "\(era) \(eraYear)/\(m)/\(d): expected year \(expectedEraYear), got \(info.year)")

            // Round-trip through RD
            let rd = date.rataDie
            let recovered = Date<Japanese>.fromRataDie(rd, calendar: japanese)
            #expect(recovered == date)
        }
    }

    // MARK: - Meiji 6 Switchover from ICU4X

    @Test("Meiji 6 switchover: pre-1873 dates show as CE")
    func meiji6Switchover() throws {
        // Dates before Meiji 6 specified as CE
        let ce1868 = try Date(year: .eraYear(era: "ce", year: 1868), month: 10, day: 23, calendar: japanese)
        #expect(ce1868.year.eraYear?.era == "ce")

        // Dates before Meiji 6 specified as Meiji → extended year is correct
        let meiji1 = try Date(year: .eraYear(era: "meiji", year: 1), month: 10, day: 23, calendar: japanese)
        #expect(meiji1.extendedYear == 1868)
        // But displays as CE because Meiji year < 6
        #expect(meiji1.year.eraYear?.era == "ce")

        // Post-Meiji 6 date specified as Meiji
        let meiji33 = try Date(year: .eraYear(era: "meiji", year: 33), month: 2, day: 20, calendar: japanese)
        #expect(meiji33.year.eraYear?.era == "meiji")
        #expect(meiji33.year.eraYear?.year == 33)
        #expect(meiji33.extendedYear == 1900)

        // Post-Meiji 6 date specified as CE → shows as Meiji
        let ce1900 = try Date(year: .eraYear(era: "ce", year: 1900), month: 2, day: 20, calendar: japanese)
        #expect(ce1900.year.eraYear?.era == "meiji")
        #expect(ce1900.year.eraYear?.year == 33)
    }

    // MARK: - Fixture Data from ICU4X datetime tests

    @Test("Known dates from ICU4X datetime fixtures")
    func fixtureData() throws {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, expectedEra: String, expectedYear: Int32)] = [
            (2020, 2, 20, "reiwa", 2),
            (2010, 2, 20, "heisei", 22),
            (1927, 2, 20, "showa", 2),
            (1912, 7, 30, "taisho", 1),     // Taisho transition date
            (1912, 2, 20, "meiji", 45),
            (1900, 2, 20, "meiji", 33),
            (1800, 2, 20, "ce", 1800),       // Before Meiji
        ]

        for (isoY, isoM, isoD, expectedEra, expectedYear) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Japanese>.fromRataDie(rd, calendar: japanese)

            #expect(date.year.eraYear?.era == expectedEra,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected era \(expectedEra), got \(date.year.eraYear?.era ?? "nil")")
            #expect(date.year.eraYear?.year == expectedYear,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected year \(expectedYear), got \(date.year.eraYear?.year ?? -1)")
        }
    }

    // MARK: - Calendar Conversion

    @Test("Japanese → Gregorian conversion")
    func japaneseToGregorian() throws {
        let jpDate = try Date(year: .eraYear(era: "reiwa", year: 2), month: 2, day: 20, calendar: japanese)
        let gregDate = jpDate.converting(to: greg)

        #expect(gregDate.extendedYear == 2020)
        #expect(gregDate.month.number == 2)
        #expect(gregDate.dayOfMonth == 20)
        #expect(gregDate.year.eraYear?.era == "ce")
    }

    @Test("Gregorian → Japanese conversion")
    func gregorianToJapanese() throws {
        let gregDate = try Date(year: 2020, month: 2, day: 20, calendar: greg)
        let jpDate = gregDate.converting(to: japanese)

        #expect(jpDate.year.eraYear?.era == "reiwa")
        #expect(jpDate.year.eraYear?.year == 2)
    }

    // MARK: - Extended Year

    @Test("Extended year is Gregorian year, not era year")
    func extendedYear() throws {
        let date = try Date(year: .eraYear(era: "reiwa", year: 7), month: 1, day: 1, calendar: japanese)
        #expect(date.extendedYear == 2025)
    }

    // MARK: - Round-Trip

    @Test("Round-trip RD → Japanese → RD")
    func roundTrip() {
        // Test across all era boundaries
        let ranges: [ClosedRange<Int64>] = [
            680000...680500,   // around 1862 (pre-Meiji)
            682000...682500,   // around 1868 (Meiji start)
            698000...698500,   // around 1912 (Taisho start)
            703000...703500,   // around 1926 (Showa start)
            726000...726500,   // around 1989 (Heisei start)
            737000...737500,   // around 2019 (Reiwa start)
        ]

        for range in ranges {
            for i in range {
                let rd = RataDie(i)
                let date = Date<Japanese>.fromRataDie(rd, calendar: japanese)
                #expect(date.rataDie == rd, "Round-trip failed at RD \(i)")
            }
        }
    }

    // MARK: - Invalid Era

    @Test("Invalid era throws")
    func invalidEra() {
        #expect(throws: DateNewError.self) {
            try Date(year: .eraYear(era: "tokugawa", year: 1), month: 1, day: 1, calendar: japanese)
        }
    }

    // MARK: - BCE Dates

    @Test("BCE dates work through Japanese calendar")
    func bceDates() throws {
        let date = try Date(year: .eraYear(era: "bce", year: 44), month: 3, day: 15, calendar: japanese)
        #expect(date.extendedYear == -43)
        #expect(date.year.eraYear?.era == "bce")
        #expect(date.year.eraYear?.year == 44)
    }
}

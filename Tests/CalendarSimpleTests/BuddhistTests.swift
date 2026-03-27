import Testing
@testable import CalendarCore
@testable import CalendarSimple

@Suite("Buddhist Calendar")
struct BuddhistTests {

    let buddhist = Buddhist()
    let iso = Iso()

    // MARK: - Year Offset

    @Test("Buddhist year = ISO year + 543")
    func yearOffset() {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, beYear: Int32)] = [
            // 1 CE = 544 BE
            (1, 1, 1, 544),
            // 2024 CE = 2567 BE
            (2024, 6, 15, 2567),
            // 0 CE (1 BCE) = 543 BE
            (0, 12, 31, 543),
            // -542 CE (543 BCE) = 1 BE
            (-542, 1, 1, 1),
            // -543 CE (544 BCE) = 0 BE
            (-543, 5, 12, 0),
            // -553 CE = -10 BE
            (-553, 1, 1, -10),
        ]

        for (isoY, isoM, isoD, beYear) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Buddhist>.fromRataDie(rd, calendar: buddhist)

            #expect(date.year.eraYear?.year == beYear,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected BE \(beYear), got \(date.year.eraYear?.year ?? -999)")
            #expect(date.year.eraYear?.era == "be")
            #expect(date.month.number == isoM)
            #expect(date.dayOfMonth == isoD)
        }
    }

    // MARK: - Known Values from ICU4X

    @Test("Buddhist dates near RD zero from ICU4X test suite")
    func nearRdZero() {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, beYear: Int32, m: UInt8, d: UInt8)] = [
            (-100, 2, 15, 443, 2, 15),
            (-3, 10, 29, 540, 10, 29),
            (0, 12, 31, 543, 12, 31),
            (1, 1, 1, 544, 1, 1),
            (4, 2, 29, 547, 2, 29),
        ]

        for (isoY, isoM, isoD, beYear, m, d) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Buddhist>.fromRataDie(rd, calendar: buddhist)

            #expect(date.year.eraYear?.year == beYear)
            #expect(date.month.number == m)
            #expect(date.dayOfMonth == d)
            #expect(date.rataDie == rd)
        }
    }

    @Test("Buddhist dates near epoch from ICU4X test suite")
    func nearEpoch() {
        // 1 BE = 543 BCE = -542 ISO
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, beYear: Int32, m: UInt8, d: UInt8)] = [
            (-554, 12, 31, -11, 12, 31),
            (-553, 1, 1, -10, 1, 1),
            (-544, 8, 31, -1, 8, 31),
            (-543, 5, 12, 0, 5, 12),
            (-543, 12, 31, 0, 12, 31),
            (-542, 1, 1, 1, 1, 1),
            (-541, 7, 9, 2, 7, 9),
        ]

        for (isoY, isoM, isoD, beYear, m, d) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Buddhist>.fromRataDie(rd, calendar: buddhist)

            #expect(date.year.eraYear?.year == beYear,
                    "ISO \(isoY): expected BE \(beYear)")
            #expect(date.month.number == m)
            #expect(date.dayOfMonth == d)
            #expect(date.rataDie == rd)
        }
    }

    // MARK: - Round-Trip

    @Test("Round-trip RD → Buddhist → RD near RD zero")
    func roundTripNearZero() {
        for i in stride(from: Int64(-10000), through: 10000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Buddhist>.fromRataDie(rd, calendar: buddhist)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    @Test("Round-trip near Buddhist epoch (RD -198326)")
    func roundTripNearEpoch() {
        for i in stride(from: Int64(-208326), through: -188326, by: 1) {
            let rd = RataDie(i)
            let date = Date<Buddhist>.fromRataDie(rd, calendar: buddhist)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    // MARK: - Directionality

    @Test("Directionality near RD zero")
    func directionalityNearZero() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Buddhist>.fromRataDie(RataDie(i), calendar: buddhist)
                let dj = Date<Buddhist>.fromRataDie(RataDie(j), calendar: buddhist)

                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }

    // MARK: - Calendar Conversion

    @Test("Buddhist → ISO → Buddhist round-trip")
    func calendarConversion() throws {
        let beDate = try Date(year: 2567, month: 6, day: 15, calendar: buddhist)
        let isoDate = beDate.converting(to: iso)
        let backToBe = isoDate.converting(to: buddhist)

        #expect(isoDate.extendedYear == 2024)
        #expect(isoDate.month.number == 6)
        #expect(isoDate.dayOfMonth == 15)
        #expect(backToBe == beDate)
    }
}

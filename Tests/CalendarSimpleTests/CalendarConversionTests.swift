import Testing
@testable import CalendarCore
@testable import CalendarSimple

@Suite("Cross-Calendar Conversion")
struct CalendarConversionTests {

    let iso = Iso()
    let greg = Gregorian()
    let julian = Julian()
    let buddhist = Buddhist()
    let roc = Roc()

    // MARK: - ISO ↔ Gregorian

    @Test("ISO and Gregorian produce identical RataDie")
    func isoGregorianIdentity() throws {
        // ISO and Gregorian have identical arithmetic; they differ only in era display.
        for y: Int32 in [-100, -1, 0, 1, 100, 1000, 1582, 2000, 2024] {
            for m: UInt8 in [1, 6, 12] {
                let isoDate = try Date(year: .extended(y), month: .new(m), day: 1, calendar: iso)
                let gregDate = try Date(year: .extended(y), month: .new(m), day: 1, calendar: greg)
                #expect(isoDate.rataDie == gregDate.rataDie,
                        "ISO and Gregorian should have same RD for \(y)-\(m)-1")
            }
        }
    }

    // MARK: - Julian ↔ ISO Round-Trip

    @Test("Julian → ISO → Julian round-trip preserves date")
    func julianIsoRoundTrip() throws {
        let testDates: [(Int32, UInt8, UInt8)] = [
            (1, 1, 1), (100, 6, 15), (1582, 10, 4),
            (2000, 3, 1), (-100, 7, 20), (0, 12, 31),
        ]

        for (y, m, d) in testDates {
            let julDate = try Date(year: .extended(y), month: .new(m), day: d, calendar: julian)
            let isoDate = julDate.converting(to: iso)
            let backToJulian = isoDate.converting(to: julian)
            #expect(backToJulian == julDate,
                    "Julian \(y)-\(m)-\(d) round-trip failed")
        }
    }

    // MARK: - Buddhist ↔ Gregorian

    @Test("Buddhist 2567 = Gregorian 2024")
    func buddhistGregorian() throws {
        let beDate = try Date(year: 2567, month: 1, day: 1, calendar: buddhist)
        let gregDate = beDate.converting(to: greg)

        #expect(gregDate.extendedYear == 2024)
        #expect(gregDate.month.number == 1)
        #expect(gregDate.dayOfMonth == 1)
    }

    @Test("Buddhist 544 = Gregorian 1 CE")
    func buddhistYear544() throws {
        let beDate = try Date(year: 544, month: 1, day: 1, calendar: buddhist)
        let gregDate = beDate.converting(to: greg)

        #expect(gregDate.extendedYear == 1)
        #expect(gregDate.year.eraYear?.era == "ce")
    }

    // MARK: - ROC ↔ Gregorian

    @Test("ROC 1 = Gregorian 1912")
    func rocGregorian() throws {
        let rocDate = try Date(year: .eraYear(era: "roc", year: 1), month: 1, day: 1, calendar: roc)
        let gregDate = rocDate.converting(to: greg)

        #expect(gregDate.extendedYear == 1912)
        #expect(gregDate.year.eraYear?.era == "ce")
    }

    @Test("BROC 1 = Gregorian 1911")
    func brocGregorian() throws {
        let brocDate = try Date(year: .eraYear(era: "broc", year: 1), month: 7, day: 4, calendar: roc)
        let gregDate = brocDate.converting(to: greg)

        #expect(gregDate.extendedYear == 1911)
        #expect(gregDate.month.number == 7)
        #expect(gregDate.dayOfMonth == 4)
    }

    // MARK: - Full Chain

    @Test("ISO → Julian → Buddhist → ROC → Gregorian → ISO")
    func fullChain() throws {
        let start = try Date(year: 2024, month: 3, day: 15, calendar: iso)

        let asJulian = start.converting(to: julian)
        let asBuddhist = asJulian.converting(to: buddhist)
        let asRoc = asBuddhist.converting(to: roc)
        let asGregorian = asRoc.converting(to: greg)
        let backToIso = asGregorian.converting(to: iso)

        #expect(backToIso == start)
        #expect(backToIso.rataDie == start.rataDie)
    }

    // MARK: - Historical Equivalences

    @Test("Julian Oct 4, 1582 + 1 day = Gregorian Oct 15, 1582")
    func gregorianCutover() throws {
        let julianLast = try Date(year: 1582, month: 10, day: 4, calendar: julian)
        let gregFirst = try Date(year: 1582, month: 10, day: 15, calendar: greg)
        #expect(gregFirst.rataDie - julianLast.rataDie == 1)
    }

    @Test("Julian Dec 25 = Gregorian Jan 7 in 2024 (Orthodox Christmas)")
    func orthodoxChristmas() throws {
        // Julian Dec 25, 2023 = Gregorian Jan 7, 2024
        let julianXmas = try Date(year: 2023, month: 12, day: 25, calendar: julian)
        let gregDate = julianXmas.converting(to: greg)

        #expect(gregDate.extendedYear == 2024)
        #expect(gregDate.month.number == 1)
        #expect(gregDate.dayOfMonth == 7)
    }
}

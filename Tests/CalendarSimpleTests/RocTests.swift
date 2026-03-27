import Testing
@testable import CalendarCore
@testable import CalendarSimple

@Suite("ROC (Republic of China) Calendar")
struct RocTests {

    let roc = Roc()
    let iso = Iso()
    let greg = Gregorian()

    // MARK: - Current Era (ROC/Minguo)

    @Test("ROC dates in Minguo era from ICU4X test suite")
    func currentEra() {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, rocYear: Int32, era: String)] = [
            (1912, 1, 1, 1, "roc"),
            (1912, 2, 29, 1, "roc"),
            (1913, 6, 30, 2, "roc"),
            (2023, 7, 13, 112, "roc"),
        ]

        for (isoY, isoM, isoD, rocYear, era) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Roc>.fromRataDie(rd, calendar: roc)

            #expect(date.year.eraYear?.year == rocYear,
                    "ISO \(isoY): expected ROC \(rocYear)")
            #expect(date.year.eraYear?.era == era)
            #expect(date.month.number == isoM)
            #expect(date.dayOfMonth == isoD)
            #expect(date.rataDie == rd)
        }
    }

    // MARK: - Prior Era (Before ROC)

    @Test("ROC dates in Before-Minguo era from ICU4X test suite")
    func priorEra() {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, brocYear: Int32, era: String, m: UInt8, d: UInt8)] = [
            (1911, 12, 31, 1, "broc", 12, 31),
            (1911, 1, 1, 1, "broc", 1, 1),
            (1910, 12, 31, 2, "broc", 12, 31),
            (1908, 2, 29, 4, "broc", 2, 29),
            (1, 1, 1, 1911, "broc", 1, 1),
            (0, 12, 31, 1912, "broc", 12, 31),
        ]

        for (isoY, isoM, isoD, brocYear, era, m, d) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Roc>.fromRataDie(rd, calendar: roc)

            #expect(date.year.eraYear?.year == brocYear,
                    "ISO \(isoY): expected BROC \(brocYear)")
            #expect(date.year.eraYear?.era == era,
                    "ISO \(isoY): expected era \(era)")
            #expect(date.month.number == m)
            #expect(date.dayOfMonth == d)
            #expect(date.rataDie == rd)
        }
    }

    // MARK: - Era Input

    @Test("Construct from roc/broc era year")
    func eraInput() throws {
        // 1 Minguo = 1912 CE
        let roc1 = try Date(year: .eraYear(era: "roc", year: 1), month: 2, day: 3, calendar: roc)
        let greg1912 = try Date(year: 1912, month: 2, day: 3, calendar: greg)
        #expect(roc1.rataDie == greg1912.rataDie)

        // 1 Before Minguo = 1911 CE
        let broc1 = try Date(year: .eraYear(era: "broc", year: 1), month: 6, day: 15, calendar: roc)
        let greg1911 = try Date(year: 1911, month: 6, day: 15, calendar: greg)
        #expect(broc1.rataDie == greg1911.rataDie)

        // 4 Before Minguo = 1908 CE (leap year)
        let broc4 = try Date(year: .eraYear(era: "broc", year: 4), month: 2, day: 29, calendar: roc)
        let greg1908 = try Date(year: 1908, month: 2, day: 29, calendar: greg)
        #expect(broc4.rataDie == greg1908.rataDie)
    }

    // MARK: - Calendar Conversion

    @Test("ROC → Gregorian conversion")
    func rocToGregorian() throws {
        let rocDate = try Date(year: .eraYear(era: "roc", year: 1), month: 2, day: 3, calendar: roc)
        let gregDate = rocDate.converting(to: greg)

        #expect(gregDate.extendedYear == 1912)
        #expect(gregDate.month.number == 2)
        #expect(gregDate.dayOfMonth == 3)
        #expect(gregDate.year.eraYear?.era == "ce")
    }

    // MARK: - Round-Trip

    @Test("Round-trip RD → ROC → RD near RD zero")
    func roundTripNearZero() {
        for i in stride(from: Int64(-10000), through: 10000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Roc>.fromRataDie(rd, calendar: roc)
            #expect(date.rataDie == rd)
        }
    }

    // MARK: - Directionality

    @Test("Directionality near ROC epoch (RD 697978)")
    func directionalityNearEpoch() {
        let rdEpoch: Int64 = 697978  // Jan 1, 1912 CE
        for i in (rdEpoch - 100)...(rdEpoch + 100) {
            for j in (rdEpoch - 100)...(rdEpoch + 100) {
                let di = Date<Roc>.fromRataDie(RataDie(i), calendar: roc)
                let dj = Date<Roc>.fromRataDie(RataDie(j), calendar: roc)

                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }

    @Test("Directionality near RD zero")
    func directionalityNearZero() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Roc>.fromRataDie(RataDie(i), calendar: roc)
                let dj = Date<Roc>.fromRataDie(RataDie(j), calendar: roc)

                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }
}

import Testing
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

@Suite("Indian (Saka) Calendar")
struct IndianTests {

    let indian = Indian()
    let iso = Iso()

    @Test("Known Indian dates from ICU4X test suite")
    func knownDates() {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, indY: Int32, indM: UInt8, indD: UInt8)] = [
            (2022, 8, 29, 1944, 6, 7),
            (2021, 8, 29, 1943, 6, 7),
            (2020, 8, 29, 1942, 6, 7),
            (2019, 8, 29, 1941, 6, 7),
            (2023, 1, 27, 1944, 11, 7),
            (2022, 1, 27, 1943, 11, 7),
            (2021, 1, 27, 1942, 11, 7),
            (2020, 1, 27, 1941, 11, 7),
        ]

        for (isoY, isoM, isoD, indY, indM, indD) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Indian>.fromRataDie(rd, calendar: indian)

            #expect(date.extendedYear == indY,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected Saka year \(indY)")
            #expect(date.month.number == indM,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected month \(indM)")
            #expect(date.dayOfMonth == indD,
                    "ISO \(isoY)-\(isoM)-\(isoD): expected day \(indD)")
            #expect(date.rataDie == rd)
        }
    }

    @Test("Epoch: Saka 1/1/1 = ISO 79/3/22")
    func epoch() {
        let isoRd = GregorianArithmetic.fixedFromGregorian(year: 79, month: 3, day: 22)
        let date = Date<Indian>.fromRataDie(isoRd, calendar: indian)
        #expect(date.extendedYear == 1)
        #expect(date.month.number == 1)
        #expect(date.dayOfMonth == 1)
    }

    @Test("Near epoch from ICU4X")
    func nearEpoch() {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, indY: Int32, indM: UInt8, indD: UInt8)] = [
            (79, 3, 23, 1, 1, 2),
            (79, 3, 22, 1, 1, 1),
            (79, 3, 21, 0, 12, 30),
            (79, 3, 20, 0, 12, 29),
            (78, 3, 21, -1, 12, 30),
        ]

        for (isoY, isoM, isoD, indY, indM, indD) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Indian>.fromRataDie(rd, calendar: indian)
            #expect(date.extendedYear == indY, "ISO \(isoY)-\(isoM)-\(isoD)")
            #expect(date.month.number == indM, "ISO \(isoY)-\(isoM)-\(isoD)")
            #expect(date.dayOfMonth == indD, "ISO \(isoY)-\(isoM)-\(isoD)")
        }
    }

    @Test("Near RD zero from ICU4X")
    func nearRdZero() {
        let cases: [(isoY: Int32, isoM: UInt8, isoD: UInt8, indY: Int32, indM: UInt8, indD: UInt8)] = [
            (1, 3, 22, -77, 1, 1),
            (1, 3, 21, -78, 12, 30),
            (1, 1, 1, -78, 10, 11),
            (0, 3, 21, -78, 1, 1),
            (0, 1, 1, -79, 10, 11),
            (-1, 3, 21, -80, 12, 30),
        ]

        for (isoY, isoM, isoD, indY, indM, indD) in cases {
            let rd = GregorianArithmetic.fixedFromGregorian(year: isoY, month: isoM, day: isoD)
            let date = Date<Indian>.fromRataDie(rd, calendar: indian)
            #expect(date.extendedYear == indY, "ISO \(isoY)-\(isoM)-\(isoD)")
            #expect(date.month.number == indM, "ISO \(isoY)-\(isoM)-\(isoD)")
            #expect(date.dayOfMonth == indD, "ISO \(isoY)-\(isoM)-\(isoD)")
        }
    }

    @Test("Month lengths: M1=30/31, M2-6=31, M7-12=30")
    func monthLengths() {
        // Non-leap year (Saka 1943 → Gregorian 2021, not leap)
        #expect(Indian.daysInProvidedMonth(year: 1943, month: 1) == 30)
        for m: UInt8 in 2...6 {
            #expect(Indian.daysInProvidedMonth(year: 1943, month: m) == 31)
        }
        for m: UInt8 in 7...12 {
            #expect(Indian.daysInProvidedMonth(year: 1943, month: m) == 30)
        }

        // Leap year (Saka 1942 → Gregorian 2020, leap)
        #expect(Indian.daysInProvidedMonth(year: 1942, month: 1) == 31)
    }

    @Test("Round-trip RD → Indian → RD near RD zero")
    func roundTripNearZero() {
        for i in stride(from: Int64(-1000), through: 1000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Indian>.fromRataDie(rd, calendar: indian)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    @Test("Round-trip near Saka epoch (RD ~28570)")
    func roundTripNearEpoch() {
        for i: Int64 in 27570...29570 {
            let rd = RataDie(i)
            let date = Date<Indian>.fromRataDie(rd, calendar: indian)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    @Test("Directionality near RD zero")
    func directionality() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Indian>.fromRataDie(RataDie(i), calendar: indian)
                let dj = Date<Indian>.fromRataDie(RataDie(j), calendar: indian)
                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }

    @Test("Calendar conversion: Indian → ISO → Indian")
    func calendarConversion() throws {
        let indDate = try Date(year: 1944, month: 6, day: 7, calendar: indian)
        let isoDate = indDate.converting(to: iso)
        let backToInd = isoDate.converting(to: indian)

        #expect(isoDate.extendedYear == 2022)
        #expect(isoDate.month.number == 8)
        #expect(isoDate.dayOfMonth == 29)
        #expect(backToInd == indDate)
    }
}

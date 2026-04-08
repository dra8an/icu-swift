import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarAstronomical

@Suite("Islamic Tabular Calendar")
struct IslamicTabularTests {

    let islamic = IslamicTabular()  // default = .thursday
    static let epoch = TabularEpoch.thursday.rataDie

    // MARK: - ICU4X Reference Data
    // ASTRONOMICAL_CASES from ICU4X hijri.rs (lines 1448–1614) — Thursday epoch.

    static let testRD: [Int64] = [
        -214193, -61387, 25469, 49217, 171307, 210155, 253427, 369740,
        400085, 434355, 452605, 470160, 473837, 507850, 524156, 544676,
        567118, 569477, 601716, 613424, 626596, 645554, 664224, 671401,
        694799, 704424, 708842, 709409, 709580, 727274, 728714, 744313,
        764652
    ]

    static let astronomicalCases: [(year: Int32, month: UInt8, day: UInt8)] = [
        (-1245, 12, 10), (-813,  2, 24), (-568,  4,  2), (-501,  4,  7), (-157, 10, 18),
        ( -47,  6,  4), (  75,  7, 14), ( 403, 10,  6), ( 489,  5, 23), ( 586,  2,  8),
        ( 637,  8,  8), ( 687,  2, 21), ( 697,  7,  8), ( 793,  7,  2), ( 839,  7,  7),
        ( 897,  6,  2), ( 960, 10,  1), ( 967,  5, 28), (1058,  5, 19), (1091,  6,  3),
        (1128,  8,  5), (1182,  2,  4), (1234, 10, 11), (1255,  1, 12), (1321,  1, 22),
        (1348,  3, 20), (1360,  9,  9), (1362,  4, 14), (1362, 10,  8), (1412,  9, 14),
        (1416, 10,  6), (1460, 10, 13), (1518,  3,  6),
    ]

    // MARK: - Reference pair tests

    @Test("RD from Hijri (tabular/Thursday) — all 33 ICU4X reference pairs")
    func rdFromHijri() {
        for i in 0..<Self.testRD.count {
            let (year, month, day) = Self.astronomicalCases[i]
            let expectedRD = RataDie(Self.testRD[i])
            let computedRD = IslamicTabularArithmetic.fixedFromTabular(
                year: year, month: month, day: day, epoch: Self.epoch)
            #expect(computedRD == expectedRD,
                    "Case \(i): fixedFromTabular(\(year), \(month), \(day)) = \(computedRD.dayNumber), expected \(expectedRD.dayNumber)")
        }
    }

    @Test("Hijri (tabular/Thursday) from RD — all 33 ICU4X reference pairs")
    func hijriFromRd() {
        for i in 0..<Self.testRD.count {
            let rd = RataDie(Self.testRD[i])
            let (expectedYear, expectedMonth, expectedDay) = Self.astronomicalCases[i]
            let (year, month, day) = IslamicTabularArithmetic.tabularFromFixed(rd, epoch: Self.epoch)
            #expect(year == expectedYear)
            #expect(month == expectedMonth)
            #expect(day == expectedDay)

            let roundTripped = IslamicTabularArithmetic.fixedFromTabular(
                year: year, month: month, day: day, epoch: Self.epoch)
            #expect(roundTripped == rd)
        }
    }

    // MARK: - Round-trips

    @Test("Round-trip RD -> Islamic Tabular -> RD for -10000..10000")
    func roundTripWide() {
        for i in stride(from: Int64(-10000), through: 10000, by: 1) {
            let rd = RataDie(i)
            let date = Date<IslamicTabular>.fromRataDie(rd, calendar: islamic)
            #expect(date.rataDie == rd)
        }
    }

    @Test("Round-trip near Thursday epoch")
    func roundTripNearEpoch() {
        let epochRd = Self.epoch.dayNumber
        for i in (epochRd - 1000)...(epochRd + 1000) {
            let rd = RataDie(i)
            let date = Date<IslamicTabular>.fromRataDie(rd, calendar: islamic)
            #expect(date.rataDie == rd)
        }
    }

    // MARK: - 30-year leap cycle (epoch-independent)

    @Test("Leap years in 30-year cycle (Type II)")
    func leapYearCycle() {
        let leapPositions: Set<Int32> = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]
        for year: Int32 in 1...30 {
            #expect(IslamicTabularArithmetic.isLeapYear(year) == leapPositions.contains(year),
                    "Year \(year)")
        }
        for year: Int32 in 31...60 {
            let posInCycle = year - 30
            #expect(IslamicTabularArithmetic.isLeapYear(year) == leapPositions.contains(posInCycle))
        }
    }

    // MARK: - Month / year lengths (epoch-independent)

    @Test("Month lengths: odd=30, even=29, month 12=30 in leap years")
    func monthLengths() {
        for m: UInt8 in [1, 3, 5, 7, 9, 11] {
            #expect(IslamicTabularArithmetic.daysInMonth(year: 1, month: m) == 30)
            #expect(IslamicTabularArithmetic.daysInMonth(year: 2, month: m) == 30)
        }
        for m: UInt8 in [2, 4, 6, 8, 10] {
            #expect(IslamicTabularArithmetic.daysInMonth(year: 1, month: m) == 29)
            #expect(IslamicTabularArithmetic.daysInMonth(year: 2, month: m) == 29)
        }
        #expect(IslamicTabularArithmetic.daysInMonth(year: 1, month: 12) == 29)
        #expect(IslamicTabularArithmetic.daysInMonth(year: 2, month: 12) == 30)
    }

    @Test("Year length: 354 (common) or 355 (leap), 11 leap per 30 years")
    func yearLength() throws {
        let leapPositions: Set<Int32> = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]
        var leapCount = 0
        for year: Int32 in 1...30 {
            let date = try Date(year: .extended(year), month: 1, day: 1, calendar: islamic)
            let expectedDays: UInt16 = leapPositions.contains(year) ? 355 : 354
            #expect(date.daysInYear == expectedDays)
            if expectedDays == 355 { leapCount += 1 }
        }
        #expect(leapCount == 11)
    }

    @Test("Year gaps are always 354 or 355 days")
    func yearGaps() {
        for year: Int32 in -50...200 {
            let m1 = IslamicTabularArithmetic.fixedFromTabular(year: year, month: 1, day: 1, epoch: Self.epoch)
            let m2 = IslamicTabularArithmetic.fixedFromTabular(year: year + 1, month: 1, day: 1, epoch: Self.epoch)
            let gap = m2.dayNumber - m1.dayNumber
            #expect(gap == 354 || gap == 355)
        }
    }

    // MARK: - Eras

    @Test("AH and BH eras")
    func eras() throws {
        let ah = try Date(year: .eraYear(era: "ah", year: 1445), month: 1, day: 1, calendar: islamic)
        #expect(ah.extendedYear == 1445)
        #expect(ah.year.eraYear?.era == "ah")

        let bh1 = try Date(year: .eraYear(era: "bh", year: 1), month: 1, day: 1, calendar: islamic)
        #expect(bh1.extendedYear == 0)
        #expect(bh1.year.eraYear?.era == "bh")

        let bh2 = try Date(year: .eraYear(era: "bh", year: 2), month: 1, day: 1, calendar: islamic)
        #expect(bh2.extendedYear == -1)

        let ah1 = try Date(year: .eraYear(era: "ah", year: 1), month: 1, day: 1, calendar: islamic)
        #expect(ah1.rataDie > bh1.rataDie)

        #expect(throws: DateNewError.self) {
            try Date(year: .eraYear(era: "invalid", year: 1), month: 1, day: 1, calendar: islamic)
        }
    }

    // MARK: - Directionality

    @Test("Directionality: RD ordering matches date ordering")
    func directionality() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<IslamicTabular>.fromRataDie(RataDie(i), calendar: islamic)
                let dj = Date<IslamicTabular>.fromRataDie(RataDie(j), calendar: islamic)
                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }

    // MARK: - Epoch sanity

    @Test("Thursday epoch is Jul 15, 622 Julian, in Gregorian year 622")
    func epochCheck() {
        #expect(Self.epoch == JulianArithmetic.fixedFromJulian(year: 622, month: 7, day: 15))
        #expect(GregorianArithmetic.yearFromFixed(Self.epoch) == 622)
    }

    @Test("1 AH, Muharram 1 = Thursday epoch (default IslamicTabular)")
    func yearOneDayOne() throws {
        let date = try Date(year: 1, month: 1, day: 1, calendar: islamic)
        #expect(date.rataDie == Self.epoch)
    }

    // MARK: - Configurability

    @Test("IslamicTabular(epoch: .friday) matches IslamicCivil")
    func configurableEpoch() throws {
        let tFri = IslamicTabular(epoch: .friday)
        let civil = IslamicCivil()
        for rd in stride(from: Int64(-100000), through: 1000000, by: 13337) {
            let r = RataDie(rd)
            let a = Date<IslamicTabular>.fromRataDie(r, calendar: tFri)
            let b = Date<IslamicCivil>.fromRataDie(r, calendar: civil)
            #expect(a.extendedYear == b.extendedYear)
            #expect(a.month.ordinal == b.month.ordinal)
            #expect(a.dayOfMonth == b.dayOfMonth)
        }
    }

    @Test("Calendar identifier is islamic-tbla")
    func identifier() {
        #expect(IslamicTabular.calendarIdentifier == "islamic-tbla")
    }
}

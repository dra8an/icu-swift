import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarAstronomical

@Suite("Islamic Civil Calendar")
struct IslamicCivilTests {

    let islamic = IslamicCivil()
    static let epoch = TabularEpoch.friday.rataDie

    // MARK: - ICU4X Reference Data (Calendrical Calculations)
    // ARITHMETIC_CASES from ICU4X hijri.rs — Friday epoch (islamic-civil).

    static let testRD: [Int64] = [
        -214193, -61387, 25469, 49217, 171307, 210155, 253427, 369740,
        400085, 434355, 452605, 470160, 473837, 507850, 524156, 544676,
        567118, 569477, 601716, 613424, 626596, 645554, 664224, 671401,
        694799, 704424, 708842, 709409, 709580, 727274, 728714, 744313,
        764652
    ]

    static let arithmeticCases: [(year: Int32, month: UInt8, day: UInt8)] = [
        (-1245, 12,  9), (-813,  2, 23), (-568,  4,  1), (-501,  4,  6), (-157, 10, 17),
        ( -47,  6,  3), (  75,  7, 13), ( 403, 10,  5), ( 489,  5, 22), ( 586,  2,  7),
        ( 637,  8,  7), ( 687,  2, 20), ( 697,  7,  7), ( 793,  7,  1), ( 839,  7,  6),
        ( 897,  6,  1), ( 960,  9, 30), ( 967,  5, 27), (1058,  5, 18), (1091,  6,  2),
        (1128,  8,  4), (1182,  2,  3), (1234, 10, 10), (1255,  1, 11), (1321,  1, 21),
        (1348,  3, 19), (1360,  9,  8), (1362,  4, 13), (1362, 10,  7), (1412,  9, 13),
        (1416, 10,  5), (1460, 10, 12), (1518,  3,  5),
    ]

    @Test("RD from Hijri (civil) — all 33 ICU4X reference pairs")
    func rdFromHijri() {
        for i in 0..<Self.testRD.count {
            let (year, month, day) = Self.arithmeticCases[i]
            let expectedRD = RataDie(Self.testRD[i])
            let computedRD = IslamicTabularArithmetic.fixedFromTabular(
                year: year, month: month, day: day, epoch: Self.epoch)
            #expect(computedRD == expectedRD,
                    "Case \(i): fixedFromTabular(\(year), \(month), \(day)) = \(computedRD.dayNumber), expected \(expectedRD.dayNumber)")
        }
    }

    @Test("Hijri (civil) from RD — all 33 ICU4X reference pairs")
    func hijriFromRd() {
        for i in 0..<Self.testRD.count {
            let rd = RataDie(Self.testRD[i])
            let (expectedYear, expectedMonth, expectedDay) = Self.arithmeticCases[i]
            let (year, month, day) = IslamicTabularArithmetic.tabularFromFixed(rd, epoch: Self.epoch)
            #expect(year == expectedYear)
            #expect(month == expectedMonth)
            #expect(day == expectedDay)

            let roundTripped = IslamicTabularArithmetic.fixedFromTabular(
                year: year, month: month, day: day, epoch: Self.epoch)
            #expect(roundTripped == rd)
        }
    }

    @Test("Round-trip RD -> Islamic Civil -> RD for -10000..10000")
    func roundTripWide() {
        for i in stride(from: Int64(-10000), through: 10000, by: 1) {
            let rd = RataDie(i)
            let date = Date<IslamicCivil>.fromRataDie(rd, calendar: islamic)
            #expect(date.rataDie == rd)
        }
    }

    @Test("Round-trip near Friday epoch")
    func roundTripNearEpoch() {
        let epochRd = Self.epoch.dayNumber
        for i in (epochRd - 1000)...(epochRd + 1000) {
            let rd = RataDie(i)
            let date = Date<IslamicCivil>.fromRataDie(rd, calendar: islamic)
            #expect(date.rataDie == rd)
        }
    }

    @Test("Friday epoch is Jul 16, 622 Julian and falls in Gregorian year 622")
    func epoch() {
        #expect(Self.epoch == JulianArithmetic.fixedFromJulian(year: 622, month: 7, day: 16))
        #expect(GregorianArithmetic.yearFromFixed(Self.epoch) == 622)
    }

    @Test("1 AH, Muharram 1 = Friday epoch")
    func yearOneDayOne() throws {
        let date = try Date(year: 1, month: 1, day: 1, calendar: islamic)
        #expect(date.rataDie == Self.epoch)
    }

    @Test("Calendar identifier is islamic-civil")
    func identifier() {
        #expect(IslamicCivil.calendarIdentifier == "islamic-civil")
    }
}

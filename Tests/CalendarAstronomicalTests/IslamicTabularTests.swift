import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarAstronomical

@Suite("Islamic Tabular Calendar")
struct IslamicTabularTests {

    let islamic = IslamicTabular()

    // MARK: - ICU4X Reference Data (Calendrical Calculations)

    /// The 33 Rata Die values from ICU4X / Calendrical Calculations.
    static let testRD: [Int64] = [
        -214193, -61387, 25469, 49217, 171307, 210155, 253427, 369740,
        400085, 434355, 452605, 470160, 473837, 507850, 524156, 544676,
        567118, 569477, 601716, 613424, 626596, 645554, 664224, 671401,
        694799, 704424, 708842, 709409, 709580, 727274, 728714, 744313,
        764652
    ]

    /// The 33 arithmetic cases for Tabular Type II, Friday epoch.
    static let arithmeticCases: [(year: Int32, month: UInt8, day: UInt8)] = [
        (-1245, 12,  9), (-813,  2, 23), (-568,  4,  1), (-501,  4,  6), (-157, 10, 17),
        ( -47,  6,  3), (  75,  7, 13), ( 403, 10,  5), ( 489,  5, 22), ( 586,  2,  7),
        ( 637,  8,  7), ( 687,  2, 20), ( 697,  7,  7), ( 793,  7,  1), ( 839,  7,  6),
        ( 897,  6,  1), ( 960,  9, 30), ( 967,  5, 27), (1058,  5, 18), (1091,  6,  2),
        (1128,  8,  4), (1182,  2,  3), (1234, 10, 10), (1255,  1, 11), (1321,  1, 21),
        (1348,  3, 19), (1360,  9,  8), (1362,  4, 13), (1362, 10,  7), (1412,  9, 13),
        (1416, 10,  5), (1460, 10, 12), (1518,  3,  5),
    ]

    // MARK: - 1. fixedFromTabular for all 33 pairs

    @Test("RD from Hijri — all 33 ICU4X reference pairs")
    func rdFromHijri() {
        for i in 0..<Self.testRD.count {
            let (year, month, day) = Self.arithmeticCases[i]
            let expectedRD = RataDie(Self.testRD[i])
            let computedRD = IslamicTabularArithmetic.fixedFromTabular(year: year, month: month, day: day)
            #expect(computedRD == expectedRD,
                    "Case \(i): fixedFromTabular(\(year), \(month), \(day)) = \(computedRD.dayNumber), expected \(expectedRD.dayNumber)")
        }
    }

    // MARK: - 2. tabularFromFixed for all 33 pairs (round-trip verification)

    @Test("Hijri from RD — all 33 ICU4X reference pairs")
    func hijriFromRd() {
        for i in 0..<Self.testRD.count {
            let rd = RataDie(Self.testRD[i])
            let (expectedYear, expectedMonth, expectedDay) = Self.arithmeticCases[i]
            let (year, month, day) = IslamicTabularArithmetic.tabularFromFixed(rd)
            #expect(year == expectedYear,
                    "Case \(i) RD \(Self.testRD[i]): year \(year), expected \(expectedYear)")
            #expect(month == expectedMonth,
                    "Case \(i) RD \(Self.testRD[i]): month \(month), expected \(expectedMonth)")
            #expect(day == expectedDay,
                    "Case \(i) RD \(Self.testRD[i]): day \(day), expected \(expectedDay)")

            // Verify round-trip: tabularFromFixed -> fixedFromTabular -> same RD
            let roundTripped = IslamicTabularArithmetic.fixedFromTabular(year: year, month: month, day: day)
            #expect(roundTripped == rd,
                    "Case \(i): round-trip failed, got RD \(roundTripped.dayNumber) from (\(year), \(month), \(day))")
        }
    }

    // MARK: - 3. Round-trip for range -10000..10000

    @Test("Round-trip RD -> Islamic -> RD for -10000..10000")
    func roundTripWide() {
        for i in stride(from: Int64(-10000), through: 10000, by: 1) {
            let rd = RataDie(i)
            let date = Date<IslamicTabular>.fromRataDie(rd, calendar: islamic)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    // MARK: - 4. Round-trip near epoch

    @Test("Round-trip near epoch")
    func roundTripNearEpoch() {
        let epochRd = IslamicTabularArithmetic.epoch.dayNumber
        for i in (epochRd - 1000)...(epochRd + 1000) {
            let rd = RataDie(i)
            let date = Date<IslamicTabular>.fromRataDie(rd, calendar: islamic)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    // MARK: - 5. 30-year leap cycle verification

    @Test("Leap years in 30-year cycle (Type II)")
    func leapYearCycle() {
        let leapPositions: Set<Int32> = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]
        for year: Int32 in 1...30 {
            let expected = leapPositions.contains(year)
            #expect(IslamicTabularArithmetic.isLeapYear(year) == expected,
                    "Year \(year) in cycle: expected leap=\(expected)")
        }

        // Verify cycle repeats
        for year: Int32 in 31...60 {
            let posInCycle = year - 30
            let expected = leapPositions.contains(posInCycle)
            #expect(IslamicTabularArithmetic.isLeapYear(year) == expected,
                    "Year \(year): leap should match position \(posInCycle) in cycle")
        }

        // Verify negative years
        for year: Int32 in -30...0 {
            let result = IslamicTabularArithmetic.isLeapYear(year)
            #expect(result == true || result == false,
                    "isLeapYear should not crash for year \(year)")
        }
    }

    // MARK: - 6. Month lengths

    @Test("Month lengths: odd=30, even=29, month 12=30 in leap years")
    func monthLengths() {
        // Non-leap year (year 1)
        #expect(!IslamicTabularArithmetic.isLeapYear(1))
        for m: UInt8 in [1, 3, 5, 7, 9, 11] {
            #expect(IslamicTabularArithmetic.daysInMonth(year: 1, month: m) == 30,
                    "Non-leap year, month \(m) should have 30 days")
        }
        for m: UInt8 in [2, 4, 6, 8, 10] {
            #expect(IslamicTabularArithmetic.daysInMonth(year: 1, month: m) == 29,
                    "Non-leap year, month \(m) should have 29 days")
        }
        #expect(IslamicTabularArithmetic.daysInMonth(year: 1, month: 12) == 29,
                "Non-leap year, month 12 should have 29 days")

        // Leap year (year 2)
        #expect(IslamicTabularArithmetic.isLeapYear(2))
        for m: UInt8 in [1, 3, 5, 7, 9, 11] {
            #expect(IslamicTabularArithmetic.daysInMonth(year: 2, month: m) == 30,
                    "Leap year, month \(m) should have 30 days")
        }
        for m: UInt8 in [2, 4, 6, 8, 10] {
            #expect(IslamicTabularArithmetic.daysInMonth(year: 2, month: m) == 29,
                    "Leap year, month \(m) should have 29 days")
        }
        #expect(IslamicTabularArithmetic.daysInMonth(year: 2, month: 12) == 30,
                "Leap year, month 12 should have 30 days")
    }

    // MARK: - 7. Year lengths (354 vs 355)

    @Test("Year length: 354 (common) or 355 (leap)")
    func yearLength() throws {
        // Common year
        let common = try Date(year: 1, month: 1, day: 1, calendar: islamic)
        #expect(common.daysInYear == 354)

        // Leap year
        let leap = try Date(year: 2, month: 1, day: 1, calendar: islamic)
        #expect(leap.daysInYear == 355)

        // Verify across a full 30-year cycle
        let leapPositions: Set<Int32> = [2, 5, 7, 10, 13, 16, 18, 21, 24, 26, 29]
        for year: Int32 in 1...30 {
            let date = try Date(year: .extended(year), month: 1, day: 1, calendar: islamic)
            let expectedDays: UInt16 = leapPositions.contains(year) ? 355 : 354
            #expect(date.daysInYear == expectedDays,
                    "Year \(year): expected \(expectedDays) days, got \(date.daysInYear)")
        }
    }

    // MARK: - 8. Era handling (ah/bh)

    @Test("AH and BH eras")
    func eras() throws {
        // AH era
        let ah = try Date(year: .eraYear(era: "ah", year: 1445), month: 1, day: 1, calendar: islamic)
        #expect(ah.extendedYear == 1445)
        #expect(ah.year.eraYear?.era == "ah")
        #expect(ah.year.eraYear?.year == 1445)

        // BH era: bh year 1 = extended year 0
        let bh1 = try Date(year: .eraYear(era: "bh", year: 1), month: 1, day: 1, calendar: islamic)
        #expect(bh1.extendedYear == 0)
        #expect(bh1.year.eraYear?.era == "bh")
        #expect(bh1.year.eraYear?.year == 1)

        // BH era: bh year 2 = extended year -1
        let bh2 = try Date(year: .eraYear(era: "bh", year: 2), month: 1, day: 1, calendar: islamic)
        #expect(bh2.extendedYear == -1)
        #expect(bh2.year.eraYear?.era == "bh")

        // AH year 1 should be after BH year 1
        let ah1 = try Date(year: .eraYear(era: "ah", year: 1), month: 1, day: 1, calendar: islamic)
        #expect(ah1.rataDie > bh1.rataDie)

        // Invalid era should throw
        #expect(throws: DateNewError.self) {
            try Date(year: .eraYear(era: "invalid", year: 1), month: 1, day: 1, calendar: islamic)
        }
    }

    // MARK: - 9. Directionality -100..100

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

    // MARK: - 10. Days-in-year: verify daysInYear matches difference between consecutive Muharram 1 dates

    @Test("daysInYear is 354 or 355 and year gaps are always 354 or 355")
    func daysInYearConsistency() throws {
        // daysInYear should always be 354 (common) or 355 (leap)
        for year: Int32 in -50...200 {
            let muharram1 = IslamicTabularArithmetic.fixedFromTabular(year: year, month: 1, day: 1)
            let date = Date<IslamicTabular>.fromRataDie(muharram1, calendar: islamic)
            #expect(date.daysInYear == 354 || date.daysInYear == 355,
                    "Year \(year): daysInYear=\(date.daysInYear), expected 354 or 355")
        }

        // All year gaps (Muharram 1 to next Muharram 1) must be exactly 354 or 355 days
        for year: Int32 in -50...200 {
            let muharram1 = IslamicTabularArithmetic.fixedFromTabular(year: year, month: 1, day: 1)
            let nextMuharram1 = IslamicTabularArithmetic.fixedFromTabular(year: year + 1, month: 1, day: 1)
            let gap = nextMuharram1.dayNumber - muharram1.dayNumber
            #expect(gap == 354 || gap == 355,
                    "Year \(year): gap to next year is \(gap), expected 354 or 355")
        }

        // In a 30-year cycle, there should be exactly 11 leap years (355-day years)
        var leapCount = 0
        for year: Int32 in 1...30 {
            let muharram1 = IslamicTabularArithmetic.fixedFromTabular(year: year, month: 1, day: 1)
            let nextMuharram1 = IslamicTabularArithmetic.fixedFromTabular(year: year + 1, month: 1, day: 1)
            let gap = nextMuharram1.dayNumber - muharram1.dayNumber
            if gap == 355 { leapCount += 1 }
        }
        #expect(leapCount == 11, "Expected 11 leap years in 30-year cycle, got \(leapCount)")
    }

    // MARK: - Epoch

    @Test("Islamic epoch is in Gregorian year 622")
    func epoch() {
        let epochYear = GregorianArithmetic.yearFromFixed(IslamicTabularArithmetic.epoch)
        #expect(epochYear == 622)
    }

    @Test("1 AH, Muharram 1 = epoch")
    func yearOneDayOne() throws {
        let date = try Date(year: 1, month: 1, day: 1, calendar: islamic)
        #expect(date.rataDie == IslamicTabularArithmetic.epoch)
    }
}

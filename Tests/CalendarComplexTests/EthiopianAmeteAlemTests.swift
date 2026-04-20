// Tests for EthiopianAmeteAlem — verifies that it produces identical
// RataDie arithmetic to the `Ethiopian` struct (they share the same
// underlying Coptic arithmetic) while differing only in era labelling
// and calendar identifier.

import Testing
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

@Suite("Ethiopian Amete Alem")
struct EthiopianAmeteAlemTests {

    let amete = EthiopianAmeteAlem()
    let mihret = Ethiopian()

    @Test("Calendar identifier is ethiopic-amete-alem")
    func identifier() {
        #expect(EthiopianAmeteAlem.calendarIdentifier == "ethiopic-amete-alem")
    }

    @Test("Round-trip: RD → Ethiopian Amete Alem → RD for 1900-01-01..2100-12-31")
    func roundTrip() {
        let startRD = GregorianArithmetic.fixedFromGregorian(year: 1900, month: 1, day: 1)
        let endRD = GregorianArithmetic.fixedFromGregorian(year: 2100, month: 12, day: 31)
        var failures = 0
        var rd = startRD
        while rd.dayNumber <= endRD.dayNumber {
            let inner = amete.fromRataDie(rd)
            let back = amete.toRataDie(inner)
            if back != rd { failures += 1 }
            rd = RataDie(rd.dayNumber + 1)
        }
        #expect(failures == 0, "Ethiopian Amete Alem: expected 0 round-trip failures, got \(failures)")
    }

    @Test("Shares arithmetic with Ethiopian (Amete Mihret)")
    func sharedArithmeticWithAmeteMihret() {
        // For any RataDie, the DateInner produced by both calendars must be
        // byte-for-byte identical: they share CopticArithmetic and
        // EthiopianDateInner. The only legitimate difference is the
        // surface era label, not the internal coordinates.
        let testRDs = [
            GregorianArithmetic.fixedFromGregorian(year: 1900, month: 1, day: 1),
            GregorianArithmetic.fixedFromGregorian(year: 2000, month: 6, day: 15),
            GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1),
            GregorianArithmetic.fixedFromGregorian(year: 2099, month: 12, day: 31),
        ]
        for rd in testRDs {
            let ameteInner = amete.fromRataDie(rd)
            let mihretInner = mihret.fromRataDie(rd)
            #expect(ameteInner.year == mihretInner.year)
            #expect(ameteInner.month == mihretInner.month)
            #expect(ameteInner.day == mihretInner.day)
        }
    }

    @Test("yearInfo surfaces mundi era with +5500 offset")
    func yearInfoEraAndOffset() {
        // 2024-01-01 Gregorian → Ethiopian Amete Mihret year 2016
        //                     → Ethiopian Amete Alem year 2016 + 5500 = 7516
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)
        let mihretInner = mihret.fromRataDie(rd)
        let ameteInner = amete.fromRataDie(rd)

        let mihretInfo = mihret.yearInfo(mihretInner)
        let ameteInfo = amete.yearInfo(ameteInner)

        if case let .era(mihretEra) = mihretInfo, case let .era(ameteEra) = ameteInfo {
            #expect(mihretEra.era == "incar")
            #expect(ameteEra.era == "mundi")
            #expect(ameteEra.year == mihretEra.year + 5500)
            // Extended year is shared (Amete Mihret coordinates).
            #expect(ameteEra.extendedYear == mihretEra.extendedYear)
        } else {
            Issue.record("yearInfo did not return .era")
        }
    }

    @Test("newDate accepts both 'mundi' and 'incar' eras")
    func newDateEras() throws {
        // Same internal year via both era names.
        let viaMundi = try amete.newDate(
            year: .eraYear(era: "mundi", year: 7516),
            month: .new(1),
            day: 1
        )
        let viaIncar = try amete.newDate(
            year: .eraYear(era: "incar", year: 2016),
            month: .new(1),
            day: 1
        )
        let viaExtended = try amete.newDate(
            year: .extended(2016),
            month: .new(1),
            day: 1
        )
        #expect(viaMundi.year == viaIncar.year)
        #expect(viaMundi.year == viaExtended.year)
        #expect(viaMundi.year == 2016)
    }

    @Test("Invalid era throws")
    func invalidEra() {
        #expect(throws: DateNewError.self) {
            _ = try amete.newDate(
                year: .eraYear(era: "bogus", year: 1000),
                month: .new(1),
                day: 1
            )
        }
    }

    @Test("Leap-year behavior matches Ethiopian")
    func leapYearMatch() {
        // Ethiopian leap rule: (year + 1) % 4 == 0 (Julian-style).
        // Extended year 2015 (AmeteMihret) = Year 7515 (AmeteAlem): (2015+1)%4 = 0 → leap.
        let leapExt: Int32 = 2015
        let nonLeapExt: Int32 = 2016

        let leapDate = EthiopianDateInner(year: leapExt, month: 1, day: 1)
        let nonLeapDate = EthiopianDateInner(year: nonLeapExt, month: 1, day: 1)

        #expect(amete.isInLeapYear(leapDate))
        #expect(!amete.isInLeapYear(nonLeapDate))
        #expect(amete.isInLeapYear(leapDate) == mihret.isInLeapYear(leapDate))
    }

    @Test("13 months per year")
    func monthsInYear() {
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)
        let inner = amete.fromRataDie(rd)
        #expect(amete.monthsInYear(inner) == 13)
    }
}

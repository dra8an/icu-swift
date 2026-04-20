// Tests for the Vietnamese lunisolar calendar.
//
// Vietnamese follows the Chinese-family tradition but calculates new-moon
// boundaries at Hanoi's UTC+7 local time. Neither ICU4C nor ICU4X
// implement a distinct Vietnamese calendar, so these tests verify
// internal consistency (round-trip, identifier, cyclic year) rather
// than parity against an external authoritative source.

import Testing
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarAstronomical

@Suite("Vietnamese Calendar")
struct VietnameseTests {

    let viet = Vietnamese()
    let chinese = Chinese()

    @Test("Calendar identifier is 'vietnamese'")
    func identifier() {
        #expect(Vietnamese.calendarIdentifier == "vietnamese")
    }

    @Test("Round-trip: RD → Vietnamese → RD for a 1000-day window in 2024")
    func roundTripBakedRange() {
        let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)
        var failures = 0
        for i: Int64 in 0..<1000 {
            let rd = RataDie(startRD.dayNumber + i)
            let inner = viet.fromRataDie(rd)
            let back = viet.toRataDie(inner)
            if back != rd { failures += 1 }
        }
        #expect(failures == 0, "Vietnamese: expected 0 round-trip failures, got \(failures)")
    }

    @Test("Round-trip spans a Vietnamese New Year")
    func roundTripAcrossNewYear() {
        // Chinese/Vietnamese New Year 2024 was Feb 10; Vietnamese ("Tết") may
        // differ by ±1 day from Chinese New Year in rare years due to the
        // Hanoi vs Beijing longitude difference. Still, internal round-trip
        // must hold.
        let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 20)
        let endRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 3, day: 5)
        var failures = 0
        var rd = startRD
        while rd.dayNumber <= endRD.dayNumber {
            let inner = viet.fromRataDie(rd)
            let back = viet.toRataDie(inner)
            if back != rd { failures += 1 }
            rd = RataDie(rd.dayNumber + 1)
        }
        #expect(failures == 0)
    }

    @Test("Vietnamese and Chinese agree on most days in the baked range")
    func agreementWithChinese() {
        // Expectation: both share the Beijing-calibrated baked table (see
        // design note in ChineseCalendar.swift), so in most cases their
        // output matches. The UTC-offset difference only matters when
        // astronomy is computed (outside the baked range or at Moshier
        // fallback). Inside 2024's baked range, expect 100% agreement.
        let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)
        var disagreements = 0
        for i: Int64 in 0..<365 {
            let rd = RataDie(startRD.dayNumber + i)
            let vi = viet.fromRataDie(rd)
            let ch = chinese.fromRataDie(rd)
            if vi.relatedIso != ch.relatedIso ||
                vi.ordinalMonth != ch.ordinalMonth ||
                vi.day != ch.day {
                disagreements += 1
            }
        }
        #expect(disagreements == 0, "Inside baked range, Vietnamese and Chinese share table data; got \(disagreements) disagreements")
    }

    @Test("Cyclic year numbering follows Chinese convention")
    func cyclicYear() {
        // 2024 is 甲辰 (Jiǎ Chén, Wood Dragon) — position 41 in the 60-year cycle.
        // Vietnamese follows the same cyclic system, so the cyclic position
        // should match Chinese for the same underlying date.
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 15)
        let vi = viet.fromRataDie(rd)
        let ch = chinese.fromRataDie(rd)
        let viInfo = viet.yearInfo(vi)
        let chInfo = chinese.yearInfo(ch)

        if case let .cyclic(viCyclic) = viInfo, case let .cyclic(chCyclic) = chInfo {
            #expect(viCyclic.yearOfCycle == chCyclic.yearOfCycle)
            #expect(viCyclic.relatedIso == chCyclic.relatedIso)
        } else {
            Issue.record("yearInfo did not return .cyclic")
        }
    }

    @Test("Month lengths are 29 or 30 days")
    func monthLengths() {
        // Lunar months are always 29 or 30 days. Verify via daysInMonth.
        let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 2, day: 10)
        var seen29 = false
        var seen30 = false
        for i: Int64 in 0..<90 {
            let rd = RataDie(startRD.dayNumber + i)
            let inner = viet.fromRataDie(rd)
            let len = viet.daysInMonth(inner)
            #expect(len == 29 || len == 30, "Unexpected month length: \(len)")
            if len == 29 { seen29 = true }
            if len == 30 { seen30 = true }
        }
        // Over 3 months we expect to see both lengths.
        #expect(seen29 && seen30)
    }
}

import Testing
@testable import CalendarCore

@Suite("RataDie")
struct RataDieTests {

    @Test("Unix epoch is R.D. 719163")
    func unixEpoch() {
        #expect(RataDie.unixEpoch.dayNumber == 719_163)
    }

    @Test("Round-trip through Unix epoch days")
    func unixRoundTrip() {
        for days: Int64 in [-100_000, -1, 0, 1, 1000, 19000, 100_000] {
            let rd = RataDie.fromUnixEpochDays(days)
            #expect(rd.toUnixEpochDays() == days)
        }
    }

    @Test("Arithmetic: addition and subtraction")
    func arithmetic() {
        let rd = RataDie(100)
        #expect((rd + 50).dayNumber == 150)
        #expect((rd - 30).dayNumber == 70)
        #expect(RataDie(200) - RataDie(100) == 100)
    }

    @Test("Comparable ordering")
    func ordering() {
        #expect(RataDie(1) < RataDie(2))
        #expect(RataDie(100) > RataDie(99))
        #expect(RataDie(0) == RataDie(0))
        #expect(RataDie(-5) < RataDie(5))
    }

    @Test("Hashable")
    func hashable() {
        let set: Set<RataDie> = [RataDie(1), RataDie(2), RataDie(1)]
        #expect(set.count == 2)
    }

    @Test("Description format")
    func description() {
        #expect(RataDie(42).description == "RD(42)")
        #expect(RataDie(-1).description == "RD(-1)")
    }
}

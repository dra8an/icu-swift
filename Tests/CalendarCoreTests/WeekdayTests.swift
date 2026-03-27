import Testing
@testable import CalendarCore

@Suite("Weekday")
struct WeekdayTests {

    @Test("R.D. 1 (Jan 1, year 1 ISO) is Monday")
    func rdOneIsMonday() {
        #expect(Weekday.from(rataDie: RataDie(1)) == .monday)
    }

    @Test("Known dates map to correct weekdays")
    func knownDates() {
        // 2024-01-01 is Monday. Its RD = 738886
        // Unix epoch 1970-01-01 is Thursday. RD = 719163
        #expect(Weekday.from(rataDie: RataDie(719_163)) == .thursday)

        // 2024-03-15 (Friday). RD = 738886 + 74 = 738960
        // Actually let's just test a sequence from R.D. 1
        let expected: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        for i in 0..<7 {
            #expect(Weekday.from(rataDie: RataDie(Int64(1 + i))) == expected[i])
        }
    }

    @Test("Weekday cycles correctly for negative RataDie")
    func negativeRd() {
        // R.D. 0 should be Sunday (day before Monday R.D. 1)
        #expect(Weekday.from(rataDie: RataDie(0)) == .sunday)
        // R.D. -1 should be Saturday
        #expect(Weekday.from(rataDie: RataDie(-1)) == .saturday)
        // R.D. -6 should be Monday
        #expect(Weekday.from(rataDie: RataDie(-6)) == .monday)
    }

    @Test("All 7 weekdays are in CaseIterable")
    func allCases() {
        #expect(Weekday.allCases.count == 7)
        #expect(Weekday.allCases.first == .monday)
        #expect(Weekday.allCases.last == .sunday)
    }
}

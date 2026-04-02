import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import AstronomicalEngine
@testable import CalendarAstronomical

@Suite("Chinese Performance")
struct ChinesePerfTests {

    let chinese = Chinese()

    @Test("Single year computation time — Chinese 2023")
    func singleYearCompute() {
        let start = Date(timeIntervalSinceReferenceDate: ProcessInfo.processInfo.systemUptime)
        let t0 = ProcessInfo.processInfo.systemUptime

        let rd = GregorianArithmetic.fixedFromGregorian(year: 2023, month: 6, day: 15)
        let date = Date<Chinese>.fromRataDie(rd, calendar: chinese)

        let t1 = ProcessInfo.processInfo.systemUptime
        let elapsed = (t1 - t0) * 1000  // milliseconds

        print("Single fromRataDie: \(elapsed) ms")
        print("Result: year=\(date.extendedYear) month=\(date.month.ordinal) day=\(date.dayOfMonth)")

        // Should complete in reasonable time
        #expect(date.extendedYear == 2023)
    }

    @Test("Three consecutive dates in same year")
    func threeDatesInSameYear() {
        let t0 = ProcessInfo.processInfo.systemUptime

        let rd1 = GregorianArithmetic.fixedFromGregorian(year: 2023, month: 3, day: 1)
        let d1 = Date<Chinese>.fromRataDie(rd1, calendar: chinese)

        let rd2 = GregorianArithmetic.fixedFromGregorian(year: 2023, month: 6, day: 15)
        let d2 = Date<Chinese>.fromRataDie(rd2, calendar: chinese)

        let rd3 = GregorianArithmetic.fixedFromGregorian(year: 2023, month: 9, day: 30)
        let d3 = Date<Chinese>.fromRataDie(rd3, calendar: chinese)

        let t1 = ProcessInfo.processInfo.systemUptime
        let elapsed = (t1 - t0) * 1000

        print("Three dates in 2023: \(elapsed) ms")

        #expect(d1.rataDie == rd1)
        #expect(d2.rataDie == rd2)
        #expect(d3.rataDie == rd3)
    }

    @Test("Round-trip 30 consecutive days")
    func roundTrip30Days() {
        let t0 = ProcessInfo.processInfo.systemUptime

        let startRd = GregorianArithmetic.fixedFromGregorian(year: 2023, month: 6, day: 1)
        for i: Int64 in 0..<30 {
            let rd = RataDie(startRd.dayNumber + i)
            let date = Date<Chinese>.fromRataDie(rd, calendar: chinese)
            #expect(date.rataDie == rd)
        }

        let t1 = ProcessInfo.processInfo.systemUptime
        let elapsed = (t1 - t0) * 1000

        print("30-day round-trip: \(elapsed) ms")
    }
}

// Baseline performance benchmarks for all calendars.
//
// Each test converts 1,000 consecutive Gregorian days (2024-01-01 to 2026-09-27)
// to the target calendar and back, measuring round-trip throughput.
// Run with: swift test -c release --filter "CalendarBenchmarks"

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple

@Suite("Calendar Benchmarks")
struct CalendarBenchmarks {

    // 1000 consecutive RataDie values starting from 2024-01-01
    static let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)
    static let count = 1000

    private func benchmark<C: CalendarProtocol>(
        _ calendar: C,
        label: String
    ) {
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<Self.count {
            let rd = Self.startRD + Int64(i)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            #expect(back == rd)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDate = elapsed / Double(Self.count) * 1_000_000 // microseconds
        print("  \(label): \(Self.count) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDate)) µs/date)")
    }

    // MARK: - Simple calendars

    @Test("Benchmark: ISO")
    func benchISO() { benchmark(Iso(), label: "ISO") }

    @Test("Benchmark: Gregorian")
    func benchGregorian() { benchmark(Gregorian(), label: "Gregorian") }

    @Test("Benchmark: Julian")
    func benchJulian() { benchmark(Julian(), label: "Julian") }

    @Test("Benchmark: Buddhist")
    func benchBuddhist() { benchmark(Buddhist(), label: "Buddhist") }

    @Test("Benchmark: ROC")
    func benchROC() { benchmark(Roc(), label: "ROC") }
}

// Baseline performance benchmarks for all calendars.
//
// Each test converts consecutive Gregorian days starting 2024-01-01 to the
// target calendar and back, measuring round-trip throughput.
//
// Methodology: see Docs-Foundation/05-PerformanceParityGate.md.
// Hard rule: no `#expect` in the timed loop (~1.5 µs overhead/call; dominates
// microbenchmarks). Use a checksum + one `#expect` after the timed region.
//
// Run with: swift test -c release --filter "CalendarBenchmarks"

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple

@Suite("Calendar Benchmarks")
struct CalendarBenchmarks {

    static let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)

    private func benchmark<C: CalendarProtocol>(
        _ calendar: C,
        label: String,
        iterations: Int = 100_000,
        warmup: Int = 100
    ) {
        var checksum: Int64 = 0
        // Warm-up (not timed)
        for i in 0..<warmup {
            let rd = Self.startRD + Int64(i)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber ^ Int64(date.dayOfMonth)
        }
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<iterations {
            let rd = Self.startRD + Int64(i % 1000)  // stays within 1000-day window
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber ^ Int64(date.dayOfMonth)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDateNs = elapsed / Double(iterations) * 1_000_000_000
        #expect(checksum != 0)
        print("  \(label): \(iterations) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDateNs)) ns/date)")
    }

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

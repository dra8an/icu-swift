import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

@Suite("Complex Calendar Benchmarks")
struct ComplexCalendarBenchmarks {

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
        let perDate = elapsed / Double(Self.count) * 1_000_000
        print("  \(label): \(Self.count) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDate)) µs/date)")
    }

    // Alternative benchmark WITHOUT #expect inside the hot loop.
    // Accumulates a checksum to prevent the optimizer from eliding work.
    // Uses 100k iterations + high-resolution timer for ns-precision.
    private func benchmarkNoExpect<C: CalendarProtocol>(
        _ calendar: C,
        label: String
    ) {
        let iters = 100_000
        var checksum: Int64 = 0
        // Warm-up pass
        for i in 0..<100 {
            let rd = Self.startRD + Int64(i)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber
        }
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<iters {
            let rd = Self.startRD + Int64(i)   // every iteration a unique date (spans ~274 years)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            // Fold fields from both directions so the compiler cannot collapse
            // the round-trip to identity and elide the work.
            checksum &+= back.dayNumber
            checksum ^= Int64(date.month.ordinal) &* 31 &+ Int64(date.dayOfMonth)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDate = elapsed / Double(iters) * 1_000_000_000  // nanoseconds
        print("  \(label) [no-expect, 100k]: \(String(format: "%.3f", elapsed * 1000)) ms total (\(String(format: "%.1f", perDate)) ns/date), checksum \(checksum)")
    }

    @Test("Benchmark: Coptic (no expect)")
    func benchCopticNoExpect() { benchmarkNoExpect(Coptic(), label: "Coptic") }

    @Test("Benchmark: Persian (no expect)")
    func benchPersianNoExpect() { benchmarkNoExpect(Persian(), label: "Persian") }

    @Test("Benchmark: Hebrew (no expect)")
    func benchHebrewNoExpect() { benchmarkNoExpect(Hebrew(), label: "Hebrew") }

    @Test("Benchmark: Hebrew")
    func benchHebrew() { benchmark(Hebrew(), label: "Hebrew") }

    @Test("Benchmark: Coptic")
    func benchCoptic() { benchmark(Coptic(), label: "Coptic") }

    @Test("Benchmark: Ethiopian")
    func benchEthiopian() { benchmark(Ethiopian(), label: "Ethiopian") }

    @Test("Benchmark: Persian")
    func benchPersian() { benchmark(Persian(), label: "Persian") }

    @Test("Benchmark: Indian")
    func benchIndian() { benchmark(Indian(), label: "Indian") }
}

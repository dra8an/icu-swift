// Performance benchmarks for CalendarComplex calendars.
//
// Methodology: see Docs-Foundation/05-PerformanceParityGate.md.
// Hard rule: no `#expect` in the timed loop (~1.5 µs overhead/call; dominates
// microbenchmarks). Use a checksum + one `#expect` after the timed region.

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

@Suite("Complex Calendar Benchmarks")
struct ComplexCalendarBenchmarks {

    static let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)

    private func benchmark<C: CalendarProtocol>(
        _ calendar: C,
        label: String,
        iterations: Int = 100_000,
        warmup: Int = 100
    ) {
        var checksum: Int64 = 0
        for i in 0..<warmup {
            let rd = Self.startRD + Int64(i)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber ^ Int64(date.dayOfMonth)
        }
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<iterations {
            let rd = Self.startRD + Int64(i % 1000)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber ^ Int64(date.dayOfMonth)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDateNs = elapsed / Double(iterations) * 1_000_000_000
        #expect(checksum != 0)
        print("  \(label): \(iterations) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDateNs)) ns/date)")
    }

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

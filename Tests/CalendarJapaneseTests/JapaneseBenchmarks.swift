// Performance benchmarks for CalendarJapanese.
//
// Methodology: see Docs-Foundation/05-PerformanceParityGate.md.
// Hard rule: no `#expect` in the timed loop (~1.5 µs overhead/call).

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarJapanese

@Suite("Japanese Calendar Benchmarks")
struct JapaneseBenchmarks {

    static let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)

    @Test("Benchmark: Japanese")
    func benchJapanese() {
        let calendar = Japanese()
        let iterations = 100_000
        let warmup = 100
        var checksum: Int64 = 0
        for i in 0..<warmup {
            let rd = Self.startRD + Int64(i)
            let date = Date<Japanese>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber ^ Int64(date.dayOfMonth)
        }
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<iterations {
            let rd = Self.startRD + Int64(i % 1000)
            let date = Date<Japanese>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber ^ Int64(date.dayOfMonth)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDateNs = elapsed / Double(iterations) * 1_000_000_000
        #expect(checksum != 0)
        print("  Japanese: \(iterations) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDateNs)) ns/date)")
    }
}

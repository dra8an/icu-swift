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

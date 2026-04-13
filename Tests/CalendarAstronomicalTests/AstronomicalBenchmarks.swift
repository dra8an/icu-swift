import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarAstronomical

@Suite("Astronomical Calendar Benchmarks")
struct AstronomicalBenchmarks {

    static let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)
    static let count = 1000

    private func benchmark<C: CalendarProtocol>(
        _ calendar: C,
        label: String,
        count: Int = AstronomicalBenchmarks.count
    ) {
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<count {
            let rd = Self.startRD + Int64(i)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            #expect(back == rd)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDate = elapsed / Double(count) * 1_000_000
        print("  \(label): \(count) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDate)) µs/date)")
    }

    @Test("Benchmark: Islamic Tabular")
    func benchIslamicTabular() { benchmark(IslamicTabular(), label: "Islamic Tabular") }

    @Test("Benchmark: Islamic Civil")
    func benchIslamicCivil() { benchmark(IslamicCivil(), label: "Islamic Civil") }

    @Test("Benchmark: Islamic Umm al-Qura")
    func benchIslamicUQ() { benchmark(IslamicUmmAlQura(), label: "Islamic UQ") }

    @Test("Benchmark: Chinese (baked range)")
    func benchChinese() { benchmark(Chinese(), label: "Chinese") }

    @Test("Benchmark: Dangi (baked range)")
    func benchDangi() { benchmark(Dangi(), label: "Dangi") }

    @Test("Benchmark: Chinese (outside baked, Moshier)")
    func benchChineseMoshier() {
        // 30 dates in 1850 — outside baked range, triggers Moshier
        let oldStart = GregorianArithmetic.fixedFromGregorian(year: 1850, month: 6, day: 1)
        let calendar = Chinese()
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<30 {
            let rd = oldStart + Int64(i)
            let date = Date<Chinese>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            #expect(back == rd)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDate = elapsed / Double(30) * 1_000_000
        print("  Chinese (Moshier): 30 round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDate)) µs/date)")
    }
}

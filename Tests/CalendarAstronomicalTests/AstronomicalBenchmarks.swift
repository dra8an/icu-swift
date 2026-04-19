// Performance benchmarks for CalendarAstronomical.
//
// Methodology: see Docs-Foundation/05-PerformanceParityGate.md.
// Hard rule: no `#expect` in the timed loop (~1.5 µs overhead/call).
//
// Default bench: 100k iterations with `i % 1000` date offset — stays within
// the baked range (1901–2099 for Chinese, 1300–1600 AH for Islamic UQ).
// Moshier-fallback benches use a smaller iteration count and a fixed start
// date outside the baked range.

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarAstronomical

@Suite("Astronomical Calendar Benchmarks")
struct AstronomicalBenchmarks {

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

    // MARK: - Moshier-fallback variants (outside baked range)

    private func benchmarkMoshier(
        start: RataDie,
        iterations: Int,
        label: String,
        warmup: Int = 10
    ) {
        let calendar = Chinese()
        var checksum: Int64 = 0
        for i in 0..<warmup {
            let rd = start + Int64(i % iterations)
            let date = Date<Chinese>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber ^ Int64(date.dayOfMonth)
        }
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<iterations {
            let rd = start + Int64(i)
            let date = Date<Chinese>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            checksum &+= back.dayNumber ^ Int64(date.dayOfMonth)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDateNs = elapsed / Double(iterations) * 1_000_000_000
        #expect(checksum != 0)
        print("  \(label): \(iterations) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDateNs)) ns/date)")
    }

    @Test("Benchmark: Chinese (outside baked, Moshier 1850, 30 days)")
    func benchChineseMoshier() {
        let start = GregorianArithmetic.fixedFromGregorian(year: 1850, month: 6, day: 1)
        benchmarkMoshier(start: start, iterations: 30, label: "Chinese (Moshier 1850, 30d)", warmup: 0)
    }

    @Test("Benchmark: Chinese (future, Moshier 2200, 30 days)")
    func benchChineseFutureMoshier() {
        let start = GregorianArithmetic.fixedFromGregorian(year: 2200, month: 1, day: 1)
        benchmarkMoshier(start: start, iterations: 30, label: "Chinese (Moshier 2200, 30d)", warmup: 0)
    }

    @Test("Benchmark: Chinese pre-baked (1000 days, stresses Moshier cache)")
    func benchChinesePreBaked1000() {
        let start = GregorianArithmetic.fixedFromGregorian(year: 1850, month: 1, day: 1)
        benchmarkMoshier(start: start, iterations: 1000, label: "Chinese (Moshier 1850, 1000d)", warmup: 10)
    }

    @Test("Benchmark: Chinese post-baked (1000 days, stresses Moshier cache)")
    func benchChinesePostBaked1000() {
        let start = GregorianArithmetic.fixedFromGregorian(year: 2200, month: 1, day: 1)
        benchmarkMoshier(start: start, iterations: 1000, label: "Chinese (Moshier 2200, 1000d)", warmup: 10)
    }
}

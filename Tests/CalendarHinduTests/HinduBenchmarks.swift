import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarHindu

@Suite("Hindu Calendar Benchmarks")
struct HinduBenchmarks {

    static let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)
    // Hindu calendars use Moshier — 100 dates is enough for a baseline
    static let count = 100

    private func benchmark<C: CalendarProtocol>(
        _ calendar: C,
        label: String,
        allowKshaya: Bool = false
    ) {
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<Self.count {
            let rd = Self.startRD + Int64(i)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            if allowKshaya {
                // Lunisolar: kshaya tithis can cause rd to map to previous day
                #expect(back == rd || back == rd - 1)
            } else {
                #expect(back == rd)
            }
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDate = elapsed / Double(Self.count) * 1_000_000
        print("  \(label): \(Self.count) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDate)) µs/date)")
    }

    @Test("Benchmark: Hindu Tamil (solar)")
    func benchTamil() { benchmark(HinduTamil(), label: "Tamil") }

    @Test("Benchmark: Hindu Bengali (solar)")
    func benchBengali() { benchmark(HinduBengali(), label: "Bengali") }

    @Test("Benchmark: Hindu Odia (solar)")
    func benchOdia() { benchmark(HinduOdia(), label: "Odia") }

    @Test("Benchmark: Hindu Malayalam (solar)")
    func benchMalayalam() { benchmark(HinduMalayalam(), label: "Malayalam") }

    @Test("Benchmark: Hindu Amanta (lunisolar)")
    func benchAmanta() { benchmark(HinduAmanta(), label: "Amanta", allowKshaya: true) }

    @Test("Benchmark: Hindu Purnimanta (lunisolar)")
    func benchPurnimanta() { benchmark(HinduPurnimanta(), label: "Purnimanta", allowKshaya: true) }
}

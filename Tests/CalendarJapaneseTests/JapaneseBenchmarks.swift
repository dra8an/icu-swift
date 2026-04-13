import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarJapanese

@Suite("Japanese Calendar Benchmarks")
struct JapaneseBenchmarks {

    static let startRD = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 1, day: 1)
    static let count = 1000

    @Test("Benchmark: Japanese")
    func benchJapanese() {
        let calendar = Japanese()
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<Self.count {
            let rd = Self.startRD + Int64(i)
            let date = Date<Japanese>.fromRataDie(rd, calendar: calendar)
            let back = calendar.toRataDie(date.inner)
            #expect(back == rd)
        }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perDate = elapsed / Double(Self.count) * 1_000_000
        print("  Japanese: \(Self.count) round-trips in \(String(format: "%.3f", elapsed * 1000)) ms (\(String(format: "%.1f", perDate)) µs/date)")
    }
}

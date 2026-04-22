// Sub-day adapter benchmarks — icu4swift's `CalendarFoundation` adapter
// vs Foundation's `Calendar` API (Gregorian, UTC).
//
// Three operations per side:
//   1. Extraction:  absolute Date → civil components
//   2. Assembly:    civil components → absolute Date
//   3. Round-trip:  Date → components → Date
//
// Bench discipline (per `CLAUDE.md` and `05-PerformanceParityGate.md`):
//   - No `#expect` in the timed loop. ~1.5 µs/call dominates microbenches.
//   - Warm-up pass excluded from timing.
//   - 100 k iterations, single checksum, one `#expect` after the timed region.
//   - Checksum depends on computed values to prevent dead-code elimination.
//
// Run with:
//   swift test -c release --filter FoundationAdapterBenchmarks

import Testing
import Foundation
import CalendarCore
import CalendarSimple
import CalendarFoundation

@Suite("Foundation Adapter Benchmarks")
struct FoundationAdapterBenchmarks {

    static let utc = TimeZone(identifier: "UTC")!

    /// Foundation `Calendar(.gregorian)` with UTC — the apples-to-apples
    /// comparator for our adapter.
    static let foundationCalendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = utc
        return c
    }()

    /// 2024-01-01 UTC = 8,400 days after Foundation's reference date.
    static let baseTI: TimeInterval = 8_400 * 86_400
    /// 2024-01-01 as a RataDie.
    static let baseRD: RataDie = RataDie(RataDie.foundationEpoch.dayNumber + 8_400)

    // MARK: - Bench helper

    private func runBench(
        _ label: String,
        iterations: Int = 100_000,
        warmup: Int = 100,
        _ body: (Int) -> Int64
    ) {
        var checksum: Int64 = 0
        for i in 0..<warmup { checksum &+= body(i) }
        let t0 = ProcessInfo.processInfo.systemUptime
        for i in 0..<iterations { checksum &+= body(i) }
        let elapsed = ProcessInfo.processInfo.systemUptime - t0
        let perOpNs = elapsed / Double(iterations) * 1_000_000_000
        #expect(checksum != 0)
        print("  \(label): \(iterations) ops in \(String(format: "%.3f", elapsed * 1000)) ms " +
              "(\(String(format: "%.1f", perOpNs)) ns/op)")
    }

    // MARK: - Extraction: absolute Date → civil components

    @Test("Extraction: icu4swift rataDieAndTimeOfDay")
    func extractIcu() {
        let utc = Self.utc
        runBench("icu4swift adapter extract") { i in
            let d = Date(timeIntervalSinceReferenceDate:
                Self.baseTI + Double(i % 1000) * 86_400 + 12.0 * 3_600)
            let (rd, sec, ns) = rataDieAndTimeOfDay(from: d, in: utc)
            return rd.dayNumber ^ Int64(sec) ^ Int64(ns)
        }
    }

    @Test("Extraction: Foundation dateComponents([y,m,d,h,m,s,ns])")
    func extractFoundation() {
        let cal = Self.foundationCalendar
        runBench("Foundation full extract") { i in
            let d = Date(timeIntervalSinceReferenceDate:
                Self.baseTI + Double(i % 1000) * 86_400 + 12.0 * 3_600)
            let dc = cal.dateComponents(
                [.year, .month, .day, .hour, .minute, .second, .nanosecond],
                from: d
            )
            return Int64(dc.year ?? 0)
                 ^ Int64(dc.month ?? 0)
                 ^ Int64(dc.day ?? 0)
                 ^ Int64(dc.hour ?? 0)
                 ^ Int64(dc.minute ?? 0)
                 ^ Int64(dc.second ?? 0)
                 ^ Int64(dc.nanosecond ?? 0)
        }
    }

    // MARK: - Assembly: civil components → absolute Date

    @Test("Assembly: icu4swift date(rataDie:h:m:s:ns:in:)")
    func assembleIcu() {
        let utc = Self.utc
        let baseRD = Self.baseRD
        runBench("icu4swift adapter assemble") { i in
            let rd = RataDie(baseRD.dayNumber + Int64(i % 1000))
            let d = date(
                rataDie: rd,
                hour: 12, minute: 30, second: 15, nanosecond: 123_456_789,
                in: utc
            )
            return Int64(d.timeIntervalSinceReferenceDate * 1e6)
        }
    }

    @Test("Assembly: Foundation date(from: DateComponents)")
    func assembleFoundation() {
        let cal = Self.foundationCalendar
        runBench("Foundation date(from:)") { i in
            // Walk forward in days across 2024 (~1000 distinct dates).
            let day = 1 + (i % 28)
            let month = 1 + ((i / 28) % 12)
            let year = 2024 + (i / (28 * 12))
            let dc = DateComponents(
                year: year, month: month, day: day,
                hour: 12, minute: 30, second: 15, nanosecond: 123_456_789
            )
            guard let d = cal.date(from: dc) else { return 0 }
            return Int64(d.timeIntervalSinceReferenceDate * 1e6)
        }
    }

    // MARK: - Round-trip: Date → components → Date

    @Test("Round-trip: icu4swift (Date → (RD, sec, ns) → Date)")
    func roundTripIcu() {
        let utc = Self.utc
        runBench("icu4swift round-trip") { i in
            let input = Date(timeIntervalSinceReferenceDate:
                Self.baseTI + Double(i % 1000) * 86_400 + 12.5 * 3_600)
            let (rd, sec, ns) = rataDieAndTimeOfDay(from: input, in: utc)
            let hour = sec / 3_600
            let minute = (sec % 3_600) / 60
            let second = sec % 60
            let output = date(
                rataDie: rd,
                hour: hour, minute: minute, second: second, nanosecond: ns,
                in: utc
            )
            return Int64(output.timeIntervalSinceReferenceDate * 1e6)
        }
    }

    @Test("Round-trip: Foundation (Date → DateComponents → Date)")
    func roundTripFoundation() {
        let cal = Self.foundationCalendar
        runBench("Foundation round-trip") { i in
            let input = Date(timeIntervalSinceReferenceDate:
                Self.baseTI + Double(i % 1000) * 86_400 + 12.5 * 3_600)
            let dc = cal.dateComponents(
                [.year, .month, .day, .hour, .minute, .second, .nanosecond],
                from: input
            )
            guard let output = cal.date(from: dc) else { return 0 }
            return Int64(output.timeIntervalSinceReferenceDate * 1e6)
        }
    }

    // MARK: - Apples-to-apples: both sides produce/consume Y/M/D/h/m/s/ns

    // Tracked in Docs-Foundation/AdapterPerfInvestigation.md § Slice 2.
    //
    // The benchmarks above compare operations of slightly different
    // shape: our adapter returns (RataDie, secondsInDay, nanosecond)
    // while Foundation returns (Y, M, D, h, m, s, ns). To compare
    // fairly we pair our adapter with `GregorianArithmetic.gregorianFromFixed`
    // / `.fixedFromGregorian` to produce / consume the same Y/M/D
    // representation.

    @Test("APPLES: Extraction — icu4swift adapter + Gregorian → (Y,M,D,h,m,s,ns)")
    func applesExtractIcu() {
        let utc = Self.utc
        runBench("icu4swift adapter+Gregorian extract") { i in
            let d = Date(timeIntervalSinceReferenceDate:
                Self.baseTI + Double(i % 1000) * 86_400 + 12.0 * 3_600)
            let (rd, sec, ns) = rataDieAndTimeOfDay(from: d, in: utc)
            let ymd = GregorianArithmetic.gregorianFromFixed(rd)
            let hour = sec / 3_600
            let minute = (sec % 3_600) / 60
            let second = sec % 60
            return Int64(ymd.year) &+ Int64(ymd.month) &+ Int64(ymd.day)
                 &+ Int64(hour) &+ Int64(minute) &+ Int64(second) &+ Int64(ns)
        }
    }

    @Test("APPLES: Extraction — Foundation dateComponents([Y,M,D,h,m,s,ns])")
    func applesExtractFoundation() {
        let cal = Self.foundationCalendar
        runBench("Foundation dateComponents extract") { i in
            let d = Date(timeIntervalSinceReferenceDate:
                Self.baseTI + Double(i % 1000) * 86_400 + 12.0 * 3_600)
            let dc = cal.dateComponents(
                [.year, .month, .day, .hour, .minute, .second, .nanosecond],
                from: d
            )
            return Int64(dc.year ?? 0) &+ Int64(dc.month ?? 0) &+ Int64(dc.day ?? 0)
                 &+ Int64(dc.hour ?? 0) &+ Int64(dc.minute ?? 0) &+ Int64(dc.second ?? 0)
                 &+ Int64(dc.nanosecond ?? 0)
        }
    }

    @Test("APPLES: Assembly — icu4swift Gregorian + adapter ← (Y,M,D,h,m,s,ns)")
    func applesAssembleIcu() {
        let utc = Self.utc
        runBench("icu4swift Gregorian+adapter assemble") { i in
            let day = UInt8(1 + (i % 28))
            let month = UInt8(1 + ((i / 28) % 12))
            let year = Int32(2024 + (i / (28 * 12)))
            let rd = GregorianArithmetic.fixedFromGregorian(year: year, month: month, day: day)
            let d = date(
                rataDie: rd,
                hour: 12, minute: 30, second: 15, nanosecond: 123_456_789,
                in: utc
            )
            return Int64(d.timeIntervalSinceReferenceDate * 1e6)
        }
    }

    @Test("APPLES: Assembly — Foundation date(from: DateComponents(Y,M,D,h,m,s,ns))")
    func applesAssembleFoundation() {
        let cal = Self.foundationCalendar
        runBench("Foundation date(from:) assemble") { i in
            let day = 1 + (i % 28)
            let month = 1 + ((i / 28) % 12)
            let year = 2024 + (i / (28 * 12))
            let dc = DateComponents(
                year: year, month: month, day: day,
                hour: 12, minute: 30, second: 15, nanosecond: 123_456_789
            )
            guard let d = cal.date(from: dc) else { return 0 }
            return Int64(d.timeIntervalSinceReferenceDate * 1e6)
        }
    }

    @Test("APPLES: Round-trip — icu4swift (Date → (Y,M,D,h,m,s,ns) → Date)")
    func applesRoundTripIcu() {
        let utc = Self.utc
        runBench("icu4swift full round-trip") { i in
            // Date → components
            let input = Date(timeIntervalSinceReferenceDate:
                Self.baseTI + Double(i % 1000) * 86_400 + 12.5 * 3_600)
            let (rd, sec, ns) = rataDieAndTimeOfDay(from: input, in: utc)
            let ymd = GregorianArithmetic.gregorianFromFixed(rd)
            let hour = sec / 3_600
            let minute = (sec % 3_600) / 60
            let second = sec % 60
            // components → Date
            let rdBack = GregorianArithmetic.fixedFromGregorian(
                year: ymd.year, month: ymd.month, day: ymd.day
            )
            let output = date(
                rataDie: rdBack,
                hour: hour, minute: minute, second: second, nanosecond: ns,
                in: utc
            )
            return Int64(output.timeIntervalSinceReferenceDate * 1e6)
        }
    }

    @Test("APPLES: Round-trip — Foundation (Date → DateComponents → Date)")
    func applesRoundTripFoundation() {
        let cal = Self.foundationCalendar
        runBench("Foundation full round-trip") { i in
            let input = Date(timeIntervalSinceReferenceDate:
                Self.baseTI + Double(i % 1000) * 86_400 + 12.5 * 3_600)
            let dc = cal.dateComponents(
                [.year, .month, .day, .hour, .minute, .second, .nanosecond],
                from: input
            )
            guard let output = cal.date(from: dc) else { return 0 }
            return Int64(output.timeIntervalSinceReferenceDate * 1e6)
        }
    }

}

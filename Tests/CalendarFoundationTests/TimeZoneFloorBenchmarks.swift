// Microbenchmarks isolating Foundation `TimeZone.secondsFromGMT(for:)` cost.
//
// Context: the sub-day adapter (`CalendarFoundation`) calls
// `tz.secondsFromGMT(for: date)` twice on the fast path (once early-probe,
// once late-probe to detect DST transitions). If that call itself costs
// ~1 µs, 2 calls account for most of our ~3 µs adapter assembly cost.
//
// This is Slice 1 of the 9b investigation tracked in
// `Docs-Foundation/AdapterPerfInvestigation.md`.
//
// We test three zone types:
//   - UTC — should be a constant-time no-op (offset is always 0).
//   - Fixed offset — `TimeZone(secondsFromGMT: 3600)` (UTC+1). Still no
//     transition table, still O(1).
//   - DST zone — `America/Los_Angeles`. Requires a transition-table
//     binary search inside Foundation; expected to cost more per call.
//
// Run: swift test -c release --filter TimeZoneFloorBenchmarks

import Testing
import Foundation

@Suite("TimeZone floor — cost of `secondsFromGMT(for:)`")
struct TimeZoneFloorBenchmarks {

    /// 2024-01-01 UTC = 8,400 days after Foundation's reference date.
    static let baseTI: TimeInterval = 8_400 * 86_400

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
        print("  \(label): \(iterations) calls in \(String(format: "%.3f", elapsed * 1000)) ms " +
              "(\(String(format: "%.1f", perOpNs)) ns/call)")
    }

    // MARK: - The three zones

    @Test("`secondsFromGMT(for:)` — UTC")
    func utc() {
        let tz = TimeZone(identifier: "UTC")!
        runBench("UTC") { i in
            let d = Date(timeIntervalSinceReferenceDate: Self.baseTI + Double(i % 1000) * 86_400)
            // UTC always returns 0 — mix in i so the checksum isn't all-zero.
            return Int64(tz.secondsFromGMT(for: d)) &+ Int64(i)
        }
    }

    @Test("`secondsFromGMT(for:)` — fixed offset (`secondsFromGMT:`)")
    func fixedOffset() {
        let tz = TimeZone(secondsFromGMT: 3_600)!  // UTC+1
        runBench("Fixed offset (UTC+1)") { i in
            let d = Date(timeIntervalSinceReferenceDate: Self.baseTI + Double(i % 1000) * 86_400)
            return Int64(tz.secondsFromGMT(for: d))
        }
    }

    @Test("`secondsFromGMT(for:)` — DST zone (`America/Los_Angeles`)")
    func dst() {
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        runBench("America/Los_Angeles") { i in
            let d = Date(timeIntervalSinceReferenceDate: Self.baseTI + Double(i % 1000) * 86_400)
            return Int64(tz.secondsFromGMT(for: d))
        }
    }

    // MARK: - Baseline — just Date init, no TZ call

    @Test("Baseline: `Date.init(timeIntervalSinceReferenceDate:)` only, no TZ")
    func dateInitOnly() {
        runBench("Date.init baseline") { i in
            let d = Date(timeIntervalSinceReferenceDate: Self.baseTI + Double(i % 1000) * 86_400)
            // Use the Date somehow to prevent dead-code elimination — convert its
            // raw TI back to Int64 microseconds.
            return Int64(d.timeIntervalSinceReferenceDate * 1e6)
        }
    }

    // MARK: - Two-probe pattern (matches our adapter's fast path)

    @Test("Two-probe pattern (our adapter's fast path) — UTC")
    func twoProbeUTC() {
        let tz = TimeZone(identifier: "UTC")!
        runBench("2-probe UTC") { i in
            let localTI = Self.baseTI + Double(i % 1000) * 86_400
            let early = Date(timeIntervalSinceReferenceDate: localTI - 86_400)
            let late = Date(timeIntervalSinceReferenceDate: localTI + 86_400)
            let o1 = tz.secondsFromGMT(for: early)
            let o2 = tz.secondsFromGMT(for: late)
            return Int64(o1) &+ Int64(o2) &+ Int64(i)
        }
    }

    @Test("Two-probe pattern (our adapter's fast path) — DST zone")
    func twoProbeDST() {
        let tz = TimeZone(identifier: "America/Los_Angeles")!
        runBench("2-probe America/Los_Angeles") { i in
            let localTI = Self.baseTI + Double(i % 1000) * 86_400
            let early = Date(timeIntervalSinceReferenceDate: localTI - 86_400)
            let late = Date(timeIntervalSinceReferenceDate: localTI + 86_400)
            let o1 = tz.secondsFromGMT(for: early)
            let o2 = tz.secondsFromGMT(for: late)
            return Int64(o1) &+ Int64(o2)
        }
    }

    // MARK: - Full adapter fast-path reconstruction

    /// Reconstruct what our `resolveLocalTI` fast path does — 2 probes,
    /// 2 Date inits, 1 comparison, 1 return Date init — without the
    /// overhead of calling through the adapter's `date(rataDie:...)` wrapper.
    @Test("Fast-path reconstruction — all of resolveLocalTI's fast-path work")
    func fastPathReconstructionUTC() {
        let tz = TimeZone(identifier: "UTC")!
        runBench("resolveLocalTI fast-path (inline)") { i in
            let localTI = Self.baseTI + Double(i % 1000) * 86_400
            let early = Date(timeIntervalSinceReferenceDate: localTI - 86_400)
            let late = Date(timeIntervalSinceReferenceDate: localTI + 86_400)
            let offsetBefore = tz.secondsFromGMT(for: early)
            let offsetAfter = tz.secondsFromGMT(for: late)
            if offsetBefore == offsetAfter {
                let d = Date(timeIntervalSinceReferenceDate: localTI - Double(offsetBefore))
                return Int64(d.timeIntervalSinceReferenceDate * 1e6)
            }
            return 0  // slow path — not exercised for UTC
        }
    }

    /// All of `date(rataDie:hour:minute:second:nanosecond:in:)` inline,
    /// UTC. Measures what the full adapter assembly function costs,
    /// minus any closure/checksum overhead from the existing harness.
    @Test("Full adapter assembly inline — UTC")
    func fullAssemblyInlineUTC() {
        let tz = TimeZone(identifier: "UTC")!
        runBench("full assembly inline UTC") { i in
            let rdDayNumber: Int64 = 730_486 &+ Int64(i % 1000)
            let daysFromEpoch = rdDayNumber - 730_486
            let totalSecLocal = daysFromEpoch * 86_400
                              &+ 12 * 3_600 &+ 30 * 60 &+ 15
            let localTI = Double(totalSecLocal) + 123_456_789.0 / 1_000_000_000.0
            let early = Date(timeIntervalSinceReferenceDate: localTI - 86_400)
            let late = Date(timeIntervalSinceReferenceDate: localTI + 86_400)
            let offsetBefore = tz.secondsFromGMT(for: early)
            let offsetAfter = tz.secondsFromGMT(for: late)
            if offsetBefore == offsetAfter {
                let d = Date(timeIntervalSinceReferenceDate: localTI - Double(offsetBefore))
                return Int64(d.timeIntervalSinceReferenceDate * 1e6)
            }
            return 0
        }
    }
}

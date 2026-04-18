// Foundation Chinese-calendar round-trip benchmark.
//
// Mirrors the icu4swift Chinese benchmarks:
//   - baked range: 1000 round-trips from 2024-01-01
//   - Moshier (outside baked): 30 round-trips from 1850-06-01
//
// Usage:
//   swiftc -O Scripts/FoundationChineseBench.swift -o /tmp/fbench
//   /tmp/fbench             # runs default (2024 baked range, 1000 iters)
//   /tmp/fbench 1850 30     # runs 30 iters starting 1850
//   /tmp/fbench 2200 30     # runs 30 iters starting 2200

import Foundation

// Parse args.
let args = CommandLine.arguments
let startYear = args.count > 1 ? Int(args[1]) ?? 2024 : 2024
let iterations = args.count > 2 ? Int(args[2]) ?? 1000 : 1000

let cal = Calendar(identifier: .chinese)

// Start date: <startYear>-01-01 00:00:00 UTC.
var startComponents = DateComponents()
startComponents.year = startYear
startComponents.month = startYear == 1850 ? 6 : 1
startComponents.day = 1
startComponents.timeZone = TimeZone(identifier: "UTC")

var gregorianCal = Calendar(identifier: .gregorian)
gregorianCal.timeZone = TimeZone(identifier: "UTC")!
guard let start = gregorianCal.date(from: startComponents) else {
    fatalError("Failed to construct start date")
}

// Pre-build the date list.
var dates: [Date] = []
dates.reserveCapacity(iterations)
for i in 0..<iterations {
    dates.append(start.addingTimeInterval(Double(i) * 86400.0))
}

let fields: Set<Calendar.Component> = [.era, .year, .month, .day, .isLeapMonth]

// Warm-up pass.
for d in dates {
    _ = cal.date(from: cal.dateComponents(fields, from: d))
}

// Timed loop.
let t0 = ProcessInfo.processInfo.systemUptime

var checksum: TimeInterval = 0
for d in dates {
    let dc = cal.dateComponents(fields, from: d)
    if let back = cal.date(from: dc) {
        checksum += back.timeIntervalSinceReferenceDate
    }
}

let elapsed = ProcessInfo.processInfo.systemUptime - t0
let perDate = elapsed / Double(iterations) * 1_000_000

print("Foundation Chinese (\(startYear), \(iterations) iters): \(String(format: "%.3f", elapsed * 1000)) ms total, \(String(format: "%.1f", perDate)) µs/date")
print("  checksum: \(checksum)")

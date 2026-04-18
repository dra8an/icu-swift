// Foundation calendar round-trip benchmark, parameterized by identifier.
//
// Mirrors icu4swift's generic benchmark: 1000 daily round-trips starting
// from a given Gregorian start date.
//
// Per iteration:
//   dateComponents([.era, .year, .month, .day, .isLeapMonth], from:)
//   date(from:)
//
// Compile:
//   swiftc -O Scripts/FoundationCalBench.swift -o /tmp/fcalbench
//
// Usage:
//   /tmp/fcalbench <identifier> [year] [iters]
//     identifier: chinese, hebrew, persian, islamic, ...
//     year:       Gregorian start year (default 2024)
//     iters:      iteration count (default 1000)
//
// Example:
//   /tmp/fcalbench hebrew
//   /tmp/fcalbench chinese 1850 30

import Foundation

let args = CommandLine.arguments
guard args.count >= 2 else {
    print("usage: \(args[0]) <identifier> [year] [iters]")
    exit(1)
}

let identifierStr = args[1]
let startYear = args.count > 2 ? Int(args[2]) ?? 2024 : 2024
let iterations = args.count > 3 ? Int(args[3]) ?? 1000 : 1000

let knownIdentifiers: [String: Calendar.Identifier] = [
    "gregorian": .gregorian,
    "iso8601": .iso8601,
    "buddhist": .buddhist,
    "chinese": .chinese,
    "coptic": .coptic,
    "ethiopicAmeteMihret": .ethiopicAmeteMihret,
    "ethiopicAmeteAlem": .ethiopicAmeteAlem,
    "hebrew": .hebrew,
    "indian": .indian,
    "islamic": .islamic,
    "islamicCivil": .islamicCivil,
    "islamicTabular": .islamicTabular,
    "islamicUmmAlQura": .islamicUmmAlQura,
    "japanese": .japanese,
    "persian": .persian,
    "republicOfChina": .republicOfChina,
    // Note: .dangi, .bangla, .tamil, .malayalam, .odia require macOS 26.0+.
    // Omitted here for broader compatibility.
]

guard let identifier = knownIdentifiers[identifierStr] else {
    print("unknown identifier: \(identifierStr)")
    print("supported: \(knownIdentifiers.keys.sorted().joined(separator: ", "))")
    exit(2)
}

let cal = Calendar(identifier: identifier)

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

print("Foundation \(identifierStr) (\(startYear), \(iterations) iters): \(String(format: "%.3f", elapsed * 1000)) ms total, \(String(format: "%.1f", perDate)) µs/date")
print("  checksum: \(checksum)")

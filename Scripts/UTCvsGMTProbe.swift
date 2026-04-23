// UTCvsGMTProbe — does UTC (ICU-backed) ever disagree with GMT (fixed)?
//
// Run: swift Scripts/UTCvsGMTProbe.swift
//
// Probes `TimeZone(identifier: "UTC").secondsFromGMT(for:)` and
// `TimeZone.gmt.secondsFromGMT(for:)` at a wide range of dates.
// Reports every disagreement.

import Foundation

let utcViaIdentifier = TimeZone(identifier: "UTC")!
let gmtSingleton = TimeZone.gmt

print("TimeZone(identifier: \"UTC\").identifier = \(utcViaIdentifier.identifier)")
print("TimeZone.gmt.identifier                 = \(gmtSingleton.identifier)")
print("Same identifier? \(utcViaIdentifier.identifier == gmtSingleton.identifier)")
print("Equal as values? \(utcViaIdentifier == gmtSingleton)")
print("")

// Probe dates across a very wide range
struct Probe { let label: String; let date: Date }

let probes: [Probe] = [
    .init(label: "year 1 (RD 1)",       date: Date(timeIntervalSinceReferenceDate: -63_082_281_600)), // ~0001-01-01
    .init(label: "1582-10-14 (pre-Gregorian switch)", date: Date(timeIntervalSinceReferenceDate: -13_196_188_800)),
    .init(label: "1800-01-01",          date: Date(timeIntervalSinceReferenceDate: -6_342_364_800)),
    .init(label: "1900-01-01",          date: Date(timeIntervalSinceReferenceDate: -3_187_296_000)),
    .init(label: "1970-01-01 (Unix)",   date: Date(timeIntervalSinceReferenceDate: -978_307_200)),
    .init(label: "1972-01-01 (UTC leap second era begins)", date: Date(timeIntervalSinceReferenceDate: -915_148_800)),
    .init(label: "2001-01-01 (ref)",    date: Date(timeIntervalSinceReferenceDate: 0)),
    .init(label: "2024-01-01",          date: Date(timeIntervalSinceReferenceDate: 725_760_000)),
    .init(label: "2100-01-01",          date: Date(timeIntervalSinceReferenceDate: 3_124_310_400)),
    .init(label: "year 3000",           date: Date(timeIntervalSinceReferenceDate: 31_525_776_000)),
    .init(label: "year 10000 approx",   date: Date(timeIntervalSinceReferenceDate: 252_423_360_000)),
]

var disagreements = 0
for p in probes {
    let utc = utcViaIdentifier.secondsFromGMT(for: p.date)
    let gmt = gmtSingleton.secondsFromGMT(for: p.date)
    let dstUtc = utcViaIdentifier.daylightSavingTimeOffset(for: p.date)
    let dstGmt = gmtSingleton.daylightSavingTimeOffset(for: p.date)
    let mark = (utc == gmt && dstUtc == dstGmt) ? "✓" : "✗"
    if utc != gmt || dstUtc != dstGmt { disagreements += 1 }
    print(String(format: "%@ %-45@  utc=(%d,%.1f)  gmt=(%d,%.1f)", mark, p.label, utc, dstUtc, gmt, dstGmt))
}

print("")
print("Disagreements: \(disagreements)")

// Also: does UTC ever report DST?
print("")
print("--- Does UTC report DST? Check `isDaylightSavingTime(for:)` ---")
for p in probes {
    let isDst = utcViaIdentifier.isDaylightSavingTime(for: p.date)
    if isDst {
        print("  ✗ UTC reports DST at \(p.label) !!!")
        disagreements += 1
    }
}
if disagreements == 0 {
    print("  (never — UTC never reports DST across all probed dates)")
}

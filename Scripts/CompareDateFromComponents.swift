// CompareDateFromComponents.swift
//
// Foundation's high-level Calendar API on the same input as
// Scripts/CompareDateFromComponents.c. Run both and compare to confirm what
// Foundation produces for sparse DateComponents missing month/time.
//
// Run:
//   swift Scripts/CompareDateFromComponents.swift

import Foundation

func pad(_ s: String, _ w: Int) -> String {
    s.count >= w ? s : s + String(repeating: " ", count: w - s.count)
}

func d2(_ n: Int) -> String { n < 10 ? "0\(n)" : "\(n)" }
func d3(_ n: Int) -> String { n < 10 ? "00\(n)" : (n < 100 ? "0\(n)" : "\(n)") }
func d4(_ n: Int) -> String {
    if n < 0 { return "-" + d4(-n) }
    if n < 10  { return "000\(n)" }
    if n < 100 { return "00\(n)" }
    if n < 1000 { return "0\(n)" }
    return "\(n)"
}

func describe(_ date: Date?) -> String {
    guard let date else { return "<nil>" }
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let dc = cal.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .nanosecond], from: date)
    let raw = Int64(date.timeIntervalSince1970 * 1000)
    let ms = (dc.nanosecond ?? 0) / 1_000_000
    return "\(d4(dc.year ?? -1))-\(d2(dc.month ?? -1))-\(d2(dc.day ?? -1)) "
         + "\(d2(dc.hour ?? -1)):\(d2(dc.minute ?? -1)):\(d2(dc.second ?? -1)).\(d3(ms)) "
         + "UTC (era=\(dc.era ?? -1))  raw=\(raw) ms"
}

func run(_ label: String, identifier: Calendar.Identifier, components: DateComponents) {
    var cal = Calendar(identifier: identifier)
    cal.timeZone = TimeZone(identifier: "UTC")!
    let result = cal.date(from: components)
    print("\(pad(label, 60)) \(describe(result))")
}

print("Input:  DateComponents(year: 2026, day: 21)  (TZ = UTC)")
print("Format: <yyyy-MM-dd HH:mm:ss.SSS UTC (era=N)  raw=<millis since epoch>>\n")

let dc = DateComponents(year: 2026, day: 21)
run("Foundation .gregorian (_CalendarGregorian path)", identifier: .gregorian, components: dc)
run("Foundation .hebrew    (_CalendarICU path)",       identifier: .hebrew,    components: dc)

print("")
print("Sanity:  fully specified DateComponents(year: 2026, month: 4, day: 21)")
let full = DateComponents(year: 2026, month: 4, day: 21)
run("Foundation .gregorian (full)",                    identifier: .gregorian, components: full)
run("Foundation .hebrew    (full)",                    identifier: .hebrew,    components: full)

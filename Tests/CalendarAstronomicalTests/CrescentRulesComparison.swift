// Compares the crescent rules in CrescentRules against officially announced month starts.
//
// Method: for every pair of consecutive official month starts P and S, the rule looks at the evening of
// day 29 (P + 28) and predicts a 29-day month (new month tomorrow) or a 30-day month. That prediction is
// compared with S - P, so one wrong decision cannot shift the months after it. The data come from
// crescent_official_dates.csv (collected 2026-11-05; see swift-foundation Docs/TEMP_Islamic_References).
//
// This is a measurement, not a regression test: it prints RESULT and MISS lines and only fails if the
// data cannot be read.

import Testing
import Foundation
import CalendarCore
import AstronomicalEngine
@testable import CalendarAstronomical

private struct OfficialMonth {
    let rule: String
    let scope: String
    let year: Int
    let month: Int
    let firstDay: Int64
    let text: String
    var index: Int { year * 12 + month - 1 }
}

private func fixedFromGregorian(_ y: Int, _ m: Int, _ d: Int) -> Int64 {
    let y1 = Int64(y - 1)
    let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
    var days = 365 * y1 + y1 / 4 - y1 / 100 + y1 / 400 + Int64((367 * m - 362) / 12)
    if m > 2 { days += leap ? -1 : -2 }
    return days + Int64(d)
}

private let csvPath = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("crescent_official_dates.csv").path

private func loadRows() -> [OfficialMonth] {
    guard let text = try? String(contentsOfFile: csvPath, encoding: .utf8) else { return [] }
    var rows: [OfficialMonth] = []
    for line in text.split(whereSeparator: \.isNewline).dropFirst() {
        let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard f.count >= 5, let y = Int(f[2]), let m = Int(f[3]) else { continue }
        let g = f[4].split(separator: "-").compactMap { Int($0) }
        guard g.count == 3 else { continue }
        rows.append(OfficialMonth(rule: f[0], scope: f[1], year: y, month: m, firstDay: fixedFromGregorian(g[0], g[1], g[2]), text: f[4]))
    }
    return rows
}

/// Consecutive official months (P, S) for one rule and scope, de-duplicated by Hijri month.
private func pairs(_ rows: [OfficialMonth], rule: String, scope: String) -> [(OfficialMonth, OfficialMonth)] {
    var byIndex: [Int: OfficialMonth] = [:]
    for r in rows where r.rule == rule && r.scope == scope { byIndex[r.index] = byIndex[r.index] ?? r }
    return byIndex.keys.sorted().compactMap { i in
        guard let p = byIndex[i], let s = byIndex[i + 1] else { return nil }
        return (p, s)
    }
}

private struct Tally {
    let name: String
    var total = 0
    var matched = 0
    var misses: [String] = []
    var anomalies: [String] = []

    mutating func record(_ p: OfficialMonth, _ s: OfficialMonth, predictsNewMonth: Bool, detail: @autoclosure () -> String) {
        let length = s.firstDay - p.firstDay
        guard length == 29 || length == 30 else {
            anomalies.append("AH \(s.year)-\(s.month) starts \(s.text) after a \(length)-day month")
            return
        }
        total += 1
        if (length == 29) == predictsNewMonth {
            matched += 1
        } else {
            misses.append("AH \(s.year)-\(s.month) official \(s.text) (\(length)d), rule says \(predictsNewMonth ? 29 : 30)d | \(detail())")
        }
    }

    func report() {
        let pct = total == 0 ? 0 : Double(matched) * 100 / Double(total)
        print("RESULT|\(name)|\(matched)/\(total)|\(String(format: "%.1f", pct))%|misses=\(misses.count)|anomalies=\(anomalies.count)")
        for m in misses { print("MISS|\(name)|\(m)") }
        for a in anomalies { print("ANOMALY|\(name)|\(a)") }
    }
}

private func describe(_ e: CrescentRules.Evening?) -> String {
    guard let e else { return "no sunset" }
    let lag = e.lagMinutes.map { String(format: "%.0f", $0) } ?? "-"
    let moonsetAfterConj = e.moonset.map { String(format: "%.1f", ($0 - e.conjunction) * 24) } ?? "-"
    return String(format: "age %.1fh, alt geo %.2f topo %.2f app %.2f, elong geo %.2f topo %.2f, lag %@ min, moonset-conj %@ h",
                  e.ageHours, e.altitudeGeocentric, e.altitudeTopocentric, e.altitudeApparent,
                  e.elongationGeocentric, e.elongationTopocentric, lag, moonsetAfterConj)
}

@Suite("Crescent rules vs official dates", .serialized)
struct CrescentRulesComparison {
    private static let rows = loadRows()

    @Test func dataLoaded() {
        #expect(Self.rows.count > 500, "read \(Self.rows.count) rows from \(csvPath)")
    }

    @Test func ummAlQura() {
        for variant in CrescentRules.UmmAlQuraVariant.allCases {
            var t = Tally(name: "UmmAlQura/\(variant.rawValue)")
            for (p, s) in pairs(Self.rows, rule: "ummalqura", scope: "ummalqura") {
                let day = RataDie(p.firstDay + 28)
                t.record(p, s, predictsNewMonth: CrescentRules.ummAlQura(day, variant),
                         detail: describe(CrescentRules.evening(day, at: CrescentRules.makkah)))
            }
            t.report()
        }
    }

    @Test func egypt() {
        let all = pairs(Self.rows, rule: "egypt", scope: "Egypt")
        let rules: [(String, (RataDie, Location) -> Bool)] = [
            ("fatwa filter 15h40", { CrescentRules.egyptFilter($0, at: $1) }),
            ("conj<sunset, lag>0", { CrescentRules.moonsetLag($0, at: $1, minimumLagMinutes: 0.001) }),
            ("conj<sunset, lag>=5min", { CrescentRules.moonsetLag($0, at: $1, minimumLagMinutes: 5) }),
        ]
        for (ruleName, rule) in rules {
        for (name, sites) in [("Cairo", [CrescentRules.cairo]), ("anyOf10Sites", CrescentRules.egyptSites)] {
            var main = Tally(name: "Egypt/\(ruleName)/\(name), Dhu al-Hijjah excluded")
            var dhuHijjah = Tally(name: "Egypt/\(ruleName)/\(name), Dhu al-Hijjah only (follows Saudi decision)")
            for (p, s) in all {
                let day = RataDie(p.firstDay + 28)
                let passes = sites.contains { rule(day, $0) }
                let detail = describe(CrescentRules.evening(day, at: CrescentRules.cairo))
                if s.month == 12 {
                    dhuHijjah.record(p, s, predictsNewMonth: passes, detail: detail)
                } else {
                    main.record(p, s, predictsNewMonth: passes, detail: detail)
                }
            }
            main.report()
            dhuHijjah.report()
        }
        }
    }

    @Test func mabims() {
        typealias A = CrescentRules.AltitudeKind
        typealias E = CrescentRules.ElongationKind
        // Malaysia: 1992 criterion before AH 1443; 2021 criterion from 1443; Tanjung Chinchin to 1443, Pulau Perak from 1444.
        for alt in A.allCases {
            for elong in E.allCases {
                var t = Tally(name: "MABIMS/Malaysia/official places+dates/alt \(alt.rawValue)/elong \(elong.rawValue)")
                var aceh = Tally(name: "MABIMS/Malaysia/our code: Banda Aceh, 2021 criterion always/alt \(alt.rawValue)/elong \(elong.rawValue)")
                for (p, s) in pairs(Self.rows, rule: "mabims", scope: "Malaysia") {
                    let day = RataDie(p.firstDay + 28)
                    let place = s.year >= 1444 ? CrescentRules.pulauPerak : CrescentRules.tanjungChinchin
                    let passes = s.year >= 1443
                        ? CrescentRules.mabims2021(day, at: place, altitude: alt, elongation: elong)
                        : CrescentRules.mabims1992(day, at: place, altitude: alt, elongation: elong)
                    t.record(p, s, predictsNewMonth: passes, detail: describe(CrescentRules.evening(day, at: place)))
                    aceh.record(p, s, predictsNewMonth: CrescentRules.mabims2021(day, at: CrescentRules.bandaAceh, altitude: alt, elongation: elong),
                                detail: describe(CrescentRules.evening(day, at: CrescentRules.bandaAceh)))
                }
                t.report()
                aceh.report()
            }
        }
        // Indonesia: 2021 criterion from Ramadan 1443 (topocentric altitude, geocentric elongation, PMA 1/2026), judged in
        // the far northwest (Banda Aceh). Singapore: Tuas, 2021 criterion from 1443.
        for alt in A.allCases {
            for elong in E.allCases {
                var id = Tally(name: "MABIMS/Indonesia/Banda Aceh/alt \(alt.rawValue)/elong \(elong.rawValue)")
                for (p, s) in pairs(Self.rows, rule: "mabims", scope: "Indonesia") {
                    let day = RataDie(p.firstDay + 28)
                    let isNew = s.year > 1443 || (s.year == 1443 && s.month >= 9)
                    let passes = isNew
                        ? CrescentRules.mabims2021(day, at: CrescentRules.bandaAceh, altitude: alt, elongation: elong)
                        : CrescentRules.mabims1992(day, at: CrescentRules.bandaAceh, altitude: alt, elongation: elong)
                    id.record(p, s, predictsNewMonth: passes, detail: describe(CrescentRules.evening(day, at: CrescentRules.bandaAceh)))
                }
                id.report()
                var sg = Tally(name: "MABIMS/Singapore/Tuas/alt \(alt.rawValue)/elong \(elong.rawValue)")
                for (p, s) in pairs(Self.rows, rule: "mabims", scope: "Singapore") {
                    let day = RataDie(p.firstDay + 28)
                    let passes = s.year >= 1443
                        ? CrescentRules.mabims2021(day, at: CrescentRules.tuas, altitude: alt, elongation: elong)
                        : CrescentRules.mabims1992(day, at: CrescentRules.tuas, altitude: alt, elongation: elong)
                    sg.record(p, s, predictsNewMonth: passes, detail: describe(CrescentRules.evening(day, at: CrescentRules.tuas)))
                }
                sg.report()
            }
        }
    }

    @Test func diyanet() {
        let monthPairs = pairs(Self.rows, rule: "diyanet", scope: "diyanet")
        let evaluated = monthPairs.map { (p, s) in (p, s, CrescentRules.diyanet(RataDie(p.firstDay + 28))) }
        print("INFO|Diyanet without grid (sunset line at 00 UTC, exact American west coast), \(evaluated.count) months")
        let variants: [(String, String, String)] = [
            ("none", "none", "no latitude limit"),
            ("60", "none", "60 limit on the main test only"),
            ("60", "60", "60 limit on the main test and the America exception"),
        ]
        for (mainLimit, americaLimit, label) in variants {
            for kind in ["geocentric", "topocentric", "apparent"] {
                var t = Tally(name: "Diyanet/\(label)/alt \(kind)/exception on")
                for (p, s, r) in evaluated {
                    let before = r.beforeMidnight["\(mainLimit)/\(kind)"] ?? false
                    let americas = (r.americas["\(americaLimit)/\(kind)"] ?? false) && r.conjunctionBeforeWellingtonDawn
                    t.record(p, s, predictsNewMonth: before || americas,
                             detail: "before 00 UTC \(before), Americas \(r.americas["\(americaLimit)/\(kind)"] ?? false), conj before Wellington dawn \(r.conjunctionBeforeWellingtonDawn)")
                }
                t.report()
            }
        }
    }

    /// Diyanet with apparent altitude: how much does the refraction scale matter? (round 3)
    @Test func diyanetRefractionScale() {
        let monthPairs = pairs(Self.rows, rule: "diyanet", scope: "diyanet")
        for scale in [0.5, 0.6, 0.7, 0.75, 0.8, 0.85, 0.9, 1.0, 1.1, 1.2] {
            var t = Tally(name: "Diyanet/apparent, refraction x\(scale)/no latitude limit")
            for (p, s) in monthPairs {
                let r = CrescentRules.diyanet(RataDie(p.firstDay + 28), refractionScale: scale)
                let before = r.beforeMidnight["none/apparent"] ?? false
                let americas = (r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn
                t.record(p, s, predictsNewMonth: before || americas, detail: "before 00 UTC \(before), Americas \(americas)")
            }
            t.report()
        }
    }

    /// Hypothesis (round 3): Diyanet starts the Hajj months on the Umm al-Qura (Saudi) date. Months listed in
    /// `followSaudi` are predicted with the Umm al-Qura rule at the Kaaba, the rest with Diyanet's own rule
    /// (apparent altitude, no latitude limit).
    @Test func diyanetHajjMonths() {
        let monthPairs = pairs(Self.rows, rule: "diyanet", scope: "diyanet")
        let own = monthPairs.map { (p, s) in (p, s, CrescentRules.diyanet(RataDie(p.firstDay + 28))) }
        let variants: [(String, Set<Int>)] = [("none", []), ("Zilhicce", [12]), ("Zilkade+Zilhicce", [11, 12]), ("Zilkade", [11]), ("all months", Set(1...12))]
        for (label, followSaudi) in variants {
            var t = Tally(name: "Diyanet/apparent/Umm al-Qura for: \(label)")
            for (p, s, r) in own {
                let day = RataDie(p.firstDay + 28)
                let diyanetSays = (r.beforeMidnight["none/apparent"] ?? false) || ((r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn)
                let saudiSays = CrescentRules.ummAlQura(day, .threeConditions)
                let predicts = followSaudi.contains(s.month) ? saudiSays : diyanetSays
                t.record(p, s, predictsNewMonth: predicts, detail: "Diyanet rule \(diyanetSays), Umm al-Qura rule \(saudiSays)")
            }
            t.report()
        }
        // Where do the two rules disagree on a Hajj month, and what did Diyanet announce?
        for (p, s, r) in own where s.month == 11 || s.month == 12 {
            let day = RataDie(p.firstDay + 28)
            let diyanetSays = (r.beforeMidnight["none/apparent"] ?? false) || ((r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn)
            let saudiSays = CrescentRules.ummAlQura(day, .threeConditions)
            if diyanetSays != saudiSays {
                print("HAJJ|AH \(s.year)-\(s.month) official \(s.text) (\(s.firstDay - p.firstDay)d)|Diyanet rule says new month: \(diyanetSays)|Umm al-Qura rule: \(saudiSays)")
            }
        }
    }

    /// Diyanet's whole published list AH 1318-1444 (DIYANET_HISTORY=<path to diyanet_1318_1444.txt>), scored with
    /// the 2016 rule and three readings of the 1978 rule, per period.
    @Test func diyanetHistory() {
        guard let path = ProcessInfo.processInfo.environment["DIYANET_HISTORY"], let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        var months: [OfficialMonth] = []
        for line in text.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":")
            guard parts.count == 2, let year = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }
                guard g.count == 3 else { continue }
                months.append(OfficialMonth(rule: "diyanet", scope: "history", year: year, month: k + 1, firstDay: fixedFromGregorian(g[0], g[1], g[2]), text: String(d)))
            }
        }
        let periods: [(String, ClosedRange<Int>)] = [("AH 1318-1398 (1900-1978)", 1318...1398), ("AH 1399-1437 (1978-2016)", 1399...1437), ("AH 1438-1444 (2016-2022)", 1438...1444)]
        let rules = ["2016", "1978-A anywhere", "1978-B before 00 UTC", "1978-C before 00 UTC or America"]
        var tallies: [String: Tally] = [:]
        var decade: [String: [Int: (Int, Int)]] = [:]
        for (p, s) in zip(months, months.dropFirst()) where s.index == p.index + 1 {
            let r = CrescentRules.diyanet(RataDie(p.firstDay + 28))
            let before = r.beforeMidnight["none/apparent"] ?? false
            let americas = r.americas["none/apparent"] ?? false
            let late = r.anywhereLate["none/apparent"] ?? false
            let says: [String: Bool] = [
                "2016": before || (americas && r.conjunctionBeforeWellingtonDawn),
                "1978-A anywhere": before || late,
                "1978-B before 00 UTC": before,
                "1978-C before 00 UTC or America": before || americas,
            ]
            guard let period = periods.first(where: { $0.1.contains(s.year) }) else { continue }
            let detail = "before 00 UTC \(before), America \(americas), anywhere late \(late), Wellington \(r.conjunctionBeforeWellingtonDawn)"
            for rule in rules {
                let key = "\(period.0)/\(rule)"
                var t = tallies[key] ?? Tally(name: "History/\(key)")
                t.record(p, s, predictsNewMonth: says[rule]!, detail: detail)
                tallies[key] = t
                let dec = s.year / 10 * 10
                var d = decade[rule] ?? [:]
                let hit = says[rule]! == (s.firstDay - p.firstDay == 29)
                d[dec] = ((d[dec]?.0 ?? 0) + (hit ? 1 : 0), (d[dec]?.1 ?? 0) + 1)
                decade[rule] = d
            }
        }
        for period in periods { for rule in rules { tallies["\(period.0)/\(rule)"]?.report() } }
        for rule in rules {
            let line = decade[rule]!.keys.sorted().map { "\($0)s \(decade[rule]![$0]!.0)/\(decade[rule]![$0]!.1)" }.joined(separator: "  ")
            print("DECADE|\(rule)|\(line)")
        }
    }

    @Test func malaysiaJupemStyle() {
        var options: [CrescentRules.MalaysiaOptions] = []
        for floor in [false, true] { for almanak in [false, true] { for apparentElongation in [false, true] {
            options.append(CrescentRules.MalaysiaOptions(floorToMinute: floor, almanakRefraction: almanak, elongationFromApparent: apparentElongation))
        } } }
        for blend in [0.25, 0.30, 0.35] { for almanak in [false, true] {
            options.append(CrescentRules.MalaysiaOptions(almanakRefraction: almanak, elongationBlend: blend))
        } }
        for o in options { do { do {
                    var t = Tally(name: "Malaysia JUPEM-style/\(o)")
                    for (p, s) in pairs(Self.rows, rule: "mabims", scope: "Malaysia") {
                        let day = RataDie(p.firstDay + 28)
                        let place = s.year >= 1444 ? CrescentRules.pulauPerak : CrescentRules.tanjungChinchin
                        let v = CrescentRules.malaysiaValues(day, at: place, o)
                        // JAKIM's 2021 takwim was still computed with the 1992 (2-3-8) criterion; the 2021 one appears from the 2022 edition.
                        let newCriterion = s.firstDay >= 738156 // 2022-01-01
                        t.record(p, s, predictsNewMonth: CrescentRules.malaysia(day, at: place, newCriterion: newCriterion, o),
                                 detail: v.map { String(format: "alt %.3f, elong %.3f, age %.1fh", $0.altitude, $0.elongation, $0.ageHours) } ?? "no sunset")
                    }
                    t.report()
                }
            }
        }
    }

    /// JUPEM data sheets (official, hosted by muftiwp.gov.my) print the elongation ("jarak lengkung") at given minutes.
    /// Compute every candidate definition at exactly those places and minutes to see which one JUPEM uses.
    @Test func jupemElongationCalibration() {
        func dms(_ d: Double, _ m: Double, _ s: Double) -> Double { d + m / 60 + s / 3600 }
        let rows: [(String, Location, Double, Double)] = [
            // name, place, UT moment (RD + fraction), printed elongation
            ("KL 2020-11-15 18:57", Location(latitude: dms(3, 9, 10), longitude: dms(101, 42, 13), elevation: 0, utcOffset: 8.0 / 24), 737744 + (10 * 60 + 57) / 1440.0, dms(2, 48, 41)),
            ("PICC 2022-11-24 18:59", Location(latitude: dms(2, 53, 40), longitude: dms(101, 40, 36), elevation: 0, utcOffset: 8.0 / 24), 738483 + (10 * 60 + 59) / 1440.0, dms(6, 6, 28)),
            ("Labuan 2026-11-09 18:01", Location(latitude: dms(5, 16, 43), longitude: dms(115, 10, 25), elevation: 40, utcOffset: 8.0 / 24), 739929 + (10 * 60 + 1) / 1440.0, 5.316),
        ]
        for (name, loc, ut, printed) in rows {
            let t = Moment(ut)
            let moon = Astronomical.lunarHorizontal(t, location: loc)
            let sun = Astronomical.solarHorizontal(t, location: loc)
            let topo = moon.altitude - Astronomical.lunarParallax(altitude: moon.altitude, moment: t)
            func sep(_ h1: Double, _ a1: Double, _ h2: Double, _ a2: Double) -> Double {
                let r = Double.pi / 180
                return acos(min(1, max(-1, sin(h1 * r) * sin(h2 * r) + cos(h1 * r) * cos(h2 * r) * cos((a1 - a2) * r)))) / r
            }
            let geo = Astronomical.geocentricElongation(t)
            let airless = sep(topo, moon.azimuth, sun.altitude, sun.azimuth)
            let apparent = sep(topo + Astronomical.refraction(atTrueAltitude: topo), moon.azimuth, sun.altitude + Astronomical.refraction(atTrueAltitude: sun.altitude), sun.azimuth)
            let geoHorizontal = sep(moon.altitude, moon.azimuth, sun.altitude, sun.azimuth)
            print(String(format: "JUPEM|%@|printed %.3f|geocentric %.3f|geo-horizontal %.3f|topo airless %.3f|topo apparent %.3f|moon geo alt %.3f topo %.3f|sun alt %.3f",
                         name, printed, geo, geoHorizontal, airless, apparent, moon.altitude, topo, sun.altitude))
        }
    }
}

// TEMPORARY probe (2026-11-06): Diyanet calibration against its official maps and Ramadan 1447 diagrams.
// Run: swift test --filter CrescentDiyanetProbe

import Testing
import Foundation
import CalendarCore
@testable import AstronomicalEngine
@testable import CalendarAstronomical

private func rd(_ y: Int, _ m: Int, _ d: Int) -> Int64 {
    let y1 = Int64(y - 1)
    let leap = (y % 4 == 0 && y % 100 != 0) || y % 400 == 0
    var days = 365 * y1 + y1 / 4 - y1 / 100 + y1 / 400 + Int64((367 * m - 362) / 12)
    if m > 2 { days += leap ? -1 : -2 }
    return days + Int64(d)
}

/// "dd hh:mm:ss" relative to the evening's UTC date.
private func utc(_ t: Moment, base: Int64) -> String {
    let x = t.inner - Double(base)
    let day = Int(floor(x))
    let s = Int(((x - floor(x)) * 86400).rounded())
    return String(format: "+%dd %02d:%02d:%02d", day, s / 3600, (s % 3600) / 60, s % 60)
}

private struct Point {
    var t: Moment
    var alt: [String: Double]
    var elong: [String: Double]
}

private let altKinds = ["geo", "topo", "apparent", "geo+refr"]
private let elongKinds = ["geo", "topo"]
private let sunsetKinds = ["limb-50", "centre0"]

private func sunset(_ day: RataDie, _ loc: Location, _ kind: String) -> Moment? {
    guard let s = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc) else { return nil }
    if kind == "limb-50" { return s }
    return Astronomical.crossing(from: s - 30.0 / 1440, to: s + 5.0 / 1440, target: 0, rising: false) {
        Astronomical.solarHorizontal($0, location: loc).altitude
    }
}

private func evaluate(_ t: Moment, _ loc: Location) -> Point {
    let geo = Astronomical.lunarHorizontal(t, location: loc).altitude
    let topo = geo - Astronomical.lunarParallax(altitude: geo, moment: t)
    return Point(t: t,
                 alt: ["geo": geo, "topo": topo, "apparent": topo + Astronomical.refraction(atTrueAltitude: topo),
                       "geo+refr": geo + Astronomical.refraction(atTrueAltitude: geo)],
                 elong: ["geo": Astronomical.geocentricElongation(t), "topo": Astronomical.topocentricElongation(t, location: loc)])
}

@Suite struct CrescentDiyanetProbe {
    // Evening (UTC date), Diyanet conjunction, Diyanet first visibility (as offsets from the evening date).
    static let evenings: [(Int, Int, Int, String, String)] = [
        (2021, 6, 10, "+0d 10:53", "+1d 04:00"),
        (2023, 5, 19, "+0d 15:53", "+1d 06:54"),
        (2026, 2, 17, "+0d 12:01", "+1d 03:42"),
        (2030, 5, 2, "+0d 14:12", "+1d 07:08"),
        (2032, 3, 11, "+0d 16:25", "+1d 05:00"),
        (2033, 5, 28, "+0d 11:37", "+1d 00:03"),
    ]

    @Test func firstVisibility() {
        for (y, m, d, diyConj, diyFirst) in Self.evenings {
            let base = rd(y, m, d)
            let conj = Astronomical.newMoonAtOrAfter(Moment(Double(base)))
            print("CONJ|\(y)-\(m)-\(d)|ours \(utc(conj, base: base))|Diyanet \(diyConj)")
            // For each sunset kind and latitude: scan the evening's sunsets east to west (then the next day's),
            // record the first passing point per (alt, elong) convention, then bisect in longitude.
            for sk in sunsetKinds {
                var best: [String: (Moment, Double, Double)] = [:]      // no latitude limit
                var best60: [String: (Moment, Double, Double)] = [:]    // |lat| <= 60
                for lat in stride(from: -70.0, through: 70.0, by: 0.5) {
                    var pending = Set(altKinds.flatMap { a in elongKinds.map { "\(a)/\($0)" } })
                    var previous: (RataDie, Double)? = nil
                    outer: for offset in [Int64(0), 1] {
                        let day = RataDie(base + offset)
                        for lon in stride(from: 180.0, through: -180.0, by: -1) {
                            let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                            guard let s = sunset(day, loc, sk) else { continue }
                            if s.inner < conj.inner + 0.3 { previous = (day, lon); continue }
                            let p = evaluate(s, loc)
                            for key in pending {
                                let parts = key.split(separator: "/").map(String.init)
                                guard p.alt[parts[0]]! >= 5 && p.elong[parts[1]]! >= 8 else { continue }
                                pending.remove(key)
                                // Bisect between the previous (failing) longitude and this one, same day only.
                                var found = (s, lon)
                                if let (pd, plon) = previous, pd == day {
                                    var lo = lon, hi = plon   // lo passes, hi fails (hi is further east)
                                    for _ in 0..<20 {
                                        let mid = (lo + hi) / 2
                                        let l2 = Location(latitude: lat, longitude: mid, elevation: 0, utcOffset: 0)
                                        guard let s2 = sunset(day, l2, sk) else { break }
                                        let q = evaluate(s2, l2)
                                        if q.alt[parts[0]]! >= 5 && q.elong[parts[1]]! >= 8 { lo = mid; found = (s2, mid) } else { hi = mid }
                                    }
                                }
                                if best[key] == nil || found.0 < best[key]!.0 { best[key] = (found.0, lat, found.1) }
                                if abs(lat) <= 60, best60[key] == nil || found.0 < best60[key]!.0 { best60[key] = (found.0, lat, found.1) }
                            }
                            if pending.isEmpty { break outer }
                            previous = (day, lon)
                        }
                    }
                }
                for a in altKinds { for e in elongKinds {
                    let key = "\(a)/\(e)"
                    let f = { (b: (Moment, Double, Double)?) in b.map { String(format: "%@ at %.1f,%.2f", utc($0.0, base: base), $0.1, $0.2) } ?? "none" }
                    print("FIRST|\(y)-\(m)-\(d)|Diyanet \(diyFirst)|sunset \(sk)|alt \(a) elong \(e)|nolimit \(f(best[key]))|lat60 \(f(best60[key]))")
                } }
            }
        }
    }

    @Test func ramadan1447Diagrams() {
        let places = [("Ankara", Location(latitude: 39.9334, longitude: 32.8597, elevation: 0, utcOffset: 0)),
                      ("Mecca", Location(latitude: 21.4225, longitude: 39.8262, elevation: 0, utcOffset: 0))]
        for d in 17...19 {
            let base = rd(2026, 2, d)
            for (name, loc) in places {
                for sk in sunsetKinds {
                    guard let s = sunset(RataDie(base), loc, sk) else { continue }
                    let p = evaluate(s, loc)
                    let set = Astronomical.moonsetUT(after: s - 0.1, location: loc)
                    let geoSet = Astronomical.crossing(from: s - 0.1, to: s + 0.3, target: 0, rising: false) {
                        Astronomical.lunarHorizontal($0, location: loc).altitude
                    }
                    let sunCentre = sunset(RataDie(base), loc, "centre0")!
                    let fmt = { (x: Double) -> String in
                        let sign = x < 0 ? "-" : ""; let a = abs(x)
                        return String(format: "%@%02d°%02d′", sign, Int(a), Int(((a - floor(a)) * 60).rounded()))
                    }
                    let tStd = set.map { String(format: "%.1f", ($0.inner - s.inner) * 1440) } ?? "-"
                    let tGeo = geoSet.map { String(format: "%.1f", ($0.inner - sunCentre.inner) * 1440) } ?? "-"
                    print("DIAGRAM|2026-02-\(d)|\(name)|sunset \(sk) \(utc(s, base: base))|alt geo \(fmt(p.alt["geo"]!)) topo \(fmt(p.alt["topo"]!)) apparent \(fmt(p.alt["apparent"]!)) geo+refr \(fmt(p.alt["geo+refr"]!))|elong geo \(fmt(p.elong["geo"]!)) topo \(fmt(p.elong["topo"]!))|T moonset(limb,topo)-sunset \(tStd) min, geo centre0 - sun centre0 \(tGeo) min")
                }
            }
        }
    }
    @Test func coastline() {
        guard let path = ProcessInfo.processInfo.environment["COAST_CSV"], let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let coast = text.split(whereSeparator: \.isNewline).compactMap { line -> (Double, Double)? in
            let f = line.split(separator: ",").compactMap { Double($0) }
            return f.count == 2 ? (f[0], f[1]) : nil
        }
        for (y, m, d, _, _) in Self.evenings {
            let base = rd(y, m, d)
            let day = RataDie(base)
            let midnight = Moment(Double(base) + 1)
            var bestTopo: (Double, String)? = nil, bestApp: (Double, String)? = nil
            var minK: (Double, String)? = nil   // smallest refraction factor that lets a point pass (elongation >= 8)
            for (lat, lon) in coast {
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                guard let s = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), s >= midnight else { continue }
                let p = evaluate(s, loc)
                let topo = p.alt["topo"]!, app = p.alt["apparent"]!, e = p.elong["geo"]!
                let desc = String(format: "%.2f,%.4f sunset %@ topo %.3f apparent %.3f geoElong %.3f", lat, lon, utc(s, base: base), topo, app, e)
                let mt = min(topo - 5, e - 8), ma = min(app - 5, e - 8)
                if bestTopo == nil || mt > bestTopo!.0 { bestTopo = (mt, desc) }
                if bestApp == nil || ma > bestApp!.0 { bestApp = (ma, desc) }
                if e >= 8 {
                    let k = (5 - topo) / (app - topo)
                    if minK == nil || k < minK!.0 { minK = (k, desc) }
                }
            }
            print(String(format: "COAST|%d-%d-%d|topo best margin %+.4f|", y, m, d, bestTopo?.0 ?? -99) + (bestTopo?.1 ?? ""))
            print(String(format: "COAST|%d-%d-%d|apparent best margin %+.4f|", y, m, d, bestApp?.0 ?? -99) + (bestApp?.1 ?? ""))
            print(String(format: "COAST|%d-%d-%d|min refraction factor to pass %.3f|", y, m, d, minK?.0 ?? 99) + (minK?.1 ?? ""))
        }
    }
    /// Every Diyanet month decision where the main test (before 00 UTC, 60 limit, topocentric) fails: the America
    /// exception decides. Prints the official decision, Wellington dawn margins and the exact-coast margins.
    @Test func exceptionMonths() {
        guard let path = ProcessInfo.processInfo.environment["COAST_CSV"], let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let coast = text.split(whereSeparator: \.isNewline).compactMap { line -> (Double, Double)? in
            let f = line.split(separator: ",").compactMap { Double($0) }
            return f.count == 2 ? (f[0], f[1]) : nil
        }
        let csv = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("crescent_official_dates.csv").path
        guard let data = try? String(contentsOfFile: csv, encoding: .utf8) else { return }
        var starts: [Int: (Int64, String)] = [:]
        for line in data.split(whereSeparator: \.isNewline).dropFirst() {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", f[1] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }
            guard g.count == 3 else { continue }
            starts[y * 12 + m - 1] = starts[y * 12 + m - 1] ?? (rd(g[0], g[1], g[2]), f[4])
        }
        for i in starts.keys.sorted() {
            guard let (p, pText) = starts[i], let (s, sText) = starts[i + 1] else { continue }
            let base = p + 28
            let r = CrescentRules.diyanet(RataDie(base))
            if r.beforeMidnight["60/topocentric"] ?? false { continue }
            let midnight = Moment(Double(base) + 1)
            let conj = Astronomical.newMoonBefore(midnight)
            var bestTopo = -99.0, bestApp = -99.0, where_ = ""
            for (lat, lon) in coast {
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: RataDie(base), location: loc), ss >= midnight else { continue }
                let q = evaluate(ss, loc)
                let mt = min(q.alt["topo"]! - 5, q.elong["geo"]! - 8), ma = min(q.alt["apparent"]! - 5, q.elong["geo"]! - 8)
                if mt > bestTopo { bestTopo = mt; where_ = String(format: "%.2f,%.2f %@", lat, lon, utc(ss, base: base)) }
                bestApp = max(bestApp, ma)
            }
            if bestApp < -0.3 { continue }
            var dawns: [String] = []
            for dep in [18.0, 19.0] {
                if let dawn = Astronomical.dawnUT(after: Moment(Double(base) + 0.25), location: CrescentRules.wellington, depression: dep) {
                    dawns.append(String(format: "dawn%.0f %@ (conj %+.0f min)", dep, utc(dawn, base: base), (dawn.inner - conj.inner) * 1440))
                }
            }
            let started = s - p == 29
            print(String(format: "EXC|month from %@ (+28 evening)|next %@ %@|conj %@|%@|coast topo %+.3f apparent %+.3f at %@", pText, sText, started ? "STARTED(29d)" : "no(30d)", utc(conj, base: base), dawns.joined(separator: " "), bestTopo, bestApp, where_))
        }
    }
}

/// Where did the old 3-degree grid find a pass above 60 degrees (AH 1441-2 and 1442-3), and what does the
/// sunset line at 00 UTC give on the same latitudes?
@Suite struct CrescentDiyanetHighLatitude {
    @Test func gridVersusSunsetLine() {
        for (y, m, d) in [(2019, 9, 28), (2020, 10, 16)] {
            let base = rd(y, m, d)
            let day = RataDie(base)
            let midnight = Moment(Double(base) + 1)
            print("HIGH|\(y)-\(m)-\(d)|geoElong at 00 UTC \(String(format: "%.3f", Astronomical.geocentricElongation(midnight)))")
            for lat in stride(from: -88.0, through: 88.0, by: 1) where abs(lat) > 55 {
                var bestGrid: (Double, String)? = nil
                for lon in stride(from: -180.0, to: 180.0, by: 1) {
                    let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                    guard let s = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), s < midnight else { continue }
                    let p = evaluate(s, loc)
                    let margin = min(p.alt["topo"]! - 5, p.elong["geo"]! - 8)
                    if bestGrid == nil || margin > bestGrid!.0 {
                        bestGrid = (margin, String(format: "lon %.0f sunset %@ topo %.3f geoElong %.3f", lon, utc(s, base: base), p.alt["topo"]!, p.elong["geo"]!))
                    }
                }
                var line = "none"
                if let lon = CrescentRules.sunsetLongitude(at: midnight, latitude: lat) {
                    let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                    let p = evaluate(midnight, loc)
                    let check = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc).map { utc($0, base: base) } ?? "nil"
                    line = String(format: "lon %.2f (sunsetUT there %@) topo %.3f geoElong %.3f margin %+.3f", lon, check, p.alt["topo"]!, p.elong["geo"]!, min(p.alt["topo"]! - 5, p.elong["geo"]! - 8))
                }
                if let g = bestGrid, g.0 > -0.5 { print(String(format: "HIGH|%d-%d-%d|lat %.0f|grid best %+.3f %@|line %@", y, m, d, lat, g.0, g.1, line)) }
            }
        }
    }
}

/// Which New Zealand place (and dawn angle) separates the America-exception months? Conjunction minus dawn, minutes.
@Suite struct CrescentDiyanetNewZealand {
    @Test func dawnPlaces() {
        let places: [(String, Double, Double)] = [
            ("Wellington", -41.2865, 174.7762), ("Auckland", -36.8485, 174.7633), ("Gisborne", -38.6623, 178.0176),
            ("East Cape", -37.6886, 178.5480), ("Chatham Is", -43.9535, -176.5597), ("Cape Reinga", -34.4285, 172.6806),
        ]
        // Evenings where the exception could decide and the conjunction is within a few hours of NZ dawn.
        let evenings: [(Int, Int, Int, String)] = [
            (2031, 2, 21, "STARTED"), (2032, 3, 11, "no"), (2030, 5, 2, "STARTED"), (2023, 5, 19, "no"),
            (2021, 8, 8, "STARTED"), (2029, 5, 13, "STARTED"), (2026, 2, 17, "no(astro)"), (2022, 7, 28, "no(astro)"),
        ]
        for (y, m, d, decision) in evenings {
            let base = rd(y, m, d)
            let conj = Astronomical.newMoonBefore(Moment(Double(base) + 1))
            var parts: [String] = []
            for (name, lat, lon) in places {
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                for dep in [18.0] {
                    if let dawn = Astronomical.dawnUT(after: Moment(Double(base) + 0.25), location: loc, depression: dep) {
                        parts.append(String(format: "%@ %+.0f", name, (dawn.inner - conj.inner) * 1440))
                    }
                }
            }
            print("NZ|\(y)-\(m)-\(d) \(decision)|conj \(utc(conj, base: base))|dawn18 minus conj: " + parts.joined(separator: ", "))
        }
    }
}

/// Every Diyanet map header (conjunction, first visibility, read by OCR) against our values.
/// Run with MAPS_CSV=<voted.csv> (columns file,kind,value,votes,readings; value "YYYY-MM-DD HH:MM" UTC).
@Suite struct CrescentDiyanetMaps {
    static func moment(_ s: String) -> Moment? {
        let p = s.split(whereSeparator: { $0 == "-" || $0 == " " || $0 == ":" }).compactMap { Int($0) }
        guard p.count == 5 else { return nil }
        return Moment(Double(rd(p[0], p[1], p[2])) + (Double(p[3]) * 60 + Double(p[4])) / 1440)
    }

    /// Earliest moment with geocentric elongation >= 8 and, somewhere on the sunset line, altitude >= 5.
    static func firstVisibility(conjunction: Moment, altitude: (Double, Moment) -> Double) -> (Moment, Bool)? {
        let t8 = Astronomical.crossing(from: conjunction, to: conjunction + 3, target: 8, rising: true) { Astronomical.geocentricElongation($0) }
        guard let t8 else { return nil }
        func ok(_ t: Moment) -> Bool {
            for k in -352...352 {
                let lat = Double(k) / 4
                guard let lon = CrescentRules.sunsetLongitude(at: t, latitude: lat) else { continue }
                let geo = Astronomical.lunarHorizontal(t, location: Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)).altitude
                if geo >= 4.5 && altitude(geo, t) >= 5 { return true }
            }
            return false
        }
        if ok(t8) { return (t8, false) }
        var lo = t8.inner, hi = t8.inner
        repeat { lo = hi; hi += 5.0 / 1440 } while !ok(Moment(hi)) && hi < t8.inner + 2
        guard hi < t8.inner + 2 else { return nil }
        for _ in 0..<14 { let mid = (lo + hi) / 2; if ok(Moment(mid)) { hi = mid } else { lo = mid } }
        return (Moment(hi), true)
    }

    @Test func compare() {
        guard let path = ProcessInfo.processInfo.environment["MAPS_CSV"], let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        var conj: [String: String] = [:], first: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline).dropFirst() {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 3, !f[2].isEmpty else { continue }
            if f[1] == "conj" { conj[f[0]] = f[2] } else if f[1] == "first" { first[f[0]] = f[2] }
        }
        let topo: (Double, Moment) -> Double = { geo, t in geo - Astronomical.lunarParallax(altitude: geo, moment: t) }
        let apparent: (Double) -> (Double, Moment) -> Double = { scale in { geo, t in
            let tp = topo(geo, t); return tp + scale * Astronomical.refraction(atTrueAltitude: tp) } }
        let fmt: (Moment) -> String = { m in
            let s = Int(((m.inner - floor(m.inner)) * 86400).rounded())
            return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        for file in Set(conj.keys).union(first.keys).sorted() {
            // Our conjunction: the new moon nearest the printed one (or nearest before the printed first visibility).
            guard let anchor = conj[file].flatMap(Self.moment) ?? first[file].flatMap(Self.moment).map({ $0 - 1 }) else { continue }
            let a = Astronomical.newMoonAtOrAfter(anchor - 1)
            let ours = abs(a.inner - anchor.inner) < 2 ? a : Astronomical.newMoonAtOrAfter(anchor - 0.5)
            var line = "MAP|\(file)"
            if let c = conj[file], let pc = Self.moment(c) {
                line += String(format: "|conj %@ ours %@ diff %+.0f s", c, fmt(ours), (ours.inner - pc.inner) * 86400)
            } else { line += "|conj ? ours \(fmt(ours))" }
            if let fv = first[file], let pf = Self.moment(fv) {
                line += "|first \(fv)"
                for (name, alt) in [("app", apparent(1)), ("app0.8", apparent(0.8)), ("topo", topo)] {
                    if let (m, altBound) = Self.firstVisibility(conjunction: ours, altitude: alt) {
                        line += String(format: " %@ %+.0f s%@", name, (m.inner - pf.inner) * 86400, altBound ? "(alt)" : "")
                    } else { line += " \(name) none" }
                }
            } else { line += "|first ?" }
            print(line)
        }
    }
}

@Suite struct CrescentDiyanetShaban1449 {
    @Test func check() {
        let anchor = Moment(Double(rd(2027, 12, 27)))
        let ours = Astronomical.newMoonAtOrAfter(anchor)
        let moshier = MoshierEngine().newMoonAtOrAfter(anchor)
        let fmt: (Moment) -> String = { m in
            let s = Int(((m.inner - floor(m.inner)) * 86400).rounded())
            return String(format: "%02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60) }
        let fv = CrescentDiyanetMaps.firstVisibility(conjunction: ours) { geo, t in geo - Astronomical.lunarParallax(altitude: geo, moment: t) }
        print("SHABAN1449|conj ours (Reingold) \(fmt(ours)) Moshier \(fmt(moshier)) Diyanet 20:16|first ours \(fv.map { fmt($0.0) } ?? "none") Diyanet 12:59")
        // Same check for a neighbouring month as a control.
        let c2 = Astronomical.newMoonAtOrAfter(Moment(Double(rd(2027, 11, 28))))
        print("SHABAN1449|control 2027-11 conj ours \(fmt(c2)) Moshier \(fmt(MoshierEngine().newMoonAtOrAfter(Moment(Double(rd(2027, 11, 28))))))")
    }
}

/// AH 1428-1444 decisions that depend on sunsets after 00:00 UTC: where the best point after midnight is, with margins.
/// Run with DIYANET_HISTORY=<diyanet_1318_1444.txt> COAST_CSV=<coast_fine.csv>.
@Suite struct CrescentDiyanetTransition {
    @Test func lateDecisions() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let cp = env["COAST_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        let coast = ct.split(whereSeparator: \.isNewline).compactMap { l -> (Double, Double)? in
            let f = l.split(separator: ",").compactMap { Double($0) }; return f.count == 2 ? (f[0], f[1]) : nil }
        var starts: [(Int, Int, Int64)] = []
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts.append((y, k + 1, rd(g[0], g[1], g[2]))) }
            }
        }
        for (p, s) in zip(starts, starts.dropFirst()) where s.0 >= 1428 {
            let base = p.2 + 28
            let r = CrescentRules.diyanet(RataDie(base))
            let before = r.beforeMidnight["none/apparent"] ?? false
            let late = r.anywhereLate["none/apparent"] ?? false
            guard !before, late else { continue }
            let midnight = Moment(Double(base) + 1)
            func margin(_ loc: Location) -> (Double, Moment)? {
                guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: RataDie(base), location: loc), ss >= midnight else { return nil }
                let q = evaluate(ss, loc)
                return (min(q.alt["apparent"]! - 5, q.elong["geo"]! - 8), ss)
            }
            var bestCoast = (-99.0, ""), bestLine = (-99.0, "")
            for (lat, lon) in coast {
                if let (m, ss) = margin(Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)), m > bestCoast.0 {
                    bestCoast = (m, String(format: "%.2f,%.2f %@", lat, lon, utc(ss, base: base))) }
            }
            for k in -352...352 {
                let lat = Double(k) / 4
                if let (m, ss) = margin(Location(latitude: lat, longitude: -179.999, elevation: 0, utcOffset: 0)), m > bestLine.0 {
                    bestLine = (m, String(format: "%.2f,-180 %@", lat, utc(ss, base: base))) }
            }
            let started = s.2 - p.2 == 29
            print(String(format: "LATE|AH %d-%02d evening +28 of %d-%02d|%@|Wellington %@|America coast %+.3f at %@|date line %+.3f at %@",
                         s.0, s.1, p.0, p.1, started ? "STARTED" : "no", r.conjunctionBeforeWellingtonDawn ? "yes" : "NO", bestCoast.0, bestCoast.1, bestLine.0, bestLine.1))
        }
    }
}

/// AH 1425-1440: first-visibility moment (apparent altitude, geocentric elongation) relative to 00:00 UTC after the
/// evening of day 29, against Diyanet's decision. Is there a time cut-off? Run with DIYANET_HISTORY=<...>.
@Suite struct CrescentDiyanetCutoff {
    @Test func firstVisibilityTimes() {
        guard let hp = ProcessInfo.processInfo.environment["DIYANET_HISTORY"], let ht = try? String(contentsOfFile: hp, encoding: .utf8) else { return }
        var starts: [(Int, Int, Int64)] = []
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts.append((y, k + 1, rd(g[0], g[1], g[2]))) }
            }
        }
        let apparent: (Double, Moment) -> Double = { geo, t in
            let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: t); return tp + Astronomical.refraction(atTrueAltitude: tp) }
        for (p, s) in zip(starts, starts.dropFirst()) where s.0 >= 1425 && s.0 <= 1440 {
            let base = p.2 + 28
            let midnight = Moment(Double(base) + 1)
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            guard midnight.inner + 0.5 - conj.inner < 3, let (fv, _) = CrescentDiyanetMaps.firstVisibility(conjunction: conj, altitude: apparent) else { continue }
            let hours = (fv.inner - midnight.inner) * 24
            guard hours > -6 && hours < 18 else { continue }
            print(String(format: "CUT|AH %d-%02d|%@|first visibility %+.2f h from 00 UTC|conj %+.2f h", s.0, s.1, s.2 - p.2 == 29 ? "STARTED" : "no", hours, (conj.inner - midnight.inner) * 24))
        }
    }
}

/// AH 1399-1457: Diyanet's period rules, main test over any point (ocean) or land only (Natural Earth, islands
/// included). Run with DIYANET_HISTORY, LAND_ROWS (land_rows.txt), DIYANET_CSV (crescent_official_dates.csv).
@Suite struct CrescentDiyanetLand {
    static func loadLand(_ path: String) -> [Int: [Double]] {
        var rows: [Int: [Double]] = [:]
        guard let t = try? String(contentsOfFile: path, encoding: .utf8) else { return rows }
        for line in t.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":"); guard parts.count == 2, let lat = Double(parts[0]) else { continue }
            rows[Int((lat * 4).rounded())] = parts[1].split(separator: " ").flatMap { $0.split(separator: ",").compactMap { Double($0) } }
        }
        return rows
    }

    /// Criterion at the best point per latitude with sunset at or before `cut` (a moment) on the evening of `day`.
    static func mainTest(_ day: RataDie, cut: Moment, land: [Int: [Double]]?) -> (Bool, String) {
        let conj = Astronomical.newMoonBefore(Moment(Double(day.dayNumber) + 1.5))
        guard Astronomical.geocentricElongation(cut) >= 8 else { return (false, "") }
        var best = (-99.0, "")
        for k in -352...352 {
            let lat = Double(k) / 4
            guard let l = CrescentRules.sunsetLongitude(at: cut, latitude: lat) else { continue }
            var lon = l, moment = cut
            if let land {
                let row = land[k] ?? []
                var pick: Double? = nil
                var i = 0
                while i + 1 < row.count { if row[i + 1] >= l { pick = max(row[i], l); break }; i += 2 }
                guard let p = pick else { continue }
                lon = p
                guard let s = Astronomical.sunsetUT(nearLocalNoonOf: day, location: Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)), s <= cut + 1e-6 else { continue }
                moment = s
            }
            guard moment > conj, moment - conj < 3 else { continue }
            let q = evaluate(moment, Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0))
            let m = min(q.alt["apparent"]! - 5, q.elong["geo"]! - 8)
            if m > best.0 { best = (m, String(format: "%+.3f at %.2f,%.2f", m, lat, lon)) }
        }
        return (best.0 >= 0, best.1)
    }

    @Test func score() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let lp = env["LAND_ROWS"], let cp = env["DIYANET_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        let land = Self.loadLand(lp)
        var starts: [Int: Int64] = [:]   // year*12+month-1 -> first day
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        for line in ct.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
        }
        var tally: [String: (Int, Int)] = [:]
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            let year = idx / 12, month = idx % 12 + 1
            let day = RataDie(p + 28)
            let midnight = Moment(Double(p + 29))
            let started = s - p == 29
            let period = year <= 1429 ? "A 1399-1429" : (year <= 1435 ? "B 1430-1435" : (year <= 1437 ? "C 1436-1437" : "D 1438-1457"))
            let cutHours = period.hasPrefix("B") ? 5.25 : 0
            let cut = midnight + cutHours / 24
            let (ocean, oceanWhere) = Self.mainTest(day, cut: cut, land: nil)
            let (onLand, landWhere) = Self.mainTest(day, cut: cut, land: land)
            var exception = false
            if period.hasPrefix("D") {
                let r = CrescentRules.diyanet(day)
                exception = (r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn
            }
            for (variant, main) in [("ocean", ocean), ("land", onLand)] {
                let predicts = main || exception
                let key = "\(period)/\(variant)"
                tally[key] = ((tally[key]?.0 ?? 0) + (predicts == started ? 1 : 0), (tally[key]?.1 ?? 0) + 1)
                if predicts != started {
                    print("LMISS|\(key)|AH \(year)-\(month) official \(started ? "29d" : "30d") rule \(predicts ? "29d" : "30d")|ocean \(oceanWhere.isEmpty ? "-" : oceanWhere)|land \(landWhere.isEmpty ? "-" : landWhere)|exception \(exception)")
                }
            }
        }
        for k in tally.keys.sorted() { print("LRESULT|\(k)|\(tally[k]!.0)/\(tally[k]!.1)") }
    }
}

/// Grid hypothesis: Diyanet evaluates only on a grid of points (spacing g, aligned to multiples of g plus an offset).
/// Along a latitude the best grid point is the westernmost one east of the sunset line (main test) or the westernmost
/// one on the American mainland (exception), so each grid needs one evaluation per grid latitude.
/// Env: DIYANET_HISTORY, LAND_ROWS, DIYANET_CSV.
@Suite struct CrescentDiyanetGrid {
    static func passes(_ day: RataDie, _ lat: Double, _ lon: Double, conj: Moment, before cut: Moment?, after midnight: Moment?) -> Bool {
        let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
        guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss > conj, ss - conj < 3 else { return false }
        if let cut, ss > cut + 1e-7 { return false }
        if let midnight, ss < midnight { return false }
        guard Astronomical.geocentricElongation(ss) >= 8 else { return false }
        return evaluate(ss, loc).alt["apparent"]! >= 5
    }

    @Test func search() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let lp = env["LAND_ROWS"], let cp = env["DIYANET_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        let land = CrescentDiyanetLand.loadLand(lp)
        func onLand(_ lat: Double, _ lon: Double) -> Bool {
            let row = land[Int((lat * 4).rounded())] ?? []
            var i = 0; while i + 1 < row.count { if lon >= row[i] && lon <= row[i + 1] { return true }; i += 2 }
            return false
        }
        var starts: [Int: Int64] = [:]
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        for line in ct.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
        }
        let grids: [(Double, Double)] = [0.5, 1, 2, 2.5, 3, 5, 10].flatMap { g in [(g, 0.0), (g, g / 2)] }
        var fits: [String: Int] = [:], total = 0
        var misses: [String: [String]] = [:]
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            total += 1
            let year = idx / 12, month = idx % 12 + 1
            let day = RataDie(p + 28)
            let midnight = Moment(Double(p + 29))
            let started = s - p == 29
            let periodD = year >= 1438, periodB = (1430...1435).contains(year)
            let cut = midnight + (periodB ? 5.25 : 0) / 24
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            let r = CrescentRules.diyanet(day)
            let exactMain = periodB ? CrescentDiyanetLand.mainTest(day, cut: cut, land: nil).0 : (r.beforeMidnight["none/apparent"] ?? false)
            let exactExc = periodD && (r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn
            for (g, off) in grids {
                let key = String(format: "g%04.1f off%.2f", g, off)
                var main = false, exc = false
                if exactMain {
                    var lat = off - 90; while lat < -88 { lat += g }
                    while lat <= 88 && !main {
                        if let l = CrescentRules.sunsetLongitude(at: cut, latitude: lat) {
                            let lon = ((l - off) / g).rounded(.up) * g + off
                            if lon <= 180 { main = Self.passes(day, lat, lon, conj: conj, before: cut, after: nil) }
                        }
                        lat += g
                    }
                }
                if exactExc && !main {
                    var lat = off - 60; while lat < -56 { lat += g }
                    while lat <= 72 && !exc {
                        let w = CrescentRules.americanWestCoastLongitude(latitude: lat)
                        if let w {
                            var lon = ((w - off) / g).rounded(.up) * g + off
                            var tries = 0
                            while lon < -30 && tries < Int(20 / g) + 1 && !onLand(lat, lon) { lon += g; tries += 1 }
                            if lon < -30 && onLand(lat, lon) { exc = Self.passes(day, lat, lon, conj: conj, before: nil, after: midnight) }
                        }
                        lat += g
                    }
                }
                let predicts = main || exc
                if predicts == started { fits[key, default: 0] += 1 } else { misses[key, default: []].append("\(year)-\(month)\(started ? "S" : "n")") }
            }
        }
        for k in fits.keys.sorted() { print("GRIDFIT|\(k)|\(fits[k]!)/\(total)|misses: \((misses[k] ?? []).joined(separator: " "))") }
    }
}

/// For every AH 1399-1457 decision where Diyanet's period rule says "start", print candidate extra conditions.
/// Env: DIYANET_HISTORY, DIYANET_CSV.
@Suite struct CrescentDiyanetFeatures {
    @Test func features() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let cp = env["DIYANET_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        var starts: [Int: Int64] = [:]
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        for line in ct.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
        }
        let ankara = Location(latitude: 39.93, longitude: 32.86, elevation: 0, utcOffset: 0)
        let mecca = Location(latitude: 21.4225, longitude: 39.8262, elevation: 0, utcOffset: 0)
        let istanbul = Location(latitude: 41.01, longitude: 28.98, elevation: 0, utcOffset: 0)
        let apparent: (Double, Moment) -> Double = { geo, t in
            let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: t); return tp + Astronomical.refraction(atTrueAltitude: tp) }
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            let year = idx / 12, month = idx % 12 + 1
            let day = RataDie(p + 28)
            let midnight = Moment(Double(p + 29))
            let periodD = year >= 1438, periodB = (1430...1435).contains(year)
            let cut = midnight + (periodB ? 5.25 : 0) / 24
            let r = CrescentRules.diyanet(day)
            let main = periodB ? CrescentDiyanetLand.mainTest(day, cut: cut, land: nil).0 : (r.beforeMidnight["none/apparent"] ?? false)
            let exc = periodD && (r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn
            guard main || exc else { continue }
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            let fv = CrescentDiyanetMaps.firstVisibility(conjunction: conj, altitude: apparent)?.0
            func local(_ loc: Location) -> String {
                guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc) else { return "nan,nan,nan" }
                let q = evaluate(ss, loc)
                let set = Astronomical.moonsetUT(after: ss - 0.1, location: loc)
                return String(format: "%.3f,%.3f,%.2f", q.alt["apparent"]!, q.elong["geo"]!, set.map { ($0.inner - ss.inner) * 1440 } ?? .nan)
            }
            let wDawn = Astronomical.dawnUT(after: Moment(Double(day.dayNumber) + 0.25), location: CrescentRules.wellington, depression: 18)
            print(String(format: "FEAT|%d|%d|%@|%@|%.3f|%.3f|%.3f|%.3f|", year, month, s - p == 29 ? "S" : "n", main ? "main" : "exc",
                         (conj.inner - midnight.inner) * 24, fv.map { ($0.inner - midnight.inner) * 24 } ?? .nan,
                         fv.map { ($0.inner - conj.inner) * 24 } ?? .nan, wDawn.map { ($0.inner - conj.inner) * 24 } ?? .nan)
                  + "\(local(ankara))|\(local(mecca))|\(local(istanbul))")
        }
    }
}

/// AH 1428-1437 decisions where the main test (before 00 UTC) fails: what the Americas looked like that evening.
/// Per decision: first visibility (h after 00 UTC), Wellington, and over the American mainland west coast (sunsets of
/// that evening, before or after 00 UTC): best apparent altitude, best geocentric elongation, best moonset lag,
/// best 5/8 margin. Env: DIYANET_HISTORY, COAST_CSV.
@Suite struct CrescentDiyanetEraB {
    @Test func americas() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let cp = env["COAST_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ctext = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        let coast = ctext.split(whereSeparator: \.isNewline).compactMap { l -> (Double, Double)? in
            let f = l.split(separator: ",").compactMap { Double($0) }; return f.count == 2 ? (f[0], f[1]) : nil }
        var starts: [Int: Int64] = [:]
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        let apparent: (Double, Moment) -> Double = { geo, t in
            let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: t); return tp + Astronomical.refraction(atTrueAltitude: tp) }
        for idx in starts.keys.sorted() where idx >= 1428 * 12 && idx < 1438 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            let day = RataDie(p + 28)
            let r = CrescentRules.diyanet(day)
            if r.beforeMidnight["none/apparent"] ?? false { continue }
            let midnight = Moment(Double(p + 29))
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            guard midnight.inner + 0.5 - conj.inner < 3 else { continue }
            let fv = CrescentDiyanetMaps.firstVisibility(conjunction: conj, altitude: apparent)?.0
            let fvh = fv.map { ($0.inner - midnight.inner) * 24 } ?? 99
            guard fvh < 14 else { continue }
            var bestAlt = -99.0, bestElong = -99.0, bestLag = -999.0, bestMargin = -99.0, conjBeforeSunset = false
            for (i, (lat, lon)) in coast.enumerated() where i % 4 == 0 {
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss > conj - 1 else { continue }
                if ss > conj { conjBeforeSunset = true }
                let q = evaluate(ss, loc)
                bestAlt = max(bestAlt, q.alt["apparent"]!); bestElong = max(bestElong, q.elong["geo"]!)
                bestMargin = max(bestMargin, min(q.alt["apparent"]! - 5, q.elong["geo"]! - 8))
                if let set = Astronomical.moonsetUT(after: ss - 0.1, location: loc) { bestLag = max(bestLag, (set.inner - ss.inner) * 1440) }
            }
            print(String(format: "ERAB|AH %d-%02d|%@|FV %+.2f h|Wellington %@|America: alt %.2f elong %.2f lag %.1f min margin %+.2f conjBeforeSunset %@",
                         idx / 12, idx % 12 + 1, s - p == 29 ? "STARTED" : "no", fvh, r.conjunctionBeforeWellingtonDawn ? "yes" : "NO",
                         bestAlt, bestElong, bestLag, bestMargin, conjBeforeSunset ? "yes" : "no"))
        }
    }
}

/// Period rules assigned by the Gregorian year of the month's first day (Diyanet computes a calendar year at a time):
/// A to 2008, B 2009-2013 (cut-off 05:15 UTC), C 2014-2016 (no exception), D from 2017 (2016 rule).
@Suite struct CrescentDiyanetBatches {
    @Test func score() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let cp = env["DIYANET_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        var starts: [Int: Int64] = [:]
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        for line in ct.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
        }
        let y2009 = rd(2009, 1, 1), y2014 = rd(2014, 1, 1), y2017 = rd(2017, 1, 1)
        var hits = 0, total = 0
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            total += 1
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29))
            let period = s < y2009 ? "A" : (s < y2014 ? "B" : (s < y2017 ? "C" : "D"))
            let r = CrescentRules.diyanet(day)
            let main = period == "B" ? CrescentDiyanetLand.mainTest(day, cut: midnight + 5.25 / 24, land: nil).0 : (r.beforeMidnight["none/apparent"] ?? false)
            let exc = period == "D" && (r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn
            let predicts = main || exc, started = s - p == 29
            if predicts == started { hits += 1 } else { print("BMISS|\(period)|AH \(idx / 12)-\(idx % 12 + 1) first day +\(s - rd(2000, 1, 1)) from 2000-01-01|official \(started ? "29d" : "30d") rule \(predicts ? "29d" : "30d")") }
        }
        print("BRESULT|\(hits)/\(total)")
    }
}

/// Does a list of American places (cities) reproduce the exception decisions since 2017? For each evening where the
/// main test fails and Wellington passes, print the places where the criterion is met at sunset after 00:00 UTC.
/// Env: DIYANET_HISTORY, DIYANET_CSV.
@Suite struct CrescentDiyanetCities {
    static let cities: [(String, Double, Double)] = [
        ("Utqiagvik", 71.29, -156.79), ("Point Hope", 68.35, -166.80), ("Kotzebue", 66.90, -162.60), ("Wales AK", 65.61, -168.09),
        ("Nome", 64.50, -165.41), ("Fairbanks", 64.84, -147.72), ("Unalakleet", 63.87, -160.79), ("Hooper Bay", 61.53, -166.10),
        ("Chevak", 61.53, -165.59), ("Anchorage", 61.22, -149.90), ("Wasilla", 61.58, -149.44), ("Valdez", 61.13, -146.35),
        ("Bethel", 60.79, -161.76), ("Quinhagak", 59.75, -161.92), ("Homer", 59.64, -151.55), ("Dillingham", 59.04, -158.46),
        ("Platinum", 59.01, -161.82), ("Togiak", 59.06, -160.38), ("Naknek", 58.73, -157.02), ("King Salmon", 58.69, -156.66),
        ("Juneau", 58.30, -134.42), ("Kodiak*", 57.79, -152.41), ("Sitka*", 57.05, -135.33), ("Cold Bay", 55.20, -162.72),
        ("Ketchikan*", 55.34, -131.65), ("Unalaska*", 53.87, -166.54), ("Prince Rupert", 54.32, -130.32), ("Whitehorse", 60.72, -135.06),
        ("Inuvik", 68.36, -133.72), ("Yellowknife", 62.45, -114.37), ("Edmonton", 53.55, -113.49), ("Calgary", 51.05, -114.07),
        ("Vancouver", 49.28, -123.12), ("Victoria", 48.43, -123.37), ("Seattle", 47.61, -122.33), ("Astoria", 46.19, -123.83),
        ("Portland", 45.52, -122.68), ("Newport OR", 44.64, -124.05), ("Eureka", 40.80, -124.16), ("San Francisco", 37.77, -122.42),
        ("Monterey", 36.60, -121.89), ("Los Angeles", 34.05, -118.24), ("San Diego", 32.72, -117.16), ("Tijuana", 32.51, -117.04),
        ("Ensenada", 31.87, -116.60), ("Las Vegas", 36.17, -115.14), ("Phoenix", 33.45, -112.07), ("Hermosillo", 29.07, -110.96),
        ("Cabo San Lucas", 22.89, -109.92), ("Mazatlan", 23.22, -106.42), ("Puerto Vallarta", 20.65, -105.23), ("Manzanillo", 19.05, -104.32),
        ("Mexico City", 19.43, -99.13), ("Acapulco", 16.86, -99.88), ("Guatemala City", 14.63, -90.51), ("San Jose CR", 9.93, -84.08),
        ("Panama City", 8.98, -79.52), ("Guayaquil", -2.19, -79.89), ("Lima", -12.05, -77.04), ("Antofagasta", -23.65, -70.40),
        ("Santiago", -33.45, -70.67), ("Valdivia", -39.81, -73.25), ("Puerto Montt", -41.47, -72.94), ("Punta Arenas", -53.16, -70.91),
        ("Ushuaia", -54.80, -68.30), ("Buenos Aires", -34.60, -58.38), ("Brasilia", -15.79, -47.88), ("Bogota", 4.71, -74.07),
        ("Havana", 23.13, -82.38), ("Miami", 25.76, -80.19), ("New York", 40.71, -74.01), ("Toronto", 43.65, -79.38),
    ]

    @Test func passing() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let cp = env["DIYANET_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        var starts: [Int: Int64] = [:]
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        for line in ct.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
        }
        let y2017 = rd(2017, 1, 1)
        for idx in starts.keys.sorted() {
            guard let p = starts[idx - 1], let s = starts[idx], s >= y2017 else { continue }
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29))
            let r = CrescentRules.diyanet(day)
            guard !(r.beforeMidnight["none/apparent"] ?? false), r.conjunctionBeforeWellingtonDawn, Astronomical.geocentricElongation(midnight + 0.5) >= 8 else { continue }
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            var pass: [String] = []
            var near: [String] = []
            for (name, lat, lon) in Self.cities {
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss >= midnight, ss > conj else { continue }
                let q = evaluate(ss, loc)
                let m = min(q.alt["apparent"]! - 5, q.elong["geo"]! - 8)
                if m >= 0 { pass.append(String(format: "%@ %+.2f", name, m)) } else if m > -0.3 { near.append(String(format: "%@ %+.2f", name, m)) }
            }
            print("CITY|AH \(idx / 12)-\(idx % 12 + 1) evening +28 of \(p - rd(2000, 1, 1))|\(s - p == 29 ? "STARTED" : "no")|coast \(String(format: "%+.3f", 0.0))|pass: \(pass.joined(separator: ", "))|near: \(near.joined(separator: ", "))")
        }
    }
}

/// Dumps, for the evening EVENING=YYYY-MM-DD (UTC date of day 29), the pass/fail of the criterion on a 0.5-degree
/// grid: west of 30 W the sunset of local date EVENING; elsewhere the sunset of the next local date (the same sweep of
/// sunsets after 00:00 UTC). Apparent altitude >= 5, geocentric elongation >= 8, after the conjunction.
/// Output ZONE|lat|lon|margin|sunsetUTChours to ZONE_OUT.
@Suite struct CrescentDiyanetZoneDump {
    @Test func dump() {
        let env = ProcessInfo.processInfo.environment
        guard let e = env["EVENING"], let out = env["ZONE_OUT"] else { return }
        let g = e.split(separator: "-").compactMap { Int($0) }; guard g.count == 3 else { return }
        let base = rd(g[0], g[1], g[2])
        let midnight = Moment(Double(base) + 1)
        let conj = Astronomical.newMoonBefore(midnight + 0.5)
        var lines: [String] = []
        for k in -140...150 {
            let lat = Double(k) / 2
            for j in -360..<360 {
                let lon = Double(j) / 2
                let day = RataDie(lon < -30 ? base : base + 1)
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss > conj, ss - conj < 3 else { continue }
                let e8 = Astronomical.geocentricElongation(ss) - 8
                if e8 < -1 { continue }
                let q = evaluate(ss, loc)
                let m = min(q.alt["apparent"]! - 5, e8)
                if m > -1 { lines.append(String(format: "%.1f|%.1f|%.3f|%.2f", lat, lon, m, (ss.inner - midnight.inner) * 24)) }
            }
        }
        try? lines.joined(separator: "\n").write(toFile: out, atomically: true, encoding: .utf8)
        print("ZONE|\(e)|\(lines.count) points")
    }
}

/// Exception evaluated with the ecliptic-longitude difference (moon minus sun) in place of the true elongation,
/// at the westernmost mainland coast (COAST_CSV). For every evening since 2017 where the main test fails and
/// Wellington passes: best margins with true elongation and with the longitude difference, and the moon's ecliptic
/// latitude. Env: DIYANET_HISTORY, DIYANET_CSV, COAST_CSV.
@Suite struct CrescentDiyanetDeltaLambda {
    @Test func compare() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let cp = env["DIYANET_CSV"], let kp = env["COAST_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8),
              let kt = try? String(contentsOfFile: kp, encoding: .utf8) else { return }
        let coast = kt.split(whereSeparator: \.isNewline).compactMap { l -> (Double, Double)? in
            let f = l.split(separator: ",").compactMap { Double($0) }; return f.count == 2 ? (f[0], f[1]) : nil }
        var starts: [Int: Int64] = [:]
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        for line in ct.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
        }
        let y2017 = rd(2017, 1, 1)
        var tally = [0, 0], total = 0
        for idx in starts.keys.sorted() {
            guard let p = starts[idx - 1], let s = starts[idx], s >= y2017 else { continue }
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29))
            let r = CrescentRules.diyanet(day)
            guard !(r.beforeMidnight["none/apparent"] ?? false), r.conjunctionBeforeWellingtonDawn, Astronomical.geocentricElongation(midnight + 0.5) >= 7 else { continue }
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            var bestE = (-99.0, ""), bestL = (-99.0, ""), beta = 0.0
            for (lat, lon) in coast {
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss >= midnight, ss > conj else { continue }
                let q = evaluate(ss, loc)
                let c = Astronomical.julianCenturies(ss)
                var dl = Astronomical.lunarLongitude(c) - Astronomical.solarLongitude(c)
                dl = dl.truncatingRemainder(dividingBy: 360); if dl < 0 { dl += 360 }
                let mE = min(q.alt["apparent"]! - 5, q.elong["geo"]! - 8), mL = min(q.alt["apparent"]! - 5, dl - 8)
                if mE > bestE.0 { bestE = (mE, String(format: "%.2f,%.2f alt %.2f E %.3f dλ %.3f", lat, lon, q.alt["apparent"]!, q.elong["geo"]!, dl)); beta = Astronomical.lunarLatitude(c) }
                if mL > bestL.0 { bestL = (mL, String(format: "%.2f,%.2f alt %.2f dλ %.3f", lat, lon, q.alt["apparent"]!, dl)) }
            }
            let started = s - p == 29
            total += 1
            if (bestE.0 >= 0) == started { tally[0] += 1 }
            if (bestL.0 >= 0) == started { tally[1] += 1 }
            print(String(format: "DL|AH %d-%02d|%@|β %+.2f|trueE best %+.3f at %@|dλ best %+.3f at %@", idx / 12, idx % 12 + 1, started ? "STARTED" : "no", beta, bestE.0, bestE.1, bestL.0, bestL.1))
        }
        print("DLRESULT|true elongation \(tally[0])/\(total)|longitude difference \(tally[1])/\(total)")
    }
}

/// Every decision AH 1399-1457: first visibility (apparent altitude, geocentric elongation) relative to 00:00 UTC
/// after the evening of day 29, with Diyanet's outcome, for the window -90 .. +90 minutes. Env: DIYANET_HISTORY, DIYANET_CSV.
@Suite struct CrescentDiyanetCutoffAll {
    @Test func window() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let cp = env["DIYANET_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        var starts: [Int: Int64] = [:]
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        for line in ct.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
        }
        let apparent: (Double, Moment) -> Double = { geo, t in
            let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: t); return tp + Astronomical.refraction(atTrueAltitude: tp) }
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            let midnight = Moment(Double(p + 29))
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            guard midnight.inner + 0.5 - conj.inner < 3, let (fv, altBound) = CrescentDiyanetMaps.firstVisibility(conjunction: conj, altitude: apparent) else { continue }
            let minutes = (fv.inner - midnight.inner) * 1440
            guard minutes > -90 && minutes < 90 else { continue }
            let gy = (s - rd(2000, 1, 1)) / 365 + 2000
            print(String(format: "WIN|AH %d-%02d|~%d|%@|FV %+.1f min from 00:00 UTC%@", idx / 12, idx % 12 + 1, gy, s - p == 29 ? "STARTED" : "no", minutes, altBound ? " (altitude-bound)" : ""))
        }
    }
}

/// For every decision 2009-2013 (and 2017+ for reference) where the main test fails: the northern limit of our strict
/// day-29 zone on the Americas/Pacific side (sunsets after 00:00 UTC, longitude -180 .. -30), i.e. the highest latitude
/// at which some sunset there meets apparent altitude >= 5 and geocentric elongation >= 8. Env: DIYANET_HISTORY, DIYANET_CSV.
@Suite struct CrescentDiyanetNorthLimit {
    @Test func limits() {
        let env = ProcessInfo.processInfo.environment
        guard let hp = env["DIYANET_HISTORY"], let cp = env["DIYANET_CSV"],
              let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return }
        var starts: [Int: Int64] = [:]
        for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
            let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
            for (k, d) in parts[1].split(separator: " ").enumerated() {
                let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
            }
        }
        for line in ct.split(whereSeparator: \.isNewline) {
            let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
            let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
        }
        let y2009 = rd(2009, 1, 1), y2014 = rd(2014, 1, 1), y2017 = rd(2017, 1, 1)
        for idx in starts.keys.sorted() {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            let period = s < y2009 ? "A" : (s < y2014 ? "B" : (s < y2017 ? "C" : "D"))
            guard period == "B" || period == "D" else { continue }
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29))
            let r = CrescentRules.diyanet(day)
            if r.beforeMidnight["none/apparent"] ?? false { continue }
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            guard midnight.inner + 0.5 - conj.inner < 3, Astronomical.geocentricElongation(midnight + 0.5) >= 7.5 else { continue }
            var north = -99.0, south = 99.0, bestLat = 0.0, bestMargin = -99.0, count = 0
            for k in -140...150 {
                let lat = Double(k) / 2
                var any = false
                for j in -360...(-60) {
                    let lon = Double(j) / 2
                    let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                    guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss >= midnight, ss > conj, ss - conj < 3 else { continue }
                    let e = Astronomical.geocentricElongation(ss) - 8
                    if e < -0.5 { continue }
                    let q = evaluate(ss, loc)
                    let m = min(q.alt["apparent"]! - 5, e)
                    if m >= 0 { any = true; count += 1; if m > bestMargin { bestMargin = m; bestLat = lat } }
                }
                if any { north = max(north, lat); south = min(south, lat) }
            }
            let fv = (CrescentDiyanetMaps.firstVisibility(conjunction: conj) { geo, t in let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: t); return tp + Astronomical.refraction(atTrueAltitude: tp) })?.0
            print(String(format: "NL|%@|AH %d-%02d|%@|FV %+.2f h|north %@|south %@|points %d|best %+.2f at %.1f|Wellington %@|America %@",
                         period, idx / 12, idx % 12 + 1, s - p == 29 ? "STARTED" : "no", fv.map { ($0.inner - midnight.inner) * 24 } ?? .nan,
                         north > -99 ? String(format: "%.1f", north) : "-", south < 99 ? String(format: "%.1f", south) : "-", count, bestMargin, bestLat,
                         r.conjunctionBeforeWellingtonDawn ? "yes" : "NO", (r.americas["none/apparent"] ?? false) ? "yes" : "no"))
        }
    }
}

/// Official month starts keyed by AH year*12 + month-1, from DIYANET_HISTORY (AH 1318-1444 list) and DIYANET_CSV.
private func loadStartsFromEnv(_ env: [String: String]) -> [Int: Int64]? {
    guard let hp = env["DIYANET_HISTORY"], let cp = env["DIYANET_CSV"],
          let ht = try? String(contentsOfFile: hp, encoding: .utf8), let ct = try? String(contentsOfFile: cp, encoding: .utf8) else { return nil }
    var starts: [Int: Int64] = [:]
    for line in ht.split(whereSeparator: \.isNewline) where line.hasPrefix("AH ") {
        let parts = line.split(separator: ":"); guard parts.count == 2, let y = Int(parts[0].dropFirst(3)) else { continue }
        for (k, d) in parts[1].split(separator: " ").enumerated() {
            let g = d.split(separator: "-").compactMap { Int($0) }; if g.count == 3 { starts[y * 12 + k] = rd(g[0], g[1], g[2]) }
        }
    }
    for line in ct.split(whereSeparator: \.isNewline) {
        let f = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
        guard f.count >= 5, f[0] == "diyanet", let y = Int(f[2]), let m = Int(f[3]) else { continue }
        let g = f[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3, starts[y * 12 + m - 1] == nil { starts[y * 12 + m - 1] = rd(g[0], g[1], g[2]) }
    }
    return starts
}

/// Period A (AH 1399 to calendar year 2008): the main test at the 00:00 UTC sunset line under four elongation
/// definitions. The altitude part (apparent altitude >= 5 somewhere on the line) is shared. Env: DIYANET_HISTORY, DIYANET_CSV.
@Suite struct CrescentDiyanetElongationA {
    @Test func score() {
        guard let starts = loadStartsFromEnv(ProcessInfo.processInfo.environment) else { return }
        let y2009 = rd(2009, 1, 1)
        let names = ["geo", "dlambda", "dra", "topo"]
        var hits: [String: Int] = [:], misses: [String: [String]] = [:], total = 0
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx], s < y2009 else { continue }
            total += 1
            let midnight = Moment(Double(p + 29))
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            let started = s - p == 29
            let afterConj = midnight > conj && midnight.inner - conj.inner < 3
            let c = Astronomical.julianCenturies(midnight)
            let lam = Astronomical.lunarLongitude(c), lsun = Astronomical.solarLongitude(c), beta = Astronomical.lunarLatitude(c)
            var dl = (lam - lsun).truncatingRemainder(dividingBy: 360); if dl < -180 { dl += 360 }; if dl > 180 { dl -= 360 }
            let eGeo = Astronomical.geocentricElongation(midnight)
            let raMoon = Astronomical.rightAscension(midnight, beta: beta, lambda: lam), raSun = Astronomical.rightAscension(midnight, beta: 0, lambda: lsun)
            var dra = (raMoon - raSun).truncatingRemainder(dividingBy: 360); if dra < -180 { dra += 360 }; if dra > 180 { dra -= 360 }
            var altOK = false, bestTopo = -99.0, bestAlt = -99.0
            if afterConj && eGeo >= 6 {
                for k in -880...880 {
                    let lat = Double(k) / 10
                    guard let lon = CrescentRules.sunsetLongitude(at: midnight, latitude: lat) else { continue }
                    let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                    let geo = Astronomical.lunarHorizontal(midnight, location: loc).altitude
                    guard geo >= 4 else { continue }
                    let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: midnight)
                    let app = tp + Astronomical.refraction(atTrueAltitude: tp)
                    bestAlt = max(bestAlt, app)
                    guard app >= 5 else { continue }
                    altOK = true
                    bestTopo = max(bestTopo, Astronomical.topocentricElongation(midnight, location: loc))
                }
            }
            let predicts: [String: Bool] = ["geo": afterConj && altOK && eGeo >= 8, "dlambda": afterConj && altOK && dl >= 8,
                                            "dra": afterConj && altOK && dra >= 8, "topo": afterConj && altOK && bestTopo >= 8]
            let tag = String(format: "AH %d-%02d", idx / 12, idx % 12 + 1)
            for n in names { if predicts[n]! == started { hits[n, default: 0] += 1 } else { misses[n, default: []].append(tag) } }
            if afterConj && (abs(eGeo - 8) < 0.5 || abs(dl - 8) < 0.5 || abs(bestTopo - 8) < 0.5 || abs(bestAlt - 5) < 0.3) {
                print(String(format: "ELA|%@|%@|geo %+.3f|dlambda %+.3f|dra %+.3f|topo %+.3f|beta %+.2f|bestAlt %+.3f", tag, started ? "STARTED" : "no",
                             eGeo - 8, dl - 8, dra - 8, bestTopo - 8, beta, bestAlt - 5))
            }
        }
        for n in names { print("ELARESULT|\(n)|\(hits[n] ?? 0)/\(total)|misses: \((misses[n] ?? []).joined(separator: " "))") }
    }
}

/// 2017+ decisions: the America exception with coarser coastlines. Rows every 0.05 degree (fine), every 0.25/0.5/1 degree,
/// and the same with the longitude snapped east (E) or to the nearest (N) multiple of the step.
/// Env: DIYANET_HISTORY, DIYANET_CSV, COAST_CSV.
@Suite struct CrescentDiyanetCoastResolution {
    struct Variant { let name: String; let step: Int; let snap: Double; let mode: Int }
    @Test func score() {
        let env = ProcessInfo.processInfo.environment
        guard let starts = loadStartsFromEnv(env), let cpath = env["COAST_CSV"], let text = try? String(contentsOfFile: cpath, encoding: .utf8) else { return }
        let coast = text.split(whereSeparator: \.isNewline).compactMap { line -> (Double, Double)? in
            let f = line.split(separator: ",").compactMap { Double($0) }; return f.count == 2 ? (f[0], f[1]) : nil }
        let variants = [Variant(name: "fine", step: 1, snap: 0, mode: 0),
                        Variant(name: "rows0.25", step: 5, snap: 0, mode: 0), Variant(name: "rows0.5", step: 10, snap: 0, mode: 0), Variant(name: "rows1", step: 20, snap: 0, mode: 0),
                        Variant(name: "grid0.25E", step: 5, snap: 0.25, mode: 1), Variant(name: "grid0.5E", step: 10, snap: 0.5, mode: 1), Variant(name: "grid1E", step: 20, snap: 1, mode: 1),
                        Variant(name: "grid0.25N", step: 5, snap: 0.25, mode: 2), Variant(name: "grid0.5N", step: 10, snap: 0.5, mode: 2), Variant(name: "grid1N", step: 20, snap: 1, mode: 2)]
        let y2017 = rd(2017, 1, 1)
        var hits: [String: Int] = [:], total = 0
        for idx in starts.keys.sorted() {
            guard let p = starts[idx - 1], let s = starts[idx], s >= y2017 else { continue }
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29))
            let started = s - p == 29
            total += 1
            let r = CrescentRules.diyanet(day)
            if r.beforeMidnight["none/apparent"] ?? false {
                for v in variants where started { hits[v.name, default: 0] += 1 }
                if !started { print(String(format: "CR|AH %d-%02d|main test passes, official 30d", idx / 12, idx % 12 + 1)) }
                continue
            }
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            guard midnight.inner + 0.5 - conj.inner < 3 else { for v in variants where !started { hits[v.name, default: 0] += 1 }; continue }
            let dawn = Astronomical.dawnUT(after: Moment(Double(p + 28) + 0.25), location: CrescentRules.wellington, depression: 18)
            let wellMin = dawn.map { ($0.inner - conj.inner) * 1440 } ?? .nan
            func margin(_ lat: Double, _ lon: Double) -> Double {
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss >= midnight, ss > conj, ss - conj < 3 else { return -99 }
                let e = Astronomical.geocentricElongation(ss) - 8
                guard e > -1 else { return e }
                let geo = Astronomical.lunarHorizontal(ss, location: loc).altitude
                let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: ss)
                return min(e, tp + Astronomical.refraction(atTrueAltitude: tp) - 5)
            }
            var best: [String: (Double, Double)] = [:]
            for v in variants {
                var b = (-99.0, 0.0)
                for (i, row) in coast.enumerated() where i % v.step == 0 {
                    var lon = row.1
                    if v.snap > 0 { lon = (v.mode == 1 ? (lon / v.snap).rounded(.up) : (lon / v.snap).rounded()) * v.snap }
                    let m = margin(row.0, lon)
                    if m > b.0 { b = (m, row.0) }
                }
                best[v.name] = b
            }
            var flags: [String] = []
            for v in variants {
                let pass = best[v.name]!.0 >= 0 && r.conjunctionBeforeWellingtonDawn
                if pass == started { hits[v.name, default: 0] += 1 }
                flags.append(String(format: "%@ %+.3f@%.2f%@", v.name, best[v.name]!.0, best[v.name]!.1, pass == started ? "" : " MISS"))
            }
            if best["fine"]!.0 > -0.5 || !started == (best["fine"]!.0 >= 0 && r.conjunctionBeforeWellingtonDawn) {
                print(String(format: "CR|AH %d-%02d|%@|Wellington %+.0f min|%@", idx / 12, idx % 12 + 1, started ? "STARTED" : "no", wellMin, flags.joined(separator: "|")))
            }
        }
        for v in variants { print("CRRESULT|\(v.name)|\(hits[v.name] ?? 0)/\(total)") }
    }
}

/// Period A near-threshold decisions: the latitude band of the 00:00 UTC sunset-line points that pass (apparent
/// altitude >= 5) and where the best altitude sits. Env: DIYANET_HISTORY, DIYANET_CSV.
@Suite struct CrescentDiyanetElongationBand {
    @Test func bands() {
        guard let starts = loadStartsFromEnv(ProcessInfo.processInfo.environment) else { return }
        let y2009 = rd(2009, 1, 1)
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx], s < y2009 else { continue }
            let midnight = Moment(Double(p + 29))
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            guard midnight > conj, midnight.inner - conj.inner < 3 else { continue }
            let e = Astronomical.geocentricElongation(midnight) - 8
            guard abs(e) < 0.25 else { continue }
            var north = -99.0, south = 99.0, bestAlt = -99.0, bestLat = 0.0, bestLon = 0.0, count = 0
            var landNorth = -99.0, landSouth = 99.0
            for k in -880...880 {
                let lat = Double(k) / 10
                guard let lon = CrescentRules.sunsetLongitude(at: midnight, latitude: lat) else { continue }
                let loc = Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)
                let geo = Astronomical.lunarHorizontal(midnight, location: loc).altitude
                guard geo >= 4 else { continue }
                let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: midnight)
                let app = tp + Astronomical.refraction(atTrueAltitude: tp)
                if app > bestAlt { bestAlt = app; bestLat = lat; bestLon = lon }
                guard app >= 5 else { continue }
                count += 1; north = max(north, lat); south = min(south, lat)
                _ = landNorth; _ = landSouth
            }
            print(String(format: "BAND|AH %d-%02d|%@|elong %+.3f|pass lat %.1f..%.1f (%d pts)|best alt %+.2f at %.1f,%.1f|conj-%.1fh", idx / 12, idx % 12 + 1,
                         s - p == 29 ? "STARTED" : "no", e, south, north, count, bestAlt - 5, bestLat, bestLon, (midnight.inner - conj.inner) * 24))
        }
    }
}

/// 2017+ exception candidates: first-visibility place, and at FV + 0, 0.5, 1 ... 6 h whether the sunset-line segment
/// that meets the criterion crosses the American mainland (east of the west coast, lon -170..-30, on land rows).
/// Env: DIYANET_HISTORY, DIYANET_CSV, LAND_ROWS.
@Suite struct CrescentDiyanetTimeProfile {
    @Test func profile() {
        let env = ProcessInfo.processInfo.environment
        guard let starts = loadStartsFromEnv(env), let lp = env["LAND_ROWS"] else { return }
        let land = CrescentDiyanetLand.loadLand(lp)
        func onLand(_ lat: Double, _ lon: Double) -> Bool {
            let row = land[Int((lat * 4).rounded())] ?? []
            var i = 0; while i + 1 < row.count { if lon >= row[i] && lon <= row[i + 1] { return true }; i += 2 }
            return false
        }
        let apparent: (Double, Moment) -> Double = { geo, t in
            let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: t); return tp + Astronomical.refraction(atTrueAltitude: tp) }
        let y2017 = rd(2017, 1, 1)
        for idx in starts.keys.sorted() {
            guard let p = starts[idx - 1], let s = starts[idx], s >= y2017 else { continue }
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29))
            let r = CrescentRules.diyanet(day)
            guard !(r.beforeMidnight["none/apparent"] ?? false), r.conjunctionBeforeWellingtonDawn else { continue }
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            guard midnight.inner + 0.5 - conj.inner < 3, let (fv, _) = CrescentDiyanetMaps.firstVisibility(conjunction: conj, altitude: apparent) else { continue }
            // FV place: best apparent altitude on the sunset line at fv.
            var fvLat = 0.0, fvLon = 0.0, fvBest = -99.0
            for k in -352...352 {
                let lat = Double(k) / 4
                guard let lon = CrescentRules.sunsetLongitude(at: fv, latitude: lat) else { continue }
                let geo = Astronomical.lunarHorizontal(fv, location: Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)).altitude
                guard geo >= 4 else { continue }
                let a = apparent(geo, fv); if a > fvBest { fvBest = a; fvLat = lat; fvLon = lon }
            }
            var cols: [String] = []
            for h in stride(from: 0.0, through: 6.0, by: 0.5) {
                let t = fv + h / 24
                guard Astronomical.geocentricElongation(t) >= 8 else { cols.append("-"); continue }
                var segN = -99.0, segS = 99.0, mainN = -99.0, mainS = 99.0, mainBest = -99.0
                for k in -352...352 {
                    let lat = Double(k) / 4
                    guard let lon = CrescentRules.sunsetLongitude(at: t, latitude: lat) else { continue }
                    let geo = Astronomical.lunarHorizontal(t, location: Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)).altitude
                    guard geo >= 4 else { continue }
                    let a = apparent(geo, t) - 5
                    guard a >= 0 else { continue }
                    segN = max(segN, lat); segS = min(segS, lat)
                    if lon > -170 && lon < -30 && CrescentRules.isEastOfAmericanWestCoast(latitude: lat, longitude: lon) && onLand(lat, lon) {
                        mainN = max(mainN, lat); mainS = min(mainS, lat); mainBest = max(mainBest, a)
                    }
                }
                if segN < -90 { cols.append("none") }
                else if mainN < -90 { cols.append(String(format: "%.0f..%.0f", segS, segN)) }
                else { cols.append(String(format: "%.0f..%.0f MAIN %.0f..%.0f %+.2f", segS, segN, mainS, mainN, mainBest)) }
            }
            print(String(format: "TP|AH %d-%02d|%@|FV %+.2f h at %.1f,%.1f|%@", idx / 12, idx % 12 + 1, s - p == 29 ? "STARTED" : "no",
                         (fv.inner - midnight.inner) * 24, fvLat, fvLon, cols.joined(separator: " | ")))
        }
    }
}

/// Our dawn (sun 18 and 19 degrees below) and sunrise at Wellington for November 2026, in UTC and NZDT (UTC+13),
/// to compare with Diyanet's published imsak. Always runs (no env).
@Suite struct CrescentDiyanetWellingtonDawn {
    @Test func november2026() {
        let w = CrescentRules.wellington
        for d in 1...30 {
            let day = rd(2026, 11, d)
            // Local morning of `day` NZDT (UTC+13) starts at day-1 11:00 UTC; search dawn after day-1 12:00 UTC.
            let start = Moment(Double(day) - 0.5)
            var parts: [String] = []
            for dep in [18.0, 19.0, 20.0] {
                if let t = Astronomical.dawnUT(after: start, location: w, depression: dep) {
                    let local = t.inner + 13.0 / 24
                    let s = Int(((local - floor(local)) * 86400).rounded())
                    parts.append(String(format: "dawn%.0f %02d:%02d:%02d", dep, s / 3600, (s % 3600) / 60, s % 60))
                }
            }
            if let dawn = Astronomical.dawnUT(after: start, location: w, depression: 18),
               let rise = Astronomical.crossing(from: dawn, to: dawn + 3.0 / 24, target: -50.0 / 60, rising: true, { Astronomical.solarHorizontal($0, location: w).altitude }) {
                let local = rise.inner + 13.0 / 24
                let s = Int(((local - floor(local)) * 86400).rounded())
                parts.append(String(format: "sunrise %02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60))
            }
            print("WD|2026-11-\(String(format: "%02d", d))|NZDT|\(parts.joined(separator: "|"))")
        }
    }
}

/// Our dawn (18/19/20 degrees) and sunrise at Ankara, 7-11 Nov 2026, local time UTC+3, against Diyanet's imsak/güneş.
@Suite struct CrescentDiyanetAnkaraDawn {
    @Test func november2026() {
        let ankara = Location(latitude: 39.9334, longitude: 32.8597, elevation: 0, utcOffset: 3.0 / 24)
        for d in 7...11 {
            let day = rd(2026, 11, d)
            let start = Moment(Double(day) - 3.0 / 24 - 0.25)   // local midnight minus 6 h
            var parts: [String] = []
            for dep in [18.0, 19.0, 20.0] {
                if let t = Astronomical.dawnUT(after: start, location: ankara, depression: dep) {
                    let local = t.inner + 3.0 / 24
                    let s = Int(((local - floor(local)) * 86400).rounded())
                    parts.append(String(format: "dawn%.0f %02d:%02d:%02d", dep, s / 3600, (s % 3600) / 60, s % 60))
                }
            }
            if let dawn = Astronomical.dawnUT(after: start, location: ankara, depression: 18),
               let rise = Astronomical.crossing(from: dawn, to: dawn + 3.0 / 24, target: -50.0 / 60, rising: true, { Astronomical.solarHorizontal($0, location: ankara).altitude }) {
                let local = rise.inner + 3.0 / 24
                let s = Int(((local - floor(local)) * 86400).rounded())
                parts.append(String(format: "sunrise %02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60))
            }
            print("AD|2026-11-\(String(format: "%02d", d))|UTC+3|\(parts.joined(separator: "|"))")
        }
    }
}

/// Final scored run, AH 1399 onwards, with the period rules: A (calendar year of the first day <= 2008) before 00:00 UTC;
/// B (2009-2013) also a start if, after 00:00 UTC, the criterion is met at a sunset west of 30 W at latitude >= 10 N
/// (best place per latitude: just east of the date line); C (2014-2016) no exception; D (2017+) the 2016 rule.
/// Env: DIYANET_HISTORY, DIYANET_CSV.
@Suite struct CrescentDiyanetFinalScore {
    @Test func score() {
        guard let starts = loadStartsFromEnv(ProcessInfo.processInfo.environment) else { return }
        let y2009 = rd(2009, 1, 1), y2014 = rd(2014, 1, 1), y2017 = rd(2017, 1, 1)
        var hits = 0, total = 0, perPeriod: [String: (Int, Int)] = [:]
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            total += 1
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29))
            let period = s < y2009 ? "A" : (s < y2014 ? "B" : (s < y2017 ? "C" : "D"))
            let r = CrescentRules.diyanet(day)
            let main = r.beforeMidnight["none/apparent"] ?? false
            var bLate = false
            if period == "B" && !main {
                let conj = Astronomical.newMoonBefore(midnight + 0.5)
                if midnight.inner + 0.5 - conj.inner < 3 {
                    for k in 40...352 {   // 10 N .. 88 N
                        let loc = Location(latitude: Double(k) / 4, longitude: -179.999, elevation: 0, utcOffset: 0)
                        guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss >= midnight, ss > conj, ss - conj < 3,
                              Astronomical.geocentricElongation(ss) >= 8 else { continue }
                        let geo = Astronomical.lunarHorizontal(ss, location: loc).altitude
                        guard geo >= 4 else { continue }
                        let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: ss)
                        if tp + Astronomical.refraction(atTrueAltitude: tp) >= 5 { bLate = true; break }
                    }
                }
            }
            let exc = period == "D" && (r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn
            let predicts = main || bLate || exc, started = s - p == 29
            let t = perPeriod[period] ?? (0, 0)
            perPeriod[period] = (t.0 + (predicts == started ? 1 : 0), t.1 + 1)
            if predicts == started { hits += 1 } else {
                let g = s - rd(2000, 1, 1)
                print("FMISS|\(period)|AH \(idx / 12)-\(String(format: "%02d", idx % 12 + 1))|official \(started ? "29d" : "30d") rule \(predicts ? "29d" : "30d")|first day = 2000-01-01 + \(g) d|main \(main) bLate \(bLate) america \(r.americas["none/apparent"] ?? false) wellington \(r.conjunctionBeforeWellingtonDawn)")
            }
        }
        for k in perPeriod.keys.sorted() { print("FRESULT|period \(k)|\(perPeriod[k]!.0)/\(perPeriod[k]!.1)") }
        print("FRESULT|all|\(hits)/\(total)")
    }
}

/// Umm al-Qura (ICU table) first days for the five Diyanet misses, as "days since 2000-01-01" and Gregorian.
@Suite struct CrescentDiyanetUmmAlQuraCheck {
    @Test func dates() throws {
        let uq = IslamicUmmAlQura()
        let cases: [(Int32, UInt8, String)] = [(1399, 9, "Diyanet 1979-07-26"), (1401, 8, "Diyanet 1981-06-04"), (1411, 5, "Diyanet 1990-11-19"),
                                               (1444, 11, "Diyanet 2023-05-21"), (1453, 12, "Diyanet 2032-03-13")]
        for (y, m, note) in cases {
            let d = try uq.newDate(year: .extended(y), month: Month(integerLiteral: m), day: 1)
            let r = uq.toRataDie(d).dayNumber
            // Gregorian from rata die (proleptic), simple algorithm.
            var days = Int(r) - 1; var year = 1
            let d400 = 146097, d100 = 36524, d4 = 1461
            year += 400 * (days / d400); days %= d400
            var n100 = days / d100; if n100 == 4 { n100 = 3 }; year += 100 * n100; days -= n100 * d100
            year += 4 * (days / d4); days %= d4
            var n1 = days / 365; if n1 == 4 { n1 = 3 }; year += n1; days -= n1 * 365
            let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
            let ml = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
            var month = 0; while days >= ml[month] { days -= ml[month]; month += 1 }
            print(String(format: "UQ|AH %d-%02d|Umm al-Qura 1st = %04d-%02d-%02d|%@", y, m, year, month + 1, days + 1, note))
        }
    }
}

/// Is Diyanet's first day the later of (our period rule) and (the Umm al-Qura first day of the same month)?
/// Env: DIYANET_HISTORY, DIYANET_CSV.
@Suite struct CrescentDiyanetUmmAlQuraBound {
    @Test func score() throws {
        guard let starts = loadStartsFromEnv(ProcessInfo.processInfo.environment) else { return }
        let uq = IslamicUmmAlQura()
        let y2009 = rd(2009, 1, 1), y2014 = rd(2014, 1, 1), y2017 = rd(2017, 1, 1)
        var total = 0, ruleHits = 0, boundHits = 0, uqEqualsD = 0, uqLater = 0, uqEarlier = 0
        for idx in starts.keys.sorted() where idx >= 1399 * 12 {
            guard let p = starts[idx - 1], let s = starts[idx] else { continue }
            total += 1
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29))
            let period = s < y2009 ? "A" : (s < y2014 ? "B" : (s < y2017 ? "C" : "D"))
            let r = CrescentRules.diyanet(day)
            let main = r.beforeMidnight["none/apparent"] ?? false
            var bLate = false
            if period == "B" && !main {
                let conj = Astronomical.newMoonBefore(midnight + 0.5)
                if midnight.inner + 0.5 - conj.inner < 3 {
                    for k in 40...352 {
                        let loc = Location(latitude: Double(k) / 4, longitude: -179.999, elevation: 0, utcOffset: 0)
                        guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss >= midnight, ss > conj, ss - conj < 3,
                              Astronomical.geocentricElongation(ss) >= 8 else { continue }
                        let geo = Astronomical.lunarHorizontal(ss, location: loc).altitude
                        guard geo >= 4 else { continue }
                        let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: ss)
                        if tp + Astronomical.refraction(atTrueAltitude: tp) >= 5 { bLate = true; break }
                    }
                }
            }
            let exc = period == "D" && (r.americas["none/apparent"] ?? false) && r.conjunctionBeforeWellingtonDawn
            let ruleDay = p + ((main || bLate || exc) ? 29 : 30)
            let u = uq.toRataDie(try uq.newDate(year: .extended(Int32(idx / 12)), month: Month(integerLiteral: UInt8(idx % 12 + 1)), day: 1)).dayNumber
            let bound = max(ruleDay, u)
            if ruleDay == s { ruleHits += 1 }
            if bound == s { boundHits += 1 }
            if u == s { uqEqualsD += 1 } else if u > s { uqLater += 1 } else { uqEarlier += 1 }
            let tag = String(format: "AH %d-%02d", idx / 12, idx % 12 + 1)
            if u != s || ruleDay != s {
                print("UQB|\(period)|\(tag)|Diyanet-rule \(s - ruleDay) d|UQ-Diyanet \(u - s) d|bound \(bound == s ? "ok" : "MISS")|first day 2000-01-01+\(s - rd(2000, 1, 1))")
            }
        }
        print("UQBRESULT|total \(total)|rule \(ruleHits)|later-of(rule, UQ) \(boundHits)|UQ==Diyanet \(uqEqualsD)|UQ later \(uqLater)|UQ earlier \(uqEarlier)")
    }
}

/// Announced first days (moonsighting.com compilation, normalised CSV) against the first day predicted at a national
/// reference point under several visibility rules, plus ICU's conjunction clock. Env: ANNOUNCED_CSV.
@Suite struct CrescentAnnouncementsProbe {
    static func loc(_ lat: Double, _ lon: Double, _ tz: Double) -> Location { Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: tz / 24) }
    static let places: [String: Location] = [
        "Pakistan": loc(24.86, 67.01, 5), "Morocco": loc(34.02, -6.84, 0), "Oman": loc(23.59, 58.41, 4), "India": loc(28.61, 77.21, 5.5),
        "Bangladesh": loc(23.81, 90.41, 6), "Iran": loc(35.69, 51.39, 3.5), "Egypt": loc(30.04, 31.24, 2), "Saudi Arabia": loc(24.71, 46.68, 3),
        "Indonesia": loc(-6.21, 106.85, 7), "Malaysia": loc(3.14, 101.69, 8), "Turkey": loc(39.93, 32.86, 3), "Algeria": loc(36.75, 3.06, 1),
        "Tunisia": loc(36.81, 10.18, 1), "Libya": loc(32.89, 13.19, 2), "Nigeria": loc(9.06, 7.49, 1), "South Africa": loc(-33.93, 18.42, 2),
        "Brunei": loc(4.89, 114.94, 8), "Sri Lanka": loc(6.93, 79.85, 5.5), "Jordan": loc(31.95, 35.93, 3), "Kuwait": loc(29.38, 47.99, 3),
        "Australia": loc(-31.95, 115.86, 8), "UK": loc(51.51, -0.13, 0), "USA": loc(38.9, -77.04, -5), "Canada": loc(43.65, -79.38, -5),
        "New Zealand": loc(-36.85, 174.76, 12), "Nepal": loc(27.72, 85.32, 5.75), "Mauritius": loc(-20.16, 57.5, 4), "Kenya": loc(-1.29, 36.82, 3),
        "Tanzania": loc(-6.79, 39.28, 3), "Senegal": loc(14.69, -17.44, 0), "Ghana": loc(5.6, -0.19, 0), "Guyana": loc(6.8, -58.16, -4),
        "Trinidad": loc(10.65, -61.52, -4), "Barbados": loc(13.1, -59.61, -4), "Yemen": loc(15.37, 44.19, 3), "Sudan": loc(15.5, 32.56, 2),
        "Iraq": loc(33.31, 44.37, 3), "Syria": loc(33.51, 36.29, 3), "Lebanon": loc(33.89, 35.5, 3), "Palestine": loc(31.9, 35.2, 2),
        "Qatar": loc(25.29, 51.53, 3), "Bahrain": loc(26.23, 50.59, 3), "UAE": loc(24.45, 54.38, 4), "Afghanistan": loc(34.53, 69.17, 4.5),
        "Chile": loc(-33.45, -70.67, -4), "Argentina": loc(-34.6, -58.38, -3), "Namibia": loc(-22.56, 17.08, 2), "Zambia": loc(-15.39, 28.32, 2),
        "Zimbabwe": loc(-17.83, 31.05, 2), "Mozambique": loc(-25.97, 32.57, 2), "Maldives": loc(4.18, 73.51, 5), "Somalia": loc(2.05, 45.32, 3),
    ]
    static let names = ["mabims", "diyanet58", "uqMoonset", "odehB", "odehA", "icu"]

    /// Predicted first day (RD) per rule for the lunation whose conjunction precedes `announced`.
    static func predictions(announced: Int64, at place: Location) -> [String: Int64] {
        let conj = Astronomical.newMoonBefore(Moment(Double(announced) + 0.5))
        var out: [String: Int64] = ["icu": Int64(ceil(conj.inner))]   // ICU: the day whose 00:00 UTC is the first after the conjunction
        let first = Int64(floor(conj.inner)) - 1
        func odehV(_ e: CrescentRules.Evening) -> Double? {
            guard let ms = e.moonset, ms > e.sunset else { return nil }
            let tb = e.sunset + (ms - e.sunset) * 4 / 9
            let moon = Astronomical.topocentricLunarHorizontal(tb, location: place).altitude
            let sun = Astronomical.solarHorizontal(tb, location: place).altitude
            let arcl = Astronomical.topocentricElongation(tb, location: place)
            let sdArcmin = 0.2725 * Astronomical.lunarParallaxHorizontal(tb) * 60
            let w = sdArcmin * (1 - cos(arcl * .pi / 180))
            return (moon - sun) - (-0.1018 * w * w * w + 0.7319 * w * w - 6.3226 * w + 7.1651)
        }
        var found: Set<String> = []
        for d in first...(first + 5) {
            guard let e = CrescentRules.evening(RataDie(d), at: place) else { continue }
            let after = e.conjunction < e.sunset && e.sunset - e.conjunction < 3 && e.conjunction.inner > conj.inner - 0.01
            if !after { continue }
            let v = odehV(e)
            let tests: [(String, Bool)] = [
                ("mabims", e.altitudeApparent >= 3 && e.elongationGeocentric >= 6.4),
                ("diyanet58", e.altitudeApparent >= 5 && e.elongationGeocentric >= 8),
                ("uqMoonset", (e.moonset.map { $0 > e.sunset } ?? false)),
                ("odehB", (v ?? -99) >= 2), ("odehA", (v ?? -99) >= 5.65),
            ]
            for (n, ok) in tests where ok && !found.contains(n) { found.insert(n); out[n] = d + 1 }
            if found.count == 5 { break }
        }
        return out
    }

    @Test func measure() {
        guard let path = ProcessInfo.processInfo.environment["ANNOUNCED_CSV"], let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        var lines = text.split(whereSeparator: \.isNewline).map(String.init)
        let header = lines.removeFirst().split(separator: ",").map(String.init)
        func col(_ n: String) -> Int { header.firstIndex(of: n)! }
        // naive CSV split honouring quotes
        func fields(_ s: String) -> [String] {
            var out: [String] = [], cur = "", q = false
            for ch in s { if ch == "\"" { q.toggle() } else if ch == "," && !q { out.append(cur); cur = "" } else { cur.append(ch) } }
            out.append(cur); return out
        }
        var tally: [String: [String: [Int: Int]]] = [:]   // country -> rule -> delta -> count
        var seen: Set<String> = []
        for line in lines {
            let f = fields(line)
            guard f.count == header.count, f[col("subgroup")] == "no" else { continue }
            let country = f[col("country_key")]
            guard let place = Self.places[country] else { continue }
            let g = f[col("first_day")].split(separator: "-").compactMap { Int($0) }
            guard g.count == 3 else { continue }
            let key = "\(country)|\(f[col("ah_year")])|\(f[col("ah_month")])"
            guard !seen.contains(key) else { continue }   // first row per country-month
            seen.insert(key)
            let announced = rd(g[0], g[1], g[2])
            let p = Self.predictions(announced: announced, at: place)
            for n in Self.names {
                let delta = p[n].map { Int(announced - $0) } ?? 99
                tally[country, default: [:]][n, default: [:]][delta, default: 0] += 1
            }
        }
        print("ANSUM|country|n|" + Self.names.map { "\($0): exact/+1/-1/other" }.joined(separator: "|"))
        var grand: [String: [Int: Int]] = [:]
        for country in tally.keys.sorted() {
            let n = tally[country]![Self.names[0]]!.values.reduce(0, +)
            var cells: [String] = []
            for r in Self.names {
                let d = tally[country]![r] ?? [:]
                let exact = d[0] ?? 0, plus = d[1] ?? 0, minus = d[-1] ?? 0
                cells.append("\(exact)/\(plus)/\(minus)/\(n - exact - plus - minus)")
                for (k, v) in d { grand[r, default: [:]][k, default: 0] += v }
            }
            print("ANSUM|\(country)|\(n)|" + cells.joined(separator: "|"))
        }
        let total = grand[Self.names[0]]!.values.reduce(0, +)
        print("ANALL|all listed countries|\(total)|" + Self.names.map { r in let d = grand[r]!; return "\(d[0] ?? 0)/\(d[1] ?? 0)/\(d[-1] ?? 0)/\(total - (d[0] ?? 0) - (d[1] ?? 0) - (d[-1] ?? 0))" }.joined(separator: "|"))
    }
}

/// Exports the astronomy cross-check fixture for the port: per decision evening, the quantities our engine computes.
/// Env: FIXTURE_OUT (csv path), ANNOUNCED_CSV, MAPS_CSV (optional).
@Suite struct CrescentFixtureExport {
    static func gregorian(_ r: Int64) -> (Int, Int, Int) {
        var days = Int(r) - 1; var year = 1
        year += 400 * (days / 146097); days %= 146097
        var n100 = days / 36524; if n100 == 4 { n100 = 3 }; year += 100 * n100; days -= n100 * 36524
        year += 4 * (days / 1461); days %= 1461
        var n1 = days / 365; if n1 == 4 { n1 = 3 }; year += n1; days -= n1 * 365
        let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
        let ml = [31, leap ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
        var month = 0; while days >= ml[month] { days -= ml[month]; month += 1 }
        return (year, month + 1, days + 1)
    }
    static func date(_ r: Int64) -> String { let g = gregorian(r); return String(format: "%04d-%02d-%02d", g.0, g.1, g.2) }
    static func utc(_ m: Moment?) -> String {
        guard let m else { return "" }
        let day = Int64(floor(m.inner)); let s = Int(((m.inner - floor(m.inner)) * 86400).rounded())
        return date(day) + String(format: " %02d:%02d:%02d", s / 3600, (s % 3600) / 60, s % 60)
    }
    static func f(_ x: Double?, _ digits: Int = 3) -> String { x.map { String(format: "%.\(digits)f", $0) } ?? "" }

    @Test func export() {
        let env = ProcessInfo.processInfo.environment
        guard let outPath = env["FIXTURE_OUT"] else { return }
        var lines = ["kind,authority_or_country,ah_year,ah_month,evening_utc_date,published_or_announced,rule_days,conjunction_utc,sunset_utc,moonset_utc,alt_apparent,alt_geocentric,alt_topocentric,elong_geocentric,elong_topocentric,odeh_v,extra1,extra2,extra3,extra4"]
        let csv = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("crescent_official_dates.csv").path
        let official = (try? String(contentsOfFile: csv, encoding: .utf8)) ?? ""
        func starts(_ rule: String, _ scope: String) -> [Int: Int64] {
            var s: [Int: Int64] = [:]
            for line in official.split(whereSeparator: \.isNewline).dropFirst() {
                let fl = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
                guard fl.count >= 5, fl[0] == rule, fl[1] == scope, let y = Int(fl[2]), let m = Int(fl[3]) else { continue }
                let g = fl[4].split(separator: "-").compactMap { Int($0) }; if g.count == 3 { s[y * 12 + m - 1] = s[y * 12 + m - 1] ?? rd(g[0], g[1], g[2]) }
            }
            return s
        }
        // Diyanet: every decision, the 00:00 UTC sunset-line maximum, Wellington dawn, and for 2017+ the best mainland point.
        let dy = starts("diyanet", "diyanet")
        for idx in dy.keys.sorted() where idx >= 1399 * 12 {
            guard let p = dy[idx - 1], let s = dy[idx] else { continue }
            let day = RataDie(p + 28), midnight = Moment(Double(p + 29)), next = (year: idx / 12, month: idx % 12 + 1)
            let conj = Astronomical.newMoonBefore(midnight + 0.5)
            let e0 = Astronomical.geocentricElongation(midnight)
            var bestAlt = -99.0, bestLat = 0.0, bestLon = 0.0
            if midnight > conj, midnight.inner - conj.inner < 3 {
                for k in -880...880 {
                    let lat = Double(k) / 10
                    guard let lon = CrescentRules.sunsetLongitude(at: midnight, latitude: lat) else { continue }
                    let geo = Astronomical.lunarHorizontal(midnight, location: Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: 0)).altitude
                    guard geo >= 3 else { continue }
                    let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: midnight); let app = tp + Astronomical.refraction(atTrueAltitude: tp)
                    if app > bestAlt { bestAlt = app; bestLat = lat; bestLon = lon }
                }
            }
            let dawn = Astronomical.dawnUT(after: Moment(Double(p + 28) + 0.25), location: CrescentRules.wellington, depression: 18)
            var mainland = ""
            if CrescentRules.DiyanetEra(firstDay: RataDie(p + 29)) == .from2017, Astronomical.geocentricElongation(midnight + 0.5) >= 8 {
                var best = (-99.0, 0.0, 0.0, Moment(0))
                for (i, lon) in CrescentRules.americanWestCoast.enumerated() {
                    let loc = Location(latitude: 71.95 - 0.05 * Double(i), longitude: lon, elevation: 0, utcOffset: 0)
                    guard let ss = Astronomical.sunsetUT(nearLocalNoonOf: day, location: loc), ss >= midnight, ss > conj, ss - conj < 3 else { continue }
                    let el = Astronomical.geocentricElongation(ss) - 8; guard el > -1 else { continue }
                    let geo = Astronomical.lunarHorizontal(ss, location: loc).altitude; let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: ss)
                    let m = min(el, tp + Astronomical.refraction(atTrueAltitude: tp) - 5)
                    if m > best.0 { best = (m, loc.latitude, lon, ss) }
                }
                mainland = "mainland margin \(Self.f(best.0)) at \(Self.f(best.1, 2)),\(Self.f(best.2, 3)) sunset \(Self.utc(best.3))"
            }
            let rule = CrescentRules.diyanetMonthLength(start: RataDie(p), next: next, corrections: false)
            lines.append("diyanet,TR,\(next.year),\(next.month),\(Self.date(p + 28)),\(s - p),\(rule),\(Self.utc(conj)),,,\(Self.f(bestAlt)),,,\(Self.f(e0)),,,00utc line max at \(Self.f(bestLat, 1)) \(Self.f(bestLon, 2)),wellington dawn18 \(Self.utc(dawn)),\(mainland),era \(CrescentRules.DiyanetEra(firstDay: RataDie(p + 29)))")
        }
        // Umm al-Qura at the Kaaba.
        let uq = starts("ummalqura", "ummalqura")
        for idx in uq.keys.sorted() {
            guard let p = uq[idx - 1], let s = uq[idx], let e = CrescentRules.evening(RataDie(p + 28), at: CrescentRules.makkah) else { continue }
            let rule = CrescentRules.ummAlQuraMonthLength(start: RataDie(p), next: (idx / 12, idx % 12 + 1), corrections: false)
            lines.append("ummalqura,SA,\(idx / 12),\(idx % 12 + 1),\(Self.date(p + 28)),\(s - p),\(rule),\(Self.utc(e.conjunction)),\(Self.utc(e.sunset)),\(Self.utc(e.moonset)),\(Self.f(e.altitudeApparent)),\(Self.f(e.altitudeGeocentric)),\(Self.f(e.altitudeTopocentric)),\(Self.f(e.elongationGeocentric)),\(Self.f(e.elongationTopocentric)),,lag min \(Self.f(e.lagMinutes, 2)),,,")
        }
        // Malaysia at the official point, Indonesia at Banda Aceh.
        let my = starts("mabims", "Malaysia")
        for idx in my.keys.sorted() {
            guard let p = my[idx - 1], let s = my[idx] else { continue }
            let next = (year: idx / 12, month: idx % 12 + 1), place = next.year >= 1444 ? CrescentRules.pulauPerak : CrescentRules.tanjungChinchin
            guard let e = CrescentRules.evening(RataDie(p + 28), at: place) else { continue }
            let v = CrescentRules.malaysiaValues(RataDie(p + 28), at: place, CrescentRules.MalaysiaOptions(elongationFromApparent: true))
            let rule = HijriRegional.malaysiaMonthLength(start: RataDie(p), next: next, corrections: false)
            lines.append("malaysia,MY,\(next.year),\(next.month),\(Self.date(p + 28)),\(s - p),\(rule),\(Self.utc(e.conjunction)),\(Self.utc(e.sunset)),\(Self.utc(e.moonset)),\(Self.f(e.altitudeApparent)),\(Self.f(e.altitudeGeocentric)),\(Self.f(e.altitudeTopocentric)),\(Self.f(e.elongationGeocentric)),\(Self.f(e.elongationTopocentric)),,place \(next.year >= 1444 ? "Pulau Perak" : "Tanjung Chinchin"),rule altitude \(Self.f(v?.altitude)),rule elongation(refracted) \(Self.f(v?.elongation)),criterion \((p + 29) >= 738156 ? "2021" : "1992")")
        }
        let id = starts("mabims", "Indonesia")
        for idx in id.keys.sorted() {
            guard let p = id[idx - 1], let s = id[idx], let e = CrescentRules.evening(RataDie(p + 28), at: CrescentRules.bandaAceh) else { continue }
            let next = (year: idx / 12, month: idx % 12 + 1)
            let rule = HijriRegional.indonesiaMonthLength(start: RataDie(p), next: next)
            lines.append("indonesia,ID,\(next.year),\(next.month),\(Self.date(p + 28)),\(s - p),\(rule),\(Self.utc(e.conjunction)),\(Self.utc(e.sunset)),\(Self.utc(e.moonset)),\(Self.f(e.altitudeApparent)),\(Self.f(e.altitudeGeocentric)),\(Self.f(e.altitudeTopocentric)),\(Self.f(e.elongationGeocentric)),\(Self.f(e.elongationTopocentric)),,Banda Aceh geocentric,,,")
        }
        // Visibility countries: the evening the dispatcher predicts, with the Odeh value there.
        if let ap = env["ANNOUNCED_CSV"], let text = try? String(contentsOfFile: ap, encoding: .utf8) {
            let iso: [String: String] = ["Pakistan": "PK", "Morocco": "MA", "Oman": "OM", "India": "IN", "Bangladesh": "BD", "Iran": "IR", "South Africa": "ZA", "Sri Lanka": "LK", "Mauritius": "MU", "Tanzania": "TZ", "Kenya": "KE", "Australia": "AU", "New Zealand": "NZ", "Nigeria": "NG", "Brunei": "BN", "Trinidad": "TT", "Guyana": "GY", "Barbados": "BB", "Chile": "CL", "Namibia": "NA", "Zimbabwe": "ZW", "Zambia": "ZM", "Mozambique": "MZ", "Senegal": "SN", "Ghana": "GH", "Nepal": "NP", "Maldives": "MV"]
            var rows = text.split(whereSeparator: \.isNewline).map(String.init); let header = rows.removeFirst().split(separator: ",").map(String.init)
            func col(_ n: String) -> Int { header.firstIndex(of: n)! }
            func fields(_ s: String) -> [String] { var out: [String] = [], cur = "", q = false; for ch in s { if ch == "\"" { q.toggle() } else if ch == "," && !q { out.append(cur); cur = "" } else { cur.append(ch) } }; out.append(cur); return out }
            var seen: Set<String> = []
            for line in rows {
                let fl = fields(line); guard fl.count == header.count, fl[col("subgroup")] == "no", let code = iso[fl[col("country_key")]] else { continue }
                let y = Int(fl[col("ah_year")])!, m = Int(fl[col("ah_month")])!; let key = "\(code)|\(y)|\(m)"; guard !seen.contains(key) else { continue }; seen.insert(key)
                let g = fl[col("first_day")].split(separator: "-").compactMap { Int($0) }; guard g.count == 3 else { continue }
                let announced = rd(g[0], g[1], g[2]); let method = HijriRegional.method(forRegion: code)
                guard case .visibility(let place, let minimum) = method else { continue }
                let conj = Astronomical.newMoonBefore(Moment(Double(announced) + 0.5)); let first = Int64(floor(conj.inner)) - 1
                var predicted: Int64? = nil
                for ev in first...(first + 5) where (HijriRegional.odehValue(evening: RataDie(ev), at: place) ?? -99) >= minimum { predicted = ev + 1; break }
                let ev = (predicted ?? announced) - 1
                let e = CrescentRules.evening(RataDie(ev), at: place); let v = HijriRegional.odehValue(evening: RataDie(ev), at: place)
                lines.append("visibility,\(code),\(y),\(m),\(Self.date(ev)),\(Self.date(announced)),\(predicted.map { Self.date($0) } ?? ""),\(Self.utc(e?.conjunction)),\(Self.utc(e?.sunset)),\(Self.utc(e?.moonset)),\(Self.f(e?.altitudeApparent)),\(Self.f(e?.altitudeGeocentric)),\(Self.f(e?.altitudeTopocentric)),\(Self.f(e?.elongationGeocentric)),\(Self.f(e?.elongationTopocentric)),\(Self.f(v)),threshold \(minimum),place \(Self.f(place.latitude, 2)) \(Self.f(place.longitude, 2)),announced vs predicted,")
            }
        }
        // Diyanet's printed map times vs ours (external calibration).
        if let mp = env["MAPS_CSV"], let text = try? String(contentsOfFile: mp, encoding: .utf8) {
            var byFile: [String: (String, String)] = [:]
            for line in text.split(whereSeparator: \.isNewline).dropFirst() {
                let fl = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init); guard fl.count >= 3 else { continue }
                var cur = byFile[fl[0]] ?? ("", ""); if fl[1] == "conj" { cur.0 = fl[2] } else if fl[1] == "first" { cur.1 = fl[2] }; byFile[fl[0]] = cur
            }
            let apparent: (Double, Moment) -> Double = { geo, t in let tp = geo - Astronomical.lunarParallax(altitude: geo, moment: t); return tp + Astronomical.refraction(atTrueAltitude: tp) }
            for (file, v) in byFile.sorted(by: { $0.key < $1.key }) {
                guard let printedConj = CrescentDiyanetMaps.moment(v.0) else { continue }
                let ours = Astronomical.newMoonBefore(printedConj + 0.5)
                let fv = CrescentDiyanetMaps.firstVisibility(conjunction: ours, altitude: apparent)?.0
                lines.append("diyanet_map,TR,,,,,,\(Self.utc(ours)),,,,,,,,,printed conjunction \(v.0),printed first visibility \(v.1),our first visibility \(Self.utc(fv)),\(file)")
            }
        }
        try? lines.joined(separator: "\n").appending("\n").write(toFile: outPath, atomically: true, encoding: .utf8)
        print("FIXTURE|rows \(lines.count - 1)|\(outPath)")
    }
}

/// Our Umm al-Qura rule (conjunction before sunset, moonset after sunset at the Kaaba) against the whole KACST table
/// AH 1300–1600, with the margins of every miss. The current rule dates from AH 1420; earlier years used other rules.
@Suite struct CrescentUmmAlQuraTableSweep {
    @Test func sweep() throws {
        let uq = IslamicUmmAlQura()
        func first(_ y: Int, _ m: Int) throws -> Int64 { uq.toRataDie(try uq.newDate(year: .extended(Int32(y)), month: Month(integerLiteral: UInt8(m)), day: 1)).dayNumber }
        var eras: [String: (Int, Int)] = [:]
        var closest: [(Double, String)] = []
        for y in 1300...1600 {
            for m in 1...12 {
                if y == 1300 && m == 1 { continue }
                let (py, pm) = m == 1 ? (y - 1, 12) : (y, m - 1)
                let p = try first(py, pm), s = try first(y, m)
                let rule = CrescentRules.ummAlQuraMonthLength(start: RataDie(p), next: (y, m), corrections: false)
                let era = y >= 1420 ? "1420-1600 (current rule)" : "1300-1419 (earlier rules)"
                var t = eras[era] ?? (0, 0); t.1 += 1
                let e = CrescentRules.evening(RataDie(p + 28), at: CrescentRules.makkah)
                let lag = e?.lagMinutes, conjMargin = e.map { ($0.sunset - $0.conjunction) * 1440 }
                if rule == Int(s - p) { t.0 += 1 } else if y >= 1420 {
                    print(String(format: "UQMISS|AH %d-%02d|table %dd rule %dd|evening %@|lag %+.2f min|sunset-conjunction %+.1f min", y, m, s - p, rule, CrescentFixtureExport.date(p + 28), lag ?? .nan, conjMargin ?? .nan))
                }
                eras[era] = t
                if y >= 1420, let lag, let cm = conjMargin {
                    let tight = min(abs(lag), abs(cm))
                    if tight < 1 { closest.append((tight, String(format: "AH %d-%02d lag %+.2f min, sunset-conj %+.1f min, rule %@ table", y, m, lag, cm, rule == Int(s - p) ? "==" : "!="))) }
                }
            }
        }
        for (k, v) in eras.sorted(by: { $0.key < $1.key }) { print("UQSWEEP|\(k)|\(v.0)/\(v.1)") }
        print("UQTIES|months 1420-1600 within 1 minute of a threshold: \(closest.count)")
        for c in closest.sorted(by: { $0.0 < $1.0 }) { print("UQTIE|\(c.1)") }
    }
}

/// What is the ICU "Umm al-Qura" table outside KACST's published range? Compare its first days with the arithmetic calendars.
@Suite struct CrescentUmmAlQuraTableOrigin {
    @Test func compare() throws {
        let uq = IslamicUmmAlQura(), civil = IslamicCivil(), tabular = IslamicTabular()
        func fd<C: CalendarProtocol>(_ c: C, _ y: Int, _ m: Int) throws -> Int64 where C.DateInner == IslamicTabularDateInner {
            c.toRataDie(try c.newDate(year: .extended(Int32(y)), month: Month(integerLiteral: UInt8(m)), day: 1)).dayNumber
        }
        for (name, lo, hi) in [("1300-1355", 1300, 1355), ("1356-1419", 1356, 1419), ("1420-1450 (published)", 1420, 1450), ("1451-1500", 1451, 1500), ("1501-1600", 1501, 1600)] {
            var n = 0, sameCivil = 0, sameTab = 0, diffs: [Int: Int] = [:]
            for y in lo...hi { for m in 1...12 {
                let a = try fd(uq, y, m), b = try fd(civil, y, m), c = try fd(tabular, y, m)
                n += 1; if a == b { sameCivil += 1 }; if a == c { sameTab += 1 }; diffs[Int(a - b), default: 0] += 1
            } }
            print("UQORIGIN|\(name)|months \(n)|same as civil (Friday epoch) \(sameCivil)|same as tabular (Thursday epoch) \(sameTab)|table minus civil day histogram \(diffs.sorted(by: { $0.key < $1.key }))")
        }
    }
}

/// Which rule generated the ICU table outside 1420–1450? Candidates against the table's month lengths, per range.
@Suite struct CrescentUmmAlQuraTableRule {
    @Test func identify() throws {
        let uq = IslamicUmmAlQura()
        func first(_ y: Int, _ m: Int) throws -> Int64 { uq.toRataDie(try uq.newDate(year: .extended(Int32(y)), month: Month(integerLiteral: UInt8(m)), day: 1)).dayNumber }
        let names = ["conj<sunset & moonset>sunset (current UQ)", "moonset>sunset only (1420-22)", "conj<sunset only", "conj<Mecca midnight", "conj<00UTC", "age>=12h at Mecca sunset", "conj<12UTC (ISESCO)", "ICU islamic clock (ceil conj UTC)"]
        for (range, lo, hi) in [("1300-1355", 1300, 1355), ("1356-1419", 1356, 1419), ("1420-1450", 1420, 1450), ("1451-1500", 1451, 1500), ("1501-1600", 1501, 1600)] {
            var hits = [Int](repeating: 0, count: names.count), n = 0
            for y in lo...hi { for m in 1...12 {
                if y == 1300 && m == 1 { continue }
                let (py, pm) = m == 1 ? (y - 1, 12) : (y, m - 1)
                let p = try first(py, pm), s = try first(y, m); let len = Int(s - p); n += 1
                guard let e = CrescentRules.evening(RataDie(p + 28), at: CrescentRules.makkah) else { continue }
                let conjBeforeSunset = e.conjunction < e.sunset && e.sunset - e.conjunction < 3
                let moonsetAfter = e.moonset.map { $0 > e.sunset } ?? false
                let midnightMecca = Moment(Double(p + 29) - 3.0 / 24)   // 00:00 Mecca = 21:00 UTC of the evening's date
                let midnightUTC = Moment(Double(p + 29))
                let conj = Astronomical.newMoonBefore(midnightUTC + 0.5)
                let preds = [conjBeforeSunset && moonsetAfter, moonsetAfter, conjBeforeSunset,
                             conj < midnightMecca && midnightMecca - conj < 3, conj < midnightUTC && midnightUTC - conj < 3,
                             conjBeforeSunset && (e.sunset - e.conjunction) * 24 >= 12,
                             conj < Moment(Double(p + 28) + 0.5) && Moment(Double(p + 28) + 0.5) - conj < 3,
                             Int64(ceil(conj.inner)) == p + 29]
                for (i, pr) in preds.enumerated() where (pr ? 29 : 30) == len { hits[i] += 1 }
            } }
            print("UQRULE|\(range)|months \(n)|" + zip(names, hits).map { "\($0): \($1) (\(100 * $1 / max(n, 1))%)" }.joined(separator: " | "))
        }
    }
}

/// Moon-age variants against the ICU table outside 1420–1450: age measured at Mecca sunset, Mecca midnight, 00 UTC,
/// 12 UTC, with thresholds 0–24 h; also the same with the mean conjunction (mean synodic month from a fixed epoch).
@Suite struct CrescentUmmAlQuraTableAgeSweep {
    @Test func sweep() throws {
        let uq = IslamicUmmAlQura()
        func first(_ y: Int, _ m: Int) throws -> Int64 { uq.toRataDie(try uq.newDate(year: .extended(Int32(y)), month: Month(integerLiteral: UInt8(m)), day: 1)).dayNumber }
        let thresholds: [Double] = [0, 6, 8, 10, 11, 12, 13, 14, 15, 16, 18, 20, 22, 24]
        let moments = ["Mecca sunset", "Mecca midnight", "00 UTC", "12 UTC", "Mecca noon"]
        for (range, lo, hi) in [("1356-1419", 1356, 1419), ("1451-1600", 1451, 1600)] {
            var hits = [[Int]](repeating: [Int](repeating: 0, count: thresholds.count), count: moments.count), n = 0
            var meanHits = [Int](repeating: 0, count: thresholds.count)
            for y in lo...hi { for m in 1...12 {
                let (py, pm) = m == 1 ? (y - 1, 12) : (y, m - 1)
                let p = try first(py, pm), s = try first(y, m); let len = Int(s - p); n += 1
                let midnightUTC = Moment(Double(p + 29))
                let conj = Astronomical.newMoonBefore(midnightUTC + 0.5)
                guard let e = CrescentRules.evening(RataDie(p + 28), at: CrescentRules.makkah) else { continue }
                let refs = [e.sunset, Moment(Double(p + 29) - 3.0 / 24), midnightUTC, Moment(Double(p + 28) + 0.5), Moment(Double(p + 28) + 0.5 - 3.0 / 24 + 0.0)]
                for (i, r) in refs.enumerated() {
                    let age = (r - conj) * 24
                    for (j, t) in thresholds.enumerated() where ((age >= t && age < 72) ? 29 : 30) == len { hits[i][j] += 1 }
                }
                // mean conjunction: mean new moon nearest before, from epoch 2000-01-06 18:14 UTC, synodic 29.530588853 d
                let epoch = 730125.0 + 18.23 / 24
                let k = floor((midnightUTC.inner + 0.5 - epoch) / 29.530588853)
                let meanConj = epoch + k * 29.530588853
                let meanAge = (e.sunset.inner - meanConj) * 24
                for (j, t) in thresholds.enumerated() where ((meanAge >= t && meanAge < 72) ? 29 : 30) == len { meanHits[j] += 1 }
            } }
            for (i, mo) in moments.enumerated() {
                print("UQAGE|\(range)|\(mo)|" + zip(thresholds, hits[i]).map { String(format: "%.0fh:%d%%", $0, 100 * $1 / max(n, 1)) }.joined(separator: " "))
            }
            print("UQAGE|\(range)|mean conj, Mecca sunset|" + zip(thresholds, meanHits).map { String(format: "%.0fh:%d%%", $0, 100 * $1 / max(n, 1)) }.joined(separator: " "))
        }
    }
}

/// Alignment of the ICU table's month starts with the conjunction: histogram of (table first day − UTC date after the
/// conjunction) per range. The 1392–1419 rule ("new moon less than 3 h after Saudi midnight" = before 00:00 UTC) predicts 0.
@Suite struct CrescentUmmAlQuraTableAlignment {
    @Test func histogram() throws {
        let uq = IslamicUmmAlQura()
        func first(_ y: Int, _ m: Int) throws -> Int64 { uq.toRataDie(try uq.newDate(year: .extended(Int32(y)), month: Month(integerLiteral: UInt8(m)), day: 1)).dayNumber }
        for (range, lo, hi) in [("1300-1355", 1300, 1355), ("1356-1391", 1356, 1391), ("1392-1419", 1392, 1419), ("1420-1422", 1420, 1422), ("1423-1450", 1423, 1450), ("1451-1500", 1451, 1500), ("1501-1600", 1501, 1600)] {
            var hist: [Int: Int] = [:], n = 0
            for y in lo...hi { for m in 1...12 {
                let s = try first(y, m)
                let conj = Astronomical.newMoonBefore(Moment(Double(s) + 2.0))
                let clock = Int64(ceil(conj.inner))      // UTC date whose 00:00 is the first after the conjunction
                hist[Int(s - clock), default: 0] += 1; n += 1
            } }
            print("UQALIGN|\(range)|months \(n)|table first day minus (day after conjunction, UTC): " + hist.sorted(by: { $0.key < $1.key }).map { "\($0.key): \(100 * $0.value / n)%" }.joined(separator: ", "))
        }
    }
}

/// Emulates ICU's astronomical `islamic` month start (trueMonthStart: mean-month guess at 00:00 UTC from the Hijra epoch,
/// step back while the moon is past new, else forward until it is, then +1 day) with our ephemeris, and compares it
/// with the ICU "Umm al-Qura" table per range.
@Suite struct CrescentUmmAlQuraTableIsICUIslamic {
    static func moonPastNew(_ t: Moment) -> Bool {
        let c = Astronomical.julianCenturies(t)
        var dl = (Astronomical.lunarLongitude(c) - Astronomical.solarLongitude(c)).truncatingRemainder(dividingBy: 360)
        if dl < 0 { dl += 360 }
        return dl < 180
    }
    static func icuIslamicStart(year: Int, month: Int) -> Int64 {
        let hijra = 227015.0
        let index = Double((year - 1) * 12 + (month - 1))
        var t = hijra + floor(index * 29.530588853)
        if moonPastNew(Moment(t)) { repeat { t -= 1 } while moonPastNew(Moment(t)) } else { repeat { t += 1 } while !moonPastNew(Moment(t)) }
        return Int64(t) + 1
    }
    @Test func compare() throws {
        let uq = IslamicUmmAlQura()
        func first(_ y: Int, _ m: Int) throws -> Int64 { uq.toRataDie(try uq.newDate(year: .extended(Int32(y)), month: Month(integerLiteral: UInt8(m)), day: 1)).dayNumber }
        for (range, lo, hi) in [("1300-1355", 1300, 1355), ("1356-1391", 1356, 1391), ("1392-1419", 1392, 1419), ("1420-1450", 1420, 1450), ("1451-1500", 1451, 1500), ("1501-1600", 1501, 1600)] {
            var n = 0, same = 0, hist: [Int: Int] = [:]
            for y in lo...hi { for m in 1...12 {
                let s = try first(y, m), i = Self.icuIslamicStart(year: y, month: m)
                n += 1; if s == i { same += 1 }; hist[Int(s - i), default: 0] += 1
            } }
            print("UQICU|\(range)|months \(n)|table == emulated ICU islamic: \(same) (\(100 * same / n)%)|table minus emulated: " + hist.sorted(by: { $0.key < $1.key }).map { "\($0.key): \($0.value)" }.joined(separator: ", "))
        }
    }
}

/// Round 4 (2026-11-11): the other agent's two Umm al-Qura rules, evaluated with our engine against the whole ICU table,
/// AH 1300-01 to 1600-11 (the month whose length is decided labels the row). Definitions as in its code
/// (swift-foundation port/islamic-family 5396bd74, `VisibilityRule.ummAlQura` and `.ummAlQuraTable`):
/// Rule A (AH 1423 on): the new moon comes before the geometric sunset (the sun's centre at 0°, no refraction); at the
/// moment the sun's centre is 34' + dip below the horizon, the moon's topocentric centre is at or above that same line.
/// Rule B (found by it from the table; AH 1451–1600 and 1300–1419): at the geometric sunset, the new moon came before
/// 00:00 Mecca time of that day, or the moon is at least 5.5 hours old and its topocentric centre, without refraction,
/// sets at least 19.515 minutes later. Writes one row per month to the file named by UQ_ROUND4_OUT.
@Suite struct CrescentUmmAlQuraRound4Check {
    static let mecca = Location(latitude: 21.4225, longitude: 39.8256, elevation: 295, utcOffset: 3.0 / 24)

    /// Moment in [lo, hi] at which `f` falls through `target`, by bisection (far below a second), or nil.
    static func falling(from lo: Double, to hi: Double, target: Double, _ f: (Moment) -> Double) -> Moment? {
        var a = lo, b = hi
        guard f(Moment(a)) > target, f(Moment(b)) <= target else { return nil }
        for _ in 0..<60 { let mid = (a + b) / 2; if f(Moment(mid)) > target { a = mid } else { b = mid } }
        return Moment((a + b) / 2)
    }

    struct Row {
        var year = 0, month = 0, first: Int64 = 0, tableDays = 0
        var newMoon = Moment(0), geometricSunset = Moment(0)
        var ageHours = 0.0, beforeDayStartHours = 0.0, centreLagMinutes = Double.nan, marginA = Double.nan
        var ruleA = 30, ruleB = 30, ours = 30
        var ourLag: Double? = nil, ourConjunctionMargin: Double? = nil
    }

    static func row(year y: Int, month m: Int, first p: Int64, next s: Int64, lagLimit: Double = 19.515, ageLimit: Double = 5.5) -> Row? {
        let place = mecca, evening = p + 28
        let noon = Double(evening) + 0.5 - place.longitude / 360          // local mean noon, universal time
        let depression = Astronomical.refraction(place)                   // 34' + dip of the horizon at 295 m
        let sunAltitude: (Moment) -> Double = { Astronomical.solarHorizontal($0, location: place).altitude }
        let moonAltitude: (Moment) -> Double = { Astronomical.topocentricLunarHorizontal($0, location: place).altitude }
        guard let geometricSunset = falling(from: noon, to: noon + 0.5, target: 0, sunAltitude),
              let refractedSunset = falling(from: noon, to: noon + 0.5, target: -depression, sunAltitude) else { return nil }
        // The new moon that ends this month: the last one before the geometric sunset if it is recent, otherwise the next one.
        let before = Astronomical.newMoonBefore(geometricSunset)
        let recent = geometricSunset - before < 7
        let newMoon = recent ? before : Astronomical.newMoonAtOrAfter(geometricSunset)
        var r = Row()
        (r.year, r.month, r.first, r.tableDays) = (y, m, p, Int(s - p))
        (r.newMoon, r.geometricSunset) = (newMoon, geometricSunset)
        r.ageHours = (geometricSunset - newMoon) * 24
        r.beforeDayStartHours = (Double(evening) - place.utcOffset - newMoon.inner) * 24
        if let moonCentreSet = falling(from: noon + 2.0 / 24, to: noon + 0.5, target: 0, moonAltitude) {
            r.centreLagMinutes = (moonCentreSet - geometricSunset) * 1440
        }
        r.marginA = moonAltitude(refractedSunset) + depression
        r.ruleA = recent && r.marginA >= 0 ? 29 : 30
        let byLag = r.ageHours >= ageLimit && r.centreLagMinutes >= lagLimit   // NaN compares false
        let byDay = r.beforeDayStartHours > 0
        r.ruleB = recent && (byLag || byDay) ? 29 : 30
        r.ours = CrescentRules.ummAlQura(RataDie(evening), .twoConditions) ? 29 : 30
        if let e = CrescentRules.evening(RataDie(evening), at: CrescentRules.makkah) {
            r.ourLag = e.lagMinutes
            let conjunctionOfMonth = e.sunset - e.conjunction < 7 ? e.conjunction : Astronomical.newMoonAtOrAfter(e.sunset)
            r.ourConjunctionMargin = (e.sunset - conjunctionOfMonth) * 1440
        }
        return r
    }

    @Test func check() throws {
        guard let out = ProcessInfo.processInfo.environment["UQ_ROUND4_OUT"] else { return }
        let uq = IslamicUmmAlQura()
        func first(_ y: Int, _ m: Int) throws -> Int64 { uq.toRataDie(try uq.newDate(year: .extended(Int32(y)), month: Month(integerLiteral: UInt8(m)), day: 1)).dayNumber }
        var lines = ["hijri_year,hijri_month,first_day,evening,table_days,new_moon_utc,geometric_sunset_utc,age_hours,new_moon_before_day_start_hours,centre_lag_minutes,moon_margin_degrees,rule_a_days,rule_b_days,our_rule_days,our_lag_minutes,our_sunset_minus_conjunction_minutes"]
        var tally: [String: [Int]] = [:]   // era: months, rule A, rule B, our rule
        let f = CrescentFixtureExport.f
        for y in 1300...1600 {
            for m in 1...12 {
                if y == 1600 && m == 12 { continue }   // its length needs 1 Muharram 1601, outside the table
                let (ny, nm) = m == 12 ? (y + 1, 1) : (y, m + 1)
                let p = try first(y, m), s = try first(ny, nm)
                guard let r = Self.row(year: y, month: m, first: p, next: s) else { print("UQ4|no sunset|AH \(y)-\(m)"); continue }
                let era = y < 1420 ? "1300-1419" : y < 1423 ? "1420-1422" : y <= 1450 ? "1423-1450" : "1451-1600/11"
                var t = tally[era] ?? [0, 0, 0, 0]
                t[0] += 1
                if r.ruleA == r.tableDays { t[1] += 1 }
                if r.ruleB == r.tableDays { t[2] += 1 }
                if r.ours == r.tableDays { t[3] += 1 }
                tally[era] = t
                lines.append("\(y),\(m),\(CrescentFixtureExport.date(p)),\(CrescentFixtureExport.date(p + 28)),\(r.tableDays),\(CrescentFixtureExport.utc(r.newMoon)),\(CrescentFixtureExport.utc(r.geometricSunset)),\(f(r.ageHours, 4)),\(f(r.beforeDayStartHours, 4)),\(r.centreLagMinutes.isNaN ? "" : f(r.centreLagMinutes, 4)),\(f(r.marginA, 5)),\(r.ruleA),\(r.ruleB),\(r.ours),\(f(r.ourLag, 4)),\(f(r.ourConjunctionMargin, 2))")
            }
        }
        for (k, v) in tally.sorted(by: { $0.key < $1.key }) { print("UQ4|\(k)|months \(v[0])|rule A \(v[1])|rule B \(v[2])|our rule \(v[3])") }
        try lines.joined(separator: "\n").appending("\n").write(toFile: out, atomically: true, encoding: .utf8)
        print("UQ4|rows \(lines.count - 1)|\(out)")
    }

    /// The same rules against any other list of month starts (hijri_year,hijri_month,first_day as yyyy-mm-dd) named by
    /// UQ_FIRSTDAYS_CSV; used for the table in Microsoft's .NET (AH 1318–1500, MIT-licensed source). Adds the rule
    /// documented for AH 1392–1419 (van Gent): the month starts on the day after the UTC date of the new moon.
    @Test func otherTable() throws {
        guard let path = ProcessInfo.processInfo.environment["UQ_FIRSTDAYS_CSV"], let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        var firstDay: [Int: Int64] = [:]   // year * 12 + month - 1
        for line in text.split(whereSeparator: \.isNewline).dropFirst() {
            let f = line.split(separator: ","); guard f.count >= 3, let y = Int(f[0]), let m = Int(f[1]) else { continue }
            let d = f[2].split(separator: "-").compactMap { Int($0) }; guard d.count == 3 else { continue }
            firstDay[y * 12 + m - 1] = rd(d[0], d[1], d[2])
        }
        var tally: [String: [Int]] = [:]   // era: months, rule A, rule B, our rule, day after the new moon's UTC date
        for key in firstDay.keys.sorted() {
            guard let p = firstDay[key], let s = firstDay[key + 1] else { continue }
            let y = key / 12, m = key % 12 + 1
            guard let r = Self.row(year: y, month: m, first: p, next: s) else { continue }
            let utcClock = r.newMoon.inner < Double(p + 29) ? 29 : 30
            let era = y < 1356 ? "1318-1355" : y < 1392 ? "1356-1391" : y < 1420 ? "1392-1419" : y < 1423 ? "1420-1422" : y <= 1450 ? "1423-1450" : "1451-1500"
            var t = tally[era] ?? [0, 0, 0, 0, 0]
            t[0] += 1
            if r.ruleA == r.tableDays { t[1] += 1 }
            if r.ruleB == r.tableDays { t[2] += 1 }
            if r.ours == r.tableDays { t[3] += 1 }
            if utcClock == r.tableDays { t[4] += 1 }
            tally[era] = t
            if y >= 1451, r.ruleA != r.tableDays {
                print(String(format: "UQ4OTHER|miss of rule A|AH %d-%02d|evening %@|table %dd rule A %dd|age %+.2f min|moon margin %+.4f deg|centre lag %+.2f min", y, m, CrescentFixtureExport.date(p + 28), r.tableDays, r.ruleA, r.ageHours * 60, r.marginA, r.centreLagMinutes))
            }
            if (1392...1419).contains(y), utcClock != r.tableDays {
                print(String(format: "UQ4OTHER|miss of the UTC-date rule|AH %d-%02d|evening %@|table %dd rule %dd|new moon %@", y, m, CrescentFixtureExport.date(p + 28), r.tableDays, utcClock, CrescentFixtureExport.utc(r.newMoon)))
            }
        }
        for (k, v) in tally.sorted(by: { $0.key < $1.key }) { print("UQ4OTHER|\(k)|months \(v[0])|rule A \(v[1])|rule B \(v[2])|our rule \(v[3])|day after the new moon's UTC date \(v[4])") }
    }
}

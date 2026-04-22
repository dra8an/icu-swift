// Round-trip stability over ±10,000 ISO years — every day.
//
// For each pure-arithmetic calendar, walk every RataDie in
// [-10,000-01-01, +10,000-12-31] and assert
// `calendar.toRataDie(calendar.fromRataDie(rd)) == rd`. That's ~7.3 M
// days × N calendars.
//
// Purpose: catches any internal inconsistency in a calendar's
// conversion code (missing special case, off-by-one near era edges,
// Int truncation that only bites at specific year numbers) over a
// range far wider than the 1900–2100 regression CSVs cover, without
// needing an external authority. Complements the ±10-B RD two-point
// smoke test in `ExtremeRataDieTests.swift` — that checks Int64 safety
// at the endpoints; this checks every day in between at a realistic
// extended range.
//
// Bench discipline — this is a loop over millions of iterations, so:
//   - No `#expect` inside the loop (~1.5 µs per call would dominate).
//   - Count failures, log the first few, one `#expect(failures == 0)`
//     at the end.
//
// Astronomical calendars (Chinese, Dangi, Vietnamese, Hindu) are
// excluded — Moshier's precision envelope is only ~±3,000 years,
// and calling them 7 M times would take a long time anyway.

import Testing
import CalendarCore
import CalendarSimple
import CalendarComplex
import CalendarJapanese
import CalendarAstronomical

@Suite("Round-trip stability — every day across ±10,000 ISO years")
struct RoundTripStabilityTests {

    /// RD bounds for ±10,000 ISO years (proleptic Gregorian).
    static let rdMin: Int64 = GregorianArithmetic.fixedFromGregorian(
        year: -10_000, month: 1, day: 1
    ).dayNumber
    static let rdMax: Int64 = GregorianArithmetic.fixedFromGregorian(
        year: 10_000, month: 12, day: 31
    ).dayNumber
    static var totalDays: Int64 { rdMax - rdMin + 1 }

    /// Walks every day in the test range; collects failures; returns
    /// a human-readable summary. One `#expect(summary.failures == 0)`
    /// at the call site.
    private func runRoundTrip<C: CalendarProtocol>(
        _ calendar: C, name: String
    ) -> (failures: Int64, firstFailures: [String]) {
        var failures: Int64 = 0
        var firstFailures: [String] = []
        var rd = Self.rdMin
        while rd <= Self.rdMax {
            let r = RataDie(rd)
            let inner = calendar.fromRataDie(r)
            let back = calendar.toRataDie(inner)
            if back != r {
                failures &+= 1
                if firstFailures.count < 5 {
                    firstFailures.append("RD(\(rd)) → inner → RD(\(back.dayNumber))")
                }
            }
            rd &+= 1
        }
        print("  \(name): \(Self.totalDays) days, \(failures) failures" +
              (firstFailures.isEmpty ? "" : "; first: \(firstFailures.prefix(3))"))
        return (failures, firstFailures)
    }

    // MARK: - CalendarSimple

    @Test("ISO: ±10,000 years round-trip") func iso() {
        let r = runRoundTrip(Iso(), name: "Iso")
        #expect(r.failures == 0)
    }

    @Test("Gregorian: ±10,000 years round-trip") func gregorian() {
        let r = runRoundTrip(Gregorian(), name: "Gregorian")
        #expect(r.failures == 0)
    }

    @Test("Julian: ±10,000 years round-trip") func julian() {
        let r = runRoundTrip(Julian(), name: "Julian")
        #expect(r.failures == 0)
    }

    @Test("Buddhist: ±10,000 years round-trip") func buddhist() {
        let r = runRoundTrip(Buddhist(), name: "Buddhist")
        #expect(r.failures == 0)
    }

    @Test("ROC: ±10,000 years round-trip") func roc() {
        let r = runRoundTrip(Roc(), name: "ROC")
        #expect(r.failures == 0)
    }

    // MARK: - CalendarComplex

    @Test("Coptic: ±10,000 years round-trip") func coptic() {
        let r = runRoundTrip(Coptic(), name: "Coptic")
        #expect(r.failures == 0)
    }

    @Test("Ethiopian: ±10,000 years round-trip") func ethiopian() {
        let r = runRoundTrip(Ethiopian(), name: "Ethiopian")
        #expect(r.failures == 0)
    }

    @Test("Ethiopian Amete Alem: ±10,000 years round-trip") func ethiopianAmeteAlem() {
        let r = runRoundTrip(EthiopianAmeteAlem(), name: "EthiopianAmeteAlem")
        #expect(r.failures == 0)
    }

    @Test("Persian: ±10,000 years round-trip") func persian() {
        let r = runRoundTrip(Persian(), name: "Persian")
        #expect(r.failures == 0)
    }

    @Test("Indian: ±10,000 years round-trip") func indian() {
        let r = runRoundTrip(Indian(), name: "Indian")
        #expect(r.failures == 0)
    }

    @Test("Hebrew: ±10,000 years round-trip") func hebrew() {
        let r = runRoundTrip(Hebrew(), name: "Hebrew")
        #expect(r.failures == 0)
    }

    // MARK: - Japanese

    @Test("Japanese: ±10,000 years round-trip") func japanese() {
        let r = runRoundTrip(Japanese(), name: "Japanese")
        #expect(r.failures == 0)
    }

    // MARK: - Islamic

    @Test("Islamic Civil: ±10,000 years round-trip") func islamicCivil() {
        let r = runRoundTrip(IslamicCivil(), name: "IslamicCivil")
        #expect(r.failures == 0)
    }

    @Test("Islamic Tabular: ±10,000 years round-trip") func islamicTabular() {
        let r = runRoundTrip(IslamicTabular(), name: "IslamicTabular")
        #expect(r.failures == 0)
    }

    @Test("Islamic Umm al-Qura: ±10,000 years round-trip (exercises baked + fallback)")
    func islamicUmmAlQura() {
        // Baked range 1300–1600 AH ≈ 1882–2174 CE sits inside our span;
        // most of the ±10,000-year range falls in the Islamic Civil fallback.
        let r = runRoundTrip(IslamicUmmAlQura(), name: "IslamicUmmAlQura")
        #expect(r.failures == 0)
    }

    @Test("Islamic Astronomical (alias): ±10,000 years round-trip")
    func islamicAstronomical() {
        let r = runRoundTrip(IslamicAstronomical(), name: "IslamicAstronomical")
        #expect(r.failures == 0)
    }
}

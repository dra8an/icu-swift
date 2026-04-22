import Testing
import Foundation
import CalendarFoundation
import CalendarCore

@Suite("Foundation adapter — Phase A (UTC)")
struct FoundationAdapterUTCTests {

    let utc = TimeZone(identifier: "UTC")!

    // MARK: - Extraction

    @Test("Reference date (2001-01-01 00:00:00 UTC) maps to foundationEpoch at 00:00:00")
    func referenceDate() {
        let date = Date(timeIntervalSinceReferenceDate: 0)
        let (rd, sec, ns) = rataDieAndTimeOfDay(from: date, in: utc)
        #expect(rd == RataDie.foundationEpoch)
        #expect(sec == 0)
        #expect(ns == 0)
    }

    @Test("Unix epoch (1970-01-01 00:00:00 UTC) maps to unixEpoch at 00:00:00")
    func unixEpoch() {
        // Unix epoch is 978_307_200 seconds before 2001-01-01 UTC.
        let date = Date(timeIntervalSinceReferenceDate: -978_307_200)
        let (rd, sec, ns) = rataDieAndTimeOfDay(from: date, in: utc)
        #expect(rd == RataDie.unixEpoch)
        #expect(sec == 0)
        #expect(ns == 0)
    }

    @Test("2024-01-01 00:00:00 UTC — known civil date")
    func y2024New() {
        // Days from 2001-01-01 to 2024-01-01: 23 years, 6 leap days (2004, 08, 12, 16, 20)
        // = 23*365 + 6 = 8401 days; add year 2000 leap? No, span is exclusive of 2001 start.
        // Wait — 2020 leap day is Feb 29, 2020 — it falls inside the span. Leap years with Feb
        // 29 inside [2001, 2024) are 2004, 2008, 2012, 2016, 2020 = 5. So 23*365 + 5 = 8400.
        let rdExpected = RataDie(RataDie.foundationEpoch.dayNumber + 8400)
        let secondsBetween: TimeInterval = 8400 * 86_400
        let date = Date(timeIntervalSinceReferenceDate: secondsBetween)

        let (rd, sec, ns) = rataDieAndTimeOfDay(from: date, in: utc)
        #expect(rd == rdExpected)
        #expect(sec == 0)
        #expect(ns == 0)
    }

    @Test("Time-of-day extraction — each civil hour of 2024-06-15")
    func eachHour() {
        // 2024-06-15 is day 167 of 2024 (leap year): Jan 31 + Feb 29 + Mar 31 + Apr 30 + May 31 + Jun 15 = 167
        // Days from 2001-01-01 to 2024-06-15 = 8400 + 166 = 8566.
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 8566)
        let baseTI: TimeInterval = 8566 * 86_400

        for hour in 0..<24 {
            for minute in [0, 17, 45] {
                for second in [0, 3, 59] {
                    let ti = baseTI
                          + TimeInterval(hour) * 3600
                          + TimeInterval(minute) * 60
                          + TimeInterval(second)
                    let date = Date(timeIntervalSinceReferenceDate: ti)
                    let (rd, sec, _) = rataDieAndTimeOfDay(from: date, in: utc)
                    #expect(rd == baseRD, "RD mismatch at \(hour):\(minute):\(second)")
                    let expectedSec = hour * 3600 + minute * 60 + second
                    #expect(sec == expectedSec, "sec mismatch at \(hour):\(minute):\(second): got \(sec), expected \(expectedSec)")
                }
            }
        }
    }

    @Test("Nanosecond extraction")
    func nanoseconds() {
        // 2001-01-01 00:00:00.123_456_789 UTC
        let ti: TimeInterval = 0.123_456_789
        let date = Date(timeIntervalSinceReferenceDate: ti)
        let (_, sec, ns) = rataDieAndTimeOfDay(from: date, in: utc)
        #expect(sec == 0)
        // Double-precision floor: ns may land at 123_456_789 or one off. Accept ±1.
        #expect(abs(ns - 123_456_789) <= 1, "got \(ns)")
    }

    @Test("Pre-reference-date (1990-07-04 12:00:00 UTC)")
    func preReferenceDate() {
        // 1990-07-04 = Unix epoch + 7489 days. Total seconds = 7489*86400 = 647_049_600.
        // Relative to 2001-01-01 ref: 647_049_600 - 978_307_200 = -331_257_600.
        // Plus 12:00:00 = +43_200 → -331_214_400.
        let ti: TimeInterval = -331_214_400
        let date = Date(timeIntervalSinceReferenceDate: ti)
        let (rd, sec, ns) = rataDieAndTimeOfDay(from: date, in: utc)
        #expect(rd == RataDie(RataDie.unixEpoch.dayNumber + 7489))
        #expect(sec == 43_200)
        #expect(ns == 0)
    }

    // MARK: - Assembly

    @Test("Assembly: 2001-01-01 00:00:00 UTC → reference date")
    func assemblyReferenceDate() {
        let d = date(rataDie: RataDie.foundationEpoch, in: utc)
        #expect(d.timeIntervalSinceReferenceDate == 0)
    }

    @Test("Assembly: with time-of-day")
    func assemblyWithTOD() {
        let d = date(
            rataDie: RataDie.foundationEpoch,
            hour: 14, minute: 30, second: 15, nanosecond: 500_000_000,
            in: utc
        )
        let expectedTI: TimeInterval = TimeInterval(14 * 3600 + 30 * 60 + 15) + 0.5
        #expect(abs(d.timeIntervalSinceReferenceDate - expectedTI) < 1e-9)
    }

    // MARK: - Round trips

    @Test("Round-trip: every civil hour on 2024-06-15 UTC")
    func roundTripHours() {
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 8566)
        for hour in 0..<24 {
            for minute in [0, 17, 45] {
                for second in [0, 3, 59] {
                    let d = date(
                        rataDie: baseRD,
                        hour: hour, minute: minute, second: second,
                        in: utc
                    )
                    let (rd2, sec2, ns2) = rataDieAndTimeOfDay(from: d, in: utc)
                    #expect(rd2 == baseRD)
                    #expect(sec2 == hour*3600 + minute*60 + second)
                    #expect(ns2 == 0)
                }
            }
        }
    }

    @Test("Round-trip with nanoseconds")
    func roundTripNanoseconds() {
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 100)
        for ns in [0, 1, 123_456_789, 999_999_999] {
            let d = date(
                rataDie: baseRD,
                hour: 12, minute: 0, second: 0, nanosecond: ns,
                in: utc
            )
            let (rd2, sec2, ns2) = rataDieAndTimeOfDay(from: d, in: utc)
            #expect(rd2 == baseRD)
            #expect(sec2 == 12 * 3600)
            #expect(abs(ns2 - ns) <= 1, "ns=\(ns), got \(ns2)")
        }
    }

    @Test("Round-trip: negative offsets (pre-2001)")
    func roundTripNegative() {
        // 1900-01-01 — solidly pre-reference
        let rd1900 = RataDie(RataDie.unixEpoch.dayNumber - (70 * 365 + 17))  // 17 leap days between 1900 and 1970
        for hour in [0, 12, 23] {
            for second in [0, 45] {
                let d = date(
                    rataDie: rd1900,
                    hour: hour, minute: 0, second: second,
                    in: utc
                )
                let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: utc)
                #expect(rd2 == rd1900)
                #expect(sec2 == hour * 3600 + second)
            }
        }
    }

    @Test("Round-trip: end of day (23:59:59.000_000_000) — full-precision case")
    func roundTripEndOfDay() {
        // Note: 23:59:59.999_999_999 round-trips lossily because Double can't
        // represent 86_486_399.999_999_999 exactly at this magnitude — the
        // fractional-second precision degrades. That's a Phase E edge case
        // matching `_CalendarGregorian`'s own behaviour. Phase A uses
        // integer-second end-of-day, which round-trips cleanly.
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 1000)
        let d = date(
            rataDie: baseRD,
            hour: 23, minute: 59, second: 59, nanosecond: 0,
            in: utc
        )
        let (rd2, sec2, ns2) = rataDieAndTimeOfDay(from: d, in: utc)
        #expect(rd2 == baseRD)
        #expect(sec2 == 86_399)
        #expect(ns2 == 0)
    }
}

@Suite("Foundation adapter — Phase B (fixed-offset TZ)")
struct FoundationAdapterFixedOffsetTests {

    // MARK: - Extraction in non-UTC offsets

    @Test("Extraction: 2024-01-01 00:00:00 UTC viewed from UTC+05:00 is local 05:00")
    func extractNewYear0500() {
        let tz = TimeZone(secondsFromGMT: 5 * 3600)!
        let rdExpected = RataDie(RataDie.foundationEpoch.dayNumber + 8400)
        let date = Date(timeIntervalSinceReferenceDate: 8400 * 86_400)
        let (rd, sec, _) = rataDieAndTimeOfDay(from: date, in: tz)
        #expect(rd == rdExpected)
        #expect(sec == 5 * 3600)
    }

    @Test("Extraction: 2024-01-01 00:00:00 UTC viewed from UTC−05:00 is still 2023-12-31 19:00")
    func extractNewYearNeg0500() {
        let tz = TimeZone(secondsFromGMT: -5 * 3600)!
        // UTC midnight minus 5 hours = prev civil day 19:00
        let rdExpected = RataDie(RataDie.foundationEpoch.dayNumber + 8399)
        let date = Date(timeIntervalSinceReferenceDate: 8400 * 86_400)
        let (rd, sec, _) = rataDieAndTimeOfDay(from: date, in: tz)
        #expect(rd == rdExpected)
        #expect(sec == 19 * 3600)
    }

    // MARK: - Round trips across representative offsets

    @Test("Round-trip: UTC+13:00 (Pacific / Tonga-style)")
    func roundTripPlus13() {
        let tz = TimeZone(secondsFromGMT: 13 * 3600)!
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 5000)
        for hour in [0, 6, 12, 18, 23] {
            for minute in [0, 30] {
                let d = date(rataDie: baseRD, hour: hour, minute: minute, in: tz)
                let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
                #expect(rd2 == baseRD)
                #expect(sec2 == hour * 3600 + minute * 60)
            }
        }
    }

    @Test("Round-trip: UTC−13:00 (hypothetical westward extreme)")
    func roundTripMinus13() {
        let tz = TimeZone(secondsFromGMT: -13 * 3600)!
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 5000)
        for hour in [0, 6, 12, 18, 23] {
            let d = date(rataDie: baseRD, hour: hour, in: tz)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
            #expect(rd2 == baseRD)
            #expect(sec2 == hour * 3600)
        }
    }

    @Test("Round-trip: UTC+00:30 (half-hour offset)")
    func roundTripHalfHour() {
        let tz = TimeZone(secondsFromGMT: 30 * 60)!
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 5000)
        for hour in [0, 6, 12, 23] {
            for minute in [0, 15, 30, 45] {
                for second in [0, 29, 59] {
                    let d = date(rataDie: baseRD, hour: hour, minute: minute, second: second, in: tz)
                    let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
                    #expect(rd2 == baseRD, "RD at \(hour):\(minute):\(second)")
                    #expect(sec2 == hour * 3600 + minute * 60 + second)
                }
            }
        }
    }

    @Test("Round-trip: UTC+05:45 (Nepal-style, unusual offset)")
    func roundTripNepal() {
        let tz = TimeZone(secondsFromGMT: 5 * 3600 + 45 * 60)!
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 5000)
        for hour in [0, 12, 23] {
            let d = date(rataDie: baseRD, hour: hour, minute: 15, in: tz)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
            #expect(rd2 == baseRD)
            #expect(sec2 == hour * 3600 + 15 * 60)
        }
    }

    // MARK: - Named no-DST TZ

    @Test("Round-trip: America/Phoenix (no DST)")
    func roundTripPhoenix() {
        let tz = TimeZone(identifier: "America/Phoenix")!
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 5000)
        // Test across both "summer" and "winter" days — Phoenix doesn't shift.
        for daysOffset in [0, 90, 180, 270] {
            let rd = RataDie(baseRD.dayNumber + Int64(daysOffset))
            let d = date(rataDie: rd, hour: 15, minute: 30, in: tz)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
            #expect(rd2 == rd, "day+\(daysOffset): \(rd2) vs \(rd)")
            #expect(sec2 == 15 * 3600 + 30 * 60)
        }
    }

    // MARK: - Year extremes

    @Test("Round-trip: year 1900 in UTC+09:00")
    func roundTripYear1900() {
        let tz = TimeZone(secondsFromGMT: 9 * 3600)!
        // 1900-06-15: use unix epoch - (70-1900->1970 years): 70 years before 1970 = days
        // RD for 1900-06-15: unixEpoch - (70y*365 + 17 leap days between 1900-1970) + 165 days into year
        // Simpler: known RD 693961 = 1900-01-01 Gregorian (ICU / Reingold reference)
        // We'll use a relative construction.
        let rd = RataDie(693_961 + 165) // 1900-06-15
        for hour in [0, 12, 23] {
            let d = date(rataDie: rd, hour: hour, in: tz)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
            #expect(rd2 == rd)
            #expect(sec2 == hour * 3600)
        }
    }

    @Test("Round-trip: year 2100 in UTC−08:00")
    func roundTripYear2100() {
        let tz = TimeZone(secondsFromGMT: -8 * 3600)!
        // 2100-01-01 RD = foundationEpoch + (100y*365 + 24 leap days) = 730486 + 36524 = 767010
        // Actually leap days 2001-2100 (inclusive start, exclusive end): 2004, 2008, ..., 2096 = 24, minus 2100 not leap
        let rd = RataDie(730_486 + 100 * 365 + 24)
        for hour in [0, 6, 12, 18, 23] {
            let d = date(rataDie: rd, hour: hour, in: tz)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
            #expect(rd2 == rd)
            #expect(sec2 == hour * 3600)
        }
    }

    @Test("Round-trip: Australia/Sydney Jan and Jul (both stable, no transitions)")
    func roundTripSydneyNonTransition() {
        let tz = TimeZone(identifier: "Australia/Sydney")!
        let winter = RataDie(RataDie.foundationEpoch.dayNumber + 8596) // 2024-07-15
        let summer = RataDie(RataDie.foundationEpoch.dayNumber + 8415) // 2024-01-16
        for rd in [winter, summer] {
            for hour in [0, 12, 23] {
                let d = date(rataDie: rd, hour: hour, in: tz)
                let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
                #expect(rd2 == rd)
                #expect(sec2 == hour * 3600)
            }
        }
    }

    @Test("Cross-TZ consistency: same absolute Date → different (RD, sec) but same localTI−tzOffset")
    func crossZoneConsistency() {
        // A single absolute instant: 2024-06-15 18:00:00 UTC
        let ti: TimeInterval = TimeInterval(8566 * 86_400) + TimeInterval(18 * 3600)
        let absolute = Date(timeIntervalSinceReferenceDate: ti)

        let tzUtc = TimeZone(identifier: "UTC")!
        let tzTokyo = TimeZone(secondsFromGMT: 9 * 3600)!     // UTC+09: same instant → 2024-06-16 03:00
        let tzNewYork = TimeZone(secondsFromGMT: -4 * 3600)!  // fixed-offset stand-in → 2024-06-15 14:00

        let (rdU, secU, _) = rataDieAndTimeOfDay(from: absolute, in: tzUtc)
        let (rdT, secT, _) = rataDieAndTimeOfDay(from: absolute, in: tzTokyo)
        let (rdN, secN, _) = rataDieAndTimeOfDay(from: absolute, in: tzNewYork)

        // UTC: 2024-06-15 18:00
        #expect(rdU == RataDie(RataDie.foundationEpoch.dayNumber + 8566))
        #expect(secU == 18 * 3600)

        // Tokyo: 2024-06-16 03:00 (next day!)
        #expect(rdT == RataDie(RataDie.foundationEpoch.dayNumber + 8567))
        #expect(secT == 3 * 3600)

        // Fixed UTC-4: 2024-06-15 14:00
        #expect(rdN == RataDie(RataDie.foundationEpoch.dayNumber + 8566))
        #expect(secN == 14 * 3600)
    }
}

@Suite("Foundation adapter — Phase C (DST transitions)")
struct FoundationAdapterDSTTests {

    // 2024-03-10 is spring-forward in America/Los_Angeles (02:00 PST → 03:00 PDT).
    // 2024-03-10 RD = foundationEpoch + 8400 + 31 + 29 + 9 = 730486 + 8469 = 738955
    let laSpringForward = RataDie(738_955)
    // 2024-11-03 is fall-back in America/Los_Angeles (02:00 PDT → 01:00 PST).
    let laFallBack = RataDie(730_486 + 8400 + 307) // 2024-11-03

    // Same zone for both transition tests.
    let la = TimeZone(identifier: "America/Los_Angeles")!

    // MARK: - Spring-forward: skipped wall time

    @Test("Skipped (LA spring-forward): 02:30 with .former → applies PST offset")
    func laSkippedFormer() {
        // .former = "use the offset that was in effect before the transition" = PST (-8h).
        // 02:30 PST = 10:30 UTC.
        let d = date(
            rataDie: laSpringForward,
            hour: 2, minute: 30,
            in: la,
            skippedTimePolicy: .former
        )
        // 2024-03-10 10:30 UTC
        let expectedUTC = Date(timeIntervalSinceReferenceDate: 8469.0 * 86_400 + 10.5 * 3600)
        #expect(abs(d.timeIntervalSinceReferenceDate - expectedUTC.timeIntervalSinceReferenceDate) < 1e-6)
    }

    @Test("Skipped (LA spring-forward): 02:30 with .latter → applies PDT offset")
    func laSkippedLatter() {
        // .latter = "use the offset that came into effect after the transition" = PDT (-7h).
        // 02:30 PDT = 09:30 UTC.
        let d = date(
            rataDie: laSpringForward,
            hour: 2, minute: 30,
            in: la,
            skippedTimePolicy: .latter
        )
        // 2024-03-10 09:30 UTC
        let expectedUTC = Date(timeIntervalSinceReferenceDate: 8469.0 * 86_400 + 9.5 * 3600)
        #expect(abs(d.timeIntervalSinceReferenceDate - expectedUTC.timeIntervalSinceReferenceDate) < 1e-6)
    }

    @Test("Skipped .former returns a LATER UTC than .latter (spring-forward asymmetry)")
    func skippedFormerVsLatter() {
        let dFormer = date(rataDie: laSpringForward, hour: 2, minute: 30, in: la, skippedTimePolicy: .former)
        let dLatter = date(rataDie: laSpringForward, hour: 2, minute: 30, in: la, skippedTimePolicy: .latter)
        #expect(dFormer > dLatter)
        // Exactly 1 hour apart (the size of the DST shift).
        let diff = dFormer.timeIntervalSinceReferenceDate - dLatter.timeIntervalSinceReferenceDate
        #expect(abs(diff - 3600) < 1e-6)
    }

    // MARK: - Fall-back: repeated wall time

    @Test("Repeated (LA fall-back): 01:30 with .former → first occurrence (PDT)")
    func laRepeatedFormer() {
        // First 01:30 occurs during PDT (-7h). 01:30 PDT = 08:30 UTC.
        let d = date(
            rataDie: laFallBack,
            hour: 1, minute: 30,
            in: la,
            repeatedTimePolicy: .former
        )
        // 2024-11-03: days from 2001-01-01 = 8400 (to 2024-01-01) + 307 (Jan + Feb29 + ... + 3 days in Nov) = 8707
        let daysFromRefDate = 8707.0
        let expectedUTC = Date(timeIntervalSinceReferenceDate: daysFromRefDate * 86_400 + 8.5 * 3600)
        #expect(abs(d.timeIntervalSinceReferenceDate - expectedUTC.timeIntervalSinceReferenceDate) < 1e-6)
    }

    @Test("Repeated (LA fall-back): 01:30 with .latter → second occurrence (PST)")
    func laRepeatedLatter() {
        // Second 01:30 occurs during PST (-8h). 01:30 PST = 09:30 UTC.
        let d = date(
            rataDie: laFallBack,
            hour: 1, minute: 30,
            in: la,
            repeatedTimePolicy: .latter
        )
        let daysFromRefDate = 8707.0
        let expectedUTC = Date(timeIntervalSinceReferenceDate: daysFromRefDate * 86_400 + 9.5 * 3600)
        #expect(abs(d.timeIntervalSinceReferenceDate - expectedUTC.timeIntervalSinceReferenceDate) < 1e-6)
    }

    @Test("Repeated .former returns an EARLIER UTC than .latter (fall-back normal direction)")
    func repeatedFormerVsLatter() {
        let dFormer = date(rataDie: laFallBack, hour: 1, minute: 30, in: la, repeatedTimePolicy: .former)
        let dLatter = date(rataDie: laFallBack, hour: 1, minute: 30, in: la, repeatedTimePolicy: .latter)
        #expect(dFormer < dLatter)
        let diff = dLatter.timeIntervalSinceReferenceDate - dFormer.timeIntervalSinceReferenceDate
        #expect(abs(diff - 3600) < 1e-6)
    }

    // MARK: - Normal round-trips around (but not AT) DST edges

    @Test("Round-trip: LA 00:30 on spring-forward day (pre-transition, PST)")
    func roundTripLAPreSpringForward() {
        let d = date(rataDie: laSpringForward, hour: 0, minute: 30, in: la)
        let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: la)
        #expect(rd2 == laSpringForward)
        #expect(sec2 == 30 * 60)
    }

    @Test("Round-trip: LA 04:30 on spring-forward day (post-transition, PDT)")
    func roundTripLAPostSpringForward() {
        let d = date(rataDie: laSpringForward, hour: 4, minute: 30, in: la)
        let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: la)
        #expect(rd2 == laSpringForward)
        #expect(sec2 == 4 * 3600 + 30 * 60)
    }

    @Test("Round-trip: LA 00:30 on fall-back day (pre-transition, PDT)")
    func roundTripLAPreFallBack() {
        let d = date(rataDie: laFallBack, hour: 0, minute: 30, in: la)
        let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: la)
        #expect(rd2 == laFallBack)
        #expect(sec2 == 30 * 60)
    }

    @Test("Round-trip: LA 03:30 on fall-back day (post-transition, PST)")
    func roundTripLAPostFallBack() {
        let d = date(rataDie: laFallBack, hour: 3, minute: 30, in: la)
        let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: la)
        #expect(rd2 == laFallBack)
        #expect(sec2 == 3 * 3600 + 30 * 60)
    }

    // MARK: - Southern hemisphere DST

    @Test("Round-trip: Australia/Sydney DST transition (April)")
    func roundTripSydneyDST() {
        let tz = TimeZone(identifier: "Australia/Sydney")!
        // 2024-04-07 is Sydney fall-back (end of DST in southern hem).
        // RD = foundationEpoch + 8400 + 31 + 29 + 31 + 6 = 730486 + 8497 = 738983
        let rd = RataDie(738_983)
        // Normal times around it (not AT 02:00-03:00 window): 00:00 and 04:00 both unique.
        for hour in [0, 4, 12, 23] {
            let d = date(rataDie: rd, hour: hour, in: tz)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
            #expect(rd2 == rd)
            #expect(sec2 == hour * 3600)
        }
    }

    // MARK: - Second-resolution historical offset

    @Test("Round-trip: Europe/Berlin 1900 (pre-standardization offset)")
    func roundTripBerlin1900() {
        let tz = TimeZone(identifier: "Europe/Berlin")!
        // 1900-06-15 RD = unixEpoch - (70 years - 17 leap days) + 165 days
        // Simpler: known RD for 1900-06-15 = 693_961 + 165 = 694_126
        let rd = RataDie(693_961 + 165)
        for hour in [0, 12, 23] {
            let d = date(rataDie: rd, hour: hour, in: tz)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: tz)
            #expect(rd2 == rd, "hour=\(hour): got RD \(rd2), expected \(rd)")
            #expect(sec2 == hour * 3600)
        }
    }

    // MARK: - Default-policy sanity

    @Test("Default policies are .former / .former (match Foundation's _CalendarGregorian)")
    func defaultsAreFormer() {
        let dDefault = date(rataDie: laSpringForward, hour: 2, minute: 30, in: la)
        let dExplicit = date(
            rataDie: laSpringForward,
            hour: 2, minute: 30,
            in: la,
            repeatedTimePolicy: .former,
            skippedTimePolicy: .former
        )
        #expect(dDefault == dExplicit)
    }
}

@Suite("Foundation adapter — Phase D/E (extreme ranges + nanosecond edges)")
struct FoundationAdapterEdgeCaseTests {

    let utc = TimeZone(identifier: "UTC")!

    // MARK: - Phase E: Nanosecond precision

    @Test("Nanosecond round-trip at small TI magnitude (reference date)")
    func nsAtReferenceEpoch() {
        // At TI ≈ 0, Double has full ~100 ns granularity at the seconds fraction.
        let baseRD = RataDie.foundationEpoch
        for ns in [0, 1, 500, 123_456, 999_999, 123_456_789] {
            let d = date(rataDie: baseRD, hour: 0, second: 0, nanosecond: ns, in: utc)
            let (rd2, sec2, ns2) = rataDieAndTimeOfDay(from: d, in: utc)
            #expect(rd2 == baseRD)
            #expect(sec2 == 0)
            #expect(abs(ns2 - ns) <= 1, "ns=\(ns), got \(ns2)")
        }
    }

    @Test("Nanosecond round-trip at medium TI (2024 era) — bounded by Double precision")
    func nsAt2024() {
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 8566) // 2024-06-15
        // At TI ≈ 7.4e8, Double has ~200 ns precision on the fractional second.
        // This matches Foundation's `_CalendarGregorian` behavior exactly —
        // the precision is an inherent property of the Double representation,
        // not a bug in our adapter.
        let tolerance = 200 // ns
        for ns in [0, 1, 1_000_000, 500_000_000, 123_456_789] {
            let d = date(rataDie: baseRD, hour: 12, nanosecond: ns, in: utc)
            let (rd2, sec2, ns2) = rataDieAndTimeOfDay(from: d, in: utc)
            #expect(rd2 == baseRD)
            #expect(sec2 == 12 * 3600)
            #expect(abs(ns2 - ns) <= tolerance, "ns=\(ns), got \(ns2)")
        }
    }

    @Test("Nanosecond round-trip with negative TI (1950 era) — bounded by Double precision")
    func nsPre2001() {
        // 1950-01-01 RD ≈ 711857, TI ≈ −1.6e9.
        let baseRD = RataDie(711_857)
        let tolerance = 200 // ns — same scale as 2024 because |TI| is comparable.
        for ns in [0, 500_000_000, 999_000_000] {
            let d = date(rataDie: baseRD, hour: 8, nanosecond: ns, in: utc)
            let (rd2, sec2, ns2) = rataDieAndTimeOfDay(from: d, in: utc)
            #expect(rd2 == baseRD)
            #expect(sec2 == 8 * 3600)
            #expect(abs(ns2 - ns) <= tolerance, "ns=\(ns), got \(ns2)")
        }
    }

    @Test("Documented quirk: 23:59:59.999_999_999 rolls forward to next-day midnight")
    func nsEndOfDayQuirk() {
        // At totalSec ≈ 8.64e13, `Double(totalSec) + 0.999_999_999` rounds up
        // to the next integer due to Double's precision limit (~16 sig figs).
        // This matches `_CalendarGregorian`'s behavior exactly; callers who
        // need full ns precision at end-of-day should prefer millisecond
        // inputs (< 1 billion ns).
        let baseRD = RataDie(RataDie.foundationEpoch.dayNumber + 1000)
        let d = date(
            rataDie: baseRD,
            hour: 23, minute: 59, second: 59, nanosecond: 999_999_999,
            in: utc
        )
        let (rd2, _, _) = rataDieAndTimeOfDay(from: d, in: utc)
        // Expected: rolls into the NEXT civil day because the Double
        // round-trip lands at exactly next-day midnight.
        #expect(rd2.dayNumber == baseRD.dayNumber + 1)
    }

    @Test("Nanosecond round-trip precision degrades linearly with TI magnitude")
    func nsPrecisionProfile() {
        // This test documents Double's precision ceiling at various TI scales.
        // There is no amount of adapter cleverness that can do better than Double
        // gives us — we inherit the ceiling from `Foundation.Date`.
        //
        // Double has ~15.95 significant decimal digits. Nanosecond precision
        // requires 9 fractional digits, leaving ~7 for the integer part (~1e7).
        // Above that, precision degrades by a factor of 10 for each decade.
        //
        // Observed tolerances (empirical, as of Phase E):
        //   TI ≈ 0 (reference epoch)        → ~1 ns
        //   TI ≈ 1e8 (~3 years from 2001)    → ~10 ns
        //   TI ≈ 1e9 (~30 years)             → ~100 ns
        //   TI ≈ 1e10 (~300 years)           → ~1000 ns
        //
        // All these match `_CalendarGregorian` by construction.
        struct Scenario { let dayOffset: Int64; let tolerance: Int }
        let scenarios = [
            Scenario(dayOffset: 0,        tolerance: 1),     // ~TI 0
            Scenario(dayOffset: 100,      tolerance: 10),    // ~TI 8.6e6
            Scenario(dayOffset: 1_000,    tolerance: 10),    // ~TI 8.6e7
            Scenario(dayOffset: 10_000,   tolerance: 100),   // ~TI 8.6e8
            Scenario(dayOffset: -10_000,  tolerance: 100),   // ~TI -8.6e8
        ]
        for s in scenarios {
            let rd = RataDie(RataDie.foundationEpoch.dayNumber + s.dayOffset)
            for ns in [0, 1, 999_999] {
                let d = date(rataDie: rd, hour: 6, nanosecond: ns, in: utc)
                let (_, _, ns2) = rataDieAndTimeOfDay(from: d, in: utc)
                #expect(abs(ns2 - ns) <= s.tolerance,
                        "dayOffset=\(s.dayOffset), ns=\(ns), got \(ns2), tol=\(s.tolerance)")
            }
        }
    }

    // MARK: - Phase D: Extreme-year round-trips

    @Test("Round-trip: year +10,000 CE")
    func yearTenThousand() {
        // 10000-01-01 RD = foundationEpoch + ~(7999 * 365.2425) ≈ 730486 + 2921940 = 3652426
        // Compute exactly: 7999 years from 2001 to 10000.
        // Leap days: (10000/4 - 10000/100 + 10000/400) - (2000/4 - 2000/100 + 2000/400)
        //          = (2500 - 100 + 25) - (500 - 20 + 5) = 2425 - 485 = 1940
        // Non-leap years: 7999 - 1940 = 6059
        // Total days: 6059*365 + 1940*366 = 2_211_535 + 710_040 = 2_921_575
        let rd = RataDie(RataDie.foundationEpoch.dayNumber + 2_921_575)
        for hour in [0, 12, 23] {
            let d = date(rataDie: rd, hour: hour, in: utc)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: utc)
            #expect(rd2 == rd, "hour=\(hour)")
            #expect(sec2 == hour * 3600)
        }
    }

    @Test("Round-trip: year −10,000 BCE (proleptic)")
    func yearMinusTenThousand() {
        // −10000 (11,999 years before 2001). Leap-day math symmetric to above.
        // Just pick a plausible RD far in the negative and round-trip.
        let rd = RataDie(-3_650_000) // roughly −9000 ISO
        for hour in [0, 12, 23] {
            let d = date(rataDie: rd, hour: hour, in: utc)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: utc)
            #expect(rd2 == rd)
            #expect(sec2 == hour * 3600)
        }
    }

    @Test("Round-trip: year +1,000,000 CE (upper edge of icu4swift validRange)")
    func yearMillion() {
        // Still well within Int64 seconds range (1M years ≈ 3.65e8 days ≈ 3.15e13 seconds).
        let rd = RataDie(RataDie.foundationEpoch.dayNumber + 1_000_000 * 365)
        let d = date(rataDie: rd, hour: 12, in: utc)
        let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: utc)
        #expect(rd2 == rd)
        #expect(sec2 == 12 * 3600)
    }

    @Test("Round-trip: RataDie at validRange upper bound (±365M days)")
    func validRangeBound() {
        // Edge of RataDie.validRange = ±365M days ≈ ±1,000,000 years.
        let rdHigh = RataDie(365_000_000)
        let rdLow = RataDie(-365_000_000)
        for rd in [rdHigh, rdLow] {
            let d = date(rataDie: rd, hour: 0, in: utc)
            let (rd2, sec2, _) = rataDieAndTimeOfDay(from: d, in: utc)
            #expect(rd2 == rd, "rd=\(rd)")
            #expect(sec2 == 0)
        }
    }
}

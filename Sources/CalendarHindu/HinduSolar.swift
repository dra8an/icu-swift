// Hindu solar calendars — Tamil, Bengali, Odia, Malayalam.
//
// Solar months are determined by when the sidereal sun enters each zodiac sign (rashi).
// Each regional variant has a different "critical time" for evaluating the rashi,
// a different year-start rashi, and a different era.
//
// Ported from hindu-calendar/swift/Sources/HinduCalendar/Core/Solar.swift.

import Foundation
import CalendarCore
import CalendarSimple
import AstronomicalEngine

// MARK: - Solar Calendar Variant Protocol

/// Protocol for Hindu solar calendar regional variants.
public protocol HinduSolarVariant: Sendable {
    static var calendarIdentifier: String { get }
    /// The first rashi of the year (1=Mesha for Tamil/Bengali, 5=Simha for Malayalam, 6=Kanya for Odia).
    static var firstRashi: Int { get }
    /// The rashi that starts a new year.
    static var yearStartRashi: Int { get }
    /// Offset from Gregorian year to regional year when date is on or after year start.
    static var gyOffsetOn: Int { get }
    /// Offset from Gregorian year to regional year when date is before year start.
    static var gyOffsetBefore: Int { get }
    /// Era name for display.
    static var eraName: String { get }
    /// Compute the critical time (JD UT) for evaluating rashi on a given civil day.
    static func criticalTimeJd(_ jdMidnightUt: Double, _ loc: Location, engine: MoshierEngine) -> Double

    /// Bengali per-rashi tuning: adjust critical time for specific rashis.
    static func tunedCriticalTime(_ baseCritJd: Double, _ rashi: Int) -> Double

    /// Bengali day edge offset: shift the day boundary for specific rashis.
    static func dayEdgeOffset(_ rashi: Int) -> Double

    /// Bengali rashi correction: correct rashi near boundaries using tuned critical time.
    static func rashiCorrection(_ jdCrit: Double, _ rashi: inout Int, _ lon: inout Double)

    /// Bengali tithi push: use tithi boundary to decide if the next day should be used.
    static func tithiPushNext(_ jdSankranti: Double, _ jdDay: Double, _ rashi: Int, _ loc: Location) -> Bool
}

// Default implementations — no adjustments for non-Bengali calendars
extension HinduSolarVariant {
    public static func tunedCriticalTime(_ baseCritJd: Double, _ rashi: Int) -> Double { baseCritJd }
    public static func dayEdgeOffset(_ rashi: Int) -> Double { 0.0 }
    public static func rashiCorrection(_ jdCrit: Double, _ rashi: inout Int, _ lon: inout Double) { }
    public static func tithiPushNext(_ jdSankranti: Double, _ jdDay: Double, _ rashi: Int, _ loc: Location) -> Bool { false }
}

// MARK: - Tamil

public enum Tamil: HinduSolarVariant {
    public static let calendarIdentifier = "hindu-solar-tamil"
    public static let firstRashi = 1
    public static let yearStartRashi = 1
    public static let gyOffsetOn = 78
    public static let gyOffsetBefore = 79
    public static let eraName = "saka"

    public static func criticalTimeJd(_ jdMidnightUt: Double, _ loc: Location, engine: MoshierEngine) -> Double {
        // Sunset − 9.5 minutes
        // Hindu project adjusts for UTC offset before calling Rise.sunset
        let ss = MoshierSunrise.sunset(jdMidnightUt - loc.utcOffset, loc.longitude, loc.latitude, loc.elevation)
        if ss > 0 {
            return ss - 9.5 / (24.0 * 60.0)
        }
        return jdMidnightUt + 18.0 / 24.0 - 9.5 / (24.0 * 60.0)
    }
}

// MARK: - Bengali

public enum Bengali: HinduSolarVariant {
    public static let calendarIdentifier = "hindu-solar-bengali"
    public static let firstRashi = 1
    public static let yearStartRashi = 1
    public static let gyOffsetOn = 593
    public static let gyOffsetBefore = 594
    public static let eraName = "bangabda"

    public static func criticalTimeJd(_ jdMidnightUt: Double, _ loc: Location, engine: MoshierEngine) -> Double {
        // Midnight IST + 24 minutes = 00:24 IST
        // loc.utcOffset is already in fractional days, not hours
        jdMidnightUt - loc.utcOffset + 24.0 / (24.0 * 60.0)
    }

    // Per-rashi tuning: adjust critical time for Karkata (+8 min) and Tula (-1 min)
    public static func tunedCriticalTime(_ baseCritJd: Double, _ rashi: Int) -> Double {
        let adjustMin: Double
        switch rashi {
        case 4:  adjustMin = 8.0     // Karkata
        case 7:  adjustMin = -1.0    // Tula
        default: adjustMin = 0.0
        }
        return baseCritJd + adjustMin / (24.0 * 60.0)
    }

    // Day edge offset: shift day boundary for Kanya, Tula, Dhanu
    public static func dayEdgeOffset(_ rashi: Int) -> Double {
        switch rashi {
        case 6:  return 4.0 / (24.0 * 60.0)    // Kanya: 23:56
        case 7:  return 21.0 / (24.0 * 60.0)   // Tula: 23:39
        case 9:  return 11.0 / (24.0 * 60.0)   // Dhanu: 23:49
        default: return 0.0
        }
    }

    // Rashi correction: check if the next rashi should be used at the tuned critical time
    public static func rashiCorrection(_ jdCrit: Double, _ rashi: inout Int, _ lon: inout Double) {
        let nextR = (rashi % 12) + 1
        let tuned = tunedCriticalTime(jdCrit, nextR)
        if tuned > jdCrit {
            let lon2 = HinduAyanamsa.siderealSolarLongitude(tuned)
            var r2 = Int(floor(lon2 / 30.0)) + 1
            if r2 > 12 { r2 = 12 }
            if r2 == nextR {
                rashi = nextR
                lon = lon2
            }
        }
    }

    // Tithi push: use tithi boundary to decide next-day assignment
    public static func tithiPushNext(_ jdSankranti: Double, _ jdDay: Double, _ rashi: Int, _ loc: Location) -> Bool {
        if rashi == 4 { return false }   // Karkata: always this day
        if rashi == 10 { return true }   // Makara: always next day

        // Check if tithi boundary of previous day falls before or after sankranti
        let prevYmd = JulianDayHelper.jdToYmd(jdDay - 1.0)
        let prevJd = JulianDayHelper.ymdToJd(year: prevYmd.0, month: prevYmd.1, day: prevYmd.2)
        let jdPrevRise = MoshierSunrise.sunrise(
            prevJd - loc.utcOffset,
            loc.longitude, loc.latitude, loc.elevation
        )
        guard jdPrevRise > 0 else { return false }

        // Find the tithi at sunrise of previous day, then find when that tithi ends
        let phase = LunisolarArithmetic.lunarPhase(jdPrevRise)
        let t = min(Int(phase / 12.0) + 1, 30)
        let nextTithi = (t % 30) + 1
        let targetPhase = Double(nextTithi - 1) * 12.0

        // Find tithi boundary (when the next tithi starts)
        var lo = jdPrevRise
        var hi = jdPrevRise + 2.0
        for _ in 0..<50 {
            let mid = (lo + hi) / 2.0
            let p = LunisolarArithmetic.lunarPhase(mid)
            var diff = p - targetPhase
            if diff > 180.0 { diff -= 360.0 }
            if diff < -180.0 { diff += 360.0 }
            if diff >= 0 { hi = mid } else { lo = mid }
        }
        let jdTithiEnd = (lo + hi) / 2.0

        return jdTithiEnd <= jdSankranti
    }
}

// MARK: - Odia

public enum Odia: HinduSolarVariant {
    public static let calendarIdentifier = "hindu-solar-odia"
    public static let firstRashi = 1
    public static let yearStartRashi = 6
    public static let gyOffsetOn = 592
    public static let gyOffsetBefore = 593
    public static let eraName = "amli"

    public static func criticalTimeJd(_ jdMidnightUt: Double, _ loc: Location, engine: MoshierEngine) -> Double {
        // Fixed 22:12 IST = 16:42 UT
        // 22.2 hours = 22h 12m; convert to days then subtract UTC offset (already in days)
        jdMidnightUt + 22.2 / 24.0 - loc.utcOffset
    }
}

// MARK: - Malayalam

public enum Malayalam: HinduSolarVariant {
    public static let calendarIdentifier = "hindu-solar-malayalam"
    public static let firstRashi = 5
    public static let yearStartRashi = 5
    public static let gyOffsetOn = 824
    public static let gyOffsetBefore = 825
    public static let eraName = "kollam"

    public static func criticalTimeJd(_ jdMidnightUt: Double, _ loc: Location, engine: MoshierEngine) -> Double {
        // End of madhyahna − 9.5 minutes
        // madhyahna end = sunrise + 0.6 × (sunset − sunrise)
        // Hindu project adjusts for UTC offset before calling Rise.sunrise/sunset
        let adjustedJd = jdMidnightUt - loc.utcOffset
        let sr = MoshierSunrise.sunrise(adjustedJd, loc.longitude, loc.latitude, loc.elevation)
        let ss = MoshierSunrise.sunset(adjustedJd, loc.longitude, loc.latitude, loc.elevation)
        if sr > 0 && ss > 0 {
            let madhyahnaEnd = sr + 0.6 * (ss - sr)
            return madhyahnaEnd - 9.5 / (24.0 * 60.0)
        }
        return jdMidnightUt + 14.0 / 24.0 - 9.5 / (24.0 * 60.0)
    }
}

// MARK: - Hindu Solar Calendar

/// A Hindu solar calendar parameterized by regional variant.
///
/// Solar months correspond to zodiac signs (rashis). The month starts on the civil
/// day when the sidereal sun enters that rashi, evaluated at the variant's "critical time."
///
/// The calendar requires a geographic location for sunrise/sunset calculations.
public struct HinduSolar<V: HinduSolarVariant>: CalendarProtocol, Sendable {
    public static var calendarIdentifier: String { V.calendarIdentifier }

    public let location: Location?
    private let loc: Location
    private let engine: MoshierEngine

    public init(location: Location = .newDelhi) {
        self.location = location
        self.loc = location
        self.engine = MoshierEngine()
    }

    // MARK: - CalendarProtocol

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> HinduSolarDateInner {
        let extYear = try resolveYear(year)
        guard !month.isLeap else { throw DateNewError.monthNotInCalendar }
        guard month.number >= 1, month.number <= 12 else { throw DateNewError.monthNotInCalendar }
        // We can't easily validate the day without computing the month start,
        // so we do a basic range check
        guard day >= 1, day <= 32 else { throw DateNewError.invalidDay(max: 32) }
        return HinduSolarDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: HinduSolarDateInner) -> RataDie {
        let jdStart = HinduSolarArithmetic.solarMonthStart(
            month: Int(date.month), year: Int(date.year), variant: V.self, loc: loc, engine: engine
        )
        return JulianDayHelper.jdToRd(jdStart + Double(date.day - 1))
    }

    public func fromRataDie(_ rd: RataDie) -> HinduSolarDateInner {
        let jd = JulianDayHelper.rdToJd(rd)
        let result = HinduSolarArithmetic.gregorianToSolar(
            jd: jd, loc: loc, variant: V.self, engine: engine
        )
        return HinduSolarDateInner(year: Int32(result.year), month: UInt8(result.month), day: UInt8(result.day))
    }

    public func yearInfo(_ date: HinduSolarDateInner) -> YearInfo {
        .era(EraYear(
            era: V.eraName,
            year: date.year,
            extendedYear: date.year,
            ambiguity: .centuryRequired
        ))
    }

    public func monthInfo(_ date: HinduSolarDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: HinduSolarDateInner) -> UInt8 { date.day }

    public func dayOfYear(_ date: HinduSolarDateInner) -> UInt16 {
        // Sum days in months before this one
        var total: UInt16 = 0
        for m in 1..<Int(date.month) {
            total += UInt16(HinduSolarArithmetic.solarMonthLength(
                month: m, year: Int(date.year), variant: V.self, loc: loc, engine: engine
            ))
        }
        return total + UInt16(date.day)
    }

    public func daysInMonth(_ date: HinduSolarDateInner) -> UInt8 {
        UInt8(HinduSolarArithmetic.solarMonthLength(
            month: Int(date.month), year: Int(date.year), variant: V.self, loc: loc, engine: engine
        ))
    }

    public func daysInYear(_ date: HinduSolarDateInner) -> UInt16 {
        var total: UInt16 = 0
        for m in 1...12 {
            total += UInt16(HinduSolarArithmetic.solarMonthLength(
                month: m, year: Int(date.year), variant: V.self, loc: loc, engine: engine
            ))
        }
        return total
    }

    public func monthsInYear(_ date: HinduSolarDateInner) -> UInt8 { 12 }

    public func isInLeapYear(_ date: HinduSolarDateInner) -> Bool {
        daysInYear(date) > 365
    }

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(let era, let year):
            guard era == V.eraName else { throw DateNewError.invalidEra }
            return year
        }
    }
}

// MARK: - HinduSolarDateInner

public struct HinduSolarDateInner: Equatable, Comparable, Hashable, Sendable {
    let year: Int32
    let month: UInt8   // 1-12 regional month
    let day: UInt8     // 1-32

    public static func < (lhs: HinduSolarDateInner, rhs: HinduSolarDateInner) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}

// MARK: - HinduSolarArithmetic

enum HinduSolarArithmetic {

    /// Find the JD (UT) of the sankranti (rashi entry) nearest to `jdApprox` for `targetLongitude`.
    static func sankrantiJd(_ jdApprox: Double, _ targetLongitude: Double) -> Double {
        var lo = jdApprox - 20.0
        var hi = jdApprox + 20.0

        let lonLo = HinduAyanamsa.siderealSolarLongitude(lo)
        var diffLo = lonLo - targetLongitude
        if diffLo > 180.0 { diffLo -= 360.0 }
        if diffLo < -180.0 { diffLo += 360.0 }
        if diffLo >= 0 { lo -= 30.0 }

        for _ in 0..<50 {
            let mid = (lo + hi) / 2.0
            let lon = HinduAyanamsa.siderealSolarLongitude(mid)
            var diff = lon - targetLongitude
            if diff > 180.0 { diff -= 360.0 }
            if diff < -180.0 { diff += 360.0 }

            if diff >= 0 {
                hi = mid
            } else {
                lo = mid
            }

            if hi - lo < 1e-3 / 86400.0 { break }
        }

        return (lo + hi) / 2.0
    }

    /// Convert a Gregorian date (as JD) to a Hindu solar date.
    static func gregorianToSolar<V: HinduSolarVariant>(
        jd: Double, loc: Location, variant: V.Type, engine: MoshierEngine
    ) -> (year: Int, month: Int, day: Int) {
        let jdMidnight = floor(jd - 0.5) + 0.5
        let jdCrit = V.criticalTimeJd(jdMidnight, loc, engine: engine)

        var lon = HinduAyanamsa.siderealSolarLongitude(jdCrit)
        var rashi = Int(floor(lon / 30.0)) + 1
        if rashi > 12 { rashi = 12 }
        if rashi < 1 { rashi = 1 }

        // Bengali rashi correction near boundaries
        V.rashiCorrection(jdCrit, &rashi, &lon)

        let target = Double(rashi - 1) * 30.0
        var degreesPast = lon - target
        if degreesPast < 0 { degreesPast += 360.0 }
        let jdEst = jdCrit - degreesPast
        var jdSankranti = sankrantiJd(jdEst, target)

        let civilDay = sankrantiToCivilDay(jdSankranti, loc, V.self, rashi, engine: engine)
        let jdMonthStart = JulianDayHelper.ymdToJd(year: civilDay.0, month: civilDay.1, day: civilDay.2)
        var solarDay = Int(floor(jd - 0.5) + 0.5 - jdMonthStart) + 1

        if solarDay <= 0 {
            let prevRashi = (rashi == 1) ? 12 : rashi - 1
            let prevTarget = Double(prevRashi - 1) * 30.0
            jdSankranti = sankrantiJd(jdSankranti - 28.0, prevTarget)
            let prevCivil = sankrantiToCivilDay(jdSankranti, loc, V.self, prevRashi, engine: engine)
            let jdPrevStart = JulianDayHelper.ymdToJd(year: prevCivil.0, month: prevCivil.1, day: prevCivil.2)
            rashi = prevRashi
            solarDay = Int(floor(jd - 0.5) + 0.5 - jdPrevStart) + 1
        }

        let regionalMonth = rashiToRegionalMonth(rashi, V.self)
        let solarYear = computeSolarYear(jdCrit: jdCrit, loc: loc, jdGregDate: floor(jd - 0.5) + 0.5, variant: V.self, engine: engine)

        return (solarYear, regionalMonth, solarDay)
    }

    /// Find the JD of the first civil day of a solar month.
    static func solarMonthStart<V: HinduSolarVariant>(
        month: Int, year: Int, variant: V.Type, loc: Location, engine: MoshierEngine
    ) -> Double {
        var rashi = month + V.firstRashi - 1
        if rashi > 12 { rashi -= 12 }

        let yearStartMonth = ((V.yearStartRashi - V.firstRashi) % 12) + 1
        var monthsPast = month - yearStartMonth
        if monthsPast < 0 { monthsPast += 12 }

        var gy = year + V.gyOffsetOn
        var gmStart = 3 + V.yearStartRashi
        if gmStart > 12 { gmStart -= 12; gy += 1 }
        var approxGm = gmStart + monthsPast
        while approxGm > 12 { approxGm -= 12; gy += 1 }

        let jdApprox = JulianDayHelper.ymdToJd(year: gy, month: approxGm, day: 14)
        let target = Double(rashi - 1) * 30.0
        let jdSk = sankrantiJd(jdApprox, target)

        let civilDay = sankrantiToCivilDay(jdSk, loc, V.self, rashi, engine: engine)
        return JulianDayHelper.ymdToJd(year: civilDay.0, month: civilDay.1, day: civilDay.2)
    }

    /// Length of a solar month in days.
    static func solarMonthLength<V: HinduSolarVariant>(
        month: Int, year: Int, variant: V.Type, loc: Location, engine: MoshierEngine
    ) -> Int {
        let jdStart = solarMonthStart(month: month, year: year, variant: variant, loc: loc, engine: engine)
        let nextMonth = (month == 12) ? 1 : month + 1
        let yearStartMonth = ((V.yearStartRashi - V.firstRashi) % 12) + 1
        let lastMonth = (yearStartMonth == 1) ? 12 : yearStartMonth - 1
        let nextYear = (month == lastMonth) ? year + 1 : year
        let jdEnd = solarMonthStart(month: nextMonth, year: nextYear, variant: variant, loc: loc, engine: engine)
        return Int(jdEnd - jdStart)
    }

    /// Convert sankranti JD to the civil day it applies to.
    /// Includes Bengali per-rashi day edge offset, tuned critical time, and tithi push.
    private static func sankrantiToCivilDay<V: HinduSolarVariant>(
        _ jdSankranti: Double, _ loc: Location, _ variant: V.Type, _ rashi: Int, engine: MoshierEngine
    ) -> (Int, Int, Int) {
        let dayEdge = V.dayEdgeOffset(rashi)
        // loc.utcOffset is already in fractional days
        let localJd = jdSankranti + loc.utcOffset + 0.5 + dayEdge
        let ymd = JulianDayHelper.jdToYmd(floor(localJd))

        let jdDay = JulianDayHelper.ymdToJd(year: ymd.0, month: ymd.1, day: ymd.2)
        var crit = V.criticalTimeJd(jdDay, loc, engine: engine)
        crit = V.tunedCriticalTime(crit, rashi)

        if jdSankranti <= crit {
            if V.tithiPushNext(jdSankranti, jdDay, rashi, loc) {
                return JulianDayHelper.jdToYmd(jdDay + 1.0)
            }
            return ymd
        } else {
            return JulianDayHelper.jdToYmd(jdDay + 1.0)
        }
    }

    private static func rashiToRegionalMonth<V: HinduSolarVariant>(_ rashi: Int, _ variant: V.Type) -> Int {
        var m = rashi - V.firstRashi + 1
        if m <= 0 { m += 12 }
        return m
    }

    private static func computeSolarYear<V: HinduSolarVariant>(
        jdCrit: Double, loc: Location, jdGregDate: Double, variant: V.Type, engine: MoshierEngine
    ) -> Int {
        let ymd = JulianDayHelper.jdToYmd(jdCrit)
        let gy = ymd.0

        let targetLong = Double(V.yearStartRashi - 1) * 30.0
        var approxGregMonth = 3 + V.yearStartRashi
        if approxGregMonth > 12 { approxGregMonth -= 12 }

        let jdYearStartEst = JulianDayHelper.ymdToJd(year: gy, month: approxGregMonth, day: 14)
        let jdYearStart = sankrantiJd(jdYearStartEst, targetLong)

        let ysYmd = sankrantiToCivilDay(jdYearStart, loc, V.self, V.yearStartRashi, engine: engine)
        let jdYearCivil = JulianDayHelper.ymdToJd(year: ysYmd.0, month: ysYmd.1, day: ysYmd.2)

        if jdGregDate >= jdYearCivil {
            return gy - V.gyOffsetOn
        } else {
            return gy - V.gyOffsetBefore
        }
    }
}

// MARK: - JulianDayHelper (minimal JD↔Gregorian for internal use)

/// Julian Day ↔ Gregorian conversion for Hindu calendar internal use.
///
/// Returns REAL Julian Day Numbers (not RataDie+0.5).
/// JD = RataDie + 1721424.5 (for midnight).
public enum JulianDayHelper {
    /// JD offset: JD 0 = RD -1721424.5
    static let jdOffset: Double = 1721424.5

    /// Convert Gregorian (year, month, day) to Julian Day at midnight UT.
    public static func ymdToJd(year: Int, month: Int, day: Int) -> Double {
        Double(GregorianArithmetic.fixedFromGregorian(year: Int32(year), month: UInt8(month), day: UInt8(day)).dayNumber) + jdOffset
    }

    /// Convert Julian Day to Gregorian (year, month, day).
    public static func jdToYmd(_ jd: Double) -> (Int, Int, Int) {
        let rd = RataDie(Int64(floor(jd - jdOffset)))
        let (y, m, d) = GregorianArithmetic.gregorianFromFixed(rd)
        return (Int(y), Int(m), Int(d))
    }

    /// Convert RataDie to Julian Day at midnight.
    public static func rdToJd(_ rd: RataDie) -> Double {
        Double(rd.dayNumber) + jdOffset
    }

    /// Convert Julian Day to RataDie.
    public static func jdToRd(_ jd: Double) -> RataDie {
        RataDie(Int64(floor(jd - jdOffset)))
    }
}

// MARK: - Type Aliases

public typealias HinduTamil = HinduSolar<Tamil>
public typealias HinduBengali = HinduSolar<Bengali>
public typealias HinduOdia = HinduSolar<Odia>
public typealias HinduMalayalam = HinduSolar<Malayalam>

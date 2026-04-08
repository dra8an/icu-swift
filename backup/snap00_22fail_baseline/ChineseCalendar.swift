// Chinese and Korean (Dangi) lunisolar calendars.
//
// Uses astronomical calculations for winter solstice detection, new moon enumeration,
// and leap month identification. Ported from ICU4X chinese_based.rs and
// east_asian_traditional/simple.rs.

import CalendarCore
import CalendarSimple
import AstronomicalEngine
import Darwin  // for os_unfair_lock

/// Protocol for East Asian calendar variants (Chinese vs Korean/Dangi).
public protocol EastAsianVariant: Sendable {
    static var calendarIdentifier: String { get }
    /// UTC offset in fractional days for the reference location.
    static func utcOffset(rd: RataDie) -> Double
    /// The epoch for cyclic year calculation.
    static var epoch: RataDie { get }
}

/// Chinese calendar variant (Beijing, UTC+8).
public enum China: EastAsianVariant {
    public static let calendarIdentifier = "chinese"
    public static func utcOffset(rd: RataDie) -> Double {
        // Before 1929: Beijing local mean solar time (116.4°E → 1397/180/24 days)
        // From 1929: UTC+8
        let cutoff = GregorianArithmetic.fixedFromGregorian(year: 1929, month: 1, day: 1)
        if rd < cutoff {
            return 1397.0 / 180.0 / 24.0
        }
        return 8.0 / 24.0
    }
    public static let epoch = GregorianArithmetic.fixedFromGregorian(year: -2636, month: 2, day: 15)
}

/// Korean (Dangi) calendar variant (Seoul, UTC+9).
public enum Korea: EastAsianVariant {
    public static let calendarIdentifier = "dangi"
    public static func utcOffset(rd: RataDie) -> Double {
        // Historical Korean time zones varied
        let y1908 = GregorianArithmetic.fixedFromGregorian(year: 1908, month: 4, day: 1)
        let y1912 = GregorianArithmetic.fixedFromGregorian(year: 1912, month: 1, day: 1)
        let y1954 = GregorianArithmetic.fixedFromGregorian(year: 1954, month: 3, day: 21)
        let y1961 = GregorianArithmetic.fixedFromGregorian(year: 1961, month: 8, day: 10)

        if rd < y1908 { return 3809.0 / 450.0 / 24.0 }
        else if rd < y1912 { return 8.5 / 24.0 }
        else if rd < y1954 { return 9.0 / 24.0 }
        else if rd < y1961 { return 8.5 / 24.0 }
        else { return 9.0 / 24.0 }
    }
    public static let epoch = GregorianArithmetic.fixedFromGregorian(year: -2332, month: 2, day: 15)
}

/// A Chinese/Korean lunisolar calendar.
///
/// Uses astronomical calculations to determine:
/// - Winter solstice (sun at 270° longitude)
/// - New moons (lunar-solar conjunction)
/// - Leap months (first month without a major solar term)
///
/// Months are numbered 1-12, with an optional leap month. The year uses
/// 60-year cyclic numbering via `CyclicYear`.
public struct ChineseCalendar<V: EastAsianVariant>: CalendarProtocol, Sendable {
    public static var calendarIdentifier: String { V.calendarIdentifier }

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> ChineseDateInner {
        let relatedIso = try resolveYear(year)
        let yearData = ChineseYearCache.shared.get(relatedIso: relatedIso, variant: V.self)

        let ordinalMonth = try resolveOrdinalMonth(yearData: yearData, month: month)
        let maxDay = yearData.monthLength(ordinalMonth)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }

        return ChineseDateInner(relatedIso: relatedIso, ordinalMonth: ordinalMonth, day: day)
    }

    public func toRataDie(_ date: ChineseDateInner) -> RataDie {
        let yearData = ChineseYearCache.shared.get(relatedIso: date.relatedIso, variant: V.self)
        return yearData.newYear + Int64(yearData.daysBeforeMonth(date.ordinalMonth)) + Int64(date.day - 1)
    }

    public func fromRataDie(_ rd: RataDie) -> ChineseDateInner {
        // Approximate the related ISO year
        let isoYear = GregorianArithmetic.yearFromFixed(rd)
        // Chinese new year is typically in Jan-Feb, so the Chinese year for a date
        // in Jan might be the previous ISO year
        var relatedIso = isoYear
        var yearData = ChineseYearCache.shared.get(relatedIso: relatedIso, variant: V.self)

        // Adjust if rd is before this year's new year
        if rd < yearData.newYear {
            relatedIso -= 1
            yearData = ChineseYearCache.shared.get(relatedIso: relatedIso, variant: V.self)
        }

        // Check if it's actually in the next year
        let nextYearData = ChineseYearCache.shared.get(relatedIso: relatedIso + 1, variant: V.self)
        if rd >= nextYearData.newYear {
            relatedIso += 1
            yearData = nextYearData
        }

        let dayOfYear = Int(rd.dayNumber - yearData.newYear.dayNumber)
        let (ordinalMonth, day) = yearData.monthAndDay(dayOfYear: dayOfYear)

        return ChineseDateInner(relatedIso: relatedIso, ordinalMonth: ordinalMonth, day: day)
    }

    public func yearInfo(_ date: ChineseDateInner) -> YearInfo {
        let relIso = date.relatedIso
        // 60-year cycle: (relatedIso - epoch_year) mod 60
        let epochYear = GregorianArithmetic.yearFromFixed(V.epoch)
        var cyclePos = ((Int64(relIso) - Int64(epochYear)) % 60)
        if cyclePos <= 0 { cyclePos += 60 }
        return .cyclic(CyclicYear(yearOfCycle: UInt8(cyclePos), relatedIso: relIso))
    }

    public func monthInfo(_ date: ChineseDateInner) -> MonthInfo {
        let yearData = ChineseYearCache.shared.get(relatedIso: date.relatedIso, variant: V.self)
        let (number, isLeap) = yearData.monthCode(ordinal: date.ordinalMonth)
        let month = isLeap ? Month.leap(number) : Month.new(number)
        return MonthInfo(ordinal: date.ordinalMonth, month: month)
    }

    public func dayOfMonth(_ date: ChineseDateInner) -> UInt8 { date.day }

    public func dayOfYear(_ date: ChineseDateInner) -> UInt16 {
        let yearData = ChineseYearCache.shared.get(relatedIso: date.relatedIso, variant: V.self)
        return UInt16(yearData.daysBeforeMonth(date.ordinalMonth)) + UInt16(date.day)
    }

    public func daysInMonth(_ date: ChineseDateInner) -> UInt8 {
        let yearData = ChineseYearCache.shared.get(relatedIso: date.relatedIso, variant: V.self)
        return yearData.monthLength(date.ordinalMonth)
    }

    public func daysInYear(_ date: ChineseDateInner) -> UInt16 {
        let yearData = ChineseYearCache.shared.get(relatedIso: date.relatedIso, variant: V.self)
        return yearData.totalDays
    }

    public func monthsInYear(_ date: ChineseDateInner) -> UInt8 {
        let yearData = ChineseYearCache.shared.get(relatedIso: date.relatedIso, variant: V.self)
        return yearData.monthCount
    }

    public func isInLeapYear(_ date: ChineseDateInner) -> Bool {
        let yearData = ChineseYearCache.shared.get(relatedIso: date.relatedIso, variant: V.self)
        return yearData.leapMonth != nil
    }

    // MARK: - Private

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(_, _): throw DateNewError.invalidEra
        }
    }

    private func resolveOrdinalMonth(yearData: ChineseYearData, month: Month) throws -> UInt8 {
        let leapMonth = yearData.leapMonth ?? 255

        if month.isLeap {
            guard month.number == leapMonth else {
                throw DateNewError.monthNotInYear
            }
            return leapMonth + 1  // Leap month follows the regular month
        }

        let num = month.number
        guard num >= 1, num <= 12 else { throw DateNewError.monthNotInCalendar }

        // Ordinal month: if there's a leap month before this month, shift by 1
        if let lm = yearData.leapMonth, num > lm {
            return num + 1
        }
        return num
    }
}

// MARK: - ChineseDateInner

/// Internal date representation for Chinese/Korean calendars.
public struct ChineseDateInner: Equatable, Comparable, Hashable, Sendable {
    /// The related ISO year (approximate Gregorian year).
    let relatedIso: Int32
    /// Ordinal month within the year (1-13, including leap month).
    let ordinalMonth: UInt8
    /// Day of the month (1-30).
    let day: UInt8

    public static func < (lhs: ChineseDateInner, rhs: ChineseDateInner) -> Bool {
        if lhs.relatedIso != rhs.relatedIso { return lhs.relatedIso < rhs.relatedIso }
        if lhs.ordinalMonth != rhs.ordinalMonth { return lhs.ordinalMonth < rhs.ordinalMonth }
        return lhs.day < rhs.day
    }
}

// MARK: - ChineseYearData

/// Thread-safe LRU cache for Chinese/Korean year computations.
///
/// Each year requires ~15 new moon + ~15 solar longitude evaluations via Moshier.
/// Caching avoids repeating this for consecutive dates in the same year.
final class ChineseYearCache: @unchecked Sendable {
    private var cache: [(key: Int64, data: ChineseYearData)] = []
    private let maxSize = 8
    private let lock: UnsafeMutablePointer<os_unfair_lock>

    static let shared = ChineseYearCache()

    private init() {
        lock = .allocate(capacity: 1)
        lock.initialize(to: os_unfair_lock())
    }

    deinit {
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    func get<V: EastAsianVariant>(relatedIso: Int32, variant: V.Type) -> ChineseYearData {
        let key = (Int64(relatedIso) << 1) | (V.calendarIdentifier == "chinese" ? 0 : 1)

        os_unfair_lock_lock(lock)
        if let idx = cache.firstIndex(where: { $0.key == key }) {
            let data = cache[idx].data
            // Move to front (most recently used)
            if idx > 0 {
                let entry = cache.remove(at: idx)
                cache.insert(entry, at: 0)
            }
            os_unfair_lock_unlock(lock)
            return data
        }
        os_unfair_lock_unlock(lock)

        let data = ChineseYearData.compute(relatedIso: relatedIso, variant: variant)

        os_unfair_lock_lock(lock)
        cache.insert((key: key, data: data), at: 0)
        if cache.count > maxSize {
            cache.removeLast()
        }
        os_unfair_lock_unlock(lock)

        return data
    }
}

/// Computed data for a Chinese/Korean calendar year.
///
/// Contains the new year date, month lengths, and leap month information.
struct ChineseYearData {
    /// RataDie of the first day of this year (month 1, day 1).
    let newYear: RataDie
    /// Length of each month (ordinal 1-indexed). True = 30 days, false = 29 days.
    let monthLengths: [Bool]  // Up to 13 entries
    /// The month number (1-12) that is the leap month, or nil if no leap month.
    let leapMonth: UInt8?

    var monthCount: UInt8 {
        UInt8(monthLengths.count)
    }

    var totalDays: UInt16 {
        var total: UInt16 = 0
        for isLong in monthLengths {
            total += isLong ? 30 : 29
        }
        return total
    }

    func monthLength(_ ordinalMonth: UInt8) -> UInt8 {
        guard ordinalMonth >= 1, Int(ordinalMonth) <= monthLengths.count else { return 30 }
        return monthLengths[Int(ordinalMonth) - 1] ? 30 : 29
    }

    func daysBeforeMonth(_ ordinalMonth: UInt8) -> Int {
        var total = 0
        for i in 0..<Int(ordinalMonth - 1) {
            total += monthLengths[i] ? 30 : 29
        }
        return total
    }

    /// Given a 0-indexed day-of-year, return (ordinalMonth, day).
    func monthAndDay(dayOfYear: Int) -> (UInt8, UInt8) {
        var remaining = dayOfYear
        for (i, isLong) in monthLengths.enumerated() {
            let len = isLong ? 30 : 29
            if remaining < len {
                return (UInt8(i + 1), UInt8(remaining + 1))
            }
            remaining -= len
        }
        // Shouldn't reach here for valid dates
        return (UInt8(monthLengths.count), UInt8(remaining + 1))
    }

    /// Get the month code (number, isLeap) for an ordinal month.
    func monthCode(ordinal: UInt8) -> (number: UInt8, isLeap: Bool) {
        guard let lm = leapMonth else {
            return (ordinal, false)
        }
        // The leap month has ordinal = lm + 1
        let leapOrdinal = lm + 1
        if ordinal == leapOrdinal {
            return (lm, true)
        } else if ordinal > leapOrdinal {
            return (ordinal - 1, false)
        } else {
            return (ordinal, false)
        }
    }

    /// Compute year data using the HybridEngine (Moshier for modern dates, Reingold for ancient).
    static func compute<V: EastAsianVariant>(relatedIso: Int32, variant: V.Type) -> ChineseYearData {
        let engine = HybridEngine()
        let jan1 = GregorianArithmetic.fixedFromGregorian(year: relatedIso, month: 1, day: 1)

        // Helper: convert local date to midnight universal time (ICU4X convention)
        func midnight(_ rd: RataDie) -> Moment {
            let offset = V.utcOffset(rd: rd)
            return Moment(Double(rd.dayNumber)) - offset
        }

        // Helper: find new moon on or after a date in local time, return local RD
        func newMoonOnOrAfter(_ rd: RataDie) -> RataDie {
            let nmMoment = engine.newMoonAtOrAfter(midnight(rd))
            let offset = V.utcOffset(rd: nmMoment.rataDie)
            return (nmMoment + offset).rataDie
        }

        // Helper: find new moon on or before a date in local time, return local RD.
        // Searches backwards in ~30-day steps until newMoonOnOrAfter lands at-or-before rd.
        func newMoonOnOrBefore(_ rd: RataDie) -> RataDie {
            // The new moon at-or-after (rd - 35) is guaranteed to be ≤ rd, since
            // synodic month is ~29.5 days.
            var probe = RataDie(rd.dayNumber - 35)
            var nm = newMoonOnOrAfter(probe)
            // Walk forward in synodic-month steps to land on the latest new moon ≤ rd.
            while true {
                let next = newMoonOnOrAfter(RataDie(nm.dayNumber + 1))
                if next.dayNumber > rd.dayNumber { return nm }
                nm = next
                _ = probe  // silence
            }
        }

        // Helper: solar longitude at midnight universal time of a local date
        func solarLongitudeAt(_ rd: RataDie) -> Double {
            engine.solarLongitude(at: midnight(rd))
        }

        // Helper: major solar term number at a local RD
        func majorSolarTerm(_ rd: RataDie) -> UInt32 {
            let lon = solarLongitudeAt(rd)
            return UInt32(((2.0 + (lon / 30.0).rounded(.down) - 1.0)
                .truncatingRemainder(dividingBy: 12.0) + 12.0)
                .truncatingRemainder(dividingBy: 12.0)) + 1
        }

        // Find the winter solstice (solar longitude = 270°) before this date.
        let searchMoment = midnight(RataDie(jan1.dayNumber + 30))
        let solsticeMoment = Astronomical.estimatePriorSolarLongitude(angle: 270.0, moment: searchMoment)
        var solsticeDay = Moment(solsticeMoment.inner.rounded(.down))
        while 270.0 >= engine.solarLongitude(at: midnight(RataDie(Int64(solsticeDay.inner + 1.0)))) {
            solsticeDay = solsticeDay + 1.0
        }
        let solsticeRd = solsticeDay.rataDie

        // The 11th month is the lunar month CONTAINING the winter solstice.
        let nm11 = newMoonOnOrBefore(solsticeRd)

        var newMoons: [RataDie] = [nm11]
        var current = nm11
        for _ in 0..<16 {
            current = newMoonOnOrAfter(RataDie(current.dayNumber + 1))
            newMoons.append(current)
        }

        // Find next winter solstice
        let nextSearchMoment = midnight(RataDie(solsticeRd.dayNumber + 370))
        let nextSolsticeMoment = Astronomical.estimatePriorSolarLongitude(angle: 270.0, moment: nextSearchMoment)
        var nextSolsticeDay = Moment(nextSolsticeMoment.inner.rounded(.down))
        while 270.0 >= engine.solarLongitude(at: midnight(RataDie(Int64(nextSolsticeDay.inner + 1.0)))) {
            nextSolsticeDay = nextSolsticeDay + 1.0
        }
        let nextSolsticeRd = nextSolsticeDay.rataDie

        let nextNm11 = newMoonOnOrBefore(nextSolsticeRd)
        let moonsBetweenSolstices = newMoons.filter { $0 >= nm11 && $0 < nextNm11 }.count
        let hasLeapMonth = moonsBetweenSolstices == 13

        let majorSolarTerms: [UInt32] = newMoons.map { majorSolarTerm($0) }

        // nm[0] = M11. Normally nm[2] = M01. If M11 or M12 is leap, nm[3] = M01.
        var newYearIndex = 2
        if hasLeapMonth {
            for i in 0..<2 {
                if majorSolarTerms[i] == majorSolarTerms[i + 1] {
                    newYearIndex = 3
                    break
                }
            }
        }

        let newYear = newMoons[newYearIndex]

        var monthLengths: [Bool] = []
        var leapMonthNum: UInt8? = nil
        var monthNum: UInt8 = 1

        for i in newYearIndex..<min(newYearIndex + 13, newMoons.count - 1) {
            let len = newMoons[i + 1].dayNumber - newMoons[i].dayNumber
            let isLong = len == 30

            if hasLeapMonth && leapMonthNum == nil {
                if i + 1 < majorSolarTerms.count && majorSolarTerms[i] == majorSolarTerms[i + 1] {
                    leapMonthNum = monthNum - 1
                    monthLengths.append(isLong)
                    continue
                }
            }

            monthLengths.append(isLong)
            monthNum += 1

            if monthNum > 12 && leapMonthNum == nil && !hasLeapMonth { break }
            if monthNum > 13 { break }
        }

        while monthLengths.count < 12 { monthLengths.append(false) }
        if !hasLeapMonth && monthLengths.count > 12 { monthLengths = Array(monthLengths.prefix(12)) }
        if monthLengths.count > 13 { monthLengths = Array(monthLengths.prefix(13)) }

        return ChineseYearData(
            newYear: newYear,
            monthLengths: monthLengths,
            leapMonth: leapMonthNum
        )
    }

    /// Convert a new moon moment to a local RataDie, accounting for UTC offset.
    private static func localNewMoonDay(_ moment: Moment, utcOffset: Double) -> RataDie {
        let local = moment + utcOffset
        return RataDie(Int64(local.inner.rounded(FloatingPointRoundingRule.down)))
    }
}

// MARK: - Type Aliases

/// The Chinese traditional calendar.
public typealias Chinese = ChineseCalendar<China>

/// The Korean traditional (Dangi) calendar.
public typealias Dangi = ChineseCalendar<Korea>

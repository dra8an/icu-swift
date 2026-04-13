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
        let packed = packedYear(relatedIso)

        let ordinalMonth = try resolveOrdinalMonth(packed: packed, month: month)
        let maxDay = packed.monthLength(ordinalMonth)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }

        return ChineseDateInner(relatedIso: relatedIso, ordinalMonth: ordinalMonth, day: day, packed: packed)
    }

    public func toRataDie(_ date: ChineseDateInner) -> RataDie {
        let ny = date.packed.newYear(relatedIso: date.relatedIso)
        return ny + Int64(date.packed.daysBeforeMonth(date.ordinalMonth)) + Int64(date.day - 1)
    }

    public func fromRataDie(_ rd: RataDie) -> ChineseDateInner {
        let isoYear = GregorianArithmetic.yearFromFixed(rd)
        var relatedIso = isoYear
        var packed = packedYear(relatedIso)
        var ny = packed.newYear(relatedIso: relatedIso)

        // Adjust if rd is before this year's new year
        if rd.dayNumber < ny.dayNumber {
            relatedIso -= 1
            packed = packedYear(relatedIso)
            ny = packed.newYear(relatedIso: relatedIso)
        }

        // Check if it's actually in the next year
        let nextPacked = packedYear(relatedIso + 1)
        let nextNY = nextPacked.newYear(relatedIso: relatedIso + 1)
        if rd.dayNumber >= nextNY.dayNumber {
            relatedIso += 1
            packed = nextPacked
            ny = nextNY
        }

        let dayOfYear = Int(rd.dayNumber - ny.dayNumber)
        let (ordinalMonth, day) = packed.monthAndDay(dayOfYear: dayOfYear)

        return ChineseDateInner(relatedIso: relatedIso, ordinalMonth: ordinalMonth, day: day, packed: packed)
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
        let (number, isLeap) = date.packed.monthCode(ordinal: date.ordinalMonth)
        let month = isLeap ? Month.leap(number) : Month.new(number)
        return MonthInfo(ordinal: date.ordinalMonth, month: month)
    }

    public func dayOfMonth(_ date: ChineseDateInner) -> UInt8 { date.day }

    public func dayOfYear(_ date: ChineseDateInner) -> UInt16 {
        date.packed.daysBeforeMonth(date.ordinalMonth) + UInt16(date.day)
    }

    public func daysInMonth(_ date: ChineseDateInner) -> UInt8 {
        date.packed.monthLength(date.ordinalMonth)
    }

    public func daysInYear(_ date: ChineseDateInner) -> UInt16 {
        date.packed.totalDays
    }

    public func monthsInYear(_ date: ChineseDateInner) -> UInt8 {
        date.packed.monthCount
    }

    public func isInLeapYear(_ date: ChineseDateInner) -> Bool {
        date.packed.leapMonth != nil
    }

    // MARK: - Year Data Resolution

    /// Get packed year data: table lookup for 1901–2099, Moshier fallback otherwise.
    private func packedYear(_ relatedIso: Int32) -> PackedChineseYearData {
        if let p = ChineseYearTable.lookup(relatedIso) {
            return p
        }
        let yd = ChineseYearCache.shared.get(relatedIso: relatedIso, variant: V.self)
        return PackedChineseYearData.from(yearData: yd, relatedIso: relatedIso)
    }

    // MARK: - Private

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(_, _): throw DateNewError.invalidEra
        }
    }

    private func resolveOrdinalMonth(packed: PackedChineseYearData, month: Month) throws -> UInt8 {
        let leapMonth = packed.leapMonth ?? 255

        if month.isLeap {
            guard month.number == leapMonth else {
                throw DateNewError.monthNotInYear
            }
            return leapMonth + 1
        }

        let num = month.number
        guard num >= 1, num <= 12 else { throw DateNewError.monthNotInCalendar }

        if let lm = packed.leapMonth, num > lm {
            return num + 1
        }
        return num
    }
}

// MARK: - ChineseDateInner

/// Internal date representation for Chinese/Korean calendars.
///
/// Carries packed year data so that field accessors and arithmetic never
/// need a cache lookup or astronomical calculation.
public struct ChineseDateInner: Equatable, Comparable, Hashable, Sendable {
    /// The related ISO year (approximate Gregorian year).
    let relatedIso: Int32
    /// Ordinal month within the year (1-13, including leap month).
    let ordinalMonth: UInt8
    /// Day of the month (1-30).
    let day: UInt8
    /// Packed year data (month lengths, leap month, new year offset).
    let packed: PackedChineseYearData

    public static func < (lhs: ChineseDateInner, rhs: ChineseDateInner) -> Bool {
        if lhs.relatedIso != rhs.relatedIso { return lhs.relatedIso < rhs.relatedIso }
        if lhs.ordinalMonth != rhs.ordinalMonth { return lhs.ordinalMonth < rhs.ordinalMonth }
        return lhs.day < rhs.day
    }

    // Equatable/Hashable: only compare date fields, not packed data
    public static func == (lhs: ChineseDateInner, rhs: ChineseDateInner) -> Bool {
        lhs.relatedIso == rhs.relatedIso && lhs.ordinalMonth == rhs.ordinalMonth && lhs.day == rhs.day
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(relatedIso)
        hasher.combine(ordinalMonth)
        hasher.combine(day)
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

        // Helper: find new moon on or after a date in local time, return local RD.
        // When the new moon falls within ~10 seconds of local midnight (after midnight),
        // snap it back to the previous day to match HKO's authoritative tables. The
        // boundary precision of Moshier (VSOP87) vs HKO's source (likely JPL-grade)
        // can disagree by a few seconds at conjunctions; HKO has been observed to
        // place such "just-past-midnight" new moons on the prior day (e.g. 2057-09).
        func newMoonOnOrAfter(_ rd: RataDie) -> RataDie {
            let nmMoment = engine.newMoonAtOrAfter(midnight(rd))
            let offset = V.utcOffset(rd: nmMoment.rataDie)
            let local = (nmMoment + offset).inner
            let frac = local - local.rounded(.down)
            if frac < 1e-4 {
                return RataDie(Int64(local.rounded(.down)) - 1)
            }
            return RataDie(Int64(local.rounded(.down)))
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

        // Helper: find the new year (M01 start) for the Chinese year whose
        // related ISO year corresponds to a given January 1 RD. Uses the
        // sui (winter-solstice-to-winter-solstice) algorithm: M01 is the
        // 2nd new moon after the prior solstice (or 3rd if M11 or M12 of the
        // prior year is a leap month).
        func findNewYear(forJan1 j1: RataDie) -> RataDie {
            let search = midnight(RataDie(j1.dayNumber + 30))
            let estimate = Astronomical.estimatePriorSolarLongitude(angle: 270.0, moment: search)
            var sd = Moment(estimate.inner.rounded(.down))
            while 270.0 >= engine.solarLongitude(at: midnight(RataDie(Int64(sd.inner + 1.0)))) {
                sd = sd + 1.0
            }
            let solsticeRd = sd.rataDie
            // M11 = lunar month containing the winter solstice = nm on/before solstice.
            let m11 = newMoonOnOrBefore(solsticeRd)
            // Skip to M12, then M01 (or further if there's a leap M11/M12).
            let m12 = newMoonOnOrAfter(RataDie(m11.dayNumber + 1))
            let m13 = newMoonOnOrAfter(RataDie(m12.dayNumber + 1))
            // Detect leap M11 or M12: same major solar term as the next month.
            if majorSolarTerm(m11) == majorSolarTerm(m12) || majorSolarTerm(m12) == majorSolarTerm(m13) {
                // Leap was M11 or M12 — new year is one nm later.
                return newMoonOnOrAfter(RataDie(m13.dayNumber + 1))
            }
            return m13
        }

        let newYear = findNewYear(forJan1: jan1)
        let nextJan1 = GregorianArithmetic.fixedFromGregorian(year: relatedIso + 1, month: 1, day: 1)
        let nextNewYear = findNewYear(forJan1: nextJan1)

        // Iterate exactly 12 months from new year, computing lengths and detecting
        // a leap month via forward comparison of major solar terms.
        // After 12 iterations, if there's still a 13th month before next_new_year and
        // no leap was detected, the 13th month is the leap month.
        var monthLengths: [Bool] = []
        // Track the LAST same-term pair found within the 12-iter window. When
        // boundary precision causes a false positive (typically earlier in the
        // year, when a zhōngqì falls within ~1 hour of local midnight), the real
        // leap is later — so taking the last match is more robust than the first.
        var detectedLeap: UInt8? = nil
        var current = newYear
        var currentTerm = majorSolarTerm(current)

        for i in 0..<12 {
            let next = newMoonOnOrAfter(RataDie(current.dayNumber + 1))
            let nextTerm = majorSolarTerm(next)
            if currentTerm == nextTerm {
                // i is 0-indexed slot of current month within the year.
                // Display number for the leap = i (since the leap duplicates the
                // preceding regular month's number).
                detectedLeap = UInt8(i)
            }
            monthLengths.append((next.dayNumber - current.dayNumber) == 30)
            current = next
            currentTerm = nextTerm
        }

        var leapMonthNum: UInt8? = nil
        if current != nextNewYear {
            // 13-month year: append the trailing 13th month and commit the leap.
            monthLengths.append((nextNewYear.dayNumber - current.dayNumber) == 30)
            // Use detected leap if any; otherwise the 13th (M11L-style) is the leap.
            leapMonthNum = detectedLeap ?? 12
        }
        // 12-month year: no leap, even if a false positive fired (deliberately ignored).

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

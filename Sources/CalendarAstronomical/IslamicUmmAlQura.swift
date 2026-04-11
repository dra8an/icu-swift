// Islamic Umm al-Qura calendar — Saudi Arabia's official Hijri calendar.
//
// Uses baked month-length data from KACST (King Abdulaziz City for Science
// and Technology) for years 1300-1600 AH (~1882-2174 CE). Outside that
// range, falls back to Islamic Civil (Friday epoch, Type II) arithmetic.
//
// Ported from ICU4X components/calendar/src/cal/hijri.rs and
// hijri/ummalqura_data.rs (Unicode License).

import CalendarCore
import CalendarSimple

// MARK: - IslamicUmmAlQura

/// The Islamic Umm al-Qura calendar (`islamic-umalqura`).
///
/// The official civil calendar of Saudi Arabia, based on astronomical new
/// moon predictions for the Mecca region published by KACST. Month lengths
/// are 29 or 30 days but do **not** follow a fixed cycle — they are
/// determined by observation-calibrated tables.
///
/// For years 1300–1600 AH (~1882–2174 CE) the calendar uses a precomputed
/// data table of 301 entries. Outside that range it falls back to
/// `IslamicCivil` (Type II, Friday epoch) arithmetic.
///
/// Two eras: `ah` (Anno Hegirae) and `bh` (Before Hijrah).
public struct IslamicUmmAlQura: CalendarProtocol, Sendable {
    public static let calendarIdentifier = "islamic-umalqura"
    public typealias DateInner = IslamicTabularDateInner

    public init() {}

    public func newDate(year: YearInput, month: Month, day: UInt8) throws -> IslamicTabularDateInner {
        let extYear = try resolveYear(year)
        try validateMonthDay(year: extYear, month: month, day: day)
        return IslamicTabularDateInner(year: extYear, month: month.number, day: day)
    }

    public func toRataDie(_ date: IslamicTabularDateInner) -> RataDie {
        let yi = UmmAlQuraYearInfo.forYear(date.year)
        return yi.newYear + Int64(yi.packed.daysBeforeMonth(date.month)) + Int64(date.day) - 1
    }

    public func fromRataDie(_ rd: RataDie) -> IslamicTabularDateInner {
        // Use tabular yearFromFixed as initial estimate, then adjust
        let epoch = TabularEpoch.friday.rataDie
        var year = IslamicTabularArithmetic.yearFromFixed(rd, epoch: epoch)

        // Adjust: make sure year's new year ≤ rd < next year's new year
        var yi = UmmAlQuraYearInfo.forYear(year)
        while yi.newYear.dayNumber > rd.dayNumber {
            year -= 1
            yi = UmmAlQuraYearInfo.forYear(year)
        }
        while rd.dayNumber >= yi.newYear.dayNumber + Int64(yi.packed.daysInYear) {
            year += 1
            yi = UmmAlQuraYearInfo.forYear(year)
        }

        let dayOfYear = UInt16(rd.dayNumber - yi.newYear.dayNumber + 1)
        let (month, day) = yi.packed.monthAndDay(dayOfYear: dayOfYear)
        return IslamicTabularDateInner(year: year, month: month, day: day)
    }

    public func yearInfo(_ date: IslamicTabularDateInner) -> YearInfo {
        if date.year > 0 {
            return .era(EraYear(
                era: "ah", year: date.year, extendedYear: date.year,
                ambiguity: .centuryRequired
            ))
        } else {
            return .era(EraYear(
                era: "bh", year: 1 - date.year, extendedYear: date.year,
                ambiguity: .eraAndCenturyRequired
            ))
        }
    }

    public func monthInfo(_ date: IslamicTabularDateInner) -> MonthInfo {
        MonthInfo(ordinal: date.month, month: .new(date.month))
    }

    public func dayOfMonth(_ date: IslamicTabularDateInner) -> UInt8 { date.day }

    public func dayOfYear(_ date: IslamicTabularDateInner) -> UInt16 {
        let yi = UmmAlQuraYearInfo.forYear(date.year)
        return yi.packed.daysBeforeMonth(date.month) + UInt16(date.day)
    }

    public func daysInMonth(_ date: IslamicTabularDateInner) -> UInt8 {
        let yi = UmmAlQuraYearInfo.forYear(date.year)
        return yi.packed.monthLength(date.month)
    }

    public func daysInYear(_ date: IslamicTabularDateInner) -> UInt16 {
        let yi = UmmAlQuraYearInfo.forYear(date.year)
        return yi.packed.daysInYear
    }

    public func monthsInYear(_ date: IslamicTabularDateInner) -> UInt8 { 12 }

    public func isInLeapYear(_ date: IslamicTabularDateInner) -> Bool {
        let yi = UmmAlQuraYearInfo.forYear(date.year)
        return yi.packed.daysInYear == 355
    }

    private func resolveYear(_ input: YearInput) throws -> Int32 {
        switch input {
        case .extended(let y): return y
        case .eraYear(let era, let year):
            switch era {
            case "ah": return year
            case "bh": return 1 - year
            default: throw DateNewError.invalidEra
            }
        }
    }

    private func validateMonthDay(year: Int32, month: Month, day: UInt8) throws {
        guard !month.isLeap else { throw DateNewError.monthNotInCalendar }
        guard month.number >= 1, month.number <= 12 else { throw DateNewError.monthNotInCalendar }
        let yi = UmmAlQuraYearInfo.forYear(year)
        let maxDay = yi.packed.monthLength(month.number)
        guard day >= 1, day <= maxDay else { throw DateNewError.invalidDay(max: maxDay) }
    }
}

// MARK: - PackedHijriYearData

/// Packed representation of a single Hijri year's month structure.
///
/// Layout (16 bits):
/// - Bits 0–11: month length flags (1 = 30 days, 0 = 29 days), month 1 in bit 0.
/// - Bit 12: sign flag for start-day offset (1 = negative).
/// - Bits 13–15: absolute value of start-day offset from mean tabular start.
struct PackedHijriYearData: Sendable {
    let raw: UInt16

    /// Month-length bits only (bits 0-11).
    private var monthBits: UInt16 { raw & 0x0FFF }

    /// Length of a given month (1-indexed). Returns 29 or 30.
    func monthLength(_ month: UInt8) -> UInt8 {
        29 + UInt8((monthBits >> (month - 1)) & 1)
    }

    /// Days before a given month (1-indexed). Month 1 → 0, month 2 → length of month 1, etc.
    /// `month` must be 1...13. For month 13, returns total days in year.
    func daysBeforeMonth(_ month: UInt8) -> UInt16 {
        let m = UInt16(month - 1)
        let baseDays = 29 * m
        // Only bits 0-11 are month lengths; use UInt32 shift to avoid UInt16 overflow
        let mask = UInt16(truncatingIfNeeded: (UInt32(1) << m) &- 1)
        return baseDays + UInt16((monthBits & mask).nonzeroBitCount)
    }

    /// Total days in the year (354 or 355).
    var daysInYear: UInt16 {
        // Sum all 12 month lengths: 29*12 + popcount(bits 0-11)
        348 + UInt16(monthBits.nonzeroBitCount)
    }

    /// Recover (month, day) from a 1-based day-of-year.
    func monthAndDay(dayOfYear: UInt16) -> (UInt8, UInt8) {
        for m: UInt8 in 1...12 {
            let len = monthLength(m)
            let dbm = daysBeforeMonth(m)
            if dayOfYear <= dbm + UInt16(len) {
                return (m, UInt8(dayOfYear - dbm))
            }
        }
        // Last month fallback
        return (12, UInt8(dayOfYear - daysBeforeMonth(12)))
    }

    /// The new-year RataDie for a year, given this packed data and the extended year.
    func newYear(extendedYear: Int32) -> RataDie {
        let signBit = (raw >> 12) & 1
        let absOffset = Int64(raw >> 13)
        let offset = signBit != 0 ? -absOffset : absOffset
        return Self.meanTabularStart(extendedYear) + offset
    }

    /// Mean tabular start day for a Hijri year, using the ICU4X Friday epoch.
    ///
    /// Mean tabular start day for a Hijri year (Friday epoch).
    ///
    /// Uses our `TabularEpoch.friday` (R.D. 227015), which matches ICU4C / Foundation
    /// and the official Saudi Umm al-Qura dates. ICU4X's proleptic Julian formula gives
    /// R.D. 227016 for the same date, so their raw packed data needs offset recomputation.
    /// Our data table was generated from Foundation with verified round-trip correctness.
    static func meanTabularStart(_ extendedYear: Int32) -> RataDie {
        let fridayEpoch = TabularEpoch.friday.rataDie
        let y = Int64(extendedYear) - 1
        let dayOffset = y * (354 * 30 + 11) / 30
        return fridayEpoch + dayOffset
    }
}

// MARK: - UmmAlQuraYearInfo

/// Combines packed month data with the computed new-year RataDie.
struct UmmAlQuraYearInfo {
    let packed: PackedHijriYearData
    let newYear: RataDie

    /// Look up or compute year info.
    /// Uses baked data for 1300–1600 AH, falls back to tabular civil otherwise.
    static func forYear(_ year: Int32) -> UmmAlQuraYearInfo {
        let index = Int(year - UmmAlQuraData.startingYear)
        if index >= 0 && index < UmmAlQuraData.data.count {
            // Baked data path
            let packed = PackedHijriYearData(raw: UmmAlQuraData.data[index])
            let ny = packed.newYear(extendedYear: year)
            return UmmAlQuraYearInfo(packed: packed, newYear: ny)
        } else {
            // Fallback: use Islamic Civil (Friday epoch, Type II) arithmetic
            return tabularFallback(year: year)
        }
    }

    /// Build year info from tabular civil arithmetic.
    private static func tabularFallback(year: Int32) -> UmmAlQuraYearInfo {
        let epoch = TabularEpoch.friday.rataDie
        let ny = IslamicTabularArithmetic.fixedFromTabular(year: year, month: 1, day: 1, epoch: epoch)

        // Build month-length bitmask from tabular rules
        var raw: UInt16 = 0
        for m: UInt8 in 1...12 {
            let len = IslamicTabularArithmetic.daysInMonth(year: year, month: m)
            if len == 30 {
                raw |= UInt16(1) << (m - 1)
            }
        }
        // Don't encode offset — store 0 in bits 12-15 and use ny directly.
        // The mean formula can diverge from the exact tabular formula by more
        // than ±5, especially for years far from the baked range.
        let packed = PackedHijriYearData(raw: raw)
        return UmmAlQuraYearInfo(packed: packed, newYear: ny)
    }
}

// MARK: - UmmAlQuraData

/// Baked Umm al-Qura year data for 1300–1600 AH (~1882–2174 CE).
///
/// Source: ICU4X `ummalqura_data.rs`, derived from ICU4C `islamcal.cpp`,
/// originally from KACST (King Abdulaziz City for Science and Technology).
enum UmmAlQuraData {
    static let startingYear: Int32 = 1300

    // 301 packed UInt16 entries. Month lengths from ICU4X ummalqura_data.rs
    // (originally from ICU4C islamcal.cpp / KACST Mecca predictions).
    // Offsets computed for our Friday epoch (R.D. 227015) using Foundation.
    // Bits 0-11: month lengths (1=30d, 0=29d). Bit 12: offset sign.
    // Bits 13-15: abs(offset) from mean tabular start. Max offset = ±1.
    static let data: [UInt16] = [
        0x0555, 0x02AB, 0x3937, 0x02B6, 0x0576, 0x036C, 0x0B55, 0x2AAA, // 1300-1307
        0x0956, 0x049E, 0x095D, 0x02BA, 0x05B5, 0x03AA, 0x0B4B, 0x2A96, // 1308-1315
        0x052E, 0x02AD, 0x056D, 0x0B5A, 0x2752, 0x0F25, 0x2E8A, 0x2D16, // 1316-1323
        0x0A56, 0x0AB5, 0x26B4, 0x0DA9, 0x2B92, 0x2B25, 0x064B, 0x0A9B, // 1324-1331
        0x035A, 0x06D9, 0x25D4, 0x0DA5, 0x2D4A, 0x2A95, 0x0536, 0x0975, // 1332-1339
        0x22F4, 0x06E9, 0x26D4, 0x06A9, 0x0535, 0x025D, 0x34BD, 0x09BA, // 1340-1347
        0x23B4, 0x0B69, 0x2B2A, 0x0A55, 0x04AD, 0x0A5D, 0x02DA, 0x06D9, // 1348-1355
        0x2EAA, 0x2E94, 0x2D2A, 0x2C56, 0x04AE, 0x0A6D, 0x056A, 0x0D55, // 1356-1363
        0x2D4A, 0x0A93, 0x052B, 0x0A5B, 0x053A, 0x06B5, 0x2EA9, 0x2D52, // 1364-1371
        0x2D29, 0x0A55, 0x04AD, 0x056D, 0x0AEA, 0x26E4, 0x2ED1, 0x2DA2, // 1372-1379
        0x2AAA, 0x095A, 0x02DA, 0x05B9, 0x0BB2, 0x2764, 0x26C9, 0x0555, // 1380-1387
        0x02AB, 0x04DB, 0x0ABA, 0x25B4, 0x0DA9, 0x2D52, 0x2AA5, 0x092D, // 1388-1395
        0x026D, 0x08ED, 0x02DA, 0x0AD5, 0x2AA5, 0x0A4B, 0x0497, 0x3937, // 1396-1403
        0x02B6, 0x0975, 0x0D69, 0x2D52, 0x2C95, 0x092B, 0x025B, 0x34DB, // 1404-1411
        0x09D5, 0x25D2, 0x0DA5, 0x2D4A, 0x2A95, 0x054D, 0x0AAD, 0x23AA, // 1412-1419
        0x0BD2, 0x2BC4, 0x0B89, 0x0A95, 0x052D, 0x35AD, 0x0B6A, 0x26D4, // 1420-1427
        0x0DC9, 0x2D92, 0x2AA6, 0x0956, 0x02AE, 0x356D, 0x036A, 0x0B55, // 1428-1435
        0x0AAA, 0x094D, 0x049D, 0x395D, 0x02BA, 0x35B5, 0x05AA, 0x0D55, // 1436-1443
        0x0A9A, 0x092E, 0x026E, 0x355D, 0x0ADA, 0x26D4, 0x06A5, 0x0B27, // 1444-1451
        0x0A4D, 0x04AD, 0x056D, 0x0B5A, 0x2754, 0x2F49, 0x2E92, 0x2D26, // 1452-1459
        0x2A56, 0x0356, 0x06B5, 0x0BAA, 0x2B92, 0x2B25, 0x068B, 0x0A9B, // 1460-1467
        0x255A, 0x0ADA, 0x25B4, 0x0DA9, 0x2B52, 0x2A9A, 0x0536, 0x0276, // 1468-1475
        0x0575, 0x0AF2, 0x26D4, 0x26A9, 0x0555, 0x02AD, 0x34BD, 0x09BA, // 1476-1483
        0x2574, 0x0B69, 0x2B52, 0x2A95, 0x052D, 0x0A5D, 0x24DA, 0x0AD9, // 1484-1491
        0x26B2, 0x0E95, 0x2E2A, 0x2C96, 0x092E, 0x0AAD, 0x256A, 0x0D65, // 1492-1499
        0x2D4A, 0x0D15, 0x062B, 0x0C5B, 0x053A, 0x06B5, 0x2DB2, 0x2D64, // 1500-1507
        0x2D29, 0x2A55, 0x04AD, 0x096D, 0x0AEA, 0x26E8, 0x2ED1, 0x2DA4, // 1508-1515
        0x2D4A, 0x2A6A, 0x02DA, 0x05B9, 0x2B72, 0x2B68, 0x26D1, 0x0655, // 1516-1523
        0x04AB, 0x095B, 0x02BA, 0x05B5, 0x2DA9, 0x2D52, 0x2CA6, 0x094E, // 1524-1531
        0x046E, 0x095D, 0x04DA, 0x0AD5, 0x2AAA, 0x0A4D, 0x049B, 0x0937, // 1532-1539
        0x04B6, 0x0975, 0x0D6A, 0x2D52, 0x2AA5, 0x094B, 0x02AB, 0x055B, // 1540-1547
        0x0AD9, 0x25D2, 0x2DC5, 0x2D92, 0x2B25, 0x0555, 0x0AB5, 0x25B4, // 1548-1555
        0x0BA9, 0x27A2, 0x2745, 0x0593, 0x0AAB, 0x04D6, 0x09D6, 0x25D2, // 1556-1563
        0x0BA5, 0x2B4A, 0x2A95, 0x04AD, 0x015D, 0x02DD, 0x09DA, 0x25B4, // 1564-1571
        0x05A9, 0x052D, 0x025B, 0x38B7, 0x0176, 0x056D, 0x0B6A, 0x2ACA, // 1572-1579
        0x2A96, 0x052B, 0x015B, 0x32BB, 0x05B6, 0x2DAA, 0x2B94, 0x2D46, // 1580-1587
        0x2A8D, 0x052D, 0x0A9D, 0x055A, 0x0755, 0x2749, 0x0F13, 0x2E4A, // 1588-1595
        0x2A96, 0x0556, 0x06B5, 0x2BAA, 0x2B94,                         // 1596-1600
    ]
}

// Packed Chinese/Korean year data — 4 bytes encode the complete year structure.
//
// This enables O(1) table lookup for dates in the baked range (1901–2099),
// eliminating all Moshier astronomical calculations for common dates.
// The packed data also travels with the date in ChineseDateInner, so field
// accessors and arithmetic never need a cache lookup.
//
// Bit layout (24 bits used of UInt32):
//   Bits  0-12: month lengths for up to 13 months (1 = 30 days, 0 = 29 days)
//   Bits 13-16: leap month ordinal (0 = no leap, else ordinal position 2-13)
//   Bits 17-22: new year offset from January 19 of the related ISO year
//
// Source: Hong Kong Observatory data for 1901–2099 (chinese_months_1901_2100_hko.csv).

import CalendarCore
import CalendarSimple

// MARK: - PackedChineseYearData

/// Packed representation of a Chinese/Korean lunisolar year.
///
/// Encodes month lengths, leap month identity, and new year date in 4 bytes.
/// Can be constructed from the baked HKO data table or from a computed `ChineseYearData`.
public struct PackedChineseYearData: Sendable, Equatable {
    let raw: UInt32

    /// Month-length bits (bits 0-12).
    private var monthBits: UInt32 { raw & 0x1FFF }

    /// Number of months in this year (12 or 13).
    var monthCount: UInt8 {
        leapMonthOrdinal > 0 ? 13 : 12
    }

    /// Ordinal position of the leap month (0 = no leap, 2-13 = ordinal).
    var leapMonthOrdinal: UInt8 {
        UInt8((raw >> 13) & 0xF)
    }

    /// The month number (1-12) that is the leap month, or nil.
    var leapMonth: UInt8? {
        let ord = leapMonthOrdinal
        return ord > 0 ? ord - 1 : nil
    }

    /// New year offset from January 19 of the related ISO year.
    var newYearOffset: UInt8 {
        UInt8((raw >> 17) & 0x3F)
    }

    /// RataDie of new year given the related ISO year.
    func newYear(relatedIso: Int32) -> RataDie {
        let jan19 = GregorianArithmetic.fixedFromGregorian(year: relatedIso, month: 1, day: 19)
        return jan19 + Int64(newYearOffset)
    }

    /// Length of a given ordinal month (1-indexed). Returns 29 or 30.
    func monthLength(_ ordinalMonth: UInt8) -> UInt8 {
        29 + UInt8((monthBits >> (ordinalMonth - 1)) & 1)
    }

    /// Days before a given ordinal month (1-indexed).
    func daysBeforeMonth(_ ordinalMonth: UInt8) -> UInt16 {
        let m = UInt32(ordinalMonth - 1)
        let baseDays = 29 * UInt16(m)
        let mask = (UInt32(1) << m) - 1
        return baseDays + UInt16((monthBits & mask).nonzeroBitCount)
    }

    /// Total days in the year.
    var totalDays: UInt16 {
        let mc = UInt32(monthCount)
        let baseDays = 29 * UInt16(mc)
        let mask = (UInt32(1) << mc) - 1
        return baseDays + UInt16((monthBits & mask).nonzeroBitCount)
    }

    /// Recover (ordinalMonth, day) from a 0-indexed day-of-year.
    func monthAndDay(dayOfYear: Int) -> (UInt8, UInt8) {
        var remaining = dayOfYear
        let mc = Int(monthCount)
        for i in 0..<mc {
            let len = Int((monthBits >> i) & 1) == 1 ? 30 : 29
            if remaining < len {
                return (UInt8(i + 1), UInt8(remaining + 1))
            }
            remaining -= len
        }
        return (UInt8(mc), UInt8(remaining + 1))
    }

    /// Get the month code (number, isLeap) for an ordinal month.
    func monthCode(ordinal: UInt8) -> (number: UInt8, isLeap: Bool) {
        guard let lm = leapMonth else {
            return (ordinal, false)
        }
        let leapOrd = lm + 1
        if ordinal == leapOrd {
            return (lm, true)
        } else if ordinal > leapOrd {
            return (ordinal - 1, false)
        } else {
            return (ordinal, false)
        }
    }

    /// Pack from a computed `ChineseYearData` and its related ISO year.
    static func from(yearData: ChineseYearData, relatedIso: Int32) -> PackedChineseYearData {
        var bits: UInt32 = 0

        // Month lengths (bits 0-12)
        for (i, isLong) in yearData.monthLengths.enumerated() {
            if isLong { bits |= UInt32(1) << i }
        }

        // Leap month ordinal (bits 13-16)
        if let lm = yearData.leapMonth {
            bits |= UInt32(lm + 1) << 13
        }

        // New year offset from Jan 19 (bits 17-22)
        let jan19 = GregorianArithmetic.fixedFromGregorian(year: relatedIso, month: 1, day: 19)
        let offset = yearData.newYear.dayNumber - jan19.dayNumber
        bits |= (UInt32(offset) & 0x3F) << 17

        return PackedChineseYearData(raw: bits)
    }
}

// MARK: - ChineseYearTable

/// Baked year data for Chinese calendar years 1901–2099.
///
/// 199 entries generated from Hong Kong Observatory authoritative data.
/// Eliminates all Moshier astronomical calculations for this range.
enum ChineseYearTable {
    static let startingYear: Int32 = 1901

    // 199 packed UInt32 entries for Chinese years 1901–2099.
    // Bits 0-12: month lengths (1=30d, 0=29d), up to 13 months.
    // Bits 13-16: leap month ordinal (0=none, else ordinal position of leap month).
    // Bits 17-22: new year offset from Jan 19 of the related ISO year.
    // Source: Hong Kong Observatory data (chinese_months_1901_2100_hko.csv).
    static let data: [UInt32] = [
        0x003E0752, 0x00280EA5, 0x0014D64A, 0x0038064B, // 1901–1904
        0x00200A9B, 0x000CB556, 0x0032056A, 0x001C0B69, // 1905–1908
        0x00067752, 0x002C0752, 0x0016FB25, 0x003C0B25, // 1909–1912
        0x00240A4B, 0x000ED4AB, 0x003402AD, 0x001E056B, // 1913–1916
        0x00086B69, 0x002E0DA9, 0x001B1D92, 0x00400E92, // 1917–1920
        0x00280D25, 0x0012DA4D, 0x00380A56, 0x002202B6, // 1921–1924
        0x000AB5B5, 0x003206D4, 0x001C0EA9, 0x00087E92, // 1925–1928
        0x002C0E92, 0x0016ED26, 0x003A052B, 0x00240A57, // 1929–1932
        0x000ED2B6, 0x00340B5A, 0x002006D4, 0x000A8EC9, // 1933–1936
        0x002E0749, 0x00191693, 0x003E0A93, 0x0028052B, // 1937–1940
        0x0010EA5B, 0x00360AAD, 0x0022056A, 0x000CBB55, // 1941–1944
        0x00320BA4, 0x001C0B49, 0x00067A93, 0x002C0A95, // 1945–1948
        0x0015152D, 0x003A0536, 0x00240AAD, 0x0010D5AA, // 1949–1952
        0x003405B2, 0x001E0DA5, 0x000A9D4A, 0x00300D4A, // 1953–1956
        0x00192A95, 0x003C0A97, 0x00280556, 0x0012EAB5, // 1957–1960
        0x00360AD5, 0x002206D2, 0x000CAEA5, 0x00320EA5, // 1961–1964
        0x001C064A, 0x00048C97, 0x002A0A9B, 0x0017155A, // 1965–1968
        0x003A056A, 0x00240B69, 0x0010D752, 0x00360B52, // 1969–1972
        0x001E0B25, 0x0008B64B, 0x002E0A4B, 0x001934AB, // 1973–1976
        0x003C02AD, 0x0026056D, 0x0012EB69, 0x00380DA9, // 1977–1980
        0x00220D92, 0x000CBD25, 0x00320D25, 0x001D7A4D, // 1981–1984
        0x00400A56, 0x002A02B6, 0x0014E5B5, 0x003A06D5, // 1985–1988
        0x00240EA9, 0x0010DE92, 0x00360E92, 0x00200D26, // 1989–1992
        0x00088A56, 0x002C0A57, 0x001934D6, 0x003E035A, // 1993–1996
        0x002606D5, 0x0012D6C9, 0x00380749, 0x00220693, // 1997–2000
        0x000AB52B, 0x0030052B, 0x001A0A5B, 0x0006755A, // 2001–2004
        0x002A056A, 0x00151B55, 0x003C0BA4, 0x00260B49, // 2005–2008
        0x000EDA93, 0x00340A95, 0x001E052D, 0x0008AAAD, // 2009–2012
        0x002C0AB5, 0x001955AA, 0x003E05D2, 0x00280DA5, // 2013–2016
        0x0012FD4A, 0x00380D4A, 0x00220C95, 0x000CB52E, // 2017–2020
        0x00300556, 0x001A0AB5, 0x000675B2, 0x002C06D2, // 2021–2024
        0x0014EEA5, 0x003A0725, 0x0024064B, 0x000ECC97, // 2025–2028
        0x00320CAB, 0x001E055A, 0x00088AD6, 0x002E0B69, // 2029–2032
        0x00199752, 0x003E0B52, 0x00280B25, 0x0012FA4B, // 2033–2036
        0x00360A4B, 0x002004AB, 0x000AC55B, 0x003005AD, // 2037–2040
        0x001A0B6A, 0x00067B52, 0x002C0D92, 0x00171D25, // 2041–2044
        0x003A0D25, 0x00240A55, 0x000ED4AD, 0x003404B6, // 2045–2048
        0x001C05B5, 0x00088DAA, 0x002E0EC9, 0x001B3E92, // 2049–2052
        0x003E0E92, 0x00280D26, 0x0012EA56, 0x00360A57, // 2053–2056
        0x00200556, 0x000AA6D5, 0x00300755, 0x001C0749, // 2057–2060
        0x00048E93, 0x002A0693, 0x0015152B, 0x003A052B, // 2061–2064
        0x00220A5B, 0x000ED55A, 0x0034056A, 0x001E0B65, // 2065–2068
        0x0008B74A, 0x002E0B4A, 0x00193A95, 0x003E0A95, // 2069–2072
        0x0026052D, 0x0010EAAD, 0x00360AB5, 0x002205AA, // 2073–2076
        0x000AABA5, 0x00300DA5, 0x001C0D4A, 0x00069C95, // 2077–2080
        0x002A0C96, 0x0015194E, 0x003A0556, 0x00240AB5, // 2081–2084
        0x000ED5B2, 0x003406D2, 0x001E0EA5, 0x000AAE4A, // 2085–2088
        0x002C068B, 0x00172C97, 0x003C04AB, 0x0026055B, // 2089–2092
        0x0010EAD6, 0x00360B6A, 0x00220752, 0x000CB725, // 2093–2096
        0x00300B45, 0x001A0A8B, 0x0004749B,             // 2097–2099
    ]

    /// Look up packed year data. Returns nil if outside baked range.
    static func lookup(_ relatedIso: Int32) -> PackedChineseYearData? {
        let index = Int(relatedIso - startingYear)
        guard index >= 0, index < data.count else { return nil }
        return PackedChineseYearData(raw: data[index])
    }
}

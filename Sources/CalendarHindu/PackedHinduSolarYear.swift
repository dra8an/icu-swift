// Packed Hindu solar year data — eliminates Moshier astronomical calculations
// for dates in the baked range (~1900–2050).
//
// Each year is encoded as:
//   monthData: UInt32 — 2 bits per month (00=29d, 01=30d, 10=31d, 11=32d),
//                       12 months × 2 bits = 24 bits
//   newYear:   Int32  — RataDie of month 1 day 1

import CalendarCore
import CalendarSimple

// MARK: - PackedHinduSolarYearData

/// Packed month-length data for a Hindu solar year.
///
/// Hindu solar months have 29–32 days (determined by when the sidereal sun
/// enters each zodiac sign). 2 bits per regional month, 12 months = 24 bits.
///
/// `newYear` is the RataDie of the chronologically first month (which may
/// not be regional month 1 — e.g., Odia's year starts at month 6).
/// The `yearStartMonth` parameter on methods threads the variant's
/// year-start ordering through.
public struct PackedHinduSolarYearData: Sendable, Equatable {
    let monthData: UInt32
    let newYear: RataDie

    /// Length of a given regional month (1-indexed). Returns 29–32.
    func monthLength(_ month: UInt8) -> UInt8 {
        UInt8(29 + ((monthData >> ((month - 1) * 2)) & 3))
    }

    /// Days from year start to the beginning of a given regional month.
    ///
    /// The year runs chronologically from `yearStartMonth` through the
    /// preceding month (wrapping through month 12 → 1). For example, Odia's
    /// year (yearStartMonth=6) runs 6,7,...,12,1,2,...,5.
    func daysBeforeMonth(_ regionalMonth: UInt8, yearStartMonth: UInt8) -> UInt16 {
        var total: UInt16 = 0
        var m = yearStartMonth
        while m != regionalMonth {
            total += UInt16(monthLength(m))
            m = m == 12 ? 1 : m + 1
        }
        return total
    }

    /// Total days in the year.
    var totalDays: UInt16 {
        var total: UInt16 = 0
        for i: UInt8 in 1...12 {
            total += UInt16(monthLength(i))
        }
        return total
    }

    /// Recover (regionalMonth, day) from RataDie.
    func monthAndDay(rd: RataDie, yearStartMonth: UInt8) -> (UInt8, UInt8) {
        var remaining = Int(rd.dayNumber - newYear.dayNumber)
        var m = yearStartMonth
        for _ in 0..<12 {
            let len = Int(monthLength(m))
            if remaining < len {
                return (m, UInt8(remaining + 1))
            }
            remaining -= len
            m = m == 12 ? 1 : m + 1
        }
        return (yearStartMonth == 1 ? 12 : yearStartMonth - 1, UInt8(remaining + 1))
    }
}

// MARK: - HinduSolarYearTable

/// Baked year data for Hindu solar calendars (~1900–2050).
///
/// 4 variants × 150 years = 600 entries.
/// Storage per variant: 4 bytes (base) + 4 bytes × 150 (monthData) + 2 bytes × 150 (newYearOffset).
/// Total: ~3.6 KB.
///
/// New year RataDie = `baseNewYear + newYearOffset[index]`.
/// UInt16 offsets fit comfortably (max observed: 54,423; UInt16 max: 65,535).
///
/// Source: Moshier-computed regression data validated at 100% accuracy.
enum HinduSolarYearTable {

    /// Look up packed year data for a variant. Returns nil if outside baked range.
    static func lookup<V: HinduSolarVariant>(
        _ variant: V.Type, solarYear: Int32
    ) -> PackedHinduSolarYearData? {
        let (startYear, base, monthData, offsets) = tableFor(variant)
        let index = Int(solarYear - startYear)
        guard index >= 0, index < monthData.count else { return nil }
        return PackedHinduSolarYearData(
            monthData: monthData[index],
            newYear: RataDie(Int64(base) + Int64(offsets[index]))
        )
    }

    private static func tableFor<V: HinduSolarVariant>(
        _ variant: V.Type
    ) -> (startYear: Int32, base: Int32, monthData: [UInt32], offsets: [UInt16]) {
        switch V.calendarIdentifier {
        case "hindu-solar-tamil":
            return (tamilStartYear, tamilBaseNewYear, tamilMonthData, tamilNewYearOffsets)
        case "hindu-solar-bengali":
            return (bengaliStartYear, bengaliBaseNewYear, bengaliMonthData, bengaliNewYearOffsets)
        case "hindu-solar-odia":
            return (odiaStartYear, odiaBaseNewYear, odiaMonthData, odiaNewYearOffsets)
        case "hindu-solar-malayalam":
            return (malayalamStartYear, malayalamBaseNewYear, malayalamMonthData, malayalamNewYearOffsets)
        default:
            return (0, 0, [], [])
        }
    }

    // MARK: - Tamil (150 years, 1822–1971 Saka)

    static let tamilStartYear: Int32 = 1822
    static let tamilBaseNewYear: Int32 = 693698
    static let tamilMonthData: [UInt32] = [
        0x5456EA, 0x511ABA, 0x911ABA, 0x8456ED, 0x5456EA, 0x511ABA, // 1822–1827
        0x911ABA, 0x5456ED, 0x5456EA, 0x511ABA, 0x911AAE, 0x5456ED, // 1828–1833
        0x5456EA, 0x511ABA, 0x911AAE, 0x5456EA, 0x5456EA, 0x511ABA, // 1834–1839
        0x905AAE, 0x5456EA, 0x5456BA, 0x511ABA, 0x845AAE, 0x5456EA, // 1840–1845
        0x5456BA, 0x511ABA, 0x845AAE, 0x5456EA, 0x5156BA, 0x911ABA, // 1846–1851
        0x845AAD, 0x5456EA, 0x5156BA, 0x911ABA, 0x845AAD, 0x5456EA, // 1852–1857
        0x511ABA, 0x911ABA, 0x8457AD, 0x5456EA, 0x511ABA, 0x911ABA, // 1858–1863
        0x8456ED, 0x5456EA, 0x511ABA, 0x911ABA, 0x5456ED, 0x5456EA, // 1864–1869
        0x511ABA, 0x911AAE, 0x5456ED, 0x5456EA, 0x511ABA, 0x911AAE, // 1870–1875
        0x5456EA, 0x5456EA, 0x511ABA, 0x905AAE, 0x5456EA, 0x5456BA, // 1876–1881
        0x511ABA, 0x845AAE, 0x5456EA, 0x5156BA, 0x511ABA, 0x845AAE, // 1882–1887
        0x5456EA, 0x5156BA, 0x911ABA, 0x845AAD, 0x5456EA, 0x5126BA, // 1888–1893
        0x911ABA, 0x845AAD, 0x5456EA, 0x511ABA, 0x911ABA, 0x8457AD, // 1894–1899
        0x5456EA, 0x511ABA, 0x911ABA, 0x8456ED, 0x5456EA, 0x511ABA, // 1900–1905
        0x911ABA, 0x5456ED, 0x5456EA, 0x511ABA, 0x911ABA, 0x5456ED, // 1906–1911
        0x5456EA, 0x511ABA, 0x911AAE, 0x5456EA, 0x5456EA, 0x511ABA, // 1912–1917
        0x905AAE, 0x5456EA, 0x5456BA, 0x511ABA, 0x845AAE, 0x5456EA, // 1918–1923
        0x5456BA, 0x511ABA, 0x845AAE, 0x5456EA, 0x5156BA, 0x511ABA, // 1924–1929
        0x845AAE, 0x5456EA, 0x5156BA, 0x911ABA, 0x845AAD, 0x5456EA, // 1930–1935
        0x511ABA, 0x911ABA, 0x8457AD, 0x5456EA, 0x511ABA, 0x911ABA, // 1936–1941
        0x8456ED, 0x5456EA, 0x511ABA, 0x911ABA, 0x5456ED, 0x5456EA, // 1942–1947
        0x511ABA, 0x911ABA, 0x5456ED, 0x5456EA, 0x511ABA, 0x911AAE, // 1948–1953
        0x5456EA, 0x5456EA, 0x511ABA, 0x905AAE, 0x5456EA, 0x5456BA, // 1954–1959
        0x511ABA, 0x845AAE, 0x5456EA, 0x5456BA, 0x511ABA, 0x845AAE, // 1960–1965
        0x5456EA, 0x5156BA, 0x511ABA, 0x845AAE, 0x5456EA, 0x5156BA, // 1966–1971
    ]
    static let tamilNewYearOffsets: [UInt16] = [
            0,   365,   730,  1096,  1461,  1826,  2191,  2557,  2922,  3287, // 1822–1831
         3652,  4018,  4383,  4748,  5113,  5479,  5844,  6209,  6574,  6940, // 1832–1841
         7305,  7670,  8035,  8401,  8766,  9131,  9496,  9862, 10227, 10592, // 1842–1851
        10958, 11323, 11688, 12053, 12419, 12784, 13149, 13514, 13880, 14245, // 1852–1861
        14610, 14975, 15341, 15706, 16071, 16436, 16802, 17167, 17532, 17897, // 1862–1871
        18263, 18628, 18993, 19358, 19724, 20089, 20454, 20819, 21185, 21550, // 1872–1881
        21915, 22280, 22646, 23011, 23376, 23741, 24107, 24472, 24837, 25203, // 1882–1891
        25568, 25933, 26298, 26664, 27029, 27394, 27759, 28125, 28490, 28855, // 1892–1901
        29220, 29586, 29951, 30316, 30681, 31047, 31412, 31777, 32142, 32508, // 1902–1911
        32873, 33238, 33603, 33969, 34334, 34699, 35064, 35430, 35795, 36160, // 1912–1921
        36525, 36891, 37256, 37621, 37986, 38352, 38717, 39082, 39447, 39813, // 1922–1931
        40178, 40543, 40909, 41274, 41639, 42004, 42370, 42735, 43100, 43465, // 1932–1941
        43831, 44196, 44561, 44926, 45292, 45657, 46022, 46387, 46753, 47118, // 1942–1951
        47483, 47848, 48214, 48579, 48944, 49309, 49675, 50040, 50405, 50770, // 1952–1961
        51136, 51501, 51866, 52231, 52597, 52962, 53327, 53692, 54058, 54423, // 1962–1971
    ]

    // MARK: - Bengali (150 years, 1307–1456 Bengali)

    static let bengaliStartYear: Int32 = 1307
    static let bengaliBaseNewYear: Int32 = 693699
    static let bengaliMonthData: [UInt32] = [
        0x8456ED, 0x5456EA, 0x511ABA, 0x911AAE, 0x8456ED, 0x5456EA, // 1307–1312
        0x511ABA, 0x911AAE, 0x5456EA, 0x5456EA, 0x511ABA, 0x911AAE, // 1313–1318
        0x5456EA, 0x5456BA, 0x511ABA, 0x911AAE, 0x5456EA, 0x5456BA, // 1319–1324
        0x511ABA, 0x911AAE, 0x5456EA, 0x5456BA, 0x511ABA, 0x845AAE, // 1325–1330
        0x5456EA, 0x5456BA, 0x511ABA, 0x845AAE, 0x5456EA, 0x5156BA, // 1331–1336
        0x911ABA, 0x845AAD, 0x5456EA, 0x514ABA, 0x911ABA, 0x8456ED, // 1337–1342
        0x5456EA, 0x511ABA, 0x911ABA, 0x8456ED, 0x5456EA, 0x511ABA, // 1343–1348
        0x911ABA, 0x5456ED, 0x5456EA, 0x511ABA, 0x911AAE, 0x5456ED, // 1349–1354
        0x5456EA, 0x511ABA, 0x911AAE, 0x5456EA, 0x5456EA, 0x511ABA, // 1355–1360
        0x911AAE, 0x5456EA, 0x5456BA, 0x511ABA, 0x905AAE, 0x5456EA, // 1361–1366
        0x5456BA, 0x511ABA, 0x905AAE, 0x5456EA, 0x5456BA, 0x911ABA, // 1367–1372
        0x845AAD, 0x5456EA, 0x5156BA, 0x911ABA, 0x845AAD, 0x5456EA, // 1373–1378
        0x514ABA, 0x911ABA, 0x8456ED, 0x5456EA, 0x511ABA, 0x911ABA, // 1379–1384
        0x8456ED, 0x5456EA, 0x511ABA, 0x911AAE, 0x5456ED, 0x5456EA, // 1385–1390
        0x511ABA, 0x911AAE, 0x5456EA, 0x5456EA, 0x511ABA, 0x911AAE, // 1391–1396
        0x5456EA, 0x5456EA, 0x511ABA, 0x911AAE, 0x5456EA, 0x5456BA, // 1397–1402
        0x511ABA, 0x911AAE, 0x5456EA, 0x5456BA, 0x511ABA, 0x845AAE, // 1403–1408
        0x5456EA, 0x5456BA, 0x511ABA, 0x845AAE, 0x5456EA, 0x5156BA, // 1409–1414
        0x911ABA, 0x845AAD, 0x5456EA, 0x514ABA, 0x911ABA, 0x8456ED, // 1415–1420
        0x5456EA, 0x514ABA, 0x911ABA, 0x8456ED, 0x5456EA, 0x511ABA, // 1421–1426
        0x911ABA, 0x5456ED, 0x5456EA, 0x511ABA, 0x911AAE, 0x5456ED, // 1427–1432
        0x5456EA, 0x511ABA, 0x911AAE, 0x5456EA, 0x5456EA, 0x511ABA, // 1433–1438
        0x911AAE, 0x5456EA, 0x5456BA, 0x511ABA, 0x905AAE, 0x5456EA, // 1439–1444
        0x5456BA, 0x511ABA, 0x845AAE, 0x5456EA, 0x5456BA, 0x911ABA, // 1445–1450
        0x845AAD, 0x5456EA, 0x5156BA, 0x911ABA, 0x845AAD, 0x5456EA, // 1451–1456
    ]
    static let bengaliNewYearOffsets: [UInt16] = [
            0,   365,   730,  1095,  1461,  1826,  2191,  2556,  2922,  3287, // 1307–1316
         3652,  4017,  4383,  4748,  5113,  5478,  5844,  6209,  6574,  6939, // 1317–1326
         7305,  7670,  8035,  8400,  8766,  9131,  9496,  9861, 10227, 10592, // 1327–1336
        10957, 11323, 11688, 12053, 12418, 12784, 13149, 13514, 13879, 14245, // 1337–1346
        14610, 14975, 15340, 15706, 16071, 16436, 16801, 17167, 17532, 17897, // 1347–1356
        18262, 18628, 18993, 19358, 19723, 20089, 20454, 20819, 21184, 21550, // 1357–1366
        21915, 22280, 22645, 23011, 23376, 23741, 24107, 24472, 24837, 25202, // 1367–1376
        25568, 25933, 26298, 26663, 27029, 27394, 27759, 28124, 28490, 28855, // 1377–1386
        29220, 29585, 29951, 30316, 30681, 31046, 31412, 31777, 32142, 32507, // 1387–1396
        32873, 33238, 33603, 33968, 34334, 34699, 35064, 35429, 35795, 36160, // 1397–1406
        36525, 36890, 37256, 37621, 37986, 38351, 38717, 39082, 39447, 39813, // 1407–1416
        40178, 40543, 40908, 41274, 41639, 42004, 42369, 42735, 43100, 43465, // 1417–1426
        43830, 44196, 44561, 44926, 45291, 45657, 46022, 46387, 46752, 47118, // 1427–1436
        47483, 47848, 48213, 48579, 48944, 49309, 49674, 50040, 50405, 50770, // 1437–1446
        51135, 51501, 51866, 52231, 52597, 52962, 53327, 53692, 54058, 54423, // 1447–1456
    ]

    // MARK: - Odia (150 years, 1308–1457 Odia)
    // Note: Odia yearStartMonth = 6 (year runs chronologically 6,7,...,12,1,2,...,5).
    // newYear values are the RD of month 6 (Ashvina, September), not month 1.

    static let odiaStartYear: Int32 = 1308
    static let odiaBaseNewYear: Int32 = 693854
    static let odiaMonthData: [UInt32] = [
        0x5456BA, 0x5456BA, 0x511AAE, 0x911AEA, 0x5456BA, 0x5456BA, // 1308–1313
        0x511AAE, 0x905AEA, 0x5456BA, 0x5456BA, 0x511AAE, 0x845AEA, // 1314–1319
        0x5456BA, 0x5456BA, 0x511AAE, 0x845AEA, 0x5456BA, 0x5456BA, // 1320–1325
        0x911AAD, 0x845AEA, 0x5456BA, 0x5156BA, 0x911AED, 0x8456EA, // 1326–1331
        0x5456BA, 0x511ABA, 0x911AED, 0x8456EA, 0x5456BA, 0x511AAE, // 1332–1337
        0x911AED, 0x5456EA, 0x5456BA, 0x511AAE, 0x911AEA, 0x5456EA, // 1338–1343
        0x5456BA, 0x511AAE, 0x911AEA, 0x5456BA, 0x5456BA, 0x511AAE, // 1344–1349
        0x911AEA, 0x5456BA, 0x5456BA, 0x511AAE, 0x911AEA, 0x5456BA, // 1350–1355
        0x5456BA, 0x511AAE, 0x845AEA, 0x5456BA, 0x5456BA, 0x911AAD, // 1356–1361
        0x845AEA, 0x5456BA, 0x5456BA, 0x911AAD, 0x845AEA, 0x5456BA, // 1362–1367
        0x5156BA, 0x911AED, 0x8456EA, 0x5456BA, 0x511ABA, 0x911AED, // 1368–1373
        0x8456EA, 0x5456BA, 0x511AAE, 0x911AED, 0x5456EA, 0x5456BA, // 1374–1379
        0x511AAE, 0x911AED, 0x5456EA, 0x5456BA, 0x511AAE, 0x911AEA, // 1380–1385
        0x5456BA, 0x5456BA, 0x511AAE, 0x911AEA, 0x5456BA, 0x5456BA, // 1386–1391
        0x511AAE, 0x911AEA, 0x5456BA, 0x5456BA, 0x511AAE, 0x845AEA, // 1392–1397
        0x5456BA, 0x5456BA, 0x911AAD, 0x845AEA, 0x5456BA, 0x5156BA, // 1398–1403
        0x911AAD, 0x845AEA, 0x5456BA, 0x5156BA, 0x911AED, 0x8456EA, // 1404–1409
        0x5456BA, 0x511ABA, 0x911AED, 0x8456EA, 0x5456BA, 0x511ABA, // 1410–1415
        0x911AED, 0x5456EA, 0x5456BA, 0x511AAE, 0x911AEA, 0x5456EA, // 1416–1421
        0x5456BA, 0x511AAE, 0x911AEA, 0x5456BA, 0x5456BA, 0x511AAE, // 1422–1427
        0x911AEA, 0x5456BA, 0x5456BA, 0x511AAE, 0x911AEA, 0x5456BA, // 1428–1433
        0x5456BA, 0x511AAE, 0x845AEA, 0x5456BA, 0x5456BA, 0x511AAE, // 1434–1439
        0x845AEA, 0x5456BA, 0x5156BA, 0x911AAD, 0x845AEA, 0x5456BA, // 1440–1445
        0x5156BA, 0x911AED, 0x8456EA, 0x5456BA, 0x511ABA, 0x911AED, // 1446–1451
        0x8456EA, 0x5456BA, 0x511ABA, 0x911AED, 0x5456EA, 0x5456BA, // 1452–1457
    ]
    static let odiaNewYearOffsets: [UInt16] = [
            0,   365,   730,  1095,  1461,  1826,  2191,  2556,  2922,  3287, // 1308–1317
         3652,  4017,  4383,  4748,  5113,  5478,  5844,  6209,  6574,  6939, // 1318–1327
         7305,  7670,  8035,  8401,  8766,  9131,  9496,  9862, 10227, 10592, // 1328–1337
        10957, 11323, 11688, 12053, 12418, 12784, 13149, 13514, 13879, 14245, // 1338–1347
        14610, 14975, 15340, 15706, 16071, 16436, 16801, 17167, 17532, 17897, // 1348–1357
        18262, 18628, 18993, 19358, 19723, 20089, 20454, 20819, 21184, 21550, // 1358–1367
        21915, 22280, 22646, 23011, 23376, 23741, 24107, 24472, 24837, 25202, // 1368–1377
        25568, 25933, 26298, 26663, 27029, 27394, 27759, 28124, 28490, 28855, // 1378–1387
        29220, 29585, 29951, 30316, 30681, 31046, 31412, 31777, 32142, 32507, // 1388–1397
        32873, 33238, 33603, 33968, 34334, 34699, 35064, 35429, 35795, 36160, // 1398–1407
        36525, 36891, 37256, 37621, 37986, 38352, 38717, 39082, 39447, 39813, // 1408–1417
        40178, 40543, 40908, 41274, 41639, 42004, 42369, 42735, 43100, 43465, // 1418–1427
        43830, 44196, 44561, 44926, 45291, 45657, 46022, 46387, 46752, 47118, // 1428–1437
        47483, 47848, 48213, 48579, 48944, 49309, 49674, 50040, 50405, 50770, // 1438–1447
        51136, 51501, 51866, 52231, 52597, 52962, 53327, 53692, 54058, 54423, // 1448–1457
    ]

    // MARK: - Malayalam (150 years, 1076–1225 Malayalam)

    static let malayalamStartYear: Int32 = 1076
    static let malayalamBaseNewYear: Int32 = 693823
    static let malayalamMonthData: [UInt32] = [
        0xBA5156, 0xAD911A, 0xEA845A, 0xBA5456, 0xBA511A, 0xED911A, // 1076–1081
        0xEA8456, 0xBA5456, 0xBA511A, 0xED911A, 0xEA8456, 0xBA5456, // 1082–1087
        0xAE511A, 0xED911A, 0xEA5456, 0xBA5456, 0xAE511A, 0xEA911A, // 1088–1093
        0xEA5456, 0xBA5456, 0xAE511A, 0xEA911A, 0xBA5456, 0xBA5456, // 1094–1099
        0xAE511A, 0xEA911A, 0xBA5456, 0xBA5456, 0xAE511A, 0xEA905A, // 1100–1105
        0xBA5456, 0xBA5456, 0xAE511A, 0xEA845A, 0xBA5456, 0xBA5456, // 1106–1111
        0xAD911A, 0xEA845A, 0xBA5456, 0xBA5156, 0xAD911A, 0xEA845A, // 1112–1117
        0xBA5456, 0xBA511A, 0xED911A, 0xEA8456, 0xBA5456, 0xBA511A, // 1118–1123
        0xED911A, 0xEA8456, 0xBA5456, 0xAE511A, 0xED911A, 0xEA5456, // 1124–1129
        0xBA5456, 0xAE511A, 0xEA911A, 0xEA5456, 0xBA5456, 0xAE511A, // 1130–1135
        0xEA911A, 0xBA5456, 0xBA5456, 0xAE511A, 0xEA911A, 0xBA5456, // 1136–1141
        0xBA5456, 0xAE511A, 0xEA905A, 0xBA5456, 0xBA5456, 0xAE511A, // 1142–1147
        0xEA845A, 0xBA5456, 0xBA5456, 0xAD911A, 0xEA845A, 0xBA5456, // 1148–1153
        0xBA5156, 0xAD911A, 0xEA845A, 0xBA5456, 0xBA511A, 0xED911A, // 1154–1159
        0xEA8456, 0xBA5456, 0xBA511A, 0xED911A, 0xEA8456, 0xBA5456, // 1160–1165
        0xBA511A, 0xED911A, 0xEA5456, 0xBA5456, 0xAE511A, 0xEA911A, // 1166–1171
        0xEA5456, 0xBA5456, 0xAE511A, 0xEA911A, 0xBA5456, 0xBA5456, // 1172–1177
        0xAE511A, 0xEA911A, 0xBA5456, 0xBA5456, 0xAE511A, 0xEA905A, // 1178–1183
        0xBA5456, 0xBA5456, 0xAE511A, 0xEA845A, 0xBA5456, 0xBA5456, // 1184–1189
        0xAD911A, 0xEA845A, 0xBA5456, 0xBA5156, 0xAD911A, 0xEA845A, // 1190–1195
        0xBA5456, 0xBA511A, 0xED911A, 0xEA8456, 0xBA5456, 0xBA511A, // 1196–1201
        0xED911A, 0xEA8456, 0xBA5456, 0xBA511A, 0xED911A, 0xEA5456, // 1202–1207
        0xBA5456, 0xAE511A, 0xED911A, 0xEA5456, 0xBA5456, 0xAE511A, // 1208–1213
        0xEA911A, 0xBA5456, 0xBA5456, 0xAE511A, 0xEA911A, 0xBA5456, // 1214–1219
        0xBA5456, 0xAE511A, 0xEA905A, 0xBA5456, 0xBA5456, 0xAE511A, // 1220–1225
    ]
    static let malayalamNewYearOffsets: [UInt16] = [
            0,   365,   730,  1096,  1461,  1826,  2192,  2557,  2922,  3287, // 1076–1085
         3653,  4018,  4383,  4748,  5114,  5479,  5844,  6209,  6575,  6940, // 1086–1095
         7305,  7670,  8036,  8401,  8766,  9131,  9497,  9862, 10227, 10592, // 1096–1105
        10958, 11323, 11688, 12053, 12419, 12784, 13149, 13514, 13880, 14245, // 1106–1115
        14610, 14975, 15341, 15706, 16071, 16437, 16802, 17167, 17532, 17898, // 1116–1125
        18263, 18628, 18993, 19359, 19724, 20089, 20454, 20820, 21185, 21550, // 1126–1135
        21915, 22281, 22646, 23011, 23376, 23742, 24107, 24472, 24837, 25203, // 1136–1145
        25568, 25933, 26298, 26664, 27029, 27394, 27759, 28125, 28490, 28855, // 1146–1155
        29220, 29586, 29951, 30316, 30682, 31047, 31412, 31777, 32143, 32508, // 1156–1165
        32873, 33238, 33604, 33969, 34334, 34699, 35065, 35430, 35795, 36160, // 1166–1175
        36526, 36891, 37256, 37621, 37987, 38352, 38717, 39082, 39448, 39813, // 1176–1185
        40178, 40543, 40909, 41274, 41639, 42004, 42370, 42735, 43100, 43465, // 1186–1195
        43831, 44196, 44561, 44927, 45292, 45657, 46022, 46388, 46753, 47118, // 1196–1205
        47483, 47849, 48214, 48579, 48944, 49310, 49675, 50040, 50405, 50771, // 1206–1215
        51136, 51501, 51866, 52232, 52597, 52962, 53327, 53693, 54058, 54423, // 1216–1225
    ]
}

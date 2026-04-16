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
/// 4 variants × 150 years = 600 entries. Total data: ~4.7 KB.
/// Source: Moshier-computed regression data validated at 100% accuracy.
enum HinduSolarYearTable {

    /// Look up packed year data for a variant. Returns nil if outside baked range.
    static func lookup<V: HinduSolarVariant>(
        _ variant: V.Type, solarYear: Int32
    ) -> PackedHinduSolarYearData? {
        let (startYear, monthData, newYears) = tableFor(variant)
        let index = Int(solarYear - startYear)
        guard index >= 0, index < monthData.count else { return nil }
        return PackedHinduSolarYearData(
            monthData: monthData[index],
            newYear: RataDie(Int64(newYears[index]))
        )
    }

    private static func tableFor<V: HinduSolarVariant>(
        _ variant: V.Type
    ) -> (startYear: Int32, monthData: [UInt32], newYears: [Int32]) {
        switch V.calendarIdentifier {
        case "hindu-solar-tamil":
            return (tamilStartYear, tamilMonthData, tamilNewYears)
        case "hindu-solar-bengali":
            return (bengaliStartYear, bengaliMonthData, bengaliNewYears)
        case "hindu-solar-odia":
            return (odiaStartYear, odiaMonthData, odiaNewYears)
        case "hindu-solar-malayalam":
            return (malayalamStartYear, malayalamMonthData, malayalamNewYears)
        default:
            return (0, [], [])
        }
    }

    // MARK: - Tamil (150 years, 1822–1971 Saka)

    static let tamilStartYear: Int32 = 1822
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
    static let tamilNewYears: [Int32] = [
        693698, 694063, 694428, 694794, 695159, 695524, // 1822–1827
        695889, 696255, 696620, 696985, 697350, 697716, // 1828–1833
        698081, 698446, 698811, 699177, 699542, 699907, // 1834–1839
        700272, 700638, 701003, 701368, 701733, 702099, // 1840–1845
        702464, 702829, 703194, 703560, 703925, 704290, // 1846–1851
        704656, 705021, 705386, 705751, 706117, 706482, // 1852–1857
        706847, 707212, 707578, 707943, 708308, 708673, // 1858–1863
        709039, 709404, 709769, 710134, 710500, 710865, // 1864–1869
        711230, 711595, 711961, 712326, 712691, 713056, // 1870–1875
        713422, 713787, 714152, 714517, 714883, 715248, // 1876–1881
        715613, 715978, 716344, 716709, 717074, 717439, // 1882–1887
        717805, 718170, 718535, 718901, 719266, 719631, // 1888–1893
        719996, 720362, 720727, 721092, 721457, 721823, // 1894–1899
        722188, 722553, 722918, 723284, 723649, 724014, // 1900–1905
        724379, 724745, 725110, 725475, 725840, 726206, // 1906–1911
        726571, 726936, 727301, 727667, 728032, 728397, // 1912–1917
        728762, 729128, 729493, 729858, 730223, 730589, // 1918–1923
        730954, 731319, 731684, 732050, 732415, 732780, // 1924–1929
        733145, 733511, 733876, 734241, 734607, 734972, // 1930–1935
        735337, 735702, 736068, 736433, 736798, 737163, // 1936–1941
        737529, 737894, 738259, 738624, 738990, 739355, // 1942–1947
        739720, 740085, 740451, 740816, 741181, 741546, // 1948–1953
        741912, 742277, 742642, 743007, 743373, 743738, // 1954–1959
        744103, 744468, 744834, 745199, 745564, 745929, // 1960–1965
        746295, 746660, 747025, 747390, 747756, 748121, // 1966–1971
    ]

    // MARK: - Bengali (150 years, 1307–1456 Bengali)

    static let bengaliStartYear: Int32 = 1307
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
    static let bengaliNewYears: [Int32] = [
        693699, 694064, 694429, 694794, 695160, 695525, // 1307–1312
        695890, 696255, 696621, 696986, 697351, 697716, // 1313–1318
        698082, 698447, 698812, 699177, 699543, 699908, // 1319–1324
        700273, 700638, 701004, 701369, 701734, 702099, // 1325–1330
        702465, 702830, 703195, 703560, 703926, 704291, // 1331–1336
        704656, 705022, 705387, 705752, 706117, 706483, // 1337–1342
        706848, 707213, 707578, 707944, 708309, 708674, // 1343–1348
        709039, 709405, 709770, 710135, 710500, 710866, // 1349–1354
        711231, 711596, 711961, 712327, 712692, 713057, // 1355–1360
        713422, 713788, 714153, 714518, 714883, 715249, // 1361–1366
        715614, 715979, 716344, 716710, 717075, 717440, // 1367–1372
        717806, 718171, 718536, 718901, 719267, 719632, // 1373–1378
        719997, 720362, 720728, 721093, 721458, 721823, // 1379–1384
        722189, 722554, 722919, 723284, 723650, 724015, // 1385–1390
        724380, 724745, 725111, 725476, 725841, 726206, // 1391–1396
        726572, 726937, 727302, 727667, 728033, 728398, // 1397–1402
        728763, 729128, 729494, 729859, 730224, 730589, // 1403–1408
        730955, 731320, 731685, 732050, 732416, 732781, // 1409–1414
        733146, 733512, 733877, 734242, 734607, 734973, // 1415–1420
        735338, 735703, 736068, 736434, 736799, 737164, // 1421–1426
        737529, 737895, 738260, 738625, 738990, 739356, // 1427–1432
        739721, 740086, 740451, 740817, 741182, 741547, // 1433–1438
        741912, 742278, 742643, 743008, 743373, 743739, // 1439–1444
        744104, 744469, 744834, 745200, 745565, 745930, // 1445–1450
        746296, 746661, 747026, 747391, 747757, 748122, // 1451–1456
    ]

    // MARK: - Odia (150 years, 1308–1457 Odia)
    // Note: Odia yearStartMonth = 6 (year runs chronologically 6,7,...,12,1,2,...,5).
    // newYear values are the RD of month 6 (Ashvina, September), not month 1.

    static let odiaStartYear: Int32 = 1308
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
    static let odiaNewYears: [Int32] = [
        693854, 694219, 694584, 694949, 695315, 695680, // 1308–1313
        696045, 696410, 696776, 697141, 697506, 697871, // 1314–1319
        698237, 698602, 698967, 699332, 699698, 700063, // 1320–1325
        700428, 700793, 701159, 701524, 701889, 702255, // 1326–1331
        702620, 702985, 703350, 703716, 704081, 704446, // 1332–1337
        704811, 705177, 705542, 705907, 706272, 706638, // 1338–1343
        707003, 707368, 707733, 708099, 708464, 708829, // 1344–1349
        709194, 709560, 709925, 710290, 710655, 711021, // 1350–1355
        711386, 711751, 712116, 712482, 712847, 713212, // 1356–1361
        713577, 713943, 714308, 714673, 715038, 715404, // 1362–1367
        715769, 716134, 716500, 716865, 717230, 717595, // 1368–1373
        717961, 718326, 718691, 719056, 719422, 719787, // 1374–1379
        720152, 720517, 720883, 721248, 721613, 721978, // 1380–1385
        722344, 722709, 723074, 723439, 723805, 724170, // 1386–1391
        724535, 724900, 725266, 725631, 725996, 726361, // 1392–1397
        726727, 727092, 727457, 727822, 728188, 728553, // 1398–1403
        728918, 729283, 729649, 730014, 730379, 730745, // 1404–1409
        731110, 731475, 731840, 732206, 732571, 732936, // 1410–1415
        733301, 733667, 734032, 734397, 734762, 735128, // 1416–1421
        735493, 735858, 736223, 736589, 736954, 737319, // 1422–1427
        737684, 738050, 738415, 738780, 739145, 739511, // 1428–1433
        739876, 740241, 740606, 740972, 741337, 741702, // 1434–1439
        742067, 742433, 742798, 743163, 743528, 743894, // 1440–1445
        744259, 744624, 744990, 745355, 745720, 746085, // 1446–1451
        746451, 746816, 747181, 747546, 747912, 748277, // 1452–1457
    ]

    // MARK: - Malayalam (150 years, 1076–1225 Malayalam)

    static let malayalamStartYear: Int32 = 1076
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
    static let malayalamNewYears: [Int32] = [
        693823, 694188, 694553, 694919, 695284, 695649, // 1076–1081
        696015, 696380, 696745, 697110, 697476, 697841, // 1082–1087
        698206, 698571, 698937, 699302, 699667, 700032, // 1088–1093
        700398, 700763, 701128, 701493, 701859, 702224, // 1094–1099
        702589, 702954, 703320, 703685, 704050, 704415, // 1100–1105
        704781, 705146, 705511, 705876, 706242, 706607, // 1106–1111
        706972, 707337, 707703, 708068, 708433, 708798, // 1112–1117
        709164, 709529, 709894, 710260, 710625, 710990, // 1118–1123
        711355, 711721, 712086, 712451, 712816, 713182, // 1124–1129
        713547, 713912, 714277, 714643, 715008, 715373, // 1130–1135
        715738, 716104, 716469, 716834, 717199, 717565, // 1136–1141
        717930, 718295, 718660, 719026, 719391, 719756, // 1142–1147
        720121, 720487, 720852, 721217, 721582, 721948, // 1148–1153
        722313, 722678, 723043, 723409, 723774, 724139, // 1154–1159
        724505, 724870, 725235, 725600, 725966, 726331, // 1160–1165
        726696, 727061, 727427, 727792, 728157, 728522, // 1166–1171
        728888, 729253, 729618, 729983, 730349, 730714, // 1172–1177
        731079, 731444, 731810, 732175, 732540, 732905, // 1178–1183
        733271, 733636, 734001, 734366, 734732, 735097, // 1184–1189
        735462, 735827, 736193, 736558, 736923, 737288, // 1190–1195
        737654, 738019, 738384, 738750, 739115, 739480, // 1196–1201
        739845, 740211, 740576, 740941, 741306, 741672, // 1202–1207
        742037, 742402, 742767, 743133, 743498, 743863, // 1208–1213
        744228, 744594, 744959, 745324, 745689, 746055, // 1214–1219
        746420, 746785, 747150, 747516, 747881, 748246, // 1220–1225
    ]
}

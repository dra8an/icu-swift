import Testing
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

@Suite("Persian Calendar")
struct PersianTests {

    let persian = Persian()

    @Test("Persian epoch in correct Gregorian year")
    func epoch() {
        let epochYear = GregorianArithmetic.yearFromFixed(PersianArithmetic.epoch)
        #expect(epochYear == 622)
    }

    @Test("Farvardin 1 = Nowruz: correct for 2000-2050 CE")
    func nowruz() {
        // Verify Nowruz dates round-trip for a wide range
        for gYear: Int32 in 2000...2050 {
            let persianYear = gYear - 621  // approximate
            let nowruzRd = PersianArithmetic.fixedFromPersian(year: persianYear, month: 1, day: 1)
            let (y, m, d) = PersianArithmetic.persianFromFixed(nowruzRd)
            #expect(y == persianYear && m == 1 && d == 1,
                    "Nowruz round-trip failed for Persian year \(persianYear)")
        }
    }

    @Test("Month lengths: 6x31 + 5x30 + 1x29/30")
    func monthLengths() {
        // Non-leap year
        for m: UInt8 in 1...6 {
            #expect(PersianArithmetic.daysInMonth(year: 1, month: m) == 31)
        }
        for m: UInt8 in 7...11 {
            #expect(PersianArithmetic.daysInMonth(year: 1, month: m) == 30)
        }
        // Year 1: (25*1+11)%33 = 36%33 = 3 < 8 -> leap
        #expect(PersianArithmetic.isLeapYear(1))
        #expect(PersianArithmetic.daysInMonth(year: 1, month: 12) == 30)

        // Year 2: (25*2+11)%33 = 61%33 = 28 >= 8 -> not leap
        #expect(!PersianArithmetic.isLeapYear(2))
        #expect(PersianArithmetic.daysInMonth(year: 2, month: 12) == 29)
    }

    @Test("Round-trip RD -> Persian -> RD")
    func roundTrip() {
        for i in stride(from: Int64(-5000), through: 5000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Persian>.fromRataDie(rd, calendar: persian)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    @Test("Round-trip near epoch")
    func roundTripNearEpoch() {
        let epochRd = PersianArithmetic.epoch.dayNumber
        for i in (epochRd - 2000)...(epochRd + 2000) {
            let rd = RataDie(i)
            let date = Date<Persian>.fromRataDie(rd, calendar: persian)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    @Test("Directionality")
    func directionality() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Persian>.fromRataDie(RataDie(i), calendar: persian)
                let dj = Date<Persian>.fromRataDie(RataDie(j), calendar: persian)
                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }

    // MARK: - ICU4X RD <-> Persian Date Pairs

    @Test("RD <-> Persian date pairs from Calendrical Calculations (21 pairs)")
    func rdPersianPairs() {
        let rdValues: [Int64] = [
            656786, 664224, 671401, 694799, 702806, 704424, 708842, 709409, 709580,
            727274, 728714, 739330, 739331, 744313, 763436, 763437, 764652, 775123,
            775488, 775489, 1317874
        ]

        let persianDates: [(year: Int32, month: UInt8, day: UInt8)] = [
            (1178, 1, 1), (1198, 5, 10), (1218, 1, 7), (1282, 1, 29), (1304, 1, 1),
            (1308, 6, 3), (1320, 7, 7), (1322, 1, 29), (1322, 7, 14), (1370, 12, 27),
            (1374, 12, 6), (1403, 12, 30), (1404, 1, 1), (1417, 8, 19), (1469, 12, 30),
            (1470, 1, 1), (1473, 4, 28), (1501, 12, 29), (1502, 12, 29), (1503, 1, 1),
            (2988, 1, 1)
        ]

        let leapFlags: [Bool] = [
            false, false, true, false, true, false, false, false, false, true,
            false, true, false, false, true, false, false, false, false, true, true
        ]

        for i in 0..<rdValues.count {
            let rd = RataDie(rdValues[i])
            let (pYear, pMonth, pDay) = persianDates[i]
            let expectedLeap = leapFlags[i]

            // Test RD -> Persian
            let date = Date<Persian>.fromRataDie(rd, calendar: persian)
            #expect(date.extendedYear == pYear,
                    "RD \(rdValues[i]): expected year \(pYear), got \(date.extendedYear)")
            #expect(date.month.number == pMonth,
                    "RD \(rdValues[i]): expected month \(pMonth), got \(date.month.number)")
            #expect(date.dayOfMonth == pDay,
                    "RD \(rdValues[i]): expected day \(pDay), got \(date.dayOfMonth)")

            // Test leap year flag
            #expect(date.isInLeapYear == expectedLeap,
                    "Persian year \(pYear): expected leap=\(expectedLeap), got \(date.isInLeapYear)")

            // Test Persian -> RD (round-trip)
            #expect(date.rataDie == rd,
                    "RD \(rdValues[i]): round-trip failed")

            // Test fixedFromPersian
            let computedRd = PersianArithmetic.fixedFromPersian(year: pYear, month: pMonth, day: pDay)
            #expect(computedRd == rd,
                    "fixedFromPersian(\(pYear), \(pMonth), \(pDay)) = \(computedRd) != RD \(rdValues[i])")
        }
    }

    // MARK: - Calendar UT AC IR Test Data (293 Nowruz entries)

    @Test("Nowruz dates from University of Tehran data (293 entries)")
    func calendarUtAcIrData() {
        // From https://calendar.ut.ac.ir/Fa/News/Data/Doc/KabiseShamsi1206-1498-new.pdf
        // (persian_year, is_leap, gregorian_year, gregorian_month, gregorian_day)
        let testData: [(pYear: Int32, isLeap: Bool, gYear: Int32, gMonth: UInt8, gDay: UInt8)] = [
            (1206, false, 1827, 3, 22),
            (1207, false, 1828, 3, 21),
            (1208, false, 1829, 3, 21),
            (1209, false, 1830, 3, 21),
            (1210, true, 1831, 3, 21),
            (1211, false, 1832, 3, 21),
            (1212, false, 1833, 3, 21),
            (1213, false, 1834, 3, 21),
            (1214, true, 1835, 3, 21),
            (1215, false, 1836, 3, 21),
            (1216, false, 1837, 3, 21),
            (1217, false, 1838, 3, 21),
            (1218, true, 1839, 3, 21),
            (1219, false, 1840, 3, 21),
            (1220, false, 1841, 3, 21),
            (1221, false, 1842, 3, 21),
            (1222, true, 1843, 3, 21),
            (1223, false, 1844, 3, 21),
            (1224, false, 1845, 3, 21),
            (1225, false, 1846, 3, 21),
            (1226, true, 1847, 3, 21),
            (1227, false, 1848, 3, 21),
            (1228, false, 1849, 3, 21),
            (1229, false, 1850, 3, 21),
            (1230, true, 1851, 3, 21),
            (1231, false, 1852, 3, 21),
            (1232, false, 1853, 3, 21),
            (1233, false, 1854, 3, 21),
            (1234, true, 1855, 3, 21),
            (1235, false, 1856, 3, 21),
            (1236, false, 1857, 3, 21),
            (1237, false, 1858, 3, 21),
            (1238, true, 1859, 3, 21),
            (1239, false, 1860, 3, 21),
            (1240, false, 1861, 3, 21),
            (1241, false, 1862, 3, 21),
            (1242, false, 1863, 3, 21),
            (1243, true, 1864, 3, 20),
            (1244, false, 1865, 3, 21),
            (1245, false, 1866, 3, 21),
            (1246, false, 1867, 3, 21),
            (1247, true, 1868, 3, 20),
            (1248, false, 1869, 3, 21),
            (1249, false, 1870, 3, 21),
            (1250, false, 1871, 3, 21),
            (1251, true, 1872, 3, 20),
            (1252, false, 1873, 3, 21),
            (1253, false, 1874, 3, 21),
            (1254, false, 1875, 3, 21),
            (1255, true, 1876, 3, 20),
            (1256, false, 1877, 3, 21),
            (1257, false, 1878, 3, 21),
            (1258, false, 1879, 3, 21),
            (1259, true, 1880, 3, 20),
            (1260, false, 1881, 3, 21),
            (1261, false, 1882, 3, 21),
            (1262, false, 1883, 3, 21),
            (1263, true, 1884, 3, 20),
            (1264, false, 1885, 3, 21),
            (1265, false, 1886, 3, 21),
            (1266, false, 1887, 3, 21),
            (1267, true, 1888, 3, 20),
            (1268, false, 1889, 3, 21),
            (1269, false, 1890, 3, 21),
            (1270, false, 1891, 3, 21),
            (1271, true, 1892, 3, 20),
            (1272, false, 1893, 3, 21),
            (1273, false, 1894, 3, 21),
            (1274, false, 1895, 3, 21),
            (1275, false, 1896, 3, 20),
            (1276, true, 1897, 3, 20),
            (1277, false, 1898, 3, 21),
            (1278, false, 1899, 3, 21),
            (1279, false, 1900, 3, 21),
            (1280, true, 1901, 3, 21),
            (1281, false, 1902, 3, 22),
            (1282, false, 1903, 3, 22),
            (1283, false, 1904, 3, 21),
            (1284, true, 1905, 3, 21),
            (1285, false, 1906, 3, 22),
            (1286, false, 1907, 3, 22),
            (1287, false, 1908, 3, 21),
            (1288, true, 1909, 3, 21),
            (1289, false, 1910, 3, 22),
            (1290, false, 1911, 3, 22),
            (1291, false, 1912, 3, 21),
            (1292, true, 1913, 3, 21),
            (1293, false, 1914, 3, 22),
            (1294, false, 1915, 3, 22),
            (1295, false, 1916, 3, 21),
            (1296, true, 1917, 3, 21),
            (1297, false, 1918, 3, 22),
            (1298, false, 1919, 3, 22),
            (1299, false, 1920, 3, 21),
            (1300, true, 1921, 3, 21),
            (1301, false, 1922, 3, 22),
            (1302, false, 1923, 3, 22),
            (1303, false, 1924, 3, 21),
            (1304, true, 1925, 3, 21),
            (1305, false, 1926, 3, 22),
            (1306, false, 1927, 3, 22),
            (1307, false, 1928, 3, 21),
            (1308, false, 1929, 3, 21),
            (1309, true, 1930, 3, 21),
            (1310, false, 1931, 3, 22),
            (1311, false, 1932, 3, 21),
            (1312, false, 1933, 3, 21),
            (1313, true, 1934, 3, 21),
            (1314, false, 1935, 3, 22),
            (1315, false, 1936, 3, 21),
            (1316, false, 1937, 3, 21),
            (1317, true, 1938, 3, 21),
            (1318, false, 1939, 3, 22),
            (1319, false, 1940, 3, 21),
            (1320, false, 1941, 3, 21),
            (1321, true, 1942, 3, 21),
            (1322, false, 1943, 3, 22),
            (1323, false, 1944, 3, 21),
            (1324, false, 1945, 3, 21),
            (1325, true, 1946, 3, 21),
            (1326, false, 1947, 3, 22),
            (1327, false, 1948, 3, 21),
            (1328, false, 1949, 3, 21),
            (1329, true, 1950, 3, 21),
            (1330, false, 1951, 3, 22),
            (1331, false, 1952, 3, 21),
            (1332, false, 1953, 3, 21),
            (1333, true, 1954, 3, 21),
            (1334, false, 1955, 3, 22),
            (1335, false, 1956, 3, 21),
            (1336, false, 1957, 3, 21),
            (1337, true, 1958, 3, 21),
            (1338, false, 1959, 3, 22),
            (1339, false, 1960, 3, 21),
            (1340, false, 1961, 3, 21),
            (1341, false, 1962, 3, 21),
            (1342, true, 1963, 3, 21),
            (1343, false, 1964, 3, 21),
            (1344, false, 1965, 3, 21),
            (1345, false, 1966, 3, 21),
            (1346, true, 1967, 3, 21),
            (1347, false, 1968, 3, 21),
            (1348, false, 1969, 3, 21),
            (1349, false, 1970, 3, 21),
            (1350, true, 1971, 3, 21),
            (1351, false, 1972, 3, 21),
            (1352, false, 1973, 3, 21),
            (1353, false, 1974, 3, 21),
            (1354, true, 1975, 3, 21),
            (1355, false, 1976, 3, 21),
            (1356, false, 1977, 3, 21),
            (1357, false, 1978, 3, 21),
            (1358, true, 1979, 3, 21),
            (1359, false, 1980, 3, 21),
            (1360, false, 1981, 3, 21),
            (1361, false, 1982, 3, 21),
            (1362, true, 1983, 3, 21),
            (1363, false, 1984, 3, 21),
            (1364, false, 1985, 3, 21),
            (1365, false, 1986, 3, 21),
            (1366, true, 1987, 3, 21),
            (1367, false, 1988, 3, 21),
            (1368, false, 1989, 3, 21),
            (1369, false, 1990, 3, 21),
            (1370, true, 1991, 3, 21),
            (1371, false, 1992, 3, 21),
            (1372, false, 1993, 3, 21),
            (1373, false, 1994, 3, 21),
            (1374, false, 1995, 3, 21),
            (1375, true, 1996, 3, 20),
            (1376, false, 1997, 3, 21),
            (1377, false, 1998, 3, 21),
            (1378, false, 1999, 3, 21),
            (1379, true, 2000, 3, 20),
            (1380, false, 2001, 3, 21),
            (1381, false, 2002, 3, 21),
            (1382, false, 2003, 3, 21),
            (1383, true, 2004, 3, 20),
            (1384, false, 2005, 3, 21),
            (1385, false, 2006, 3, 21),
            (1386, false, 2007, 3, 21),
            (1387, true, 2008, 3, 20),
            (1388, false, 2009, 3, 21),
            (1389, false, 2010, 3, 21),
            (1390, false, 2011, 3, 21),
            (1391, true, 2012, 3, 20),
            (1392, false, 2013, 3, 21),
            (1393, false, 2014, 3, 21),
            (1394, false, 2015, 3, 21),
            (1395, true, 2016, 3, 20),
            (1396, false, 2017, 3, 21),
            (1397, false, 2018, 3, 21),
            (1398, false, 2019, 3, 21),
            (1399, true, 2020, 3, 20),
            (1400, false, 2021, 3, 21),
            (1401, false, 2022, 3, 21),
            (1402, false, 2023, 3, 21),
            (1403, true, 2024, 3, 20),
            (1404, false, 2025, 3, 21),
            (1405, false, 2026, 3, 21),
            (1406, false, 2027, 3, 21),
            (1407, false, 2028, 3, 20),
            (1408, true, 2029, 3, 20),
            (1409, false, 2030, 3, 21),
            (1410, false, 2031, 3, 21),
            (1411, false, 2032, 3, 20),
            (1412, true, 2033, 3, 20),
            (1413, false, 2034, 3, 21),
            (1414, false, 2035, 3, 21),
            (1415, false, 2036, 3, 20),
            (1416, true, 2037, 3, 20),
            (1417, false, 2038, 3, 21),
            (1418, false, 2039, 3, 21),
            (1419, false, 2040, 3, 20),
            (1420, true, 2041, 3, 20),
            (1421, false, 2042, 3, 21),
            (1422, false, 2043, 3, 21),
            (1423, false, 2044, 3, 20),
            (1424, true, 2045, 3, 20),
            (1425, false, 2046, 3, 21),
            (1426, false, 2047, 3, 21),
            (1427, false, 2048, 3, 20),
            (1428, true, 2049, 3, 20),
            (1429, false, 2050, 3, 21),
            (1430, false, 2051, 3, 21),
            (1431, false, 2052, 3, 20),
            (1432, true, 2053, 3, 20),
            (1433, false, 2054, 3, 21),
            (1434, false, 2055, 3, 21),
            (1435, false, 2056, 3, 20),
            (1436, true, 2057, 3, 20),
            (1437, false, 2058, 3, 21),
            (1438, false, 2059, 3, 21),
            (1439, false, 2060, 3, 20),
            (1440, false, 2061, 3, 20),
            (1441, true, 2062, 3, 20),
            (1442, false, 2063, 3, 21),
            (1443, false, 2064, 3, 20),
            (1444, false, 2065, 3, 20),
            (1445, true, 2066, 3, 20),
            (1446, false, 2067, 3, 21),
            (1447, false, 2068, 3, 20),
            (1448, false, 2069, 3, 20),
            (1449, true, 2070, 3, 20),
            (1450, false, 2071, 3, 21),
            (1451, false, 2072, 3, 20),
            (1452, false, 2073, 3, 20),
            (1453, true, 2074, 3, 20),
            (1454, false, 2075, 3, 21),
            (1455, false, 2076, 3, 20),
            (1456, false, 2077, 3, 20),
            (1457, true, 2078, 3, 20),
            (1458, false, 2079, 3, 21),
            (1459, false, 2080, 3, 20),
            (1460, false, 2081, 3, 20),
            (1461, true, 2082, 3, 20),
            (1462, false, 2083, 3, 21),
            (1463, false, 2084, 3, 20),
            (1464, false, 2085, 3, 20),
            (1465, true, 2086, 3, 20),
            (1466, false, 2087, 3, 21),
            (1467, false, 2088, 3, 20),
            (1468, false, 2089, 3, 20),
            (1469, true, 2090, 3, 20),
            (1470, false, 2091, 3, 21),
            (1471, false, 2092, 3, 20),
            (1472, false, 2093, 3, 20),
            (1473, false, 2094, 3, 20),
            (1474, true, 2095, 3, 20),
            (1475, false, 2096, 3, 20),
            (1476, false, 2097, 3, 20),
            (1477, false, 2098, 3, 20),
            (1478, true, 2099, 3, 20),
            (1479, false, 2100, 3, 21),
            (1480, false, 2101, 3, 21),
            (1481, false, 2102, 3, 21),
            (1482, true, 2103, 3, 21),
            (1483, false, 2104, 3, 21),
            (1484, false, 2105, 3, 21),
            (1485, false, 2106, 3, 21),
            (1486, true, 2107, 3, 21),
            (1487, false, 2108, 3, 21),
            (1488, false, 2109, 3, 21),
            (1489, false, 2110, 3, 21),
            (1490, true, 2111, 3, 21),
            (1491, false, 2112, 3, 21),
            (1492, false, 2113, 3, 21),
            (1493, false, 2114, 3, 21),
            (1494, true, 2115, 3, 21),
            (1495, false, 2116, 3, 21),
            (1496, false, 2117, 3, 21),
            (1497, false, 2118, 3, 21),
            (1498, true, 2119, 3, 21),
        ]

        for (pYear, isLeap, gYear, gMonth, gDay) in testData {
            // Convert Gregorian Nowruz date to RD
            let isoRd = GregorianArithmetic.fixedFromGregorian(year: gYear, month: gMonth, day: gDay)

            // Convert to Persian and verify it is Farvardin 1
            let persianDate = Date<Persian>.fromRataDie(isoRd, calendar: persian)
            #expect(persianDate.extendedYear == pYear,
                    "Nowruz \(gYear)-\(gMonth)-\(gDay): expected Persian year \(pYear), got \(persianDate.extendedYear)")
            #expect(persianDate.month.number == 1,
                    "Nowruz \(gYear)-\(gMonth)-\(gDay): expected month 1, got \(persianDate.month.number)")
            #expect(persianDate.dayOfMonth == 1,
                    "Nowruz \(gYear)-\(gMonth)-\(gDay): expected day 1, got \(persianDate.dayOfMonth)")

            // Verify leap year flag
            #expect(persianDate.isInLeapYear == isLeap,
                    "Persian year \(pYear): expected leap=\(isLeap), got \(persianDate.isInLeapYear)")

            // Also verify by constructing Persian date and converting to Gregorian
            let computedRd = PersianArithmetic.fixedFromPersian(year: pYear, month: 1, day: 1)
            #expect(computedRd == isoRd,
                    "Persian \(pYear)/1/1: computed RD \(computedRd) != expected RD \(isoRd)")
        }
    }

    @Test("Days in year matches consecutive Nowruz difference")
    func daysInYear() {
        let rdCases: [Int64] = [
            656786, 664224, 671401, 694799, 702806, 704424, 708842, 709409, 709580,
            727274, 728714, 739330, 739331, 744313, 763436, 763437, 764652, 775123,
            775488, 775489, 1317874
        ]
        let persianYears: [Int32] = [
            1178, 1198, 1218, 1282, 1304, 1308, 1320, 1322, 1322, 1370,
            1374, 1403, 1404, 1417, 1469, 1470, 1473, 1501, 1502, 1503, 2988
        ]

        for i in 0..<rdCases.count {
            let date = Date<Persian>.fromRataDie(RataDie(rdCases[i]), calendar: persian)
            let year = persianYears[i]
            let nextNowruz = PersianArithmetic.fixedFromPersian(year: year + 1, month: 1, day: 1)
            let thisNowruz = PersianArithmetic.fixedFromPersian(year: year, month: 1, day: 1)
            let expectedDays = UInt16(nextNowruz.dayNumber - thisNowruz.dayNumber)
            #expect(date.daysInYear == expectedDays,
                    "Persian year \(year): daysInYear=\(date.daysInYear) != \(expectedDays)")
        }
    }
}

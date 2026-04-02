// Reingold solar longitude, ephemeris correction, and related functions.
//
// Algorithms from "Calendrical Calculations" by Reingold & Dershowitz (4th ed., 2018),
// ported from ICU4X calendrical_calculations/src/astronomy.rs (Apache-2.0).

import Foundation

/// Reingold & Dershowitz astronomical calculations (solar).
public enum Astronomical {

    // MARK: - Ephemeris Correction

    /// Corrects the discrepancy between dynamical time and universal time.
    ///
    /// Based on polynomial fits from Meeus (1991) and NASA data.
    public static func ephemerisCorrection(_ moment: Moment) -> Double {
        let year = moment.inner / 365.2425
        let yearInt = Int32(year > 0 ? year + 1 : year)
        let fixedMidYear = GregorianFixed.fixedFromGregorian(year: yearInt, month: 7, day: 1)
        let c = (Double(fixedMidYear) - 693596.0) / 36525.0
        let y2000 = Double(yearInt - 2000)
        let y1700 = Double(yearInt - 1700)
        let y1600 = Double(yearInt - 1600)
        let y1000 = Double(yearInt - 1000) / 100.0
        let y0 = Double(yearInt) / 100.0
        let y1820 = Double(yearInt - 1820) / 100.0

        if (2051...2150).contains(yearInt) {
            return (-20.0 + 32.0 * Double((yearInt - 1820) * (yearInt - 1820)) / 10000.0
                    + 0.5628 * Double(2150 - yearInt)) / 86400.0
        } else if (2006...2050).contains(yearInt) {
            return (62.92 + 0.32217 * y2000 + 0.005589 * y2000 * y2000) / 86400.0
        } else if (1987...2005).contains(yearInt) {
            return poly(y2000, [63.86, 0.3345, -0.060374, 0.0017275,
                                0.000651814, 0.00002373599]) / 86400.0
        } else if (1900...1986).contains(yearInt) {
            return poly(c, [-0.00002, 0.000297, 0.025184, -0.181133,
                            0.553040, -0.861938, 0.677066, -0.212591])
        } else if (1800...1899).contains(yearInt) {
            return poly(c, [-0.000009, 0.003844, 0.083563, 0.865736,
                            4.867575, 15.845535, 31.332267, 38.291999,
                            28.316289, 11.636204, 2.043794])
        } else if (1700...1799).contains(yearInt) {
            return poly(y1700, [8.118780842, -0.005092142, 0.003336121,
                                -0.0000266484]) / 86400.0
        } else if (1600...1699).contains(yearInt) {
            return poly(y1600, [120.0, -0.9808, -0.01532, 0.000140272128]) / 86400.0
        } else if (500...1599).contains(yearInt) {
            return poly(y1000, [1574.2, -556.01, 71.23472, 0.319781,
                                -0.8503463, -0.005050998, 0.0083572073]) / 86400.0
        } else if (-499...499).contains(yearInt) {
            return poly(y0, [10583.6, -1014.41, 33.78311, -5.952053,
                             -0.1798452, 0.022174192, 0.0090316521]) / 86400.0
        } else {
            return (-20.0 + 32.0 * y1820 * y1820) / 86400.0
        }
    }

    /// Convert universal time to dynamical time.
    public static func dynamicalFromUniversal(_ universal: Moment) -> Moment {
        universal + ephemerisCorrection(universal)
    }

    /// Convert dynamical time to universal time.
    public static func universalFromDynamical(_ dynamical: Moment) -> Moment {
        dynamical - ephemerisCorrection(dynamical)
    }

    /// Julian centuries from J2000.0 in dynamical time.
    public static func julianCenturies(_ moment: Moment) -> Double {
        let dynamical = dynamicalFromUniversal(moment)
        return (dynamical - .j2000) / 36525.0
    }

    // MARK: - Nutation & Aberration

    /// Nutation in longitude (degrees).
    static func nutation(_ julianCenturies: Double) -> Double {
        let c = julianCenturies
        let a = 124.90 - 1934.134 * c + 0.002063 * c * c
        let b = 201.11 + 72001.5377 * c + 0.00057 * c * c
        return -0.004778 * sinDeg(a) - 0.0003667 * sinDeg(b)
    }

    /// Aberration correction (degrees).
    static func aberration(_ julianCenturies: Double) -> Double {
        0.0000974 * cosDeg(177.63 + 35999.01848 * julianCenturies) - 0.005575
    }

    // MARK: - Solar Longitude

    /// Solar longitude in degrees [0, 360) using the 49-term Bretagnon & Simon series.
    public static func solarLongitude(_ julianCenturies: Double) -> Double {
        let c = julianCenturies

        // 49-term Bretagnon & Simon solar longitude series
        let x: [Double] = [
            403406.0, 195207.0, 119433.0, 112392.0, 3891.0, 2819.0, 1721.0, 660.0, 350.0, 334.0,
            314.0, 268.0, 242.0, 234.0, 158.0, 132.0, 129.0, 114.0, 99.0, 93.0, 86.0, 78.0, 72.0,
            68.0, 64.0, 46.0, 38.0, 37.0, 32.0, 29.0, 28.0, 27.0, 27.0, 25.0, 24.0, 21.0, 21.0,
            20.0, 18.0, 17.0, 14.0, 13.0, 13.0, 13.0, 12.0, 10.0, 10.0, 10.0, 10.0,
        ]
        let y: [Double] = [
            270.54861, 340.19128, 63.91854, 331.26220, 317.843, 86.631, 240.052, 310.26, 247.23,
            260.87, 297.82, 343.14, 166.79, 81.53, 3.50, 132.75, 182.95, 162.03, 29.8, 266.4,
            249.2, 157.6, 257.8, 185.1, 69.9, 8.0, 197.1, 250.4, 65.3, 162.7, 341.5, 291.6, 98.5,
            146.7, 110.0, 5.2, 342.6, 230.9, 256.1, 45.3, 242.9, 115.2, 151.8, 285.3, 53.3, 126.6,
            205.7, 85.9, 146.1,
        ]
        let z: [Double] = [
            0.9287892, 35999.1376958, 35999.4089666, 35998.7287385, 71998.20261, 71998.4403,
            36000.35726, 71997.4812, 32964.4678, -19.4410, 445267.1117, 45036.8840, 3.1008,
            22518.4434, -19.9739, 65928.9345, 9038.0293, 3034.7684, 33718.148, 3034.448,
            -2280.773, 29929.992, 31556.493, 149.588, 9037.750, 107997.405, -4444.176, 151.771,
            67555.316, 31556.080, -4561.540, 107996.706, 1221.655, 62894.167, 31437.369,
            14578.298, -31931.757, 34777.243, 1221.999, 62894.511, -4442.039, 107997.909,
            119.066, 16859.071, -4.578, 26895.292, -39.127, 12297.536, 90073.778,
        ]

        var lambda = 0.0
        for i in 0..<49 {
            lambda += x[i] * sinDeg(y[i] + z[i] * c)
        }

        // Convert from arcseconds to degrees
        lambda *= 0.000005729577951308232  // = 1/3600 * pi/180 ... wait, actually this is 1/(180*1000/pi)
        // Actually: the factor converts the sum (which is in units of 0.0001 degrees × some scale)
        // Let me just use the same factor as ICU4X
        lambda += 282.7771834 + 36000.76953744 * c
        return mod360(lambda + aberration(c) + nutation(julianCenturies))
    }

    // MARK: - Obliquity

    /// Obliquity of the ecliptic (degrees).
    public static func obliquity(_ moment: Moment) -> Double {
        let c = julianCenturies(moment)
        return 23.4392911 - poly(c, [0.0, 0.013004167, 0.00000016389, 0.0000005036111])
    }

    // MARK: - Estimate Prior Solar Longitude

    /// Estimate the moment when the sun's longitude was at `angle` degrees,
    /// before the given `moment`.
    public static func estimatePriorSolarLongitude(angle: Double, moment: Moment) -> Moment {
        let rate = MEAN_TROPICAL_YEAR / 360.0
        let c = julianCenturies(moment)
        let lon = solarLongitude(c)
        let tau = Moment(moment.inner - rate * mod360(lon - angle))

        let delta = mod360(solarLongitude(julianCenturies(tau)) - angle)
        let result = Moment(tau.inner - rate * (delta < 180.0 ? delta : delta - 360.0))
        return Moment(min(moment.inner, result.inner))
    }
}

// MARK: - Gregorian Fixed Helper (internal, avoids CalendarSimple dependency)

/// Minimal Gregorian fixed-date calculation for ephemeris correction.
/// This avoids a dependency on CalendarSimple.
enum GregorianFixed {
    static func fixedFromGregorian(year: Int32, month: UInt8, day: UInt8) -> Int64 {
        let y = Int64(year)
        let prevYear = y - 1
        let daysInYear: Int64 = 365
        let yearShift: Int64 = 400 * ((Int64(Int32.max) / 400) + 1)

        var fixed = daysInYear * prevYear
        let shifted = prevYear + yearShift
        let shiftCorrection = yearShift / 4 - yearShift / 100 + yearShift / 400
        fixed += shifted / 4 - shifted / 100 + shifted / 400 - shiftCorrection

        // Days before month
        let m = Int64(month)
        let d = Int64(day)
        let daysBeforeMonth: Int64
        if m < 3 {
            daysBeforeMonth = m == 1 ? 0 : 31
        } else {
            let isLeap: Int64 = {
                if y % 25 != 0 { return y % 4 == 0 ? 1 : 0 }
                else { return y % 16 == 0 ? 1 : 0 }
            }()
            daysBeforeMonth = 31 + 28 + isLeap + Int64((979 * UInt32(month) - 2919) >> 5)
        }

        return fixed + daysBeforeMonth + d  // epoch is RD 1
    }
}

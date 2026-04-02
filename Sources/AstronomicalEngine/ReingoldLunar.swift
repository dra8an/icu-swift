// Reingold lunar longitude, new moon, and lunar phase calculations.
//
// Algorithms from "Calendrical Calculations" by Reingold & Dershowitz (4th ed., 2018),
// ported from ICU4X calendrical_calculations/src/astronomy.rs (Apache-2.0).

import Foundation

extension Astronomical {

    // MARK: - Lunar Longitude

    /// Lunar longitude in degrees [0, 360) using the Meeus 59-term series.
    public static func lunarLongitude(_ julianCenturies: Double) -> Double {
        let c = julianCenturies

        let meanMoon = mod360(poly(c, [218.3164477, 481267.88123421, -0.0015786, 1.0 / 538841.0, -1.0 / 65194000.0]))
        let elongation = mod360(poly(c, [297.8501921, 445267.1114034, -0.0018819, 1.0 / 545868.0, -1.0 / 113065000.0]))
        let solarAnomaly = mod360(poly(c, [357.5291092, 35999.0502909, -0.0001536, 1.0 / 24490000.0]))
        let lunarAnomaly = mod360(poly(c, [134.9633964, 477198.8675055, 0.0087414, 1.0 / 69699.0, -1.0 / 14712000.0]))
        let moonNode = mod360(poly(c, [93.2720950, 483202.0175233, -0.0036539, -1.0 / 3526000.0, 1.0 / 863310000.0]))
        let e = poly(c, [1.0, -0.002516, -0.0000074])

        // 59-term sine series for lunar longitude correction
        let sinCoeffs: [Double] = [
            6288774, 1274027, 658314, 213618, -185116, -114332, 58793, 57066, 53322, 45758,
            -40923, -34720, -30383, 15327, -12528, 10980, 10675, 10034, 8548, -7888,
            -6766, -5163, 4987, 4036, 3994, 3861, 3665, -2689, -2602, 2390,
            -2348, 2236, -2120, -2069, 2048, -1773, -1595, 1215, -1110, -892,
            -810, 759, -713, -700, 691, 596, 549, 537, 520, -487,
            -399, -381, 351, -340, 330, 327, -323, 299, 294,
        ]
        let dCoeffs: [Double] = [
            0, 2, 2, 0, 0, 0, 2, 2, 2, 2, 0, 1, 0, 2, 0, 0, 4, 0, 4, 2,
            2, 1, 1, 2, 2, 4, 2, 0, 2, 2, 1, 2, 0, 0, 2, 2, 2, 4, 0, 3,
            2, 4, 0, 2, 2, 2, 4, 0, 4, 1, 2, 0, 1, 3, 4, 2, 0, 1, 2,
        ]
        let mCoeffs: [Double] = [
            0, 0, 0, 0, 1, 0, 0, -1, 0, -1, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1,
            1, 0, 1, -1, 0, 0, 0, 1, 0, -1, 0, -2, 1, 2, -2, 0, 0, -1, 0, 0,
            1, -1, 2, 2, 1, -1, 0, 0, -1, 0, 1, 0, 1, 0, 0, -1, 2, 1, 0,
        ]
        let mpCoeffs: [Double] = [
            1, -1, 0, 2, 0, 0, -2, -1, 1, 0, -1, 0, 1, 0, 1, 1, -1, 3, -2, -1,
            0, -1, 0, 1, 2, 0, -3, -2, -1, -2, 1, 0, 2, 0, -1, 1, 0, -1, 2, -1,
            1, -2, -1, -1, -2, 0, 1, 4, 0, -2, 0, 2, 1, -2, -3, 2, 1, -1, 3,
        ]
        let fCoeffs: [Double] = [
            0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, 0, -2, 2, -2, 0, 0, 0, 0,
            0, 0, 0, 0, 0, 0, 0, 0, 2, 0, 0, 0, 0, 0, 0, -2, 2, 0, 2, 0,
            0, 0, 0, 0, 0, -2, 0, 0, 0, 0, -2, -2, 0, 0, 0, 0, 0, 0, 0,
        ]

        var correction = 0.0
        for i in 0..<59 {
            let ePow = pow(e, abs(mCoeffs[i]))
            let arg = dCoeffs[i] * elongation + mCoeffs[i] * solarAnomaly
                    + mpCoeffs[i] * lunarAnomaly + fCoeffs[i] * moonNode
            correction += sinCoeffs[i] * ePow * sinDeg(arg)
        }
        correction /= 1000000.0

        let venus = 3958.0 / 1000000.0 * sinDeg(119.75 + c * 131.849)
        let jupiter = 318.0 / 1000000.0 * sinDeg(53.09 + c * 479264.29)
        let flatEarth = 1962.0 / 1000000.0 * sinDeg(meanMoon - moonNode)

        return mod360(meanMoon + correction + venus + jupiter + flatEarth + nutation(julianCenturies))
    }

    // MARK: - Lunar Phase

    /// Lunar phase in degrees [0, 360). 0 = new moon, 90 = first quarter, 180 = full, 270 = last quarter.
    public static func lunarPhase(_ moment: Moment, julianCenturies: Double) -> Double {
        mod360(lunarLongitude(julianCenturies) - solarLongitude(julianCenturies))
    }

    // MARK: - New Moon

    /// The moment of the nth new moon after (or before, if negative) the new moon of January 11, 1 CE.
    ///
    /// Uses the Meeus algorithm with 24+13 correction terms.
    public static func nthNewMoon(_ n: Int32) -> Moment {
        let n0: Double = 24724.0
        let k = Double(n) - n0
        let c = k / 1236.85

        let approx = Moment.j2000
            + (5.09766 + MEAN_SYNODIC_MONTH * 1236.85 * c
               + 0.00015437 * c * c
               - 0.00000015 * c * c * c
               + 0.00000000073 * c * c * c * c)

        let e = 1.0 - 0.002516 * c - 0.0000074 * c * c
        let solarAnomaly = 2.5534 + 1236.85 * 29.10535670 * c
            - 0.0000014 * c * c - 0.00000011 * c * c * c
        let lunarAnomaly = 201.5643 + 385.81693528 * 1236.85 * c
            + 0.0107582 * c * c + 0.00001238 * c * c * c
            - 0.000000058 * c * c * c * c
        let moonArgument = 160.7108 + 390.67050284 * 1236.85 * c
            - 0.0016118 * c * c - 0.00000227 * c * c * c
            + 0.000000011 * c * c * c * c
        let omega = 124.7746 + (-1.56375588) * 1236.85 * c
            + 0.0020672 * c * c + 0.00000215 * c * c * c

        // 24-term correction
        let v: [Double] = [
            -0.40720, 0.17241, 0.01608, 0.01039, 0.00739, -0.00514, 0.00208, -0.00111, -0.00057,
            0.00056, -0.00042, 0.00042, 0.00038, -0.00024, -0.00007, 0.00004, 0.00004, 0.00003,
            0.00003, -0.00003, 0.00003, -0.00002, -0.00002, 0.00002,
        ]
        let xc: [Double] = [
            0, 1, 0, 0, -1, 1, 2, 0, 0, 1, 0, 1, 1, -1, 2, 0, 3, 1, 0, 1, -1, -1, 1, 0,
        ]
        let yc: [Double] = [
            1, 0, 2, 0, 1, 1, 0, 1, 1, 2, 3, 0, 0, 2, 1, 2, 0, 1, 2, 1, 1, 1, 3, 4,
        ]
        let zc: [Double] = [
            0, 0, 0, 2, 0, 0, 0, -2, 2, 0, 0, 2, -2, 0, 0, -2, 0, -2, 2, 2, 2, -2, 0, 0,
        ]

        var correction = -0.00017 * sinDeg(omega)
        for i in 0..<24 {
            let ePow = pow(e, abs(xc[i]))
            let arg = xc[i] * solarAnomaly + yc[i] * lunarAnomaly + zc[i] * moonArgument
            correction += v[i] * ePow * sinDeg(arg)
        }

        let extra = 0.000325 * sinDeg(299.77 + 132.8475848 * c - 0.009173 * c * c)

        // 13-term additional correction
        let ic: [Double] = [
            251.88, 251.83, 349.42, 84.66, 141.74, 207.14, 154.84, 34.52, 207.19, 291.34, 161.72, 239.56, 331.55,
        ]
        let jc: [Double] = [
            0.016321, 26.651886, 36.412478, 18.206239, 53.303771, 2.453732, 7.306860, 27.261239,
            0.121824, 1.844379, 24.198154, 25.513099, 3.592518,
        ]
        let lc: [Double] = [
            0.000165, 0.000164, 0.000126, 0.000110, 0.000062, 0.000060, 0.000056, 0.000047,
            0.000042, 0.000040, 0.000037, 0.000035, 0.000023,
        ]

        var additional = 0.0
        for i in 0..<13 {
            additional += lc[i] * sinDeg(ic[i] + jc[i] * k)
        }

        return universalFromDynamical(approx + correction + extra + additional)
    }

    /// The index n for the new moon at or after the given moment.
    public static func numOfNewMoonAtOrAfter(_ moment: Moment) -> Int32 {
        let t0 = NEW_MOON_ZERO
        let rawN = divEuclidF64(moment - t0, MEAN_SYNODIC_MONTH).rounded()
        var n = Int32(rawN)
        // Search forward
        while nthNewMoon(n) < moment {
            n += 1
        }
        return n
    }

    /// The moment of the new moon immediately before the given moment.
    public static func newMoonBefore(_ moment: Moment) -> Moment {
        let n = numOfNewMoonAtOrAfter(moment)
        return nthNewMoon(n - 1)
    }

    /// The moment of the new moon at or after the given moment.
    public static func newMoonAtOrAfter(_ moment: Moment) -> Moment {
        let n = numOfNewMoonAtOrAfter(moment)
        return nthNewMoon(n)
    }
}

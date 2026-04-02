// MoshierSolar — Moshier VSOP87 solar longitude, nutation, and Delta-T.
//
// Refactored from Hindu calendar project's Sun.swift (Moshier astronomical engine).
// Class → enum with static methods. Instance arrays → local variables.

import Foundation

/// Solar position calculations using the Moshier/VSOP87 engine.
///
/// Thread-safe: all methods are static, no mutable shared state.
public enum MoshierSolar {

    // MARK: - Constants

    private static let DEG2RAD = Double.pi / 180.0
    private static let RAD2DEG = 180.0 / Double.pi
    private static let STR = 4.8481368110953599359e-6
    private static let TIMESCALE = 3652500.0
    private static let J2000_JD = 2451545.0
    private static let J1900_JD = 2415020.0
    private static let EARTH_MOON_MRAT = 1.0 / 0.0123000383

    private static func mods3600(_ x: Double) -> Double {
        return x - 1.296e6 * floor(x / 1.296e6)
    }

    private static func normalizeDeg(_ d: Double) -> Double {
        var d = d.truncatingRemainder(dividingBy: 360.0)
        if d < 0 { d += 360.0 }
        return d
    }

    // MARK: - VSOP87 Data Tables for Earth

    private static let FREQS: [Double] = [
        53810162868.8982, 21066413643.3548, 12959774228.3429,
        6890507749.3988, 1092566037.7991, 439960985.5372,
        154248119.3933, 78655032.0744, 52272245.1795
    ]

    private static let PHASES: [Double] = [
        252.25090552 * 3600.0, 181.97980085 * 3600.0, 100.46645683 * 3600.0,
        355.43299958 * 3600.0, 34.35151874 * 3600.0, 50.07744430 * 3600.0,
        314.05500511 * 3600.0, 304.34866548 * 3600.0, 860492.1546
    ]

    private static let EAR_MAX_HARMONIC: [Int] = [1, 9, 14, 17, 5, 5, 2, 1, 0]

    private static let EARTABL: [Double] = [
        -65.54655, -232.74963, 12959774227.57587, 361678.59587,
        2.52679, -4.93511, 2.46852, -8.88928,
        6.66257, -1.94502, 0.66887, -0.06141,
        0.08893, 0.18971, 0.00068, -0.00307,
        0.03092, 0.03214, -0.14321, 0.22548,
        0.00314, -0.00221, 8.98017, 7.25747,
        -1.06655, 1.19671, -2.42276, 0.29621,
        1.55635, 0.99167, -0.00026, 0.00187,
        0.00189, 0.02742, 0.00158, 0.01475,
        0.00353, -0.02048, -0.01775, -0.01023,
        0.01927, -0.03122, -1.55440, -4.97423,
        2.14765, -2.77045, 1.02707, 0.55507,
        -0.08066, 0.18479, 0.00750, 0.00583,
        -0.16977, 0.35555, 0.32036, 0.01309,
        0.54625, 0.08167, 0.10681, 0.17231,
        -0.02287, 0.01631, -0.00866, -0.00190,
        0.00016, -0.01514, -0.00073, 0.04205,
        -0.00072, 0.01490, -0.38831, 0.41043,
        -1.11857, -0.84329, 1.15123, -1.34167,
        0.01026, -0.00432, -0.02833, -0.00705,
        -0.00285, 0.01645, -0.01234, 0.05609,
        -0.01893, -0.00171, -0.30527, 0.45390,
        0.56713, 0.70030, 1.27125, -0.76481,
        0.34857, -2.60318, -0.00160, 0.00643,
        0.28492, -0.37998, 0.23347, 0.00540,
        0.00342, 0.04406, 0.00037, -0.02449,
        0.01469, 1.59358, 0.24956, 0.71066,
        0.25477, -0.98371, -0.69412, 0.19687,
        -0.44423, -0.83331, 0.49647, -0.31021,
        0.05696, -0.00802, -0.14423, -0.04719,
        0.16762, -0.01234, 0.02481, 0.03465,
        0.01091, 0.02123, 0.08212, -0.07375,
        0.01524, -0.07388, 0.06673, -0.22486,
        0.10026, -0.00559, 0.14711, -0.11680,
        0.05460, 0.02749, -1.04467, 0.34273,
        -0.67582, -2.15117, 2.47372, -0.04332,
        0.05016, -0.03991, 0.01908, 0.00943,
        0.07321, -0.23637, 0.10564, -0.00446,
        -0.09523, -0.30710, 0.17400, -0.10681,
        0.05104, -0.14078, 0.01390, 0.07288,
        -0.26308, -0.20717, 0.20773, -0.37096,
        -0.00205, -0.27274, -0.00792, -0.00183,
        0.02985, 0.04895, 0.03785, -0.14731,
        0.02976, -0.02495, -0.02644, -0.04085,
        -0.00843, 0.00027, 0.00090, 0.00611,
        0.00040, 4.83425, 0.01692, -0.01335,
        0.04482, -0.03602, 0.01672, 0.00838,
        0.03682, -0.11206, 0.05163, -0.00219,
        -0.08381, -0.20911, 0.16400, -0.13325,
        -0.05945, 0.02114, -0.00710, -0.04695,
        -0.01657, -0.00513, -0.06999, -0.23054,
        0.13128, -0.07975, 0.00054, -0.00699,
        -0.01253, -0.04007, 0.00658, -0.00607,
        -0.48696, 0.31859, -0.84292, -0.87950,
        1.30507, -0.94042, -0.00234, 0.00339,
        -0.30647, -0.24605, 0.24948, -0.43369,
        -0.64033, 0.20754, -0.43829, -1.31801,
        1.55412, -0.02893, -0.02323, 0.02181,
        -0.00398, -0.01548, -0.08005, -0.01537,
        -0.00362, -0.02033, 0.00028, -0.03732,
        -0.14083, -7.21175, -0.07430, 0.01886,
        -0.00223, 0.01915, -0.02270, -0.03702,
        0.10167, -0.02917, 0.00879, -2.04198,
        -0.00433, -0.41764, 0.00671, -0.00030,
        0.00070, -0.01066, 0.01144, -0.03190,
        -0.29653, 0.38638, -0.16611, -0.07661,
        0.22071, 0.14665, 0.02487, 0.13524,
        -275.60942, -335.52251, -413.89009, 359.65390,
        1396.49813, 1118.56095, 2559.41622, -3393.39088,
        -6717.66079, -1543.17403, -1.90405, -0.22958,
        -0.57989, -0.36584, -0.04547, -0.14164,
        0.00749, -0.03973, 0.00033, 0.01842,
        -0.08301, -0.03523, -0.00408, -0.02008,
        0.00008, 0.00778, -0.00046, 0.02760,
        -0.03135, 0.07710, 0.06130, 0.04003,
        -0.04703, 0.00671, -0.00754, -0.01000,
        -0.01902, -0.00125, -0.00264, -0.00903,
        -0.02672, 0.12765, -0.03872, 0.03532,
        -0.01534, -0.00710, -0.01087, 0.01124,
        -0.01664, 0.06304, -0.02779, 0.00214,
        -0.01279, -5.51814, 0.05847, -0.02093,
        0.03950, 0.06696, -0.04064, 0.02687,
        0.01478, -0.02169, 0.05821, 0.03301,
        -0.03861, 0.07535, 0.00290, -0.00644,
        0.00631, 0.12905, 0.02400, 0.13194,
        -0.14339, 0.00529, 0.00343, 0.00819,
        0.02692, -0.03332, -0.07284, -0.02064,
        0.07038, 0.03999, 0.02759, 0.07599,
        0.00033, 0.00641, 0.00128, 0.02032,
        -0.00852, 0.00680, 0.23019, 0.17100,
        0.09861, 0.55013, -0.00192, 0.00953,
        -0.00943, 0.01783, 0.05975, 0.01486,
        0.00160, 0.01558, -0.01629, -0.02035,
        0.01533, 2.73176, 0.05858, -0.01327,
        0.00209, -0.01506, 0.00755, 0.03300,
        -0.00796, -0.65270, 0.02305, 0.00165,
        -0.02512, 0.06560, 0.16108, -0.02087,
        0.00016, 0.10729, 0.04175, 0.00559,
        0.01176, 0.00110, 15.15730, -0.52460,
        -37.16535, -25.85564, -60.94577, 4.29961,
        57.11617, 67.96463, 31.41414, -64.75731,
        0.00848, 0.02971, -0.03690, -0.00010,
        -0.03568, 0.06325, 0.11311, 0.02431,
        -0.00383, 0.00421, -0.00140, 0.00680,
        0.00069, -0.21036, 0.00386, 0.04210,
        -0.01324, 0.16454, -0.01398, -0.00109,
        0.02548, -0.03842, -0.06504, -0.02204,
        0.01359, 0.00232, 0.07634, -1.64648,
        -1.73103, 0.89176, 0.81398, 0.65209,
        0.00021, -0.08441, -0.00012, 0.01262,
        -0.00666, -0.00050, -0.00130, 0.01596,
        -0.00485, -0.00213, 0.00009, -0.03941,
        -0.02266, -0.04421, -0.01341, 0.01083,
        -0.00011, 0.00004, 0.00003, -0.02017,
        0.00003, -0.01096, 0.00002, -0.00623,
    ]

    private static let EARARGS: [Int8] = [
        0, 3,
        3, 4, 3, -8, 4, 3, 5, 2,
        2, 2, 5, -5, 6, 1,
        3, 2, 2, 1, 3, -8, 4, 0,
        3, 3, 2, -7, 3, 4, 4, 1,
        3, 7, 3, -13, 4, -1, 5, 0,
        2, 8, 2, -13, 3, 3,
        3, 1, 2, -8, 3, 12, 4, 0,
        1, 1, 8, 0,
        1, 1, 7, 0,
        2, 1, 5, -2, 6, 0,
        3, 3, 3, -6, 4, 2, 5, 1,
        2, 8, 3, -15, 4, 3,
        2, 2, 5, -4, 6, 0,
        1, 1, 6, 1,
        2, 9, 3, -17, 4, 2,
        3, 3, 2, -5, 3, 1, 5, 0,
        3, 2, 3, -4, 4, 2, 5, 0,
        3, 3, 2, -5, 3, 2, 5, 0,
        2, 1, 5, -1, 6, 0,
        2, 1, 3, -2, 4, 2,
        2, 2, 5, -3, 6, 0,
        1, 2, 6, 1,
        2, 3, 5, -5, 6, 1,
        1, 1, 5, 3,
        2, 1, 5, -5, 6, 0,
        2, 7, 3, -13, 4, 2,
        2, 2, 5, -2, 6, 0,
        2, 3, 2, -5, 3, 2,
        2, 2, 3, -4, 4, 2,
        2, 5, 2, -8, 3, 1,
        2, 6, 3, -11, 4, 1,
        2, 1, 1, -4, 3, 0,
        1, 2, 5, 1,
        2, 3, 3, -6, 4, 1,
        2, 5, 3, -9, 4, 1,
        2, 2, 2, -3, 3, 2,
        2, 4, 3, -8, 4, 1,
        2, 4, 3, -7, 4, 1,
        2, 3, 3, -5, 4, 1,
        2, 1, 2, -2, 3, 1,
        2, 2, 3, -3, 4, 1,
        2, 1, 3, -1, 4, 0,
        2, 4, 2, -7, 3, 0,
        2, 4, 2, -6, 3, 1,
        1, 1, 4, 1,
        2, 1, 3, -3, 4, 0,
        2, 7, 3, -12, 4, 0,
        2, 1, 2, -1, 3, 0,
        2, 1, 3, -4, 5, 0,
        2, 6, 3, -10, 4, 1,
        2, 5, 3, -8, 4, 1,
        2, 1, 3, -3, 5, 1,
        2, 2, 2, -4, 3, 1,
        2, 6, 2, -9, 3, 0,
        2, 4, 3, -6, 4, 1,
        3, 1, 3, -3, 5, 2, 6, 0,
        2, 1, 3, -5, 6, 1,
        2, 1, 3, -2, 5, 2,
        3, 1, 3, -4, 5, 5, 6, 0,
        2, 3, 3, -4, 4, 1,
        2, 3, 2, -4, 3, 2,
        2, 1, 3, -3, 6, 1,
        3, 1, 3, 1, 5, -5, 6, 1,
        2, 1, 3, -1, 5, 1,
        3, 1, 3, -3, 5, 5, 6, 1,
        2, 1, 3, -2, 6, 1,
        2, 2, 3, -2, 4, 0,
        2, 1, 3, -1, 6, 0,
        2, 1, 3, -2, 7, 0,
        2, 1, 3, -1, 7, 0,
        2, 8, 2, -14, 3, 0,
        3, 1, 3, 2, 5, -5, 6, 1,
        3, 5, 3, -8, 4, 3, 5, 1,
        1, 1, 3, 4,
        3, 3, 3, -8, 4, 3, 5, 2,
        2, 8, 2, -12, 3, 0,
        3, 1, 3, 1, 5, -2, 6, 0,
        2, 9, 3, -15, 4, 1,
        2, 1, 3, 1, 6, 0,
        1, 2, 4, 0,
        2, 1, 3, 1, 5, 1,
        2, 8, 3, -13, 4, 1,
        2, 3, 2, -6, 3, 0,
        2, 1, 3, -4, 4, 0,
        2, 5, 2, -7, 3, 0,
        2, 7, 3, -11, 4, 1,
        2, 1, 1, -3, 3, 0,
        2, 6, 3, -9, 4, 1,
        2, 2, 2, -2, 3, 0,
        2, 5, 3, -7, 4, 2,
        2, 4, 3, -5, 4, 2,
        2, 1, 2, -3, 3, 0,
        2, 3, 3, -3, 4, 0,
        2, 4, 2, -5, 3, 1,
        2, 2, 3, -5, 5, 0,
        1, 1, 2, 1,
        2, 2, 3, -4, 5, 1,
        3, 2, 3, -4, 5, 2, 6, 0,
        2, 6, 3, -8, 4, 1,
        2, 2, 3, -3, 5, 1,
        2, 6, 2, -8, 3, 0,
        2, 5, 3, -6, 4, 0,
        2, 2, 3, -5, 6, 1,
        2, 2, 3, -2, 5, 1,
        3, 2, 3, -4, 5, 5, 6, 1,
        2, 4, 3, -4, 4, 0,
        2, 3, 2, -3, 3, 0,
        2, 2, 3, -3, 6, 0,
        2, 2, 3, -1, 5, 1,
        2, 2, 3, -2, 6, 0,
        2, 3, 3, -2, 4, 0,
        2, 2, 3, -1, 6, 0,
        1, 2, 3, 4,
        2, 5, 2, -6, 3, 1,
        2, 2, 2, -1, 3, 1,
        2, 6, 3, -7, 4, 0,
        2, 5, 3, -5, 4, 0,
        2, 4, 2, -4, 3, 0,
        2, 3, 3, -4, 5, 0,
        2, 3, 3, -3, 5, 0,
        2, 6, 2, -7, 3, 0,
        2, 3, 3, -2, 5, 1,
        2, 3, 2, -2, 3, 0,
        1, 3, 3, 2,
        2, 5, 2, -5, 3, 0,
        2, 1, 1, -1, 3, 0,
        2, 7, 2, -8, 3, 0,
        2, 4, 3, -4, 5, 0,
        2, 4, 3, -3, 5, 0,
        2, 6, 2, -6, 3, 0,
        1, 4, 3, 1,
        2, 7, 2, -7, 3, 1,
        2, 8, 2, -8, 3, 0,
        2, 9, 2, -9, 3, 0,
        -1
    ]

    // MARK: - Delta-T Lookup Table

    private static let DT_TAB_START = 1900
    private static let DT_TAB_END = 2050
    private static let DT_TAB: [Double] = [
        -2.053, -0.820, 0.549, 1.992, 3.450, 4.862, 6.182, 7.431, 8.642, 9.851,
        11.092, 12.387, 13.709, 15.018, 16.275, 17.440, 18.482, 19.405, 20.222, 20.945,
        21.588, 22.159, 22.662, 23.097, 23.466, 23.767, 24.003, 24.178, 24.299, 24.372,
        24.403, 24.397, 24.363, 24.306, 24.234, 24.154, 24.076, 24.030, 24.049, 24.168,
        24.421, 24.825, 25.343, 25.922, 26.508, 27.048, 27.503, 27.890, 28.237, 28.574,
        28.931, 29.321, 29.699, 30.180, 30.623, 31.070, 31.350, 31.681, 32.181, 32.681,
        33.151, 33.591, 34.001, 34.471, 35.031, 35.731, 36.541, 37.431, 38.291, 39.201,
        40.181, 41.171, 42.232, 43.372, 44.486, 45.477, 46.458, 47.523, 48.536, 49.588,
        50.540, 51.382, 52.168, 52.958, 53.789, 54.343, 54.872, 55.323, 55.820, 56.301,
        56.856, 57.566, 58.310, 59.123, 59.986, 60.787, 61.630, 62.296, 62.967, 63.468,
        63.829, 64.091, 64.300, 64.474, 64.574, 64.688, 64.846, 65.147, 65.458, 65.777,
        66.070, 66.325, 66.603, 66.907, 67.281, 67.644, 68.103, 68.593, 68.968, 69.220,
        69.361, 69.359, 69.294, 69.183, 69.100, 69.000, 68.900, 68.800, 68.800, 69.037,
        69.276, 69.518, 69.762, 70.008, 70.257, 70.508, 70.761, 71.017, 71.276, 71.537,
        71.800, 72.066, 72.335, 72.606, 72.880, 73.157, 73.436, 73.718, 74.003, 74.290,
        74.581,
    ]

    // MARK: - Nutation Coefficients

    private static let NT_ARGS: [[Int8]] = [
        [0, 0, 0, 0, 1], [-2, 0, 0, 2, 2], [0, 0, 0, 2, 2], [0, 0, 0, 0, 2],
        [0, 1, 0, 0, 0], [0, 0, 1, 0, 0], [-2, 1, 0, 2, 2], [0, 0, 0, 2, 1],
        [0, 0, 1, 2, 2], [-2, -1, 0, 2, 2], [-2, 0, 1, 0, 0], [-2, 0, 0, 2, 1],
        [0, 0, -1, 2, 2],
    ]
    private static let NT_S0: [Double] = [
        -171996, -13187, -2274, 2062, 1426, 712, -517, -386, -301, 217, -158, 129, 123
    ]
    private static let NT_S1: [Double] = [
        -174.2, -1.6, -0.2, 0.2, -3.4, 0.1, 1.2, -0.4, 0.0, -0.5, 0.0, 0.1, 0.0
    ]
    private static let NT_C0: [Double] = [
        92025, 5736, 977, -895, 54, -7, 224, 200, 129, -95, 0, -70, -53
    ]
    private static let NT_C1: [Double] = [
        8.9, -3.1, -0.5, 0.5, -0.1, 0.0, -0.6, 0.0, -0.1, 0.3, 0.0, 0.0, 0.0
    ]

    // MARK: - sscc helper (local arrays via inout)

    private static func sscc(_ k: Int, _ arg: Double, _ n: Int,
                             ssTbl: inout [[Double]], ccTbl: inout [[Double]]) {
        let su = sin(arg), cu = cos(arg)
        ssTbl[k][0] = su
        ccTbl[k][0] = cu
        var sv = 2.0 * su * cu
        var cv = cu * cu - su * su
        ssTbl[k][1] = sv
        ccTbl[k][1] = cv
        if n > 2 {
            for i in 2..<n {
                let s = su * cv + cu * sv
                cv = cu * cv - su * sv
                sv = s
                ssTbl[k][i] = sv
                ccTbl[k][i] = cv
            }
        }
    }

    // MARK: - VSOP87 Earth Longitude

    private static func vsop87EarthLongitude(_ jdTt: Double,
                                             ssTbl: inout [[Double]],
                                             ccTbl: inout [[Double]]) -> Double {
        let T = (jdTt - J2000_JD) / TIMESCALE

        for i in 0..<9 {
            if EAR_MAX_HARMONIC[i] > 0 {
                let sr = (mods3600(FREQS[i] * T) + PHASES[i]) * STR
                sscc(i, sr, EAR_MAX_HARMONIC[i], ssTbl: &ssTbl, ccTbl: &ccTbl)
            }
        }

        var pIdx = 0
        var plIdx = 0
        var sl = 0.0

        while true {
            let np = Int(EARARGS[pIdx]); pIdx += 1
            if np < 0 { break }

            if np == 0 {
                let nt = Int(EARARGS[pIdx]); pIdx += 1
                var cu = EARTABL[plIdx]; plIdx += 1
                for _ in 0..<nt {
                    cu = cu * T + EARTABL[plIdx]; plIdx += 1
                }
                sl += mods3600(cu)
                continue
            }

            var k1 = 0
            var cv = 0.0, sv = 0.0
            for _ in 0..<np {
                let j = Int(EARARGS[pIdx]); pIdx += 1
                let m = Int(EARARGS[pIdx]) - 1; pIdx += 1
                if j != 0 {
                    var k = j < 0 ? -j : j
                    k -= 1
                    var su = ssTbl[m][k]
                    if j < 0 { su = -su }
                    let cu2 = ccTbl[m][k]
                    if k1 == 0 {
                        sv = su
                        cv = cu2
                        k1 = 1
                    } else {
                        let t = su * cv + cu2 * sv
                        cv = cu2 * cv - su * sv
                        sv = t
                    }
                }
            }

            let nt = Int(EARARGS[pIdx]); pIdx += 1
            var cu = EARTABL[plIdx]; plIdx += 1
            var su = EARTABL[plIdx]; plIdx += 1
            for _ in 0..<nt {
                cu = cu * T + EARTABL[plIdx]; plIdx += 1
                su = su * T + EARTABL[plIdx]; plIdx += 1
            }
            sl += cu * cv + su * sv
        }

        return sl
    }

    // MARK: - Earth-Moon Barycenter Correction

    private static func embEarthCorrection(_ jdTt: Double, _ L_emb_rad: Double) -> Double {
        let T = (jdTt - J1900_JD) / 36525.0

        var a = ((1.44e-5 * T + 0.009192) * T + 477198.8491) * T + 296.104608
        a = a.truncatingRemainder(dividingBy: 360.0)
        if a < 0 { a += 360.0 }
        a *= DEG2RAD
        let smp = sin(a), cmp = cos(a)
        let s2mp = 2.0 * smp * cmp

        a = ((1.9e-6 * T - 0.001436) * T + 445267.1142) * T + 350.737486
        a = a.truncatingRemainder(dividingBy: 360.0)
        if a < 0 { a += 360.0 }
        a = 2.0 * DEG2RAD * a
        let s2d = sin(a), c2d = cos(a)

        a = ((-3.0e-7 * T - 0.003211) * T + 483202.0251) * T + 11.250889
        a = a.truncatingRemainder(dividingBy: 360.0)
        if a < 0 { a += 360.0 }
        a *= DEG2RAD
        let sf = sin(a), cf = cos(a)

        let sx = s2d * cmp - c2d * smp

        var M = ((-3.3e-6 * T - 1.50e-4) * T + 35999.0498) * T + 358.475833
        M = M.truncatingRemainder(dividingBy: 360.0)
        if M < 0 { M += 360.0 }

        var L = ((1.9e-6 * T - 0.001133) * T + 481267.8831) * T + 270.434164
        L += 6.288750 * smp
            + 1.274018 * sx
            + 0.658309 * s2d
            + 0.213616 * s2mp
            - 0.185596 * sin(DEG2RAD * M)
            - 0.114336 * (2.0 * sf * cf)

        let aTmp = smp * cf
        let sxTmp = cmp * sf
        var B = 5.128189 * sf
            + 0.280606 * (aTmp + sxTmp)
            + 0.277693 * (aTmp - sxTmp)
            + 0.173238 * (s2d * cf - c2d * sf)
        B *= DEG2RAD

        let cx = c2d * cmp + s2d * smp
        var p = 0.950724
            + 0.051818 * cmp
            + 0.009531 * cx
            + 0.007843 * c2d
            + 0.002824 * (cmp * cmp - smp * smp)
        p *= DEG2RAD
        let rMoon = 4.263523e-5 / sin(p)

        L = L.truncatingRemainder(dividingBy: 360.0)
        if L < 0 { L += 360.0 }
        let L_moon_rad = L * DEG2RAD

        return -rMoon * cos(B) * sin(L_moon_rad - L_emb_rad) / (EARTH_MOON_MRAT + 1.0)
    }

    // MARK: - Delta-T

    /// Delta-T in fractional days for a given Julian Day (UT).
    public static func deltaT(_ jdUt: Double) -> Double {
        return deltaTSeconds(jdUt) / 86400.0
    }

    /// Delta-T in seconds for a given Julian Day (UT).
    static func deltaTSeconds(_ jdUt: Double) -> Double {
        let ymd = jdToYMD(jdUt)
        let y = Double(ymd.year) + (Double(ymd.month) - 0.5) / 12.0

        if y >= Double(DT_TAB_START) && y < Double(DT_TAB_END) + 1 {
            let idx = y - Double(DT_TAB_START)
            var i = Int(idx)
            if i >= DT_TAB.count - 1 { i = DT_TAB.count - 2 }
            let frac = idx - Double(i)
            return DT_TAB[i] + frac * (DT_TAB[i + 1] - DT_TAB[i])
        } else if y < Double(DT_TAB_START) {
            let t = (y - 1820.0) / 100.0
            return -20 + 32 * t * t
        } else if y < 2150 {
            return -20 + 32 * ((y - 1820.0) / 100.0) * ((y - 1820.0) / 100.0)
                - 0.5628 * (2150 - y)
        } else {
            let u = (y - 1820.0) / 100.0
            return -20 + 32 * u * u
        }
    }

    /// Convert JD (UT) to JD (TT).
    static func jdUtToTt(_ jdUt: Double) -> Double {
        return jdUt + deltaTSeconds(jdUt) / 86400.0
    }

    // MARK: - Julian Day ↔ Calendar (inline, avoids external dependency)

    /// Convert a Julian Day to year/month/day. Equivalent to JulianDay.revjul.
    static func jdToYMD(_ jd: Double) -> (year: Int, month: Int, day: Int) {
        let jd2 = jd + 0.5
        let Z = floor(jd2)

        let A: Double
        if Z < 2299161.0 {
            A = Z
        } else {
            let alpha = floor((Z - 1867216.25) / 36524.25)
            A = Z + 1 + alpha - floor(alpha / 4.0)
        }

        let B = A + 1524
        let C = floor((B - 122.1) / 365.25)
        let D = floor(365.25 * C)
        let E = floor((B - D) / 30.6001)
        let F = jd2 - Z
        let d = B - D - floor(30.6001 * E) + F
        let day = Int(d)

        let month: Int
        if E < 14 {
            month = Int(E) - 1
        } else {
            month = Int(E) - 13
        }

        let year: Int
        if month > 2 {
            year = Int(C) - 4716
        } else {
            year = Int(C) - 4715
        }

        return (year, month, day)
    }

    /// Convert year/month/day/hour to JD. Equivalent to JulianDay.julday.
    static func ymdToJD(year: Int, month: Int, day: Int, hour: Double = 0.0) -> Double {
        var y = year
        var m = month
        if m <= 2 {
            y -= 1
            m += 12
        }
        let A = y / 100
        let B = 2 - A + A / 4
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1))
            + Double(day) + hour / 24.0 + Double(B) - 1524.5
    }

    // MARK: - Nutation

    /// Nutation in longitude (dpsi) and obliquity (deps), both in degrees.
    public static func nutation(_ jdTt: Double) -> (dpsi: Double, deps: Double) {
        let T = (jdTt - 2451545.0) / 36525.0
        let T2 = T * T
        let T3 = T2 * T

        var D = 297.85036 + 445267.111480 * T - 0.0019142 * T2 + T3 / 189474.0
        var M = 357.52772 + 35999.050340 * T - 0.0001603 * T2 - T3 / 300000.0
        var Mp = 134.96298 + 477198.867398 * T + 0.0086972 * T2 + T3 / 56250.0
        var F = 93.27191 + 483202.017538 * T - 0.0036825 * T2 + T3 / 327270.0
        var Om = 125.04452 - 1934.136261 * T + 0.0020708 * T2 + T3 / 450000.0

        D *= DEG2RAD
        M *= DEG2RAD
        Mp *= DEG2RAD
        F *= DEG2RAD
        Om *= DEG2RAD

        var sumDpsi = 0.0, sumDeps = 0.0
        for i in 0..<13 {
            let arg = Double(NT_ARGS[i][0]) * D + Double(NT_ARGS[i][1]) * M
                + Double(NT_ARGS[i][2]) * Mp + Double(NT_ARGS[i][3]) * F
                + Double(NT_ARGS[i][4]) * Om
            sumDpsi += (NT_S0[i] + NT_S1[i] * T) * sin(arg)
            sumDeps += (NT_C0[i] + NT_C1[i] * T) * cos(arg)
        }

        return (sumDpsi * 0.0001 / 3600.0, sumDeps * 0.0001 / 3600.0)
    }

    // MARK: - Obliquity

    /// Mean obliquity of the ecliptic in degrees for JD (TT).
    public static func meanObliquity(_ jdTt: Double) -> Double {
        let T = (jdTt - 2451545.0) / 36525.0
        let U = T / 100.0
        return 23.0 + 26.0 / 60.0 + 21.448 / 3600.0
            + (-4680.93 * U
            - 1.55 * U * U
            + 1999.25 * U * U * U
            - 51.38 * U * U * U * U
            - 249.67 * U * U * U * U * U
            - 39.05 * U * U * U * U * U * U
            + 7.12 * U * U * U * U * U * U * U
            + 27.87 * U * U * U * U * U * U * U * U
            + 5.79 * U * U * U * U * U * U * U * U * U
            + 2.45 * U * U * U * U * U * U * U * U * U * U) / 3600.0
    }

    // MARK: - Solar Position

    private static func solarPosition(_ jdUt: Double) -> (longitude: Double, declination: Double, nutLon: Double) {
        let jdTt = jdUtToTt(jdUt)
        let T = (jdTt - J2000_JD) / 36525.0

        var ssTbl = [[Double]](repeating: [Double](repeating: 0.0, count: 24), count: 9)
        var ccTbl = [[Double]](repeating: [Double](repeating: 0.0, count: 24), count: 9)

        let sl = vsop87EarthLongitude(jdTt, ssTbl: &ssTbl, ccTbl: &ccTbl)
        let L_emb_j2000 = sl * STR

        let pA = (5029.0966 + 1.11113 * T - 0.000006 * T * T) * T
        let L_emb_date = L_emb_j2000 + pA * STR

        let dL = embEarthCorrection(jdTt, L_emb_date)
        let L_earth_date = L_emb_date + dL

        let L_sun_date = L_earth_date + Double.pi

        let nut = nutation(jdTt)
        var L_apparent = L_sun_date + nut.dpsi * DEG2RAD

        L_apparent -= 20.496 * STR

        let apparent = normalizeDeg(L_apparent * RAD2DEG)

        let eps0 = meanObliquity(jdTt)
        let eps = (eps0 + nut.deps) * DEG2RAD
        let lam = apparent * DEG2RAD
        let declination = asin(sin(eps) * sin(lam)) * RAD2DEG

        return (apparent, declination, nut.dpsi)
    }

    // MARK: - Public API (Julian Day)

    /// Solar longitude in degrees [0, 360) for JD (UT).
    public static func solarLongitude(_ jdUt: Double) -> Double {
        return solarPosition(jdUt).longitude
    }

    /// Solar declination in degrees for JD (UT).
    public static func solarDeclination(_ jdUt: Double) -> Double {
        return solarPosition(jdUt).declination
    }

    /// Solar right ascension in degrees [0, 360) for JD (UT).
    public static func solarRa(_ jdUt: Double) -> Double {
        let jdTt = jdUtToTt(jdUt)
        let nut = nutation(jdTt)
        let eps0 = meanObliquity(jdTt)
        let eps = (eps0 + nut.deps) * DEG2RAD
        let lam = solarLongitude(jdUt) * DEG2RAD
        let ra = atan2(cos(eps) * sin(lam), cos(lam)) * RAD2DEG
        return normalizeDeg(ra)
    }

    /// Nutation in longitude (degrees) for JD (UT).
    public static func nutationLongitude(_ jdUt: Double) -> Double {
        let jdTt = jdUtToTt(jdUt)
        return nutation(jdTt).dpsi
    }

    /// Mean obliquity of the ecliptic (degrees) for JD (UT).
    public static func meanObliquityUt(_ jdUt: Double) -> Double {
        return meanObliquity(jdUtToTt(jdUt))
    }

    /// True obliquity of the ecliptic (degrees) for JD (UT).
    public static func trueObliquity(_ jdUt: Double) -> Double {
        let jdTt = jdUtToTt(jdUt)
        return meanObliquity(jdTt) + nutation(jdTt).deps
    }

    // MARK: - Public API (Moment)

    /// Solar longitude in degrees [0, 360) at the given Moment.
    public static func solarLongitude(at moment: Moment) -> Double {
        return solarLongitude(moment.toJulianDay())
    }

    /// Solar declination in degrees at the given Moment.
    public static func solarDeclination(at moment: Moment) -> Double {
        return solarDeclination(moment.toJulianDay())
    }
}

// MoshierLunar — Moshier DE404 lunar longitude.
//
// Refactored from Hindu calendar project's Moon.swift (Moshier astronomical engine).
// Class → enum with static methods. Instance arrays → local LunarWorkspace struct.

import Foundation

/// Lunar position calculations using the Moshier/DE404 engine.
///
/// Thread-safe: all methods are static, mutable state is local to each call.
public enum MoshierLunar {

    // MARK: - Constants

    private static let STR = 4.8481368110953599359e-6
    private static let J2000 = 2451545.0

    private static func mods3600(_ x: Double) -> Double {
        return x - 1296000.0 * floor(x / 1296000.0)
    }

    // MARK: - Workspace (replaces mutable instance state)

    /// Mutable workspace for a single lunar longitude computation.
    private struct LunarWorkspace {
        var ss = [[Double]](repeating: [Double](repeating: 0.0, count: 8), count: 5)
        var cc = [[Double]](repeating: [Double](repeating: 0.0, count: 8), count: 5)

        var SWELP = 0.0, M_sun = 0.0, MP = 0.0, D = 0.0, NF = 0.0
        var T = 0.0, T2 = 0.0
        var Ve = 0.0, Ea = 0.0, Ma = 0.0, Ju = 0.0, Sa = 0.0

        mutating func sscc(_ k: Int, _ arg: Double, _ n: Int) {
            let cu = cos(arg), su = sin(arg)
            ss[k][0] = su
            cc[k][0] = cu
            var sv = 2.0 * su * cu
            var cv = cu * cu - su * su
            ss[k][1] = sv
            cc[k][1] = cv
            for i in 2..<n {
                let s = su * cv + cu * sv
                cv = cu * cv - su * sv
                sv = s
                ss[k][i] = sv
                cc[k][i] = cv
            }
        }
    }

    // MARK: - DE404 Correction Terms

    private static let Z: [Double] = [
        -1.312045233711e+01, -1.138215912580e-03, -9.646018347184e-06,
        3.146734198839e+01, 4.768357585780e-02, -3.421689790404e-04,
        -6.847070905410e+00, -5.834100476561e-03, -2.905334122698e-04,
        -5.663161722088e+00, 5.722859298199e-03, -8.466472828815e-05,
        -8.429817796435e+01, -2.072552484689e+02,
        7.876842214863e+00, 1.836463749022e+00,
        -1.557471855361e+01, -2.006969124724e+01,
        2.152670284757e+01, -6.179946916139e+00,
        -9.070028191196e-01, -1.270848233038e+01,
        -2.145589319058e+00, 1.381936399935e+01,
        -1.999840061168e+00,
    ]

    // MARK: - Lunar Tables

    private static let NLR = 118
    private static let LR: [Int16] = [
        0, 0, 1, 0, 22639, 5858, -20905, -3550,
        2, 0, -1, 0, 4586, 4383, -3699, -1109,
        2, 0, 0, 0, 2369, 9139, -2955, -9676,
        0, 0, 2, 0, 769, 257, -569, -9251,
        0, 1, 0, 0, -666, -4171, 48, 8883,
        0, 0, 0, 2, -411, -5957, -3, -1483,
        2, 0, -2, 0, 211, 6556, 246, 1585,
        2, -1, -1, 0, 205, 4358, -152, -1377,
        2, 0, 1, 0, 191, 9562, -170, -7331,
        2, -1, 0, 0, 164, 7285, -204, -5860,
        0, 1, -1, 0, -147, -3213, -129, -6201,
        1, 0, 0, 0, -124, -9881, 108, 7427,
        0, 1, 1, 0, -109, -3803, 104, 7552,
        2, 0, 0, -2, 55, 1771, 10, 3211,
        0, 0, 1, 2, -45, -996, 0, 0,
        0, 0, 1, -2, 39, 5333, 79, 6606,
        4, 0, -1, 0, 38, 4298, -34, -7825,
        0, 0, 3, 0, 36, 1238, -23, -2104,
        4, 0, -2, 0, 30, 7726, -21, -6363,
        2, 1, -1, 0, -28, -3971, 24, 2085,
        2, 1, 0, 0, -24, -3582, 30, 8238,
        1, 0, -1, 0, -18, -5847, -8, -3791,
        1, 1, 0, 0, 17, 9545, -16, -6747,
        2, -1, 1, 0, 14, 5303, -12, -8314,
        2, 0, 2, 0, 14, 3797, -10, -4448,
        4, 0, 0, 0, 13, 8991, -11, -6500,
        2, 0, -3, 0, 13, 1941, 14, 4027,
        0, 1, -2, 0, -9, -6791, -7, -27,
        2, 0, -1, 2, -9, -3659, 0, 7740,
        2, -1, -2, 0, 8, 6055, 10, 562,
        1, 0, 1, 0, -8, -4531, 6, 3220,
        2, -2, 0, 0, 8, 502, -9, -8845,
        0, 1, 2, 0, -7, -6302, 5, 7509,
        0, 2, 0, 0, -7, -4475, 1, 657,
        2, -2, -1, 0, 7, 3712, -4, -9501,
        2, 0, 1, -2, -6, -3832, 4, 1311,
        2, 0, 0, 2, -5, -7416, 0, 0,
        4, -1, -1, 0, 4, 3740, -3, -9580,
        0, 0, 2, 2, -3, -9976, 0, 0,
        3, 0, -1, 0, -3, -2097, 3, 2582,
        2, 1, 1, 0, -2, -9145, 2, 6164,
        4, -1, -2, 0, 2, 7319, -1, -8970,
        0, 2, -1, 0, -2, -5679, -2, -1171,
        2, 2, -1, 0, -2, -5212, 2, 3536,
        2, 1, -2, 0, 2, 4889, 0, 1437,
        2, -1, 0, -2, 2, 1461, 0, 6571,
        4, 0, 1, 0, 1, 9777, -1, -4226,
        0, 0, 4, 0, 1, 9337, -1, -1169,
        4, -1, 0, 0, 1, 8708, -1, -5714,
        1, 0, -2, 0, -1, -7530, -1, -7385,
        2, 1, 0, -2, -1, -4372, 0, -1357,
        0, 0, 2, -2, -1, -3726, -4, -4212,
        1, 1, 1, 0, 1, 2618, 0, -9333,
        3, 0, -2, 0, -1, -2241, 0, 8624,
        4, 0, -3, 0, 1, 1868, 0, -5142,
        2, -1, 2, 0, 1, 1770, 0, -8488,
        0, 2, 1, 0, -1, -1617, 1, 1655,
        1, 1, -1, 0, 1, 777, 0, 8512,
        2, 0, 3, 0, 1, 595, 0, -6697,
        2, 0, 1, 2, 0, -9902, 0, 0,
        2, 0, -4, 0, 0, 9483, 0, 7785,
        2, -2, 1, 0, 0, 7517, 0, -6575,
        0, 1, -3, 0, 0, -6694, 0, -4224,
        4, 1, -1, 0, 0, -6352, 0, 5788,
        1, 0, 2, 0, 0, -5840, 0, 3785,
        1, 0, 0, -2, 0, -5833, 0, -7956,
        6, 0, -2, 0, 0, 5716, 0, -4225,
        2, 0, -2, -2, 0, -5606, 0, 4726,
        1, -1, 0, 0, 0, -5569, 0, 4976,
        0, 1, 3, 0, 0, -5459, 0, 3551,
        2, 0, -2, 2, 0, -5357, 0, 7740,
        2, 0, -1, -2, 0, 1790, 8, 7516,
        3, 0, 0, 0, 0, 4042, -1, -4189,
        2, -1, -3, 0, 0, 4784, 0, 4950,
        2, -1, 3, 0, 0, 932, 0, -585,
        2, 0, 2, -2, 0, -4538, 0, 2840,
        2, -1, -1, 2, 0, -4262, 0, 373,
        0, 0, 0, 4, 0, 4203, 0, 0,
        0, 1, 0, 2, 0, 4134, 0, -1580,
        6, 0, -1, 0, 0, 3945, 0, -2866,
        2, -1, 0, 2, 0, -3821, 0, 0,
        2, -1, 1, -2, 0, -3745, 0, 2094,
        4, 1, -2, 0, 0, -3576, 0, 2370,
        1, 1, -2, 0, 0, 3497, 0, 3323,
        2, -3, 0, 0, 0, 3398, 0, -4107,
        0, 0, 3, 2, 0, -3286, 0, 0,
        4, -2, -1, 0, 0, -3087, 0, -2790,
        0, 1, -1, -2, 0, 3015, 0, 0,
        4, 0, -1, -2, 0, 3009, 0, -3218,
        2, -2, -2, 0, 0, 2942, 0, 3430,
        6, 0, -3, 0, 0, 2925, 0, -1832,
        2, 1, 2, 0, 0, -2902, 0, 2125,
        4, 1, 0, 0, 0, -2891, 0, 2445,
        4, -1, 1, 0, 0, 2825, 0, -2029,
        3, 1, -1, 0, 0, 2737, 0, -2126,
        0, 1, 1, 2, 0, 2634, 0, 0,
        1, 0, 0, 2, 0, 2543, 0, 0,
        3, 0, 0, -2, 0, -2530, 0, 2010,
        2, 2, -2, 0, 0, -2499, 0, -1089,
        2, -3, -1, 0, 0, 2469, 0, -1481,
        3, -1, -1, 0, 0, -2314, 0, 2556,
        4, 0, 2, 0, 0, 2185, 0, -1392,
        4, 0, -1, 2, 0, -2013, 0, 0,
        0, 2, -2, 0, 0, -1931, 0, 0,
        2, 2, 0, 0, 0, -1858, 0, 0,
        2, 1, -3, 0, 0, 1762, 0, 0,
        4, 0, -2, 2, 0, -1698, 0, 0,
        4, -2, -2, 0, 0, 1578, 0, -1083,
        4, -2, 0, 0, 0, 1522, 0, -1281,
        3, 1, 0, 0, 0, 1499, 0, -1077,
        1, -1, -1, 0, 0, -1364, 0, 1141,
        1, -3, 0, 0, 0, -1281, 0, 0,
        6, 0, 0, 0, 0, 1261, 0, -859,
        2, 0, 2, 2, 0, -1239, 0, 0,
        1, -1, 1, 0, 0, -1207, 0, 1100,
        0, 0, 5, 0, 0, 1110, 0, -589,
        0, 3, 0, 0, 0, -1013, 0, 213,
        4, -1, -3, 0, 0, 998, 0, 0,
    ]

    private static let NLRT = 38
    private static let LRT: [Int16] = [
        0, 1, 0, 0, 16, 7680, -1, -2302,
        2, -1, -1, 0, -5, -1642, 3, 8245,
        2, -1, 0, 0, -4, -1383, 5, 1395,
        0, 1, -1, 0, 3, 7115, 3, 2654,
        0, 1, 1, 0, 2, 7560, -2, -6396,
        2, 1, -1, 0, 0, 7118, 0, -6068,
        2, 1, 0, 0, 0, 6128, 0, -7754,
        1, 1, 0, 0, 0, -4516, 0, 4194,
        2, -2, 0, 0, 0, -4048, 0, 4970,
        0, 2, 0, 0, 0, 3747, 0, -540,
        2, -2, -1, 0, 0, -3707, 0, 2490,
        2, -1, 1, 0, 0, -3649, 0, 3222,
        0, 1, -2, 0, 0, 2438, 0, 1760,
        2, -1, -2, 0, 0, -2165, 0, -2530,
        0, 1, 2, 0, 0, 1923, 0, -1450,
        0, 2, -1, 0, 0, 1292, 0, 1070,
        2, 2, -1, 0, 0, 1271, 0, -6070,
        4, -1, -1, 0, 0, -1098, 0, 990,
        2, 0, 0, 0, 0, 1073, 0, -1360,
        2, 0, -1, 0, 0, 839, 0, -630,
        2, 1, 1, 0, 0, 734, 0, -660,
        4, -1, -2, 0, 0, -688, 0, 480,
        2, 1, -2, 0, 0, -630, 0, 0,
        0, 2, 1, 0, 0, 587, 0, -590,
        2, -1, 0, -2, 0, -540, 0, -170,
        4, -1, 0, 0, 0, -468, 0, 390,
        2, -2, 1, 0, 0, -378, 0, 330,
        2, 1, 0, -2, 0, 364, 0, 0,
        1, 1, 1, 0, 0, -317, 0, 240,
        2, -1, 2, 0, 0, -295, 0, 210,
        1, 1, -1, 0, 0, -270, 0, -210,
        2, -3, 0, 0, 0, -256, 0, 310,
        2, -3, -1, 0, 0, -187, 0, 110,
        0, 1, -3, 0, 0, 169, 0, 110,
        4, 1, -1, 0, 0, 158, 0, -150,
        4, -2, -1, 0, 0, -155, 0, 140,
        0, 0, 1, 0, 0, 155, 0, -250,
        2, -2, -2, 0, 0, -148, 0, -170,
    ]

    private static let NLRT2 = 25
    private static let LRT2: [Int16] = [
        0, 1, 0, 0, 487, -36,
        2, -1, -1, 0, -150, 111,
        2, -1, 0, 0, -120, 149,
        0, 1, -1, 0, 108, 95,
        0, 1, 1, 0, 80, -77,
        2, 1, -1, 0, 21, -18,
        2, 1, 0, 0, 20, -23,
        1, 1, 0, 0, -13, 12,
        2, -2, 0, 0, -12, 14,
        2, -1, 1, 0, -11, 9,
        2, -2, -1, 0, -11, 7,
        0, 2, 0, 0, 11, 0,
        2, -1, -2, 0, -6, -7,
        0, 1, -2, 0, 7, 5,
        0, 1, 2, 0, 6, -4,
        2, 2, -1, 0, 5, -3,
        0, 2, -1, 0, 5, 3,
        4, -1, -1, 0, -3, 3,
        2, 0, 0, 0, 3, -4,
        4, -1, -2, 0, -2, 0,
        2, 1, -2, 0, -2, 0,
        2, -1, 0, -2, -2, 0,
        2, 1, 1, 0, 2, -2,
        2, 0, -1, 0, 2, 0,
        0, 2, 1, 0, 2, 0,
    ]

    // MARK: - chewm (operates on workspace arrays)

    private static func chewm(_ pt: [Int16], _ nlines: Int, _ nangles: Int, _ typflg: Int,
                               ws: inout LunarWorkspace) -> Double {
        var ans = 0.0
        var idx = 0
        for _ in 0..<nlines {
            var k1 = 0
            var sv = 0.0, cv = 0.0
            for m in 0..<nangles {
                let j = Int(pt[idx]); idx += 1
                if j != 0 {
                    var k = j < 0 ? -j : j
                    k -= 1
                    var su = ws.ss[m][k]
                    if j < 0 { su = -su }
                    let cu = ws.cc[m][k]
                    if k1 == 0 {
                        sv = su
                        cv = cu
                        k1 = 1
                    } else {
                        let ff = su * cv + cu * sv
                        cv = cu * cv - su * sv
                        sv = ff
                    }
                }
            }

            switch typflg {
            case 1:
                let j1 = Int(pt[idx]); idx += 1
                let k2 = Int(pt[idx]); idx += 1
                ans += Double(10000 * j1 + k2) * sv
                idx += 2 // skip radius
            case 2:
                let j2 = Int(pt[idx]); idx += 1
                ans += Double(j2) * sv
                idx += 1 // skip radius
            default:
                break
            }
        }
        return ans
    }

    // MARK: - Mean Elements

    private static func meanElements(_ ws: inout LunarWorkspace) {
        let fracT = ws.T.truncatingRemainder(dividingBy: 1.0)

        ws.M_sun = mods3600(129600000.0 * fracT - 3418.961646 * ws.T + 1287104.76154)
        ws.M_sun += ((((((((
            1.62e-20 * ws.T
                - 1.0390e-17) * ws.T
                - 3.83508e-15) * ws.T
                + 4.237343e-13) * ws.T
                + 8.8555011e-11) * ws.T
                - 4.77258489e-8) * ws.T
                - 1.1297037031e-5) * ws.T
                + 1.4732069041e-4) * ws.T
                - 0.552891801772) * ws.T2

        ws.NF = mods3600(1739232000.0 * fracT + 295263.0983 * ws.T
            - 2.079419901760e-01 * ws.T + 335779.55755)

        ws.MP = mods3600(1717200000.0 * fracT + 715923.4728 * ws.T
            - 2.035946368532e-01 * ws.T + 485868.28096)

        ws.D = mods3600(1601856000.0 * fracT + 1105601.4603 * ws.T
            + 3.962893294503e-01 * ws.T + 1072260.73512)

        ws.SWELP = mods3600(1731456000.0 * fracT + 1108372.83264 * ws.T
            - 6.784914260953e-01 * ws.T + 785939.95571)

        ws.NF += ((Z[2] * ws.T + Z[1]) * ws.T + Z[0]) * ws.T2
        ws.MP += ((Z[5] * ws.T + Z[4]) * ws.T + Z[3]) * ws.T2
        ws.D += ((Z[8] * ws.T + Z[7]) * ws.T + Z[6]) * ws.T2
        ws.SWELP += ((Z[11] * ws.T + Z[10]) * ws.T + Z[9]) * ws.T2
    }

    private static func meanElementsPl(_ ws: inout LunarWorkspace) {
        ws.Ve = mods3600(210664136.4335482 * ws.T + 655127.283046)
        ws.Ve += ((((((((
            -9.36e-023 * ws.T
                - 1.95e-20) * ws.T
                + 6.097e-18) * ws.T
                + 4.43201e-15) * ws.T
                + 2.509418e-13) * ws.T
                - 3.0622898e-10) * ws.T
                - 2.26602516e-9) * ws.T
                - 1.4244812531e-5) * ws.T
                + 0.005871373088) * ws.T2

        ws.Ea = mods3600(129597742.26669231 * ws.T + 361679.214649)
        ws.Ea += ((((((((-1.16e-22 * ws.T
            + 2.976e-19) * ws.T
            + 2.8460e-17) * ws.T
            - 1.08402e-14) * ws.T
            - 1.226182e-12) * ws.T
            + 1.7228268e-10) * ws.T
            + 1.515912254e-7) * ws.T
            + 8.863982531e-6) * ws.T
            - 2.0199859001e-2) * ws.T2

        ws.Ma = mods3600(68905077.59284 * ws.T + 1279559.78866)
        ws.Ma += (-1.043e-5 * ws.T + 9.38012e-3) * ws.T2

        ws.Ju = mods3600(10925660.428608 * ws.T + 123665.342120)
        ws.Ju += (1.543273e-5 * ws.T - 3.06037836351e-1) * ws.T2

        ws.Sa = mods3600(4399609.65932 * ws.T + 180278.89694)
        ws.Sa += ((4.475946e-8 * ws.T - 6.874806E-5) * ws.T + 7.56161437443E-1) * ws.T2
    }

    // MARK: - Lunar Perturbations

    private static func lunarPerturbations(_ ws: inout LunarWorkspace) -> Double {
        var moonpol0: Double, l_acc: Double, l1: Double, l2: Double, l3: Double, l4: Double
        var f_ve: Double, cg: Double, sg: Double

        for i in 0..<5 {
            for j in 0..<8 {
                ws.ss[i][j] = 0
                ws.cc[i][j] = 0
            }
        }

        ws.sscc(0, STR * ws.D, 6)
        ws.sscc(1, STR * ws.M_sun, 4)
        ws.sscc(2, STR * ws.MP, 4)
        ws.sscc(3, STR * ws.NF, 4)

        moonpol0 = chewm(LRT2, NLRT2, 4, 2, ws: &ws)

        f_ve = 18.0 * ws.Ve - 16.0 * ws.Ea

        var g_arg = STR * (f_ve - ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc = 6.367278 * cg + 12.747036 * sg
        l1 = 23123.70 * cg - 10570.02 * sg
        l2 = Z[12] * cg + Z[13] * sg

        g_arg = STR * (10.0 * ws.Ve - 3.0 * ws.Ea - ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.253102 * cg + 0.503359 * sg
        l1 += 1258.46 * cg + 707.29 * sg
        l2 += Z[14] * cg + Z[15] * sg

        g_arg = STR * (8.0 * ws.Ve - 13.0 * ws.Ea)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.187231 * cg - 0.127481 * sg
        l1 += -319.87 * cg - 18.34 * sg
        l2 += Z[16] * cg + Z[17] * sg

        let a = 4.0 * ws.Ea - 8.0 * ws.Ma + 3.0 * ws.Ju
        g_arg = STR * a
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.866287 * cg + 0.248192 * sg
        l1 += 41.87 * cg + 1053.97 * sg
        l2 += Z[18] * cg + Z[19] * sg

        g_arg = STR * (a - ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.165009 * cg + 0.044176 * sg
        l1 += 4.67 * cg + 201.55 * sg

        g_arg = STR * f_ve
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.330401 * cg + 0.661362 * sg
        l1 += 1202.67 * cg - 555.59 * sg
        l2 += Z[20] * cg + Z[21] * sg

        g_arg = STR * (f_ve - 2.0 * ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.352185 * cg + 0.705041 * sg
        l1 += 1283.59 * cg - 586.43 * sg

        g_arg = STR * (2.0 * ws.Ju - 5.0 * ws.Sa)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.034700 * cg + 0.160041 * sg
        l2 += Z[22] * cg + Z[23] * sg

        g_arg = STR * (ws.SWELP - ws.NF)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.000116 * cg + 7.063040 * sg
        l1 += 298.8 * sg

        l3 = Z[24] * sin(STR * ws.M_sun)
        l4 = 0

        l2 += moonpol0

        moonpol0 = chewm(LRT, NLRT, 4, 1, ws: &ws)

        g_arg = STR * (2.0 * ws.Ve - 3.0 * ws.Ea)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.343550 * cg - 0.000276 * sg
        l1 += 105.90 * cg + 336.53 * sg

        g_arg = STR * (f_ve - 2.0 * ws.D)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.074668 * cg + 0.149501 * sg
        l1 += 271.77 * cg - 124.20 * sg

        g_arg = STR * (f_ve - 2.0 * ws.D - ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.073444 * cg + 0.147094 * sg
        l1 += 265.24 * cg - 121.16 * sg

        g_arg = STR * (f_ve + 2.0 * ws.D - ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.072844 * cg + 0.145829 * sg
        l1 += 265.18 * cg - 121.29 * sg

        g_arg = STR * (f_ve + 2.0 * (ws.D - ws.MP))
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.070201 * cg + 0.140542 * sg
        l1 += 255.36 * cg - 116.79 * sg

        g_arg = STR * (ws.Ea + ws.D - ws.NF)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.288209 * cg - 0.025901 * sg
        l1 += -63.51 * cg - 240.14 * sg

        g_arg = STR * (2.0 * ws.Ea - 3.0 * ws.Ju + 2.0 * ws.D - ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += 0.077865 * cg + 0.438460 * sg
        l1 += 210.57 * cg + 124.84 * sg

        g_arg = STR * (ws.Ea - 2.0 * ws.Ma)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.216579 * cg + 0.241702 * sg
        l1 += 197.67 * cg + 125.23 * sg

        g_arg = STR * (a + ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.165009 * cg + 0.044176 * sg
        l1 += 4.67 * cg + 201.55 * sg

        g_arg = STR * (a + 2.0 * ws.D - ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.133533 * cg + 0.041116 * sg
        l1 += 6.95 * cg + 187.07 * sg

        g_arg = STR * (a - 2.0 * ws.D + ws.MP)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.133430 * cg + 0.041079 * sg
        l1 += 6.28 * cg + 169.08 * sg

        g_arg = STR * (3.0 * ws.Ve - 4.0 * ws.Ea)
        cg = cos(g_arg); sg = sin(g_arg)
        l_acc += -0.175074 * cg + 0.003035 * sg
        l1 += 49.17 * cg + 150.57 * sg

        g_arg = STR * (2.0 * (ws.Ea + ws.D - ws.MP) - 3.0 * ws.Ju + 213534.0)
        l1 += 158.4 * sin(g_arg)

        l1 += moonpol0

        g_arg = STR * (2.0 * (ws.Ea - ws.Ju + ws.D) - ws.MP + 648431.172)
        l_acc += 1.14307 * sin(g_arg)

        g_arg = STR * (ws.Ve - ws.Ea + 648035.568)
        l_acc += 0.82155 * sin(g_arg)

        g_arg = STR * (3.0 * (ws.Ve - ws.Ea) + 2.0 * ws.D - ws.MP + 647933.184)
        l_acc += 0.64371 * sin(g_arg)

        g_arg = STR * (ws.Ea - ws.Ju + 4424.04)
        l_acc += 0.63880 * sin(g_arg)

        g_arg = STR * (ws.SWELP + ws.MP - ws.NF + 4.68)
        l_acc += 0.49331 * sin(g_arg)

        g_arg = STR * (ws.SWELP - ws.MP - ws.NF + 4.68)
        l_acc += 0.4914 * sin(g_arg)

        g_arg = STR * (ws.SWELP + ws.NF + 2.52)
        l_acc += 0.36061 * sin(g_arg)

        g_arg = STR * (2.0 * ws.Ve - 2.0 * ws.Ea + 736.2)
        l_acc += 0.30154 * sin(g_arg)

        g_arg = STR * (2.0 * ws.Ea - 3.0 * ws.Ju + 2.0 * ws.D - 2.0 * ws.MP + 36138.2)
        l_acc += 0.28282 * sin(g_arg)

        g_arg = STR * (2.0 * ws.Ea - 2.0 * ws.Ju + 2.0 * ws.D - 2.0 * ws.MP + 311.0)
        l_acc += 0.24516 * sin(g_arg)

        g_arg = STR * (ws.Ea - ws.Ju - 2.0 * ws.D + ws.MP + 6275.88)
        l_acc += 0.21117 * sin(g_arg)

        g_arg = STR * (2.0 * (ws.Ea - ws.Ma) - 846.36)
        l_acc += 0.19444 * sin(g_arg)

        g_arg = STR * (2.0 * (ws.Ea - ws.Ju) + 1569.96)
        l_acc -= 0.18457 * sin(g_arg)

        g_arg = STR * (2.0 * (ws.Ea - ws.Ju) - ws.MP - 55.8)
        l_acc += 0.18256 * sin(g_arg)

        g_arg = STR * (ws.Ea - ws.Ju - 2.0 * ws.D + 6490.08)
        l_acc += 0.16499 * sin(g_arg)

        g_arg = STR * (ws.Ea - 2.0 * ws.Ju - 212378.4)
        l_acc += 0.16427 * sin(g_arg)

        g_arg = STR * (2.0 * (ws.Ve - ws.Ea - ws.D) + ws.MP + 1122.48)
        l_acc += 0.16088 * sin(g_arg)

        g_arg = STR * (ws.Ve - ws.Ea - ws.MP + 32.04)
        l_acc -= 0.15350 * sin(g_arg)

        g_arg = STR * (ws.Ea - ws.Ju - ws.MP + 4488.88)
        l_acc += 0.14346 * sin(g_arg)

        g_arg = STR * (2.0 * (ws.Ve - ws.Ea + ws.D) - ws.MP - 8.64)
        l_acc += 0.13594 * sin(g_arg)

        g_arg = STR * (2.0 * (ws.Ve - ws.Ea - ws.D) + 1319.76)
        l_acc += 0.13432 * sin(g_arg)

        g_arg = STR * (ws.Ve - ws.Ea - 2.0 * ws.D + ws.MP - 56.16)
        l_acc -= 0.13122 * sin(g_arg)

        g_arg = STR * (ws.Ve - ws.Ea + ws.MP + 54.36)
        l_acc -= 0.12722 * sin(g_arg)

        g_arg = STR * (3.0 * (ws.Ve - ws.Ea) - ws.MP + 433.8)
        l_acc += 0.12539 * sin(g_arg)

        g_arg = STR * (ws.Ea - ws.Ju + ws.MP + 4002.12)
        l_acc += 0.10994 * sin(g_arg)

        g_arg = STR * (20.0 * ws.Ve - 21.0 * ws.Ea - 2.0 * ws.D + ws.MP - 317511.72)
        l_acc += 0.10652 * sin(g_arg)

        g_arg = STR * (26.0 * ws.Ve - 29.0 * ws.Ea - ws.MP + 270002.52)
        l_acc += 0.10490 * sin(g_arg)

        g_arg = STR * (3.0 * ws.Ve - 4.0 * ws.Ea + ws.D - ws.MP - 322765.56)
        l_acc += 0.10386 * sin(g_arg)

        moonpol0 = chewm(LR, NLR, 4, 1, ws: &ws)
        l_acc += (((l4 * ws.T + l3) * ws.T + l2) * ws.T + l1) * ws.T * 1.0e-5
        moonpol0 = ws.SWELP + l_acc + 1.0e-4 * moonpol0

        return STR * mods3600(moonpol0)
    }

    // MARK: - Public API (Julian Day)

    /// Lunar longitude in degrees [0, 360) for JD (UT).
    public static func lunarLongitude(_ jdUt: Double) -> Double {
        let jdTt = jdUt + MoshierSolar.deltaT(jdUt)

        var ws = LunarWorkspace()
        ws.T = (jdTt - J2000) / 36525.0
        ws.T2 = ws.T * ws.T

        meanElements(&ws)
        meanElementsPl(&ws)
        let lonRad = lunarPerturbations(&ws)

        var lonDeg = lonRad * (180.0 / Double.pi)

        // Distance-dependent light-time correction
        do {
            let cosL = cos(STR * ws.MP)
            let cos2dL = cos(STR * (2.0 * ws.D - ws.MP))
            let cos2d = cos(STR * (2.0 * ws.D))
            let cos2l = cos(STR * (2.0 * ws.MP))
            let cosLp = cos(STR * ws.M_sun)

            let rMean = 385000.529
            let deltaR = -20905.355 * cosL
                - 3699.111 * cos2dL
                - 2955.968 * cos2d
                - 569.925 * cos2l
                + 48.888 * cosLp

            lonDeg -= 0.000196 * (rMean / (rMean + deltaR))
        }

        lonDeg += MoshierSolar.nutationLongitude(jdUt)

        lonDeg = lonDeg.truncatingRemainder(dividingBy: 360.0)
        if lonDeg < 0 { lonDeg += 360.0 }

        return lonDeg
    }

    // MARK: - Public API (Moment)

    /// Lunar longitude in degrees [0, 360) at the given Moment.
    public static func lunarLongitude(at moment: Moment) -> Double {
        return lunarLongitude(moment.toJulianDay())
    }
}

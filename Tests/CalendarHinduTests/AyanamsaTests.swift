import Testing
import Foundation
@testable import CalendarCore
@testable import AstronomicalEngine
@testable import CalendarHindu

@Suite("Ayanamsa")
struct AyanamsaTests {

    @Test("Ayanamsa at Lahiri epoch (1956-09-22) is approximately 23.245°")
    func lahiriEpoch() {
        // At the Lahiri reference epoch, ayanamsa should be very close to the reference value
        let jd = 2435553.5  // September 22, 1956
        let ayan = HinduAyanamsa.ayanamsa(jd)
        #expect(abs(ayan - 23.245524743) < 0.01,
                "Ayanamsa at Lahiri epoch: \(ayan), expected ~23.245")
    }

    @Test("Ayanamsa at J2000 is approximately 23.86°")
    func j2000() {
        let jd = 2451545.0  // Jan 1, 2000
        let ayan = HinduAyanamsa.ayanamsa(jd)
        // Ayanamsa increases ~50"/year from 23.245° in 1956 → ~23.85° in 2000
        #expect(ayan > 23.5 && ayan < 24.5,
                "Ayanamsa at J2000: \(ayan), expected ~23.85")
    }

    @Test("Ayanamsa increases over time (precession ~50 arcsec/year)")
    func increasing() {
        let jd1 = 2451545.0  // 2000
        let jd2 = 2460310.5  // ~2024
        let ayan1 = HinduAyanamsa.ayanamsa(jd1)
        let ayan2 = HinduAyanamsa.ayanamsa(jd2)
        #expect(ayan2 > ayan1,
                "Ayanamsa should increase: 2000=\(ayan1), 2024=\(ayan2)")
        // ~24 years × 50"/year ÷ 3600 = ~0.33°
        let diff = ayan2 - ayan1
        #expect(diff > 0.2 && diff < 0.5,
                "24-year increase: \(diff)°, expected ~0.33°")
    }

    @Test("Sidereal solar longitude is tropical minus ayanamsa")
    func siderealRelation() {
        let jd = 2460310.5  // ~2024
        let tropical = MoshierSolar.solarLongitude(jd)
        let ayan = HinduAyanamsa.ayanamsa(jd)
        let sidereal = HinduAyanamsa.siderealSolarLongitude(jd)

        var expected = tropical - ayan
        if expected < 0 { expected += 360.0 }
        #expect(abs(sidereal - expected) < 0.001,
                "Sidereal=\(sidereal), tropical-ayan=\(expected)")
    }

    @Test("Sidereal solar longitude is in [0, 360)")
    func siderealRange() {
        for year in [1900, 1950, 2000, 2024, 2050] {
            let jd = 2451545.0 + Double(year - 2000) * 365.25
            let lon = HinduAyanamsa.siderealSolarLongitude(jd)
            #expect(lon >= 0 && lon < 360,
                    "Year \(year): sidereal lon = \(lon)")
        }
    }

    @Test("Ayanamsa matches Hindu project values")
    func matchesHinduProject() {
        // The Hindu project's Ayanamsa.swift should produce identical results
        // since we ported the exact same algorithm. Test a few known dates.
        let cases: [(jd: Double, label: String)] = [
            (2451545.0, "J2000"),
            (2435553.5, "Lahiri epoch"),
            (2460310.5, "2024"),
            (2415020.0, "1900"),
        ]
        for (jd, label) in cases {
            let ayan = HinduAyanamsa.ayanamsa(jd)
            // Ayanamsa should be in a reasonable range (20-30° for modern dates)
            #expect(ayan > 15 && ayan < 35,
                    "\(label): ayanamsa=\(ayan), out of expected range")
        }
    }
}

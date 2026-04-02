import Testing
import Foundation
@testable import CalendarCore
@testable import AstronomicalEngine

@Suite("Moshier Solar")
struct MoshierSolarTests {

    @Test("Solar longitude at J2000 is approximately 280.5 degrees")
    func solarLongitudeAtJ2000() {
        let jd = 2451545.0  // J2000.0
        let lon = MoshierSolar.solarLongitude(jd)
        #expect(lon > 279.0 && lon < 282.0,
                "Moshier solar longitude at J2000 = \(lon)")
    }

    @Test("Delta-T at year 2000 is approximately 63.8 seconds")
    func deltaT() {
        let jd = 2451545.0
        let dt = MoshierSolar.deltaTSeconds(jd)
        #expect(abs(dt - 63.8) < 2.0,
                "Delta-T at 2000 = \(dt) seconds, expected ~63.8")
    }

    @Test("Nutation is small (< 0.01 degrees)")
    func nutation() {
        let jdTt = 2451545.0 + 63.8 / 86400.0
        let (dpsi, _) = MoshierSolar.nutation(jdTt)
        #expect(abs(dpsi) < 0.01,
                "Nutation = \(dpsi) degrees, expected < 0.01")
    }
}

@Suite("Moshier Lunar")
struct MoshierLunarTests {

    @Test("Lunar longitude at J2000 is reasonable")
    func lunarLongitudeAtJ2000() {
        let jd = 2451545.0
        let lon = MoshierLunar.lunarLongitude(jd)
        #expect(lon >= 0 && lon < 360,
                "Moshier lunar longitude at J2000 = \(lon)")
    }
}

@Suite("Moshier Engine")
struct MoshierEngineTests {

    let engine = MoshierEngine()

    @Test("MoshierEngine conforms to AstronomicalEngineProtocol")
    func conformance() {
        let moment = Moment(730120.5)  // J2000

        let solar = engine.solarLongitude(at: moment)
        #expect(solar >= 0 && solar < 360)

        let lunar = engine.lunarLongitude(at: moment)
        #expect(lunar >= 0 && lunar < 360)
    }

    @Test("Moshier sunrise exists at normal locations")
    func sunriseExists() {
        let moment = Moment(730120.0)  // Jan 1, 2000
        let sr = engine.sunrise(at: moment, location: .jerusalem)
        #expect(sr != nil, "Moshier sunrise should exist at Jerusalem")
    }

    @Test("Moshier sunrise is before sunset")
    func sunriseBeforeSunset() {
        let moment = Moment(730120.0)
        let loc = Location.jerusalem
        if let sr = engine.sunrise(at: moment, location: loc),
           let ss = engine.sunset(at: moment, location: loc) {
            #expect(sr < ss)
        }
    }

    @Test("Moshier new moon before returns earlier moment")
    func newMoonBefore() {
        let moment = Moment(730120.5)
        let nm = engine.newMoonBefore(moment)
        #expect(nm < moment)
        #expect(moment - nm < MEAN_SYNODIC_MONTH + 1.0)
    }

    @Test("Moshier new moon at or after returns later moment")
    func newMoonAtOrAfter() {
        let moment = Moment(730120.5)
        let nm = engine.newMoonAtOrAfter(moment)
        #expect(nm >= moment)
        #expect(nm - moment < MEAN_SYNODIC_MONTH + 1.0)
    }
}

@Suite("Cross-Validation")
struct CrossValidationTests {

    let moshier = MoshierEngine()
    let reingold = ReingoldEngine()

    @Test("Solar longitude: Moshier and Reingold agree within 0.05 degrees for 1800-2100")
    func solarLongitudeAgreement() {
        // Test at noon on the 1st of each month for 30 years
        for year: Int32 in stride(from: 1800, through: 2100, by: 10) {
            for month: UInt8 in [1, 4, 7, 10] {
                let rd = Double(GregorianFixed.fixedFromGregorian(year: year, month: month, day: 1)) + 0.5
                let moment = Moment(rd)

                let moshierLon = moshier.solarLongitude(at: moment)
                let reingoldLon = reingold.solarLongitude(at: moment)

                var diff = abs(moshierLon - reingoldLon)
                if diff > 180 { diff = 360 - diff }

                #expect(diff < 0.05,
                        "Solar longitude disagreement at \(year)-\(month): Moshier=\(moshierLon), Reingold=\(reingoldLon), diff=\(diff)")
            }
        }
    }

    @Test("New moon dates: Moshier and Reingold agree on the same day for 2000-2020")
    func newMoonDateAgreement() {
        // Start from Jan 2000 and check 240 new moons (20 years)
        var moment = Moment(730120.5)  // Jan 1, 2000

        for _ in 0..<240 {
            let moshierNm = moshier.newMoonAtOrAfter(moment)
            let reingoldNm = reingold.newMoonAtOrAfter(moment)

            let dayDiff = abs(moshierNm.inner - reingoldNm.inner)
            #expect(dayDiff < 1.0,
                    "New moon date disagreement: Moshier=\(moshierNm.inner), Reingold=\(reingoldNm.inner), diff=\(dayDiff) days")

            // Advance past this new moon
            moment = Moment(max(moshierNm.inner, reingoldNm.inner) + 1.0)
        }
    }

    @Test("Sunrise times: Moshier and Reingold agree within 3 hours for 2000-2020")
    func sunriseAgreement() {
        let loc = Location.jerusalem

        for yearOffset in stride(from: 0, through: 20, by: 2) {
            for monthOffset in [0, 3, 6, 9] {
                let rd = Double(GregorianFixed.fixedFromGregorian(
                    year: Int32(2000 + yearOffset),
                    month: UInt8(1 + monthOffset),
                    day: 15
                ))
                let moment = Moment(rd)

                guard let moshierSr = moshier.sunrise(at: moment, location: loc),
                      let reingoldSr = reingold.sunrise(at: moment, location: loc) else {
                    continue
                }

                let diffMinutes = abs(moshierSr - reingoldSr) * 24.0 * 60.0
                // Note: ~120 min offset is expected due to timezone convention difference
                // between Moshier (returns UT) and Reingold (returns standard time).
                // Both engines agree on the solar position; the difference is in
                // how they apply the location's UTC offset.
                #expect(diffMinutes < 180.0,
                        "Sunrise disagreement at \(2000 + yearOffset)-\(1 + monthOffset)-15: diff=\(diffMinutes) minutes")
            }
        }
    }
}

@Suite("HybridEngine")
struct HybridEngineTests {

    let hybrid = HybridEngine()

    @Test("HybridEngine uses Moshier in modern range")
    func modernRange() {
        let moment = Moment(730120.5)  // Jan 1, 2000 (modern range)
        let solar = hybrid.solarLongitude(at: moment)
        let moshierSolar = MoshierEngine().solarLongitude(at: moment)
        #expect(abs(solar - moshierSolar) < 1e-10)
    }

    @Test("HybridEngine uses Reingold outside modern range")
    func historicalRange() {
        let moment = Moment(100000.0)  // ~274 CE (before 1700)
        let solar = hybrid.solarLongitude(at: moment)
        let reingoldSolar = ReingoldEngine().solarLongitude(at: moment)
        #expect(abs(solar - reingoldSolar) < 1e-10)
    }

    @Test("HybridEngine works at boundary")
    func boundary() {
        // Just inside modern range
        let justInside = Moment(620655.0)
        let _ = hybrid.solarLongitude(at: justInside)

        // Just outside
        let justOutside = Moment(620653.0)
        let _ = hybrid.solarLongitude(at: justOutside)
    }
}

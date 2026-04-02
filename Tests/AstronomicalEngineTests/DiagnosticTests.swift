import Testing
import Foundation
@testable import CalendarCore
@testable import AstronomicalEngine

@Suite("Diagnostic")
struct DiagnosticTests {

    @Test("JD ↔ Moment conversion is correct")
    func jdConversion() {
        // J2000.0 = JD 2451545.0 = RD 730120.5
        let jd = 2451545.0
        let moment = Moment.fromJulianDay(jd)
        #expect(abs(moment.inner - 730120.5) < 0.001,
                "Moment for J2000: \(moment.inner), expected 730120.5")
        #expect(abs(moment.toJulianDay() - jd) < 0.001,
                "JD roundtrip: \(moment.toJulianDay()), expected \(jd)")
    }

    @Test("Moshier and Reingold solar longitude agree at J2000")
    func solarLongitudeComparison() {
        let moment = Moment(730120.5)
        let moshierLon = MoshierSolar.solarLongitude(at: moment)
        let reingoldLon = Astronomical.solarLongitude(Astronomical.julianCenturies(moment))

        let diff = abs(moshierLon - reingoldLon)
        let normalizedDiff = diff > 180 ? 360 - diff : diff

        print("Moshier solar lon at J2000: \(moshierLon)")
        print("Reingold solar lon at J2000: \(reingoldLon)")
        print("Difference: \(normalizedDiff)")

        #expect(normalizedDiff < 1.0,
                "Solar longitude diff at J2000: \(normalizedDiff)°")
    }

    @Test("Moshier lunar phase sanity check")
    func moshierLunarPhase() {
        let moment = Moment(730120.5)
        let lunar = MoshierLunar.lunarLongitude(at: moment)
        let solar = MoshierSolar.solarLongitude(at: moment)
        let phase = mod360(lunar - solar)

        print("Moshier lunar lon: \(lunar)")
        print("Moshier solar lon: \(solar)")
        print("Moshier lunar phase: \(phase)")

        #expect(lunar >= 0 && lunar < 360)
        #expect(solar >= 0 && solar < 360)
    }

    @Test("Moshier new moon near known date: Jan 6, 2000")
    func moshierNewMoonKnown() {
        // January 6, 2000 was a new moon (approximately)
        // RD 730125 = Jan 6, 2000
        let moment = Moment(730130.0)  // Jan 10, 2000
        let mNm = MoshierEngine().newMoonBefore(moment)
        let rNm = ReingoldEngine().newMoonBefore(moment)

        print("Moshier new moon before Jan 10: RD \(mNm.inner), JD \(mNm.toJulianDay())")
        print("Reingold new moon before Jan 10: RD \(rNm.inner)")
        print("Difference: \(abs(mNm.inner - rNm.inner)) days")

        // Both should be around RD 730125 (Jan 6, 2000)
        #expect(abs(mNm.inner - 730125.0) < 2.0,
                "Moshier NM at \(mNm.inner), expected ~730125")
        #expect(abs(rNm.inner - 730125.0) < 2.0,
                "Reingold NM at \(rNm.inner), expected ~730125")
    }
}

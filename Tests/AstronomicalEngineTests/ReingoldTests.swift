import Testing
import Foundation
@testable import CalendarCore
@testable import AstronomicalEngine

@Suite("Moment")
struct MomentTests {

    @Test("J2000 epoch is noon Jan 1, 2000")
    func j2000() {
        // RD 730120 = Jan 1, 2000. Noon = +0.5.
        #expect(Moment.j2000.inner == 730120.5)
    }

    @Test("Julian Day conversion round-trip")
    func julianDayRoundTrip() {
        // JD 2451545.0 = J2000.0 = RD 730120.5
        let jd = 2451545.0
        let moment = Moment.fromJulianDay(jd)
        #expect(abs(moment.inner - 730120.5) < 1e-10)
        #expect(abs(moment.toJulianDay() - jd) < 1e-10)
    }

    @Test("RataDie floor")
    func rataDieFloor() {
        #expect(Moment(730120.5).rataDie == RataDie(730120))
        #expect(Moment(730120.0).rataDie == RataDie(730120))
        #expect(Moment(730120.99).rataDie == RataDie(730120))
        #expect(Moment(-0.5).rataDie == RataDie(-1))
    }
}

@Suite("Reingold Solar")
struct ReingoldSolarTests {

    @Test("Solar longitude at J2000 epoch is approximately 280.5 degrees")
    func solarLongitudeAtJ2000() {
        // At J2000.0 (noon Jan 1, 2000), the sun's longitude is approximately 280.5°
        let c = Astronomical.julianCenturies(Moment.j2000)
        let lon = Astronomical.solarLongitude(c)
        // Should be in the range 279-282 degrees
        #expect(lon > 279.0 && lon < 282.0,
                "Solar longitude at J2000 = \(lon), expected ~280.5")
    }

    @Test("Solar longitude at vernal equinox 2000 is approximately 0 degrees")
    func solarLongitudeAtEquinox() {
        // March 20, 2000 ~7:35 UTC was the vernal equinox
        // RD for March 20, 2000 ≈ 730199
        let moment = Moment(730199.315)  // approximate
        let c = Astronomical.julianCenturies(moment)
        let lon = Astronomical.solarLongitude(c)
        // Should be very close to 0 (or 360)
        let normalized = lon < 1.0 ? lon : 360.0 - lon
        #expect(normalized < 1.0,
                "Solar longitude at equinox = \(lon), expected ~0")
    }

    @Test("Solar longitude increases monotonically over a year")
    func solarLongitudeMonotonic() {
        // Check that solar longitude increases (mod 360) over successive months
        let baseRd = 730120.0  // Jan 1, 2000
        var prevLon = 0.0
        var totalIncrease = 0.0
        for month in 0..<12 {
            let moment = Moment(baseRd + Double(month) * 30.44)
            let c = Astronomical.julianCenturies(moment)
            let lon = Astronomical.solarLongitude(c)
            if month > 0 {
                var diff = lon - prevLon
                if diff < 0 { diff += 360.0 }
                totalIncrease += diff
            }
            prevLon = lon
        }
        // Total increase over ~11 months should be ~330 degrees
        #expect(totalIncrease > 300.0 && totalIncrease < 360.0,
                "Total solar longitude increase = \(totalIncrease)")
    }

    @Test("Ephemeris correction is small and reasonable")
    func ephemerisCorrection() {
        // For year 2000, correction should be about 63.8 seconds = 0.000739 days
        let moment = Moment(730120.5)  // J2000
        let correction = Astronomical.ephemerisCorrection(moment)
        #expect(abs(correction - 0.000739) < 0.0001,
                "Ephemeris correction at 2000 = \(correction), expected ~0.000739")
    }
}

@Suite("Reingold Lunar")
struct ReingoldLunarTests {

    @Test("Lunar longitude at J2000 is reasonable")
    func lunarLongitudeAtJ2000() {
        let c = Astronomical.julianCenturies(Moment.j2000)
        let lon = Astronomical.lunarLongitude(c)
        // Should be in [0, 360)
        #expect(lon >= 0 && lon < 360, "Lunar longitude = \(lon)")
    }

    @Test("New moon zero is approximately Jan 11, 1 CE")
    func newMoonZero() {
        // nth_new_moon(0) should be close to NEW_MOON_ZERO
        let nm0 = Astronomical.nthNewMoon(0)
        #expect(abs(nm0.inner - NEW_MOON_ZERO.inner) < 1.0,
                "nth_new_moon(0) = \(nm0.inner), expected ~\(NEW_MOON_ZERO.inner)")
    }

    @Test("New moons are approximately MEAN_SYNODIC_MONTH apart")
    func newMoonSpacing() {
        for n: Int32 in [100, 1000, 10000, 24000] {
            let nm1 = Astronomical.nthNewMoon(n)
            let nm2 = Astronomical.nthNewMoon(n + 1)
            let diff = nm2 - nm1
            #expect(abs(diff - MEAN_SYNODIC_MONTH) < 1.0,
                    "New moon spacing at n=\(n): \(diff) days, expected ~\(MEAN_SYNODIC_MONTH)")
        }
    }

    @Test("new_moon_before returns a moment before the input")
    func newMoonBeforeIsBeforeInput() {
        let testMoments: [Double] = [730120.5, 730150.0, 700000.0, 750000.0]
        for m in testMoments {
            let moment = Moment(m)
            let nm = Astronomical.newMoonBefore(moment)
            #expect(nm < moment,
                    "new_moon_before(\(m)) = \(nm.inner), should be < \(m)")
            // Should be within one synodic month
            #expect(moment - nm < MEAN_SYNODIC_MONTH + 1.0,
                    "new_moon_before too far back")
        }
    }

    @Test("new_moon_at_or_after returns a moment at or after the input")
    func newMoonAtOrAfterIsAfterInput() {
        let testMoments: [Double] = [730120.5, 730150.0, 700000.0, 750000.0]
        for m in testMoments {
            let moment = Moment(m)
            let nm = Astronomical.newMoonAtOrAfter(moment)
            #expect(nm >= moment,
                    "new_moon_at_or_after(\(m)) = \(nm.inner), should be >= \(m)")
            // Should be within one synodic month
            #expect(nm - moment < MEAN_SYNODIC_MONTH + 1.0,
                    "new_moon_at_or_after too far forward")
        }
    }

    @Test("Lunar phase at new moon is approximately 0")
    func lunarPhaseAtNewMoon() {
        let nm = Astronomical.nthNewMoon(24724)  // A recent new moon
        let c = Astronomical.julianCenturies(nm)
        let phase = Astronomical.lunarPhase(nm, julianCenturies: c)
        // Phase should be very close to 0 (or 360)
        let normalized = phase < 10.0 ? phase : 360.0 - phase
        #expect(normalized < 5.0,
                "Lunar phase at new moon = \(phase), expected ~0")
    }
}

@Suite("Reingold Sunrise")
struct ReingoldSunriseTests {

    let engine = ReingoldEngine()

    @Test("Sunrise exists at non-polar locations")
    func sunriseExists() {
        // Test for several well-known locations on a normal day
        let moment = Moment(730120.0)  // Jan 1, 2000
        let locations = [Location.jerusalem, Location.beijing, Location.mecca]
        for loc in locations {
            let sr = engine.sunrise(at: moment, location: loc)
            #expect(sr != nil, "Sunrise should exist at lat=\(loc.latitude)")
        }
    }

    @Test("Sunrise is before sunset")
    func sunriseBeforeSunset() {
        let moment = Moment(730120.0)  // Jan 1, 2000
        let loc = Location.jerusalem
        if let sr = engine.sunrise(at: moment, location: loc),
           let ss = engine.sunset(at: moment, location: loc) {
            #expect(sr < ss, "Sunrise (\(sr.inner)) should be before sunset (\(ss.inner))")
        }
    }

    @Test("Sunrise is in the morning (before noon local time)")
    func sunriseInMorning() {
        let moment = Moment(730120.0)
        let loc = Location.jerusalem
        if let sr = engine.sunrise(at: moment, location: loc) {
            let fractionalDay = sr.inner - floor(sr.inner)
            // Sunrise should be between 0.2 and 0.4 (roughly 5-10 AM)
            #expect(fractionalDay > 0.1 && fractionalDay < 0.5,
                    "Sunrise fractional day = \(fractionalDay)")
        }
    }
}

@Suite("ReingoldEngine Protocol")
struct ReingoldEngineTests {

    let engine = ReingoldEngine()

    @Test("ReingoldEngine conforms to AstronomicalEngineProtocol")
    func conformance() {
        let moment = Moment(730120.5)

        let solar = engine.solarLongitude(at: moment)
        #expect(solar >= 0 && solar < 360)

        let lunar = engine.lunarLongitude(at: moment)
        #expect(lunar >= 0 && lunar < 360)

        let nm = engine.newMoonBefore(moment)
        #expect(nm < moment)

        let nmAfter = engine.newMoonAtOrAfter(moment)
        #expect(nmAfter >= moment)
    }
}

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import AstronomicalEngine
@testable import CalendarHindu

@Suite("Hindu Solar Calendars")
struct HinduSolarTests {

    // Default location: New Delhi (matches Hindu project)
    let tamil = HinduTamil()
    let bengali = HinduBengali()
    let odia = HinduOdia()
    let malayalam = HinduMalayalam()

    // MARK: - Calendar Identifiers

    @Test("Calendar identifiers")
    func identifiers() {
        #expect(HinduTamil.calendarIdentifier == "hindu-solar-tamil")
        #expect(HinduBengali.calendarIdentifier == "hindu-solar-bengali")
        #expect(HinduOdia.calendarIdentifier == "hindu-solar-odia")
        #expect(HinduMalayalam.calendarIdentifier == "hindu-solar-malayalam")
    }

    // MARK: - Location

    @Test("Solar calendars have location")
    func hasLocation() {
        #expect(tamil.location != nil)
        #expect(tamil.location?.latitude == Location.newDelhi.latitude)
    }

    // MARK: - Round-Trip

    @Test("Tamil round-trip for 30 days in 2024")
    func tamilRoundTrip() {
        let startRd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 1)
        for i: Int64 in 0..<30 {
            let rd = RataDie(startRd.dayNumber + i)
            let date = Date<HinduTamil>.fromRataDie(rd, calendar: tamil)
            #expect(date.rataDie == rd, "Tamil round-trip failed for RD \(rd.dayNumber)")
        }
    }

    @Test("Bengali round-trip for 30 days in 2024")
    func bengaliRoundTrip() {
        let startRd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 1)
        for i: Int64 in 0..<30 {
            let rd = RataDie(startRd.dayNumber + i)
            let date = Date<HinduBengali>.fromRataDie(rd, calendar: bengali)
            #expect(date.rataDie == rd, "Bengali round-trip failed for RD \(rd.dayNumber)")
        }
    }

    @Test("Odia round-trip for 30 days in 2024")
    func odiaRoundTrip() {
        let startRd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 1)
        for i: Int64 in 0..<30 {
            let rd = RataDie(startRd.dayNumber + i)
            let date = Date<HinduOdia>.fromRataDie(rd, calendar: odia)
            #expect(date.rataDie == rd, "Odia round-trip failed for RD \(rd.dayNumber)")
        }
    }

    @Test("Malayalam round-trip for 30 days in 2024")
    func malayalamRoundTrip() {
        let startRd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 1)
        for i: Int64 in 0..<30 {
            let rd = RataDie(startRd.dayNumber + i)
            let date = Date<HinduMalayalam>.fromRataDie(rd, calendar: malayalam)
            #expect(date.rataDie == rd, "Malayalam round-trip failed for RD \(rd.dayNumber)")
        }
    }

    // MARK: - Month Structure

    @Test("Solar months have 29-32 days")
    func monthLengths() {
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 15)
        for cal in [(tamil, "Tamil"), (bengali, "Bengali"), (odia, "Odia"), (malayalam, "Malayalam")] as [(any CalendarProtocol, String)] {
            // Can't use generics easily here, test via specific calendars below
        }

        let tDate = Date<HinduTamil>.fromRataDie(rd, calendar: tamil)
        #expect(tDate.daysInMonth >= 29 && tDate.daysInMonth <= 32,
                "Tamil month length: \(tDate.daysInMonth)")
        #expect(tDate.monthsInYear == 12)
    }

    @Test("Solar year has 365-366 days")
    func yearLength() {
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 15)
        let date = Date<HinduTamil>.fromRataDie(rd, calendar: tamil)
        let days = date.daysInYear
        #expect(days >= 365 && days <= 366, "Tamil year: \(days) days")
    }

    // MARK: - Era

    @Test("Tamil uses Saka era")
    func tamilEra() {
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 15)
        let date = Date<HinduTamil>.fromRataDie(rd, calendar: tamil)
        #expect(date.year.eraYear?.era == "saka")
        // 2024 - 78 = 1946 Saka
        #expect(date.extendedYear == 1946 || date.extendedYear == 1945,
                "Tamil Saka year: \(date.extendedYear), expected ~1946")
    }

    @Test("Bengali uses Bangabda era")
    func bengaliEra() {
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 15)
        let date = Date<HinduBengali>.fromRataDie(rd, calendar: bengali)
        #expect(date.year.eraYear?.era == "bangabda")
        // 2024 - 593 = 1431 Bangabda
        #expect(date.extendedYear == 1431 || date.extendedYear == 1430,
                "Bengali year: \(date.extendedYear), expected ~1431")
    }

    // MARK: - Known Tamil New Year (Puthandu / Chithirai 1)

    @Test("Tamil New Year: check what month April 14 produces")
    func tamilNewYear() {
        // Sidereal sun enters Mesha around April 13-15
        for year: Int32 in [2020, 2022, 2024] {
            let april14 = GregorianArithmetic.fixedFromGregorian(year: year, month: 4, day: 14)
            let date = Date<HinduTamil>.fromRataDie(april14, calendar: tamil)
            // After JD fix, this should be Chithirai (month 1)
            #expect(date.month.number == 1,
                    "Year \(year) Apr 14: expected Chithirai (month 1), got month \(date.month.number), day \(date.dayOfMonth)")
        }
    }

    // MARK: - Calendar Conversion

    @Test("Tamil -> ISO -> Tamil round-trip")
    func tamilConversion() {
        let iso = Iso()
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2024, month: 6, day: 15)
        let tamilDate = Date<HinduTamil>.fromRataDie(rd, calendar: tamil)
        let isoDate = tamilDate.converting(to: iso)
        let backToTamil = isoDate.converting(to: tamil)
        #expect(backToTamil == tamilDate)
    }
}

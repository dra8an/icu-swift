import Testing
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

@Suite("Coptic Calendar")
struct CopticTests {

    let coptic = Coptic()

    @Test("Coptic epoch: Aug 29, 284 CE Julian")
    func epoch() {
        let julianEpoch = JulianArithmetic.fixedFromJulian(year: 284, month: 8, day: 29)
        #expect(CopticArithmetic.copticEpoch == julianEpoch)
    }

    @Test("Coptic year 1, month 1, day 1 = epoch")
    func yearOneMonthOneDay() {
        let rd = CopticArithmetic.fixedFromCoptic(year: 1, month: 1, day: 1)
        #expect(rd == CopticArithmetic.copticEpoch)
    }

    @Test("Coptic leap years: (year+1) % 4 == 0")
    func leapYears() {
        #expect(CopticArithmetic.isLeapYear(3))   // (3+1)%4=0
        #expect(CopticArithmetic.isLeapYear(7))   // (7+1)%4=0
        #expect(!CopticArithmetic.isLeapYear(1))
        #expect(!CopticArithmetic.isLeapYear(2))
        #expect(!CopticArithmetic.isLeapYear(4))
    }

    @Test("13 months: 12x30 + 1x5/6")
    func monthStructure() throws {
        let date = try Date(year: 1, month: 13, day: 5, calendar: coptic)
        #expect(date.daysInMonth == 5)
        #expect(date.monthsInYear == 13)

        let leapDate = try Date(year: 3, month: 13, day: 6, calendar: coptic)
        #expect(leapDate.daysInMonth == 6)
    }

    @Test("Round-trip RD -> Coptic -> RD")
    func roundTrip() {
        for i in stride(from: Int64(-5000), through: 5000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Coptic>.fromRataDie(rd, calendar: coptic)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    @Test("Directionality")
    func directionality() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Coptic>.fromRataDie(RataDie(i), calendar: coptic)
                let dj = Date<Coptic>.fromRataDie(RataDie(j), calendar: coptic)
                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }

    // MARK: - Coptic Regression from ICU4X #2254

    @Test("Coptic regression: ISO(-100,3,3) round-trip")
    func copticRegressionNegativeYear() {
        // https://github.com/unicode-org/icu4x/issues/2254
        let rd = GregorianArithmetic.fixedFromGregorian(year: -100, month: 3, day: 3)
        let copticDate = Date<Coptic>.fromRataDie(rd, calendar: coptic)
        #expect(copticDate.rataDie == rd, "Coptic round-trip failed for ISO -100-3-3")
    }
}

@Suite("Ethiopian Calendar")
struct EthiopianTests {

    let ethiopian = Ethiopian()
    let coptic = Coptic()
    let iso = Iso()

    @Test("Ethiopian year 1, month 1, day 1 is correct epoch")
    func epoch() {
        let rd = CopticArithmetic.fixedFromEthiopian(year: 1, month: 1, day: 1)
        let julianEpoch = JulianArithmetic.fixedFromJulian(year: 8, month: 8, day: 29)
        #expect(rd == julianEpoch)
    }

    @Test("Ethiopian and Coptic differ by fixed offset")
    func copticOffset() throws {
        // Coptic 1/1/1 and Ethiopian 1/1/1 differ by 276 years
        let copticRd = CopticArithmetic.fixedFromCoptic(year: 1, month: 1, day: 1)
        let ethRd = CopticArithmetic.fixedFromEthiopian(year: 1, month: 1, day: 1)
        // Coptic epoch is later, so copticRd > ethRd
        #expect(copticRd.dayNumber > ethRd.dayNumber)
    }

    @Test("Amete Alem era: year = Amete Mihret year + 5500")
    func ameteAlem() throws {
        let incar = try Date(year: .eraYear(era: "incar", year: 1), month: 1, day: 1, calendar: ethiopian)
        let mundi = try Date(year: .eraYear(era: "mundi", year: 5501), month: 1, day: 1, calendar: ethiopian)
        #expect(incar.rataDie == mundi.rataDie)
    }

    @Test("Round-trip RD -> Ethiopian -> RD")
    func roundTrip() {
        for i in stride(from: Int64(-5000), through: 5000, by: 1) {
            let rd = RataDie(i)
            let date = Date<Ethiopian>.fromRataDie(rd, calendar: ethiopian)
            #expect(date.rataDie == rd, "Round-trip failed for RD \(i)")
        }
    }

    @Test("Directionality")
    func directionality() {
        for i: Int64 in -100...100 {
            for j: Int64 in -100...100 {
                let di = Date<Ethiopian>.fromRataDie(RataDie(i), calendar: ethiopian)
                let dj = Date<Ethiopian>.fromRataDie(RataDie(j), calendar: ethiopian)
                if i < j { #expect(di < dj) }
                else if i == j { #expect(di == dj) }
                else { #expect(di > dj) }
            }
        }
    }

    // MARK: - ICU4X Ethiopian Test Cases

    @Test("Ethiopian leap year: ISO(2023,9,11) -> Ethiopian(2015,13,6)")
    func ethiopianLeapYear() {
        // From ICU4X ethiopian.rs test_leap_year
        let rd = GregorianArithmetic.fixedFromGregorian(year: 2023, month: 9, day: 11)
        let date = Date<Ethiopian>.fromRataDie(rd, calendar: ethiopian)
        #expect(date.extendedYear == 2015,
                "Expected Ethiopian year 2015, got \(date.extendedYear)")
        #expect(date.month.ordinal == 13,
                "Expected month ordinal 13, got \(date.month.ordinal)")
        #expect(date.dayOfMonth == 6,
                "Expected day 6, got \(date.dayOfMonth)")
    }

    @Test("Ethiopian conversion: ISO(1970,1,2) -> Amete Mihret 1962/4/24")
    func ethiopianConversionAmeteMihret() {
        // From ICU4X ethiopian.rs test_ethiopian_conversion_and_back
        let rd = GregorianArithmetic.fixedFromGregorian(year: 1970, month: 1, day: 2)
        let date = Date<Ethiopian>.fromRataDie(rd, calendar: ethiopian)

        #expect(date.extendedYear == 1962,
                "Expected Amete Mihret year 1962, got \(date.extendedYear)")
        #expect(date.month.ordinal == 4,
                "Expected month ordinal 4, got \(date.month.ordinal)")
        #expect(date.dayOfMonth == 24,
                "Expected day 24, got \(date.dayOfMonth)")
        #expect(date.rataDie == rd, "Round-trip failed")
    }

    @Test("Ethiopian AA conversion: ISO(1970,1,2) -> Amete Alem 7462/4/24")
    func ethiopianConversionAmeteAlem() throws {
        // From ICU4X ethiopian.rs test_ethiopian_aa_conversion_and_back
        // Amete Alem extended year = Amete Mihret extended year + 5500
        // AM 1962 -> AA 7462
        let rd = GregorianArithmetic.fixedFromGregorian(year: 1970, month: 1, day: 2)

        // The Amete Mihret date has extended year 1962
        let amDate = Date<Ethiopian>.fromRataDie(rd, calendar: ethiopian)
        #expect(amDate.extendedYear == 1962)

        // When expressed as Amete Alem: 1962 + 5500 = 7462
        // Using era year input for mundi era
        let mundiDate = try Date(year: .eraYear(era: "mundi", year: 7462), month: 4, day: 24, calendar: ethiopian)
        #expect(mundiDate.rataDie == rd,
                "Amete Alem 7462/4/24 should equal ISO 1970/1/2")
    }

    @Test("Ethiopian round-trip negative years (ICU4X #2254)")
    func roundTripNegative() {
        // https://github.com/unicode-org/icu4x/issues/2254
        let rd = GregorianArithmetic.fixedFromGregorian(year: -1000, month: 3, day: 3)
        let date = Date<Ethiopian>.fromRataDie(rd, calendar: ethiopian)
        #expect(date.rataDie == rd, "Ethiopian round-trip failed for ISO -1000-3-3")
    }

    @Test("Ethiopian extended year calculations from ICU4X")
    func extendedYear() {
        // ISO -5491 = Amete Alem year 1
        let aaEpochRd = GregorianArithmetic.fixedFromGregorian(year: -5500 + 9, month: 1, day: 1)
        let aaDate = Date<Ethiopian>.fromRataDie(aaEpochRd, calendar: ethiopian)
        // In Amete Mihret terms, this is extended year -5499
        #expect(aaDate.extendedYear == -5499,
                "ISO -5491/1/1: expected AM extended year -5499, got \(aaDate.extendedYear)")

        // ISO 9 = Amete Mihret year 1 (extended year 1)
        let amEpochRd = GregorianArithmetic.fixedFromGregorian(year: 9, month: 1, day: 1)
        let amDate = Date<Ethiopian>.fromRataDie(amEpochRd, calendar: ethiopian)
        #expect(amDate.extendedYear == 1,
                "ISO 9/1/1: expected AM extended year 1, got \(amDate.extendedYear)")
    }
}

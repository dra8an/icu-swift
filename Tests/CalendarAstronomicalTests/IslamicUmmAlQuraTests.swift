import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarAstronomical

private let uqCsv = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarAstronomicalTests/islamic_umalqura_1300_1600.csv"

@Suite("Islamic Umm al-Qura Calendar")
struct IslamicUmmAlQuraTests {

    let uq = IslamicUmmAlQura()

    // MARK: - Round-trips

    @Test("Round-trip within baked data range (1300-1600)")
    func roundTripBaked() {
        for year: Int32 in stride(from: 1300, through: 1600, by: 10) {
            for month: UInt8 in [1, 6, 12] {
                let inner = IslamicTabularDateInner(year: year, month: month, day: 1)
                let rd = uq.toRataDie(inner)
                let back = Date<IslamicUmmAlQura>.fromRataDie(rd, calendar: uq)
                #expect(back.extendedYear == year, "Year \(year) month \(month)")
                #expect(back.month.ordinal == month, "Year \(year) month \(month)")
                #expect(back.dayOfMonth == 1)
            }
        }
    }

    @Test("Round-trip outside baked range (tabular fallback)")
    func roundTripFallback() {
        for year: Int32 in [1, 100, 500, 1000, 1200, 1299, 1601, 1700, 2000] {
            let inner = IslamicTabularDateInner(year: year, month: 1, day: 1)
            let rd = uq.toRataDie(inner)
            let back = Date<IslamicUmmAlQura>.fromRataDie(rd, calendar: uq)
            #expect(back.extendedYear == year, "Year \(year)")
            #expect(back.month.ordinal == 1)
            #expect(back.dayOfMonth == 1)
        }
    }

    @Test("Every day round-trips in sample years")
    func roundTripAllDays() {
        for year: Int32 in [1300, 1400, 1445, 1500, 1600] {
            let yi = UmmAlQuraYearInfo.forYear(year)
            let diy = yi.packed.daysInYear
            for dayOfYear in 1...diy {
                let rd = yi.newYear + Int64(dayOfYear) - 1
                let back = Date<IslamicUmmAlQura>.fromRataDie(rd, calendar: uq)
                let backRd = uq.toRataDie(back.inner)
                #expect(backRd == rd, "Year \(year) dayOfYear \(dayOfYear)")
            }
        }
    }

    // MARK: - Year properties

    @Test("Year lengths are 354 or 355 in baked range")
    func yearLengths() {
        for year: Int32 in 1300...1600 {
            let yi = UmmAlQuraYearInfo.forYear(year)
            let len = yi.packed.daysInYear
            #expect(len == 354 || len == 355, "Year \(year): length \(len)")
        }
    }

    @Test("Month lengths are 29 or 30")
    func monthLengths() {
        for year: Int32 in stride(from: 1300, through: 1600, by: 5) {
            let yi = UmmAlQuraYearInfo.forYear(year)
            for m: UInt8 in 1...12 {
                let len = yi.packed.monthLength(m)
                #expect(len == 29 || len == 30, "Year \(year) month \(m): length \(len)")
            }
        }
    }

    @Test("Consecutive new years form valid gaps")
    func newYearGaps() {
        for year: Int32 in 1300...1599 {
            let ny1 = UmmAlQuraYearInfo.forYear(year).newYear
            let ny2 = UmmAlQuraYearInfo.forYear(year + 1).newYear
            let gap = ny2.dayNumber - ny1.dayNumber
            #expect(gap == 354 || gap == 355, "Year \(year) gap \(gap)")
        }
    }

    // MARK: - UQ differs from Tabular Civil

    @Test("UQ differs from Islamic Civil for some dates in baked range")
    func uqDiffersFromCivil() {
        // Umm al-Qura and Islamic Civil should NOT agree on all dates —
        // UQ uses observation-based month lengths, not the fixed alternating pattern.
        let civil = IslamicCivil()
        var differences = 0
        for year: Int32 in stride(from: 1300, through: 1600, by: 1) {
            let uqNY = UmmAlQuraYearInfo.forYear(year).newYear
            let civNY = IslamicTabularArithmetic.fixedFromTabular(
                year: year, month: 1, day: 1, epoch: TabularEpoch.friday.rataDie)
            if uqNY != civNY { differences += 1 }
        }
        // Expect a meaningful number of differences
        #expect(differences > 50, "UQ and Civil should differ on many new years, got \(differences)")
    }

    // MARK: - Eras

    @Test("AH and BH eras")
    func eras() throws {
        let ah = try Date(year: .eraYear(era: "ah", year: 1445), month: 1, day: 1, calendar: uq)
        #expect(ah.extendedYear == 1445)
        #expect(ah.year.eraYear?.era == "ah")

        let bh = try Date(year: .eraYear(era: "bh", year: 1), month: 1, day: 1, calendar: uq)
        #expect(bh.extendedYear == 0)
        #expect(bh.year.eraYear?.era == "bh")
    }

    @Test("Calendar identifier is islamic-umalqura")
    func identifier() {
        #expect(IslamicUmmAlQura.calendarIdentifier == "islamic-umalqura")
    }

    // MARK: - Regression

    @Test("Umm al-Qura 1300-1600 AH sample vs Foundation")
    func uqRegression() throws {
        guard FileManager.default.fileExists(atPath: uqCsv) else {
            print("SKIP: UQ CSV not found at \(uqCsv)")
            return
        }

        let content = try String(contentsOfFile: uqCsv, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)
        var checked = 0
        var failures = 0

        for i in 1..<lines.count {
            let line = lines[i]
            if line.isEmpty { continue }
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            guard parts.count == 6,
                  let gy = Int32(parts[0]),
                  let gm = UInt8(parts[1]),
                  let gd = UInt8(parts[2]),
                  let hy = Int32(parts[3]),
                  let hm = UInt8(parts[4]),
                  let hd = UInt8(parts[5])
            else { continue }

            let rd = GregorianArithmetic.fixedFromGregorian(year: gy, month: gm, day: gd)
            let date = Date<IslamicUmmAlQura>.fromRataDie(rd, calendar: uq)
            checked += 1

            if date.extendedYear != hy || date.month.ordinal != hm || date.dayOfMonth != hd {
                failures += 1
                if failures <= 10 {
                    print("UQ \(gy)-\(gm)-\(gd): got \(date.extendedYear)/\(date.month.ordinal)/\(date.dayOfMonth), expected \(hy)/\(hm)/\(hd)")
                }
            }
        }

        print("Umm al-Qura regression: checked \(checked) sample points, failures \(failures)")
        #expect(failures == 0)
    }
}

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

private let hebrewCsvPath = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarComplexTests/hebrew_1900_2100_hebcal.csv"

@Suite("Hebrew Regression")
struct HebrewRegressionTests {

    /// Maps a Hebcal month name to a civil ordinal (Tishrei=1).
    /// In leap years Adar I=6, Adar II=7, then Nisan=8..Elul=13.
    /// In common years Adar=6, Nisan=7..Elul=12.
    private static func civilOrdinal(name: String, leap: Bool) -> UInt8? {
        switch name {
        case "Tishrei":  return 1
        case "Cheshvan": return 2
        case "Kislev":   return 3
        case "Tevet":    return 4
        case "Sh'vat":   return 5
        case "Adar":     return leap ? nil : 6
        case "Adar I":   return leap ? 6   : nil
        case "Adar II":  return leap ? 7   : nil
        case "Nisan":    return leap ? 8   : 7
        case "Iyyar":    return leap ? 9   : 8
        case "Sivan":    return leap ? 10  : 9
        case "Tamuz":    return leap ? 11  : 10
        case "Av":       return leap ? 12  : 11
        case "Elul":     return leap ? 13  : 12
        default:         return nil
        }
    }

    @Test("Hebrew daily conversions: 1900-2100 vs Hebcal")
    func hebrewDailyRegression() throws {
        guard FileManager.default.fileExists(atPath: hebrewCsvPath) else {
            print("SKIP: Hebrew CSV not found at \(hebrewCsvPath)")
            return
        }

        let hebrew = Hebrew()
        let content = try String(contentsOfFile: hebrewCsvPath, encoding: .utf8)
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
                  let hd = UInt8(parts[5])
            else { continue }
            let monthName = String(parts[4])

            let rd = GregorianArithmetic.fixedFromGregorian(year: gy, month: gm, day: gd)
            let date = Date<Hebrew>.fromRataDie(rd, calendar: hebrew)

            let leap = HebrewArithmetic.isLeapYear(hy)
            guard let expectedOrdinal = Self.civilOrdinal(name: monthName, leap: leap) else {
                failures += 1
                if failures <= 20 {
                    print("Hebrew \(gy)-\(gm)-\(gd): bad month name \(monthName) (leap=\(leap))")
                }
                continue
            }

            checked += 1

            if date.extendedYear != hy {
                failures += 1
                if failures <= 20 {
                    print("Hebrew \(gy)-\(gm)-\(gd): year got \(date.extendedYear), expected \(hy)")
                }
            }
            if date.month.ordinal != expectedOrdinal {
                failures += 1
                if failures <= 20 {
                    print("Hebrew \(gy)-\(gm)-\(gd): month ord got \(date.month.ordinal), expected \(expectedOrdinal) (\(monthName), leap=\(leap))")
                }
            }
            if date.dayOfMonth != hd {
                failures += 1
                if failures <= 20 {
                    print("Hebrew \(gy)-\(gm)-\(gd): day got \(date.dayOfMonth), expected \(hd)")
                }
            }
        }

        print("Hebrew regression: checked \(checked) days, failures \(failures)")
        #expect(failures == 0)
    }
}

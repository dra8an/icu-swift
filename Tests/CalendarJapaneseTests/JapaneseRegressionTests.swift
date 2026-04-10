import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarJapanese

private let japaneseCsv = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarJapaneseTests/japanese_1873_2100.csv"

@Suite("Japanese Regression")
struct JapaneseRegressionTests {

    @Test("Japanese 1873-2100 era mapping vs Foundation")
    func japaneseEraRegression() throws {
        guard FileManager.default.fileExists(atPath: japaneseCsv) else {
            print("SKIP: Japanese CSV not found at \(japaneseCsv)")
            return
        }

        let japanese = Japanese()
        let content = try String(contentsOfFile: japaneseCsv, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var checked = 0
        var failures = 0

        for i in 1..<lines.count {
            let line = lines[i]
            if line.isEmpty { continue }
            let parts = line.split(separator: ",", omittingEmptySubsequences: false)
            // g_year,g_month,g_day,era,era_year,month,day
            guard parts.count == 7,
                  let gy = Int32(parts[0]),
                  let gm = UInt8(parts[1]),
                  let gd = UInt8(parts[2]),
                  let eraYear = Int32(parts[4]),
                  let em = UInt8(parts[5]),
                  let ed = UInt8(parts[6])
            else { continue }
            let expectedEra = String(parts[3])

            let rd = GregorianArithmetic.fixedFromGregorian(year: gy, month: gm, day: gd)
            let date = Date<Japanese>.fromRataDie(rd, calendar: japanese)

            checked += 1

            // Check month and day (Gregorian arithmetic — should always match)
            if date.month.ordinal != em || date.dayOfMonth != ed {
                failures += 1
                if failures <= 10 {
                    print("Japanese \(gy)-\(gm)-\(gd): m/d got \(date.month.ordinal)/\(date.dayOfMonth), expected \(em)/\(ed)")
                }
                continue
            }

            // Check era code and era year
            guard let eraInfo = date.year.eraYear else {
                failures += 1
                if failures <= 10 {
                    print("Japanese \(gy)-\(gm)-\(gd): no era info")
                }
                continue
            }

            if eraInfo.era != expectedEra || eraInfo.year != eraYear {
                failures += 1
                if failures <= 10 {
                    print("Japanese \(gy)-\(gm)-\(gd): era got \(eraInfo.era) \(eraInfo.year), expected \(expectedEra) \(eraYear)")
                }
            }
        }

        print("Japanese regression: checked \(checked) sample points, failures \(failures)")
        #expect(failures == 0)
    }
}

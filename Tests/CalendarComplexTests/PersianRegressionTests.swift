import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

private let persianCsvPath = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarComplexTests/persian_1900_2100.csv"

@Suite("Persian Regression")
struct PersianRegressionTests {

    @Test("Persian 1900-2100 sample vs Foundation+convertdate")
    func persianRegression() throws {
        guard FileManager.default.fileExists(atPath: persianCsvPath) else {
            print("SKIP: Persian CSV not found at \(persianCsvPath)")
            return
        }

        let persian = Persian()
        let content = try String(contentsOfFile: persianCsvPath, encoding: .utf8)
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
                  let py = Int32(parts[3]),
                  let pm = UInt8(parts[4]),
                  let pd = UInt8(parts[5])
            else { continue }

            let rd = GregorianArithmetic.fixedFromGregorian(year: gy, month: gm, day: gd)
            let date = Date<Persian>.fromRataDie(rd, calendar: persian)

            checked += 1

            if date.extendedYear != py || date.month.ordinal != pm || date.dayOfMonth != pd {
                failures += 1
                if failures <= 20 {
                    print("Persian \(gy)-\(gm)-\(gd): got \(date.extendedYear)/\(date.month.ordinal)/\(date.dayOfMonth), expected \(py)/\(pm)/\(pd)")
                }
            }
        }

        print("Persian regression: checked \(checked) sample points, failures \(failures)")
        #expect(failures == 0)
    }
}

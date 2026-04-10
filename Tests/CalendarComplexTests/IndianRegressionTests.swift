import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

private let indianCsv = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarComplexTests/indian_1900_2100.csv"

@Suite("Indian (Saka) Regression")
struct IndianRegressionTests {

    @Test("Indian (Saka) 1900-2100 sample vs Foundation+convertdate")
    func indianRegression() throws {
        guard FileManager.default.fileExists(atPath: indianCsv) else {
            print("SKIP: Indian CSV not found at \(indianCsv)")
            return
        }

        let indian = Indian()
        let content = try String(contentsOfFile: indianCsv, encoding: .utf8)
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
                  let cy = Int32(parts[3]),
                  let cm = UInt8(parts[4]),
                  let cd = UInt8(parts[5])
            else { continue }

            let rd = GregorianArithmetic.fixedFromGregorian(year: gy, month: gm, day: gd)
            let date = Date<Indian>.fromRataDie(rd, calendar: indian)

            checked += 1
            if date.extendedYear != cy || date.month.ordinal != cm || date.dayOfMonth != cd {
                failures += 1
                if failures <= 10 {
                    print("Indian \(gy)-\(gm)-\(gd): got \(date.extendedYear)/\(date.month.ordinal)/\(date.dayOfMonth), expected \(cy)/\(cm)/\(cd)")
                }
            }
        }

        print("Indian regression: checked \(checked) sample points, failures \(failures)")
        #expect(failures == 0)
    }
}

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarComplex

private let basePath = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarComplexTests"
private let copticCsv = "\(basePath)/coptic_1900_2100.csv"
private let ethiopianCsv = "\(basePath)/ethiopian_1900_2100.csv"

@Suite("Coptic & Ethiopian Regression")
struct CopticEthiopianRegressionTests {

    private func runRegression<C: CalendarProtocol>(
        csvPath: String,
        calendar: C,
        label: String
    ) throws -> (checked: Int, failures: Int) {
        guard FileManager.default.fileExists(atPath: csvPath) else {
            print("SKIP: \(label) CSV not found at \(csvPath)")
            return (0, 0)
        }
        let content = try String(contentsOfFile: csvPath, encoding: .utf8)
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
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            checked += 1
            if date.extendedYear != cy || date.month.ordinal != cm || date.dayOfMonth != cd {
                failures += 1
                if failures <= 10 {
                    print("\(label) \(gy)-\(gm)-\(gd): got \(date.extendedYear)/\(date.month.ordinal)/\(date.dayOfMonth), expected \(cy)/\(cm)/\(cd)")
                }
            }
        }
        print("\(label) regression: checked \(checked) sample points, failures \(failures)")
        return (checked, failures)
    }

    @Test("Coptic 1900-2100 sample vs Foundation+convertdate")
    func copticRegression() throws {
        let (_, failures) = try runRegression(
            csvPath: copticCsv,
            calendar: Coptic(),
            label: "Coptic"
        )
        #expect(failures == 0)
    }

    @Test("Ethiopian 1900-2100 sample vs Foundation+convertdate")
    func ethiopianRegression() throws {
        let (_, failures) = try runRegression(
            csvPath: ethiopianCsv,
            calendar: Ethiopian(),
            label: "Ethiopian"
        )
        #expect(failures == 0)
    }
}

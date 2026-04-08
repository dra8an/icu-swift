import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import CalendarAstronomical

private let baseDir = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarAstronomicalTests"
private let tblaCsv  = "\(baseDir)/islamic_tbla_1900_2100.csv"
private let civilCsv = "\(baseDir)/islamic_civil_1900_2100.csv"

@Suite("Islamic Tabular / Civil Regression")
struct IslamicTabularRegressionTests {

    private func runRegression<C: CalendarProtocol>(
        csvPath: String,
        calendar: C,
        label: String
    ) throws -> (checked: Int, failures: Int) where C.DateInner == IslamicTabularDateInner {
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
                  let hy = Int32(parts[3]),
                  let hm = UInt8(parts[4]),
                  let hd = UInt8(parts[5])
            else { continue }
            let rd = GregorianArithmetic.fixedFromGregorian(year: gy, month: gm, day: gd)
            let date = Date<C>.fromRataDie(rd, calendar: calendar)
            checked += 1
            if date.extendedYear != hy || date.month.ordinal != hm || date.dayOfMonth != hd {
                failures += 1
                if failures <= 10 {
                    print("\(label) \(gy)-\(gm)-\(gd): got \(date.extendedYear)/\(date.month.ordinal)/\(date.dayOfMonth), expected \(hy)/\(hm)/\(hd)")
                }
            }
        }
        print("\(label) regression: checked \(checked) days, failures \(failures)")
        return (checked, failures)
    }

    @Test("Islamic Tabular (Thursday epoch) daily 1900-2100 vs Foundation+convertdate")
    func islamicTabularRegression() throws {
        let (_, failures) = try runRegression(
            csvPath: tblaCsv,
            calendar: IslamicTabular(),  // default = .thursday
            label: "Islamic Tabular"
        )
        #expect(failures == 0)
    }

    @Test("Islamic Civil (Friday epoch) daily 1900-2100 vs Foundation+convertdate")
    func islamicCivilRegression() throws {
        let (_, failures) = try runRegression(
            csvPath: civilCsv,
            calendar: IslamicCivil(),
            label: "Islamic Civil"
        )
        #expect(failures == 0)
    }
}

import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import AstronomicalEngine
@testable import CalendarAstronomical

private let chineseCsvPath = "/Users/draganbesevic/Projects/claude/CalendarAPI/icu4swift/Tests/CalendarAstronomicalTests/chinese_months_1901_2100_hko.csv"

@Suite("Chinese Regression")
struct ChineseRegressionTests {

    @Test("Chinese month starts: 1901-2099 from Hong Kong Observatory data")
    func chineseMonthRegression() throws {
        guard FileManager.default.fileExists(atPath: chineseCsvPath) else {
            print("SKIP: Chinese CSV not found")
            return
        }

        let chinese = Chinese()
        let content = try String(contentsOfFile: chineseCsvPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        var monthsChecked = 0
        var failures = 0

        for i in 1..<lines.count {
            let line = lines[i]
            if line.isEmpty { continue }
            let parts = line.split(separator: ",")
            guard parts.count == 7,
                  let expRelatedIso = Int(parts[0]),
                  let expMonthNum = Int(parts[1]),
                  let expIsLeap = Int(parts[2]),
                  let expLength = Int(parts[3]),
                  let gy = Int(parts[4]), let gm = Int(parts[5]), let gd = Int(parts[6]) else { continue }

            let rd = GregorianArithmetic.fixedFromGregorian(year: Int32(gy), month: UInt8(gm), day: UInt8(gd))
            let date = Date<Chinese>.fromRataDie(rd, calendar: chinese)

            // Check month number
            if Int(date.month.number) != expMonthNum {
                failures += 1
                if failures <= 300 {
                    print("Chinese \(gy)-\(gm)-\(gd): month got \(date.month.number), expected \(expMonthNum)")
                }
            }

            // Check leap flag
            if date.month.isLeap != (expIsLeap != 0) {
                failures += 1
                if failures <= 300 {
                    print("Chinese \(gy)-\(gm)-\(gd): isLeap got \(date.month.isLeap), expected \(expIsLeap != 0)")
                }
            }

            // Check day = 1 (month start)
            if date.dayOfMonth != 1 {
                failures += 1
                if failures <= 300 {
                    print("Chinese \(gy)-\(gm)-\(gd): day got \(date.dayOfMonth), expected 1")
                }
            }

            // Check related ISO year
            if Int(date.extendedYear) != expRelatedIso {
                failures += 1
                if failures <= 300 {
                    print("Chinese \(gy)-\(gm)-\(gd): year got \(date.extendedYear), expected \(expRelatedIso)")
                }
            }

            // Check month length
            if Int(date.daysInMonth) != expLength {
                failures += 1
                if failures <= 300 {
                    print("Chinese \(gy)-\(gm)-\(gd): length got \(date.daysInMonth), expected \(expLength)")
                }
            }

            monthsChecked += 1
        }

        print("Chinese: checked \(monthsChecked) months, \(failures) failures")
        #expect(monthsChecked > 1800, "Should check >1800 months, got \(monthsChecked)")
        #expect(failures == 0, "Chinese: expected 0 failures, got \(failures)")
    }
}

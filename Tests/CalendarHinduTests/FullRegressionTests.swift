import Testing
import Foundation
@testable import CalendarCore
@testable import CalendarSimple
@testable import AstronomicalEngine
@testable import CalendarHindu

private let lunisolarCsvPath = "/Users/draganbesevic/Projects/claude/hindu-calendar/validation/moshier/ref_1900_2050.csv"
private let solarCsvDir = "/Users/draganbesevic/Projects/claude/hindu-calendar/validation/moshier/solar"

private func runSolarCsvTest<V: HinduSolarVariant>(
    _ calendar: HinduSolar<V>, _ csvName: String, _ calName: String
) throws {
    let path = "\(solarCsvDir)/\(csvName)"
    guard FileManager.default.fileExists(atPath: path) else {
        print("SKIP: \(path) not found"); return
    }

    let content = try String(contentsOfFile: path, encoding: .utf8)
    let lines = content.components(separatedBy: .newlines)
    var monthsChecked = 0
    var failures = 0

    for i in 1..<lines.count {
        let line = lines[i]
        if line.isEmpty { continue }
        let parts = line.split(separator: ",")
        guard parts.count >= 6,
              let expMonth = Int(parts[0]), let expYear = Int(parts[1]),
              let expLength = Int(parts[2]),
              let gy = Int(parts[3]), let gm = Int(parts[4]), let gd = Int(parts[5]) else { continue }

        let rd = GregorianArithmetic.fixedFromGregorian(year: Int32(gy), month: UInt8(gm), day: UInt8(gd))
        let date = Date.fromRataDie(rd, calendar: calendar)

        if Int(date.month.number) != expMonth {
            failures += 1
            if failures <= 10 {
                print("\(calName) \(gy)-\(gm)-\(gd): month got \(date.month.number), expected \(expMonth)")
            }
        }
        if Int(date.extendedYear) != expYear {
            failures += 1
            if failures <= 5 {
                print("\(calName) \(gy)-\(gm)-\(gd): year got \(date.extendedYear), expected \(expYear)")
            }
        }
        if date.dayOfMonth != 1 {
            failures += 1
            if failures <= 5 {
                print("\(calName) \(gy)-\(gm)-\(gd): day got \(date.dayOfMonth), expected 1")
            }
        }
        if Int(date.daysInMonth) != expLength {
            failures += 1
            if failures <= 5 {
                print("\(calName) month \(expMonth)/\(expYear): length got \(date.daysInMonth), expected \(expLength)")
            }
        }
        monthsChecked += 1
    }

    print("\(calName): checked \(monthsChecked) months, \(failures) failures")
    #expect(monthsChecked > 1800, "Should check >1800 months, got \(monthsChecked)")
    #expect(failures == 0, "\(calName): expected 0 failures, got \(failures)")
}

@Suite("Full Regression")
struct FullRegressionTests {

    @Test("Lunisolar CSV: sampled 1,100+ days from 1900-2050")
    func lunisolarCsvRegression() throws {
        guard FileManager.default.fileExists(atPath: lunisolarCsvPath) else {
            print("SKIP: lunisolar CSV not found"); return
        }

        let amanta = HinduAmanta()
        let content = try String(contentsOfFile: lunisolarCsvPath, encoding: .utf8)
        let lines = content.components(separatedBy: .newlines)

        let sampleStep = 50
        var sampled = 0
        var failures = 0

        for i in stride(from: 1, to: lines.count, by: sampleStep) {
            let line = lines[i]
            if line.isEmpty { continue }
            let parts = line.split(separator: ",")
            guard parts.count == 7,
                  let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
                  let expTithi = Int(parts[3]), let expMasa = Int(parts[4]),
                  let expAdhika = Int(parts[5]), let expSaka = Int(parts[6]) else { continue }

            let rd = GregorianArithmetic.fixedFromGregorian(year: Int32(y), month: UInt8(m), day: UInt8(d))
            let date = Date<HinduAmanta>.fromRataDie(rd, calendar: amanta)

            let label = "\(y)-\(m)-\(d)"
            if Int(date.dayOfMonth) != expTithi {
                failures += 1
                if failures <= 10 { print("\(label) tithi: got \(date.dayOfMonth), expected \(expTithi)") }
            }
            if Int(date.month.number) != expMasa {
                failures += 1
                if failures <= 10 { print("\(label) masa: got \(date.month.number), expected \(expMasa)") }
            }
            if date.month.isLeap != (expAdhika != 0) {
                failures += 1
                if failures <= 10 { print("\(label) adhika: got \(date.month.isLeap), expected \(expAdhika != 0)") }
            }
            if Int(date.extendedYear) != expSaka {
                failures += 1
                if failures <= 10 { print("\(label) saka: got \(date.extendedYear), expected \(expSaka)") }
            }
            sampled += 1
        }

        print("Lunisolar CSV: \(sampled) days sampled, \(failures) assertion failures")
        #expect(sampled > 1000, "Should sample >1000 days, got \(sampled)")
        #expect(failures == 0, "Expected 0 failures, got \(failures)")
    }

    @Test("Tamil CSV: 1,811 months from 1900-2050")
    func tamilCsvRegression() throws {
        try runSolarCsvTest(HinduTamil(), "tamil_months_1900_2050.csv", "Tamil")
    }

    @Test("Bengali CSV: 1,811 months from 1900-2050")
    func bengaliCsvRegression() throws {
        try runSolarCsvTest(HinduBengali(), "bengali_months_1900_2050.csv", "Bengali")
    }

    @Test("Odia CSV: 1,811 months from 1900-2050")
    func odiaCsvRegression() throws {
        try runSolarCsvTest(HinduOdia(), "odia_months_1900_2050.csv", "Odia")
    }

    @Test("Malayalam CSV: 1,811 months from 1900-2050")
    func malayalamCsvRegression() throws {
        try runSolarCsvTest(HinduMalayalam(), "malayalam_months_1900_2050.csv", "Malayalam")
    }
}

import Testing
@testable import CalendarCore

@Suite("YearInfo")
struct YearInfoTests {

    @Test("Era year info")
    func eraYear() {
        let era = EraYear(era: "ce", year: 2024, extendedYear: 2024)
        let info = YearInfo.era(era)

        #expect(info.extendedYear == 2024)
        #expect(info.displayYear == 2024)
        #expect(info.eraYear != nil)
        #expect(info.eraYear?.era == "ce")
        #expect(info.cyclicYear == nil)
    }

    @Test("BCE era year has negative extended year")
    func bceYear() {
        let era = EraYear(era: "bce", year: 44, extendedYear: -43, ambiguity: .eraRequired)
        let info = YearInfo.era(era)

        #expect(info.extendedYear == -43)
        #expect(info.displayYear == 44)
        #expect(info.eraYear?.ambiguity == .eraRequired)
    }

    @Test("Cyclic year info")
    func cyclicYear() {
        let cyclic = CyclicYear(yearOfCycle: 41, relatedIso: 2024)
        let info = YearInfo.cyclic(cyclic)

        #expect(info.extendedYear == 2024)
        #expect(info.displayYear == 2024)
        #expect(info.cyclicYear != nil)
        #expect(info.cyclicYear?.yearOfCycle == 41)
        #expect(info.eraYear == nil)
    }
}

@Suite("YearInput")
struct YearInputTests {

    @Test("Integer literal creates extended year")
    func integerLiteral() {
        let y: YearInput = 2024
        if case .extended(let v) = y {
            #expect(v == 2024)
        } else {
            Issue.record("Expected .extended")
        }
    }

    @Test("Era year construction")
    func eraYearInput() {
        let y = YearInput.eraYear(era: "reiwa", year: 7)
        if case .eraYear(let era, let year) = y {
            #expect(era == "reiwa")
            #expect(year == 7)
        } else {
            Issue.record("Expected .eraYear")
        }
    }
}

@Suite("YearAmbiguity")
struct YearAmbiguityTests {

    @Test("All cases exist")
    func allCases() {
        let cases: [YearAmbiguity] = [.unambiguous, .centuryRequired, .eraRequired, .eraAndCenturyRequired]
        #expect(cases.count == 4)
    }
}

import Testing
@testable import CalendarCore

@Suite("Month")
struct MonthTests {

    @Test("Non-leap month construction")
    func nonLeap() {
        let m = Month.new(3)
        #expect(m.number == 3)
        #expect(!m.isLeap)
        #expect(m.code.description == "M03")
    }

    @Test("Leap month construction")
    func leap() {
        let m = Month.leap(5)
        #expect(m.number == 5)
        #expect(m.isLeap)
        #expect(m.code.description == "M05L")
    }

    @Test("Integer literal creates non-leap month")
    func integerLiteral() {
        let m: Month = 7
        #expect(m.number == 7)
        #expect(!m.isLeap)
    }

    @Test("Month ordering: number first, then leap after non-leap")
    func ordering() {
        #expect(Month.new(1) < Month.new(2))
        #expect(Month.new(2) < Month.leap(2))
        #expect(Month.leap(2) < Month.new(3))
        #expect(Month.new(10) < Month.leap(10))
    }

    @Test("Clamping at 99")
    func clamping() {
        let m = Month.new(200)
        #expect(m.number == 99)
    }

    @Test("Convenience factory methods")
    func convenience() {
        #expect(Month.january().number == 1)
        #expect(Month.december().number == 12)
        #expect(!Month.march().isLeap)
    }
}

@Suite("MonthCode")
struct MonthCodeTests {

    @Test("Parsing valid month codes")
    func parseValid() {
        let m01 = MonthCode("M01")
        #expect(m01 != nil)
        #expect(m01?.number == 1)
        #expect(m01?.isLeap == false)

        let m12L = MonthCode("M12L")
        #expect(m12L != nil)
        #expect(m12L?.number == 12)
        #expect(m12L?.isLeap == true)
    }

    @Test("Parsing invalid month codes")
    func parseInvalid() {
        #expect(MonthCode("Jan") == nil)
        #expect(MonthCode("M1") == nil)
        #expect(MonthCode("M001") == nil)
        #expect(MonthCode("") == nil)
        #expect(MonthCode("M00") == nil)  // month 0 is invalid
    }

    @Test("Description round-trip")
    func descriptionRoundTrip() {
        for n: UInt8 in 1...13 {
            let code = MonthCode(number: n, isLeap: false)
            let parsed = MonthCode(code.description)
            #expect(parsed == code)
        }
        for n: UInt8 in 1...6 {
            let code = MonthCode(number: n, isLeap: true)
            let parsed = MonthCode(code.description)
            #expect(parsed == code)
        }
    }
}

@Suite("MonthInfo")
struct MonthInfoTests {

    @Test("MonthInfo delegates to Month")
    func delegates() {
        let info = MonthInfo(ordinal: 8, month: Month.leap(5))
        #expect(info.ordinal == 8)
        #expect(info.number == 5)
        #expect(info.isLeap)
        #expect(info.code.description == "M05L")
    }
}

// ExtremeRataDieTests — do pure-arithmetic calendars survive RataDie
// values far outside the documented `RataDie.validRange`?
//
// Just for fun. The contract says `validRange` is ±365 M days (~±1 M
// years). We push to ±10 B days (~±27 M years) — nearly two orders of
// magnitude past the contract.
//
// We assert `toRataDie(fromRataDie(rd)) == rd` — day preservation,
// not correctness of the Y/M/D fields (which are meaningless at that era).
//
// Hebrew used to crash here at extreme negative RDs — the forward-only
// year search in `hebrewFromFixed` depended on a truncating integer
// division that skewed one year high at large negative values. Fixed
// 2026-04-22 by switching to floor division (see `HebrewArithmetic.swift`
// `floorDiv` helper). Hebrew now passes ±10 B alongside the other
// arithmetic calendars.
//
// **Astronomical calendars (Chinese, Dangi, Vietnamese, Hindu) are
// excluded** because their Moshier VSOP87 precision envelope is
// ~±3,000 years from J2000. At 27 M years out, the iterative
// new-moon / solar-longitude search has no convergence — not a bug,
// just the astronomy having no answer.

import Testing
import CalendarCore
import CalendarSimple
import CalendarComplex
import CalendarJapanese
import CalendarAstronomical

@Suite("Extreme RataDie survival — ±10 B days through pure-arithmetic calendars")
struct ExtremeRataDieTests {

    static let extremes: [Int64] = [10_000_000_000, -10_000_000_000]

    private func roundTrip<C: CalendarProtocol>(
        _ calendar: C, _ rdValue: Int64, name: String
    ) {
        let rd = RataDie(rdValue)
        let inner = calendar.fromRataDie(rd)
        let recovered = calendar.toRataDie(inner)
        #expect(rd == recovered, "\(name) at RD(\(rdValue)): got \(recovered)")
    }

    @Test("ISO / Gregorian / Julian / Buddhist / ROC survive ±10 B days")
    func calendarSimple() {
        for e in Self.extremes {
            roundTrip(Iso(),       e, name: "Iso")
            roundTrip(Gregorian(), e, name: "Gregorian")
            roundTrip(Julian(),    e, name: "Julian")
            roundTrip(Buddhist(),  e, name: "Buddhist")
            roundTrip(Roc(),       e, name: "ROC")
        }
    }

    @Test("Coptic / Ethiopian / Ethiopian Amete Alem / Persian / Indian survive ±10 B days")
    func calendarComplex() {
        for e in Self.extremes {
            roundTrip(Coptic(),             e, name: "Coptic")
            roundTrip(Ethiopian(),          e, name: "Ethiopian")
            roundTrip(EthiopianAmeteAlem(), e, name: "EthiopianAmeteAlem")
            roundTrip(Persian(),            e, name: "Persian")
            roundTrip(Indian(),             e, name: "Indian")
        }
    }

    @Test("Hebrew survives ±10 B days (floor-division fix, 2026-04-22)")
    func hebrew() {
        for e in Self.extremes { roundTrip(Hebrew(), e, name: "Hebrew") }
    }

    @Test("Japanese survives ±10 B days (falls through to extended-year)")
    func japanese() {
        for e in Self.extremes { roundTrip(Japanese(), e, name: "Japanese") }
    }

    @Test("Islamic Civil / Tabular / Umm al-Qura / Astronomical survive ±10 B days")
    func islamic() {
        for e in Self.extremes {
            roundTrip(IslamicCivil(),        e, name: "IslamicCivil")
            roundTrip(IslamicTabular(),      e, name: "IslamicTabular")
            roundTrip(IslamicUmmAlQura(),    e, name: "IslamicUmmAlQura")
            roundTrip(IslamicAstronomical(), e, name: "IslamicAstronomical")
        }
    }
}

// The sky at sunset on 17 and 18 February 2026 for every place in the story, a world grid for the maps,
// and the moon's distance from the sun through the night for the film.
//
// Usage: EveningNumbers <places.csv> <grid.csv> [series.csv]
// Every value comes from CrescentRules.evening and the Astronomical functions behind it, the same calls the
// committed tests and the fixture use.
// Times are hours counted from 17 February 2026, 00:00 UTC (so 15.32 is 15:19 on the 17th, 27.70 is 03:42 on the 18th).
import AstronomicalEngine
import CalendarAstronomical
import CalendarCore
import CalendarSimple
import Foundation

let day17 = GregorianArithmetic.fixedFromGregorian(year: 2026, month: 2, day: 17)
precondition(day17 == RataDie.fromUnixEpochDays(20501), "17 February 2026 should be day 20501 of the Unix count")
let midnight17 = Moment.fromRataDie(day17)

func hours(_ m: Moment) -> Double { (m - midnight17) * 24 }

func num(_ x: Double, _ digits: Int = 3) -> String { String(format: "%.\(digits)f", x) }

struct Place {
    let name: String
    let location: Location
}

func place(_ name: String, _ lat: Double, _ lon: Double, zone: Double) -> Place {
    Place(name: name, location: Location(latitude: lat, longitude: lon, elevation: 0, utcOffset: zone / 24))
}

let places: [Place] = [
    Place(name: "Singapore (Tuas)", location: CrescentRules.tuas),
    Place(name: "Malaysia (Pulau Perak)", location: CrescentRules.pulauPerak),
    place("Kuala Lumpur", 3.139, 101.687, zone: 8),
    Place(name: "Indonesia (Banda Aceh)", location: CrescentRules.bandaAceh),
    place("Jakarta", -6.2088, 106.8456, zone: 7),
    place("Peshawar", 34.0151, 71.5249, zone: 5),
    Place(name: "Mecca (Kaaba)", location: CrescentRules.makkah),
    Place(name: "Cairo", location: CrescentRules.cairo),
    place("Istanbul", 41.0082, 28.9784, zone: 3),
    place("Ankara", 39.93, 32.86, zone: 3),
    place("London", 51.5074, -0.1278, zone: 0),
    place("Rabat", 34.0209, -6.8416, zone: 0),
    // on the way, for the film: not part of the story, only stops along the sunset's path
    place("New York", 40.7128, -74.0060, zone: -5),
    place("Los Angeles", 34.0522, -118.2437, zone: -8),
    // the first grid point to meet Türkiye's numbers, and the best point of the American mainland (fact sheet)
    place("First place (4N 142W)", 4.0, -142.0, zone: -9),
    place("Alaska Peninsula (tip)", 54.85, -163.38, zone: -9),
]

var lines = ["place,latitude,longitude,evening,sunset_utc_h,sunset_local_h,new_moon_utc_h,age_h,moonset_utc_h,lag_min,"
    + "alt_apparent,alt_topocentric,alt_geocentric,elong_geocentric,elong_topocentric,sun_azimuth,moon_azimuth,sun_altitude"]
for p in places {
    for offset in 0...1 {
        guard let e = CrescentRules.evening(day17 + Int64(offset), at: p.location) else { continue }
        let sunset = hours(e.sunset)
        let sun = Astronomical.solarHorizontal(e.sunset, location: p.location)
        let moon = Astronomical.topocentricLunarHorizontal(e.sunset, location: p.location)
        lines.append([
            p.name, num(p.location.latitude, 4), num(p.location.longitude, 4), "\(17 + offset) Feb",
            num(sunset, 4), num(sunset + p.location.utcOffset * 24, 4), num(hours(e.conjunction), 4), num(e.ageHours, 3),
            e.moonset.map { num(hours($0), 4) } ?? "", e.lagMinutes.map { num($0, 2) } ?? "",
            num(e.altitudeApparent), num(e.altitudeTopocentric), num(e.altitudeGeocentric),
            num(e.elongationGeocentric), num(e.elongationTopocentric),
            num(sun.azimuth), num(moon.azimuth), num(sun.altitude),
        ].joined(separator: ","))
    }
}
try lines.joined(separator: "\n").appending("\n").write(toFile: CommandLine.arguments[1], atomically: true, encoding: .utf8)
print("places:", lines.count - 1, "rows")

// The grid: one point per degree. For each, the sky at that point's own sunset on the evening of the 17th.
// moon_up = 1 when the moon's upper edge is still above the horizon at sunset (the same line moonset uses).
var grid = ["latitude,longitude,sunset_utc_h,age_h,alt_apparent,alt_topocentric,elong_geocentric,elong_topocentric,moon_up"]
for lat in stride(from: -66, through: 72, by: 1) {
    for lon in stride(from: -180, through: 180, by: 1) {
        let location = Location(latitude: Double(lat), longitude: Double(lon), elevation: 0, utcOffset: 0)
        guard let e = CrescentRules.evening(day17, at: location, withMoonset: false) else {
            grid.append("\(lat),\(lon),,,,,,,")
            continue
        }
        let up = e.altitudeTopocentric > -34.0 / 60 - e.semiDiameter
        grid.append([
            "\(lat)", "\(lon)", num(hours(e.sunset), 3), num(e.ageHours, 3), num(e.altitudeApparent), num(e.altitudeTopocentric),
            num(e.elongationGeocentric), num(e.elongationTopocentric), up ? "1" : "0",
        ].joined(separator: ","))
    }
}
try grid.joined(separator: "\n").appending("\n").write(toFile: CommandLine.arguments[2], atomically: true, encoding: .utf8)
print("grid:", grid.count - 1, "points")

// The series: the moon's distance from the sun (the same for everyone on Earth) every five minutes,
// from 10:00 on the 17th to 05:00 on the 18th.
if CommandLine.arguments.count > 3 {
    var series = ["utc_h,elong_geocentric"]
    var t = 10.0
    while t <= 29.0001 {
        series.append("\(num(t, 4)),\(num(Astronomical.geocentricElongation(midnight17 + t / 24), 4))")
        t += 1.0 / 12
    }
    try series.joined(separator: "\n").appending("\n").write(toFile: CommandLine.arguments[3], atomically: true, encoding: .utf8)
    print("series:", series.count - 1, "moments")
}

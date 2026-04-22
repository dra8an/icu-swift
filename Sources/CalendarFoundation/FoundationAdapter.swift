import Foundation
import CalendarCore

// Adapter between `Foundation.Date` and icu4swift's `RataDie` + time-of-day.
//
// Mirrors the split pattern used by `_CalendarGregorian` in swift-foundation
// (`Sources/FoundationEssentials/Calendar/Calendar_Gregorian.swift`):
// break `Date` into an integer day count for calendar math plus an
// integer time-of-day (seconds + nanoseconds) for sub-day work. Our
// integer day is `RataDie` (midnight-based, R.D. 1 = 0001-01-01 ISO)
// rather than Julian Day (noon-based), so assembly does not need the
// `−43_200` noon-nudge that `_CalendarGregorian` applies.
//
// See:
// - `Docs-Foundation/SUBDAY_BOUNDARY.md` — authoritative design decision.
// - `Docs-Foundation/FractionalRataDiePlan.md` — phased implementation plan.
// - `Docs/RDvsJD.md` — why RataDie, not Julian Day.
//
// Phase A: UTC-only happy path.
// Phase B: Fixed-offset time zones (same code; more tests).
// Phase C: DST-aware assembly (skipped / repeated wall-time policies).

// MARK: - DST policy enums

/// Resolution policy when a civil wall-clock time falls in a time-zone
/// "gap" that does not exist (e.g. 02:30 on spring-forward day in US Pacific).
///
/// - `former`: interpret using the offset that was in effect **before**
///   the transition. For US spring-forward at 02:30, that's PST (−8h),
///   producing an absolute instant that would be 03:30 in PDT.
/// - `latter`: interpret using the offset that came **into effect**
///   after the transition. For US spring-forward at 02:30, that's PDT
///   (−7h), producing an absolute instant that would be 01:30 in PST.
///
/// Matches the semantics of Foundation's internal
/// `TimeZone.DaylightSavingTimePolicy` (`.former` / `.latter`). Default
/// on our entry points is `.former`, matching Foundation's default.
public enum DSTSkippedTimePolicy: Sendable {
    case former
    case latter
}

/// Resolution policy when a civil wall-clock time occurs **twice**
/// due to a time-zone "repeat" (e.g. 01:30 on fall-back day in US Pacific).
///
/// - `former`: return the **chronologically earlier** absolute instant
///   (the occurrence before the fall-back).
/// - `latter`: return the **chronologically later** absolute instant
///   (the occurrence after the fall-back).
public enum DSTRepeatedTimePolicy: Sendable {
    case former
    case latter
}

// MARK: - Extraction

/// Extracts a civil `RataDie` and time-of-day from a `Foundation.Date`.
///
/// Extraction is unambiguous — an absolute instant maps to exactly one
/// local wall-clock time. Uses `TimeZone.secondsFromGMT(for:)`, which
/// incorporates DST when applicable.
///
/// - Parameters:
///   - date: The absolute instant to decompose.
///   - tz: The time zone in which to interpret `date`.
/// - Returns: Civil day number + seconds-in-day (`0..<86_400`) +
///   nanosecond-of-second (`0..<1_000_000_000`).
public func rataDieAndTimeOfDay(
    from date: Foundation.Date,
    in tz: Foundation.TimeZone
) -> (rataDie: RataDie, secondsInDay: Int, nanosecond: Int) {
    let tzOffset = tz.secondsFromGMT(for: date)
    let localTI = date.timeIntervalSinceReferenceDate + Double(tzOffset)
    let floorSec = localTI.rounded(.down)

    // Integer path for any realistic range. Int64 holds ~2.9e11 years
    // of seconds, so this covers everything except cosmological extremes.
    // Matches `_CalendarGregorian`'s `canUseIntegerMath` guard in
    // `Calendar_Gregorian.swift:2070`.
    if floorSec < Double(Int64.max) && floorSec >= Double(Int64.min) {
        let totalSec = Int64(floorSec)
        let secondsInDay = Int(((totalSec % 86_400) + 86_400) % 86_400)
        let daysFromEpoch = (totalSec - Int64(secondsInDay)) / 86_400
        let rataDie = RataDie(RataDie.foundationEpoch.dayNumber + daysFromEpoch)
        let nanosecond = Int((localTI - floorSec) * 1_000_000_000)
        return (rataDie, secondsInDay, nanosecond)
    }

    // Double fallback — precision degrades to ~1 s at these magnitudes,
    // matching `_CalendarGregorian`'s own behavior
    // (`Calendar_Gregorian.swift:2079–2091`).
    var timeInDay = floorSec.remainder(dividingBy: 86_400)
    if timeInDay < 0 { timeInDay += 86_400 }
    let hour = Int(timeInDay / 3_600)
    let remAfterHour = timeInDay.truncatingRemainder(dividingBy: 3_600)
    let minute = Int(remAfterHour / 60)
    let second = Int(remAfterHour.truncatingRemainder(dividingBy: 60))
    let secondsInDay = hour * 3_600 + minute * 60 + second
    let daysFromEpoch = Int64((floorSec - Double(secondsInDay)) / 86_400)
    let rataDie = RataDie(RataDie.foundationEpoch.dayNumber + daysFromEpoch)
    let nanosecond = Int((localTI - floorSec) * 1_000_000_000)
    return (rataDie, secondsInDay, nanosecond)
}

// MARK: - Assembly

/// Assembles a `Foundation.Date` from a civil `RataDie` and time-of-day.
///
/// Resolves DST-gap ("skipped") and DST-overlap ("repeated") wall-clock
/// times via the provided policies. Defaults match Foundation's
/// `_CalendarGregorian.date(from:inTimeZone:...)`: both `.former`.
///
/// - Parameters:
///   - rataDie: Civil day number.
///   - hour: Hour of day, `0..<24`.
///   - minute: Minute of hour, `0..<60`.
///   - second: Second of minute, `0..<60`.
///   - nanosecond: Nanosecond of second, `0..<1_000_000_000`.
///   - tz: Time zone in which the civil components are expressed.
///   - repeatedTimePolicy: Resolution for a wall time that occurs twice.
///   - skippedTimePolicy: Resolution for a wall time that doesn't exist.
public func date(
    rataDie: RataDie,
    hour: Int = 0,
    minute: Int = 0,
    second: Int = 0,
    nanosecond: Int = 0,
    in tz: Foundation.TimeZone,
    repeatedTimePolicy: DSTRepeatedTimePolicy = .former,
    skippedTimePolicy: DSTSkippedTimePolicy = .former
) -> Foundation.Date {
    let daysFromEpoch = rataDie.dayNumber - RataDie.foundationEpoch.dayNumber
    let totalSecLocal = daysFromEpoch * 86_400
                      + Int64(hour) * 3_600
                      + Int64(minute) * 60
                      + Int64(second)

    let localTI = Double(totalSecLocal) + Double(nanosecond) / 1_000_000_000.0

    return resolveLocalTI(
        localTI,
        in: tz,
        repeatedTimePolicy: repeatedTimePolicy,
        skippedTimePolicy: skippedTimePolicy
    )
}

/// Converts a "local TI" (TimeInterval in the given zone's local wall
/// clock, measured from 2001-01-01 00:00 local) into an absolute
/// `Foundation.Date`, resolving DST transitions via the given policies.
///
/// Algorithm:
///
/// 1. Probe the zone ±24 h around the local time. This always spans any
///    single DST transition (standard DST rules transition once in a
///    24-hour-wide window).
/// 2. If both probes report the same offset, there is no transition
///    nearby — fast path, apply the offset uniformly.
/// 3. Otherwise, form two candidates using the "before" and "after"
///    offsets; test each for self-consistency.
///    - Exactly one round-trips → normal case on one side of a DST edge.
///    - Both round-trip → repeated (fall-back) — apply `repeatedTimePolicy`.
///    - Neither round-trips → skipped (spring-forward) — apply
///      `skippedTimePolicy`.
///
/// Note: A "fast path via single probe + verify" was tried and rejected
/// because it silently picks the `.former` branch on fall-back regardless
/// of the caller's `repeatedTimePolicy`. The ±24 h probe is what lets us
/// respect the policy parameters correctly.
///
/// Policy semantics match Foundation's `DaylightSavingTimePolicy`
/// (and ICU's `UCAL_TZ_LOCAL_FORMER`/`UCAL_TZ_LOCAL_LATTER`): `.former`
/// uses the offset that was in effect **before** the transition;
/// `.latter` uses the offset that came into effect **after**.
private func resolveLocalTI(
    _ localTI: Double,
    in tz: Foundation.TimeZone,
    repeatedTimePolicy: DSTRepeatedTimePolicy,
    skippedTimePolicy: DSTSkippedTimePolicy
) -> Foundation.Date {
    let earlyProbe = Foundation.Date(timeIntervalSinceReferenceDate: localTI - 86_400)
    let lateProbe = Foundation.Date(timeIntervalSinceReferenceDate: localTI + 86_400)
    let offsetBefore = tz.secondsFromGMT(for: earlyProbe)
    let offsetAfter = tz.secondsFromGMT(for: lateProbe)

    // Fast path: no transition within ±24 h.
    if offsetBefore == offsetAfter {
        return Foundation.Date(timeIntervalSinceReferenceDate: localTI - Double(offsetBefore))
    }

    // Transition in the window. Form the two candidates.
    let candidateFormer = Foundation.Date(
        timeIntervalSinceReferenceDate: localTI - Double(offsetBefore)
    )
    let candidateLatter = Foundation.Date(
        timeIntervalSinceReferenceDate: localTI - Double(offsetAfter)
    )

    let formerValid = tz.secondsFromGMT(for: candidateFormer) == offsetBefore
    let latterValid = tz.secondsFromGMT(for: candidateLatter) == offsetAfter

    switch (formerValid, latterValid) {
    case (true, true):
        // Repeated wall time (fall-back).
        return repeatedTimePolicy == .former ? candidateFormer : candidateLatter
    case (false, false):
        // Skipped wall time (spring-forward).
        return skippedTimePolicy == .former ? candidateFormer : candidateLatter
    case (true, false):
        return candidateFormer
    case (false, true):
        return candidateLatter
    }
}

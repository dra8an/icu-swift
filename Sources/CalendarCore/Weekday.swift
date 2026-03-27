/// A day of the week.
///
/// Monday = 1, consistent with ISO 8601.
public enum Weekday: Int, Sendable, Hashable, CaseIterable {
    case monday = 1
    case tuesday = 2
    case wednesday = 3
    case thursday = 4
    case friday = 5
    case saturday = 6
    case sunday = 7

    /// Computes the weekday from a `RataDie`.
    ///
    /// R.D. 1 (January 1, year 1 ISO) is a Monday.
    public static func from(rataDie rd: RataDie) -> Weekday {
        // rd.dayNumber mod 7: 0=Sunday in some systems, but R.D. 1 = Monday
        // R.D. 1 is Monday. (1-1) % 7 = 0 -> Monday.
        // General: ((rd - 1) % 7) gives 0=Mon, 1=Tue, ..., 6=Sun
        let mod7 = ((rd.dayNumber - 1) % 7 + 7) % 7  // ensure non-negative
        return Weekday(rawValue: Int(mod7) + 1)!
    }
}

// MARK: - CustomStringConvertible

extension Weekday: CustomStringConvertible {
    public var description: String {
        switch self {
        case .monday: "Monday"
        case .tuesday: "Tuesday"
        case .wednesday: "Wednesday"
        case .thursday: "Thursday"
        case .friday: "Friday"
        case .saturday: "Saturday"
        case .sunday: "Sunday"
        }
    }
}

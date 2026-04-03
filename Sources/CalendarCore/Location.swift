// Location — a geographic position for calendar calculations.

/// A geographic location for sunrise/sunset and observational calendar calculations.
///
/// - `latitude`: degrees, -90 to 90
/// - `longitude`: degrees, -180 to 180
/// - `elevation`: meters above sea level
/// - `utcOffset`: UTC offset in fractional days (e.g., UTC+1 = 1.0/24.0)
public struct Location: Sendable {
    public let latitude: Double
    public let longitude: Double
    public let elevation: Double
    public let utcOffset: Double

    public init(latitude: Double, longitude: Double, elevation: Double, utcOffset: Double) {
        self.latitude = latitude
        self.longitude = longitude
        self.elevation = elevation
        self.utcOffset = utcOffset
    }

    /// Mean time zone offset from longitude (longitude / 360 days).
    public var zoneFromLongitude: Double {
        longitude / 360.0
    }

    // MARK: - Well-Known Locations

    /// Mecca, Saudi Arabia (for Islamic calendar calculations).
    public static let mecca = Location(
        latitude: 21.4225, longitude: 39.8262, elevation: 298.0,
        utcOffset: 3.0 / 24.0
    )

    /// Jerusalem (for Hebrew calendar reference).
    public static let jerusalem = Location(
        latitude: 31.78, longitude: 35.24, elevation: 740.0,
        utcOffset: 2.0 / 24.0
    )

    /// Beijing (for Chinese calendar).
    public static let beijing = Location(
        latitude: 39.9042, longitude: 116.4074, elevation: 43.0,
        utcOffset: 8.0 / 24.0
    )

    /// Seoul (for Korean/Dangi calendar).
    public static let seoul = Location(
        latitude: 37.5665, longitude: 126.9780, elevation: 38.0,
        utcOffset: 9.0 / 24.0
    )

    /// New Delhi (for Indian/Hindu calendar calculations).
    public static let newDelhi = Location(
        latitude: 28.6139, longitude: 77.2090, elevation: 216.0,
        utcOffset: 5.5 / 24.0
    )
}

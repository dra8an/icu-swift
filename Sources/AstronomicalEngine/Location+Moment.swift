// Location extensions that depend on Moment (in AstronomicalEngine, not CalendarCore).

import CalendarCore

extension Location {
    /// Convert local mean time to universal time.
    public func universalFromLocal(_ localTime: Moment) -> Moment {
        localTime - zoneFromLongitude
    }

    /// Convert universal time to local mean time.
    public func localFromUniversal(_ universalTime: Moment) -> Moment {
        universalTime + zoneFromLongitude
    }

    /// Convert standard time to universal time.
    public func universalFromStandard(_ standardTime: Moment) -> Moment {
        standardTime - utcOffset
    }

    /// Convert universal time to standard time.
    public func standardFromUniversal(_ universalTime: Moment) -> Moment {
        universalTime + utcOffset
    }
}

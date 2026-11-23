import Foundation

/// Where an aircraft is along its route.
struct RouteProgress: Hashable, Sendable {
    var flownKm: Double
    var remainingKm: Double
    var totalKm: Double
    /// 0...1 along the route.
    var fraction: Double
}

enum FlightMath {
    // MARK: Progress

    static func progress(at p: GeoPoint, route: FlightRoute) -> RouteProgress {
        let flown = Geo.distanceKm(route.origin.point, p)
        let remaining = Geo.distanceKm(p, route.destination.point)
        let total = max(flown + remaining, 1)
        return RouteProgress(
            flownKm: flown,
            remainingKm: remaining,
            totalKm: max(route.distanceKm, 1),
            fraction: min(max(flown / total, 0), 1)
        )
    }

    // MARK: Route plausibility

    /// Route databases key on callsign, and callsigns get reused, so a looked-up route is only trusted
    /// when the aircraft is actually somewhere sensible for it.
    static func isPlausible(state: AircraftState, origin: Airport, destination: Airport) -> Bool {
        let direct = Geo.distanceKm(origin.point, destination.point)
        guard direct > 30 else { return false }
        let flown = Geo.distanceKm(origin.point, state.point)
        let remaining = Geo.distanceKm(state.point, destination.point)

        if state.onGround || (state.groundSpeedKt ?? 0) < 60 {
            // Parked or taxiing: must be at one end of the route.
            return flown < 12 || remaining < 12
        }

        let detour = (flown + remaining) / direct
        let allowedDetour = 1.22 + 130 / max(direct, 60)
        guard detour <= allowedDetour else { return false }

        // Near either airport the heading is dictated by runways and procedures, not the route.
        if flown < 110 || remaining < 160 { return true }
        guard let track = state.trackDeg else { return true }
        return Geo.angleDiff(track, Geo.bearing(state.point, destination.point)) < 65
    }

    // MARK: Phase

    static func phase(state: AircraftState, route: FlightRoute?) -> FlightPhase {
        let alt = Double(state.altitudeFt ?? 0)
        let vs = Double(state.verticalRateFpm ?? 0)
        let gs = state.groundSpeedKt ?? 0

        if state.onGround || (alt < 400 && gs < 70) {
            if let route, Geo.distanceKm(state.point, route.destination.point) < 12,
               Geo.distanceKm(state.point, route.origin.point) > 12 {
                return .landed
            }
            return .ground
        }
        if let route {
            let remaining = Geo.distanceKm(state.point, route.destination.point)
            let fieldElevation = Double(route.destination.elevationFt ?? 0)
            if remaining < 45 && alt - fieldElevation < 9000 && vs < 400 { return .approach }
            if vs < -400 { return .descent }
            if remaining < 200 && alt < 24000 && vs < 300 { return .descent }
        } else if vs < -400 {
            return .descent
        }
        if vs > 400 { return .climb }
        if alt < 12000 { return vs >= 0 ? .climb : .descent }
        return .cruise
    }

    // MARK: Time to touchdown

    /// Minutes from a given distance-to-run until touchdown once an airliner is inside its arrival
    /// (deceleration, descent, vectoring to final). Fitted to the median of ~500 observations of real
    /// arrivals tracked to touchdown on 2026-11-23; individual flights vary by about ±4 minutes.
    /// Interpolated linearly between knots.
    static let terminalProfile: [(km: Double, minutes: Double)] = [
        (0, 0.7), (10, 3.0), (25, 6.0), (50, 10.5), (80, 14.5), (120, 18.5), (170, 23.0), (230, 28.0), (300, 33.0)
    ]

    static var terminalRadiusKm: Double { terminalProfile[terminalProfile.count - 1].km }

    static func terminalMinutes(forKm km: Double) -> Double {
        let table = terminalProfile
        if km <= table[0].km { return table[0].minutes }
        for i in 1..<table.count where km <= table[i].km {
            let a = table[i - 1], b = table[i]
            let t = (km - a.km) / (b.km - a.km)
            return a.minutes + t * (b.minutes - a.minutes)
        }
        return table[table.count - 1].minutes
    }

    /// Typical cruise ground speed in knots when the aircraft is not yet at cruise (still climbing).
    private static func cruiseSpeedKt(state: AircraftState) -> Double {
        let gs = state.groundSpeedKt ?? 0
        let alt = state.altitudeFt ?? 0
        if alt >= 26000 && gs > 280 { return gs }
        // Turboprops and regional types never reach jet speeds; use what we see as a hint.
        if let type = state.typeCode, ["AT72", "AT75", "AT76", "DH8D", "DH8C", "SF34", "AT45", "AT43"].contains(type) {
            return 270
        }
        return max(gs, 440)
    }

    /// Estimated seconds from `state.positionTime` until touchdown at the route's destination.
    static func secondsToLanding(state: AircraftState, route: FlightRoute) -> TimeInterval {
        let remaining = Geo.distanceKm(state.point, route.destination.point)

        if state.onGround || (state.groundSpeedKt ?? 0) < 60 {
            if remaining < 12 { return 0 }
            // Still at the gate or taxiing out: taxi + whole flight.
            let airMinutes = enrouteMinutes(km: route.distanceKm, cruiseKt: cruiseSpeedKt(state: state), climbing: true)
            return (12 + airMinutes) * 60
        }

        let climbing = (state.altitudeFt ?? 0) < 20000 && (state.verticalRateFpm ?? 0) > 300
            && Geo.distanceKm(route.origin.point, state.point) < 250
        let minutes = enrouteMinutes(km: remaining, cruiseKt: cruiseSpeedKt(state: state), climbing: climbing)
        return minutes * 60
    }

    private static func enrouteMinutes(km: Double, cruiseKt: Double, climbing: Bool) -> Double {
        let terminal = terminalRadiusKm
        if km <= terminal {
            return terminalMinutes(forKm: km)
        }
        // Flown routes are a little longer than the great circle.
        let cruiseKm = (km - terminal) * 1.035
        var minutes = cruiseKm / (cruiseKt * Geo.kmPerNM) * 60 + terminalMinutes(forKm: terminal)
        if climbing { minutes += 4 } // slower while climbing out
        return minutes
    }

    static func estimatedLanding(state: AircraftState, route: FlightRoute) -> Date {
        state.positionTime.addingTimeInterval(secondsToLanding(state: state, route: route))
    }

    // MARK: Landing detection

    /// True when a position report shows the aircraft down at its destination.
    static func hasLanded(state: AircraftState, route: FlightRoute) -> Bool {
        let remaining = Geo.distanceKm(state.point, route.destination.point)
        guard remaining < 14 else { return false }
        if state.onGround { return true }
        let above = Double(state.altitudeFt ?? 99_999) - Double(route.destination.elevationFt ?? 0)
        return above < 250 && (state.groundSpeedKt ?? 999) < 150 && remaining < 6
    }

    /// When the feed loses an aircraft low and close to its destination, it has almost certainly landed
    /// (receivers lose line of sight near the ground).
    static func vanishedOnFinal(lastSeen state: AircraftState, route: FlightRoute) -> Bool {
        let remaining = Geo.distanceKm(state.point, route.destination.point)
        let above = Double(state.altitudeFt ?? 99_999) - Double(route.destination.elevationFt ?? 0)
        return remaining < 35 && above < 6000
    }

    // MARK: Dead reckoning

    /// Where the aircraft should be `seconds` after `state.positionTime`: straight along its track while
    /// that is short, and never past the destination.
    static func projected(state: AircraftState, route: FlightRoute?, after seconds: TimeInterval) -> GeoPoint {
        guard seconds > 0, !state.onGround, let gs = state.groundSpeedKt, gs > 60 else { return state.point }
        let km = gs * Geo.kmPerNM * seconds / 3600
        if let route {
            let remaining = Geo.distanceKm(state.point, route.destination.point)
            if km >= remaining { return route.destination.point }
            // Beyond a couple of minutes the last known track is stale; steer along the route instead.
            if seconds > 120 {
                return Geo.destination(from: state.point, bearing: Geo.bearing(state.point, route.destination.point), distanceKm: km)
            }
        }
        guard let track = state.trackDeg else { return state.point }
        return Geo.destination(from: state.point, bearing: track, distanceKm: km)
    }

    // MARK: Formatting helpers shared by app and widget

    static func flightLevel(_ altitudeFt: Int?) -> String {
        guard let ft = altitudeFt else { return "—" }
        if ft >= 18000 { return String(format: "FL%03d", Int((Double(ft) / 100).rounded())) }
        return "\(ft) ft"
    }

    static func durationText(minutes: Int) -> String {
        let m = max(0, minutes)
        if m < 60 { return "\(m) 分钟" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h) 小时" : "\(h) 小时 \(r) 分"
    }

    static func shortDuration(minutes: Int) -> String {
        let m = max(0, minutes)
        if m < 60 { return "\(m)m" }
        let h = m / 60, r = m % 60
        return r == 0 ? "\(h)h" : "\(h)h\(String(format: "%02d", r))"
    }
}

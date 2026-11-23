import Foundation

/// A flight that could carry a focus session of the requested length.
struct FlightMatch: Identifiable, Hashable, Sendable {
    var flight: LiveFlight
    var minutesToLanding: Int
    var progress: RouteProgress
    /// Difference from the requested length, in minutes (negative lands early).
    var deltaMinutes: Int

    var id: String { flight.id }
}

enum Matching {
    /// How far from the requested length a flight may land and still count as a match.
    static func tolerance(forTarget minutes: Int) -> Int {
        max(5, Int((Double(minutes) * 0.12).rounded()))
    }

    /// Flights with routes, ranked by how closely their time to landing fits `targetMinutes`.
    static func rank(
        flights: [LiveFlight],
        targetMinutes: Int,
        destination: Airport?,
        now: Date,
        strict: Bool = true,
        maxAge: TimeInterval = 180
    ) -> [FlightMatch] {
        let window = tolerance(forTarget: targetMinutes)
        var out: [FlightMatch] = []
        for f in flights {
            guard let route = f.route else { continue }
            if let destination, route.destination.code != destination.code { continue }
            if f.state.onGround { continue }
            // Stale positions make for wrong estimates.
            guard now.timeIntervalSince(f.state.positionTime) < maxAge else { continue }
            let landing = FlightMath.estimatedLanding(state: f.state, route: route)
            let minutes = Int((landing.timeIntervalSince(now) / 60).rounded())
            guard minutes >= 3 else { continue }
            let delta = minutes - targetMinutes
            if strict && abs(delta) > window { continue }
            out.append(FlightMatch(
                flight: f,
                minutesToLanding: minutes,
                progress: FlightMath.progress(at: f.state.point, route: route),
                deltaMinutes: delta
            ))
        }
        out.sort { a, b in
            let da = abs(a.deltaMinutes), db = abs(b.deltaMinutes)
            if da != db { return da < db }
            return a.flight.id < b.flight.id
        }
        return out
    }

    /// Before a route is known, how promising is an aircraft for a session of `targetMinutes`?
    /// Higher is better; nil means not worth a route lookup. Used to spend lookups wisely.
    static func lookupPriority(state: AircraftState, targetMinutes: Int, destination: Airport?, now: Date, maxAge: TimeInterval = 180) -> Double? {
        guard state.hasAirlineCallsign, !state.onGround else { return nil }
        guard now.timeIntervalSince(state.positionTime) < maxAge else { return nil }
        let alt = state.altitudeFt ?? 0
        let gs = state.groundSpeedKt ?? 0
        guard gs > 120 else { return nil }
        let vs = state.verticalRateFpm ?? 0

        if let destination {
            let km = Geo.distanceKm(state.point, destination.point)
            guard km > 8 else { return nil }
            // Must be pointing roughly at it, unless already close in (arrival procedures wander).
            if km > 200, let track = state.trackDeg,
               Geo.angleDiff(track, Geo.bearing(state.point, destination.point)) > 40 { return nil }
            let minutes = SimFlight.minutes(forRemainingKm: km)
            let diff = abs(minutes - Double(targetMinutes))
            let window = Double(tolerance(forTarget: targetMinutes)) * 2.5 + 10
            guard diff <= window else { return nil }
            return 1000 - diff
        }

        // No destination: use altitude and vertical trend as a weak signal of time remaining.
        var score = 100.0
        if targetMinutes <= 25 {
            guard alt < 26000, vs < 300 else { return nil }
            score += vs < -300 ? 60 : 0
            score += alt < 15000 ? 30 : 0
        } else if targetMinutes <= 50 {
            if vs > 800 && alt < 15000 { return nil } // just departed; hours to go or a short hop — unknown
            score += vs < -300 ? 20 : 0
        } else {
            // Longer sessions need an aircraft still in cruise or climbing.
            guard alt > 24000 || vs > 500 else { return nil }
            guard vs > -500 else { return nil }
            if targetMinutes >= 150, let category = state.category, category == "A5" { score += 50 } // heavies fly far
        }
        return score
    }
}

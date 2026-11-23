import Foundation

/// A simulated flight for user-chosen routes. Position is a pure function of time and the planned
/// landing, so it needs no state and survives relaunches. Always labelled as simulated in the UI.
enum SimFlight {
    static let cruiseKt = 455.0
    static let cruiseAltFt = 36000

    /// Block time for the whole route in minutes (take-off roll to touchdown).
    static func fullMinutes(routeKm: Double) -> Double {
        minutes(forRemainingKm: routeKm) + 4
    }

    /// Minutes to touchdown from a given distance to run, mirroring `FlightMath`'s arrival model.
    static func minutes(forRemainingKm km: Double) -> Double {
        let terminal = FlightMath.terminalRadiusKm
        if km <= terminal { return FlightMath.terminalMinutes(forKm: km) }
        return (km - terminal) * 1.035 / (cruiseKt * Geo.kmPerNM) * 60 + FlightMath.terminalMinutes(forKm: terminal)
    }

    /// Inverse of `minutes(forRemainingKm:)`.
    static func remainingKm(forMinutes m: Double) -> Double {
        let table = FlightMath.terminalProfile
        if m <= table[0].minutes { return 0 }
        for i in 1..<table.count where m <= table[i].minutes {
            let a = table[i - 1], b = table[i]
            let t = (m - a.minutes) / (b.minutes - a.minutes)
            return a.km + t * (b.km - a.km)
        }
        let last = table[table.count - 1]
        return last.km + (m - last.minutes) / 60 * cruiseKt * Geo.kmPerNM / 1.035
    }

    static func state(route: FlightRoute, landing: Date, at now: Date, hex: String, callsign: String) -> AircraftState {
        let total = max(route.distanceKm, 1)
        let minutesLeft = landing.timeIntervalSince(now) / 60
        let remaining = min(max(remainingKm(forMinutes: minutesLeft), 0), total)
        let fraction = 1 - remaining / total
        let here = Geo.interpolate(route.origin.point, route.destination.point, fraction)
        let flown = total - remaining
        let landed = minutesLeft <= 0
        let notDeparted = remaining >= total

        // Simple vertical profile: climb over the first 190 km, descend over the last 230 km.
        let cruise = Double(min(cruiseAltFt, Int(8000 + total * 22)))
        let climbAlt = min(cruise, flown / 190 * cruise)
        let descentAlt = min(cruise, remaining / FlightMath.terminalRadiusKm * cruise)
        let altitude = landed || notDeparted ? 0 : max(0, min(climbAlt, descentAlt))
        let climbing = flown < 190 && climbAlt < descentAlt && climbAlt < cruise
        let descending = remaining < FlightMath.terminalRadiusKm && descentAlt < cruise && !climbing

        var speed = cruiseKt
        if climbing { speed = 250 + (cruiseKt - 250) * (flown / 190) }
        if descending { speed = 140 + (cruiseKt - 140) * min(1, remaining / FlightMath.terminalRadiusKm) }
        if landed || notDeparted { speed = 0 }

        let ahead = Geo.interpolate(route.origin.point, route.destination.point, min(1, fraction + 0.002))
        let track = fraction >= 0.998 ? Geo.bearing(route.origin.point, route.destination.point) : Geo.bearing(here, ahead)

        return AircraftState(
            hex: hex,
            callsign: callsign,
            registration: nil,
            typeCode: total > 4500 ? "A359" : "A21N",
            typeName: total > 4500 ? "AIRBUS A-350-900" : "AIRBUS A-321neo",
            lat: here.lat,
            lon: here.lon,
            altitudeFt: Int(altitude.rounded()),
            onGround: landed || notDeparted,
            groundSpeedKt: speed,
            trackDeg: track,
            verticalRateFpm: climbing ? 1800 : (descending ? -1500 : 0),
            mach: altitude > 28000 ? 0.78 : nil,
            positionTime: now,
            source: .sim
        )
    }

    /// Builds a simulated flight on a route with `minutes` left to run (capped at the full flight).
    static func make(
        origin: Airport,
        destination: Airport,
        minutes requested: Int,
        airlineICAO: String,
        flightDigits: Int,
        reference: ReferenceData,
        now: Date
    ) -> (flight: LiveFlight, landing: Date) {
        let km = Geo.distanceKm(origin.point, destination.point)
        let full = fullMinutes(routeKm: km)
        let minutes = min(Double(max(requested, 1)), full)
        let landing = now.addingTimeInterval(minutes * 60)
        let callsign = airlineICAO + String(flightDigits)
        let airline = reference.airline(icao: airlineICAO)
        let route = FlightRoute(
            callsign: callsign,
            flightNumber: (airline?.iata.isEmpty == false ? airline!.iata : airlineICAO) + String(flightDigits),
            airlineICAO: airlineICAO,
            airlineName: airline?.name,
            origin: origin,
            destination: destination,
            source: .sim
        )
        let hex = "sim" + String(format: "%05x", abs((origin.code + destination.code + callsign).hashValueStable) % 0xFFFFF)
        let s = state(route: route, landing: landing, at: now, hex: hex, callsign: callsign)
        return (LiveFlight(state: s, route: route), landing)
    }
}

extension String {
    /// A hash that is stable across launches (Swift's `hashValue` is randomised per process).
    var hashValueStable: Int {
        var h: UInt64 = 1469598103934665603
        for b in utf8 {
            h ^= UInt64(b)
            h = h &* 1099511628211
        }
        return Int(truncatingIfNeeded: h & 0x7FFF_FFFF_FFFF_FFFF)
    }
}

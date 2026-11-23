import Foundation

/// A self-contained world of flights for demos, screenshots and UI tests.
///
/// It answers the same URLs the live feeds do, with the same JSON shapes, so a demo run goes
/// through the real decoding, route resolution and session code. Nothing here is used unless
/// the app is launched with `-demo 1`.
final class DemoWorld: @unchecked Sendable {
    struct Leg: Sendable {
        var callsign: String
        var from: String
        var to: String
        /// Minutes until touchdown at the moment the demo started.
        var minutesLeft: Double
        var type: String
        var typeName: String
        var registration: String
        var hex: String
    }

    let reference: ReferenceData
    let startedAt: Date
    /// How many demo seconds pass per real second (UI tests fast-forward a flight to its landing).
    let speed: Double
    private let realStart = Date()

    let legs: [Leg] = [
        Leg(callsign: "ANA920", from: "PVG", to: "HND", minutesLeft: 61, type: "B789", typeName: "BOEING 787-9", registration: "JA873A", hex: "86e4b2"),
        Leg(callsign: "CCA1831", from: "PEK", to: "SHA", minutesLeft: 24, type: "A359", typeName: "AIRBUS A-350-900", registration: "B-1085", hex: "780a1b"),
        Leg(callsign: "CES2315", from: "XIY", to: "PVG", minutesLeft: 47, type: "A21N", typeName: "AIRBUS A-321neo", registration: "B-30EA", hex: "781c22"),
        Leg(callsign: "CSN3539", from: "CAN", to: "SHA", minutesLeft: 92, type: "B738", typeName: "BOEING 737-800", registration: "B-5718", hex: "780d44"),
        Leg(callsign: "CPA368", from: "HKG", to: "PVG", minutesLeft: 68, type: "A333", typeName: "AIRBUS A-330-300", registration: "B-LAJ", hex: "780233"),
        Leg(callsign: "JAL82", from: "SHA", to: "HND", minutesLeft: 133, type: "B788", typeName: "BOEING 787-8", registration: "JA840J", hex: "86d5c1"),
        Leg(callsign: "KAL894", from: "PVG", to: "ICN", minutesLeft: 38, type: "A333", typeName: "AIRBUS A-330-300", registration: "HL7702", hex: "71be02"),
        Leg(callsign: "SIA833", from: "PVG", to: "SIN", minutesLeft: 241, type: "A388", typeName: "AIRBUS A-380-800", registration: "9V-SKU", hex: "76cdb5"),
        Leg(callsign: "DLH729", from: "PVG", to: "FRA", minutesLeft: 598, type: "B748", typeName: "BOEING 747-8", registration: "D-ABYT", hex: "3c4b34"),
        Leg(callsign: "UAL858", from: "PVG", to: "SFO", minutesLeft: 492, type: "B77W", typeName: "BOEING 777-300ER", registration: "N2749U", hex: "a2c6f1"),
        Leg(callsign: "CHH7604", from: "PVG", to: "SZX", minutesLeft: 74, type: "B789", typeName: "BOEING 787-9", registration: "B-7667", hex: "781f09"),
        Leg(callsign: "EVA711", from: "TPE", to: "PVG", minutesLeft: 16, type: "A321", typeName: "AIRBUS A-321", registration: "B-16227", hex: "899121"),
        Leg(callsign: "CXA8502", from: "XMN", to: "SHA", minutesLeft: 55, type: "B38M", typeName: "BOEING 737 MAX 8", registration: "B-20C2", hex: "781a77"),
        Leg(callsign: "CSC8963", from: "CTU", to: "PVG", minutesLeft: 121, type: "A20N", typeName: "AIRBUS A-320neo", registration: "B-325A", hex: "781b90"),
        Leg(callsign: "UAE302", from: "DXB", to: "PVG", minutesLeft: 187, type: "A388", typeName: "AIRBUS A-380-800", registration: "A6-EUV", hex: "896472"),
        Leg(callsign: "BAW169", from: "LHR", to: "PVG", minutesLeft: 271, type: "B789", typeName: "BOEING 787-9", registration: "G-ZBKP", hex: "407973"),
        Leg(callsign: "QFA129", from: "SYD", to: "PVG", minutesLeft: 356, type: "A332", typeName: "AIRBUS A-330-200", registration: "VH-EBG", hex: "7c1470"),
        Leg(callsign: "DKH1253", from: "PVG", to: "KIX", minutesLeft: 71, type: "B789", typeName: "BOEING 787-9", registration: "B-20D1", hex: "781e55")
    ]

    init(reference: ReferenceData, speed: Double = 1) {
        self.reference = reference
        self.speed = max(speed, 1)
        self.startedAt = Date()
    }

    /// Demo time. Runs from the real launch time, optionally faster than real time.
    func now() -> Date {
        startedAt.addingTimeInterval(Date().timeIntervalSince(realStart) * speed)
    }

    private func route(for leg: Leg) -> FlightRoute? {
        guard let o = reference.airport(code: leg.from), let d = reference.airport(code: leg.to) else { return nil }
        let code = String(leg.callsign.prefix(3))
        let airline = reference.airline(icao: code)
        let digits = String(leg.callsign.dropFirst(3))
        return FlightRoute(
            callsign: leg.callsign,
            flightNumber: (airline?.iata.isEmpty == false ? airline!.iata : code) + digits,
            airlineICAO: code,
            airlineName: airline?.name,
            origin: o,
            destination: d,
            source: .vrs
        )
    }

    func state(for leg: Leg, at time: Date) -> AircraftState? {
        guard let route = route(for: leg) else { return nil }
        let landing = startedAt.addingTimeInterval(leg.minutesLeft * 60)
        var s = SimFlight.state(route: route, landing: landing, at: time, hex: leg.hex, callsign: leg.callsign)
        s.typeCode = leg.type
        s.typeName = leg.typeName
        s.registration = leg.registration
        return s
    }

    private func readsbObject(_ s: AircraftState) -> [String: Any] {
        var o: [String: Any] = [
            "hex": s.hex, "type": "adsb_icao", "flight": s.callsign.padding(toLength: 8, withPad: " ", startingAt: 0),
            "lat": s.lat, "lon": s.lon, "gs": s.groundSpeedKt ?? 0, "track": s.trackDeg ?? 0,
            "baro_rate": s.verticalRateFpm ?? 0, "seen_pos": 0.4, "seen": 0.2, "category": "A3", "squawk": "2341"
        ]
        if s.onGround { o["alt_baro"] = "ground" } else { o["alt_baro"] = s.altitudeFt ?? 0 }
        if let r = s.registration { o["r"] = r }
        if let t = s.typeCode { o["t"] = t }
        if let d = s.typeName { o["desc"] = d }
        if let m = s.mach { o["mach"] = m }
        if (s.altitudeFt ?? 0) > 28000 {
            o["oat"] = -52
            o["wd"] = 262
            o["ws"] = 74
            o["ias"] = 271
            o["tas"] = Int((s.groundSpeedKt ?? 450) - 12)
        }
        return o
    }

    private func states(at time: Date) -> [AircraftState] {
        legs.compactMap { state(for: $0, at: time) }
    }

    private func json(_ object: Any) -> Data {
        (try? JSONSerialization.data(withJSONObject: object)) ?? Data("{}".utf8)
    }

    /// Answers a feed URL, or nil for anything this world does not know.
    func respond(to url: URL) -> HTTPResult? {
        let host = url.host ?? ""
        let parts = url.path.split(separator: "/").map(String.init)
        let time = now()

        if host.contains("adsb.fi") || host.contains("api.adsb.lol") {
            var list = states(at: time)
            if let i = parts.firstIndex(of: "hex"), i + 1 < parts.count {
                list = list.filter { $0.hex == parts[i + 1].lowercased() }
                // Once parked for a while, the airframe drops off the feed like a real one.
                list = list.filter { s in
                    guard let leg = legs.first(where: { $0.hex == s.hex }) else { return false }
                    return time.timeIntervalSince(startedAt.addingTimeInterval(leg.minutesLeft * 60)) < 900
                }
            } else if let i = parts.firstIndex(of: "callsign"), i + 1 < parts.count {
                list = list.filter { $0.callsign == parts[i + 1].uppercased() }
            } else if let center = pointQuery(parts) {
                list = list.filter { Geo.distanceKm($0.point, center.point) <= center.km && !($0.onGround && ($0.groundSpeedKt ?? 0) == 0) }
            }
            return HTTPResult(status: 200, data: json(["ac": list.map(readsbObject), "msg": "No error", "total": list.count] as [String: Any]), retryAfter: nil)
        }

        if host.contains("opensky-network.org") {
            let rows: [[Any]] = states(at: time).filter { !$0.onGround }.map { s -> [Any] in
                let t = Int(time.timeIntervalSince1970)
                return [
                    s.hex, s.callsign.padding(toLength: 8, withPad: " ", startingAt: 0), "Demo", t, t,
                    s.lon, s.lat, Double(s.altitudeFt ?? 0) / 3.28084, false,
                    (s.groundSpeedKt ?? 0) / 1.943844, s.trackDeg ?? 0, Double(s.verticalRateFpm ?? 0) / 196.8504,
                    NSNull(), Double(s.altitudeFt ?? 0) / 3.28084, "2341", false, 0, 4
                ]
            }
            return HTTPResult(status: 200, data: json(["time": Int(time.timeIntervalSince1970), "states": rows] as [String: Any]), retryAfter: nil)
        }

        if host.contains("vrs-standing-data") {
            let callsign = (parts.last ?? "").replacingOccurrences(of: ".json", with: "")
            guard let leg = legs.first(where: { $0.callsign == callsign }), let route = route(for: leg) else {
                return HTTPResult(status: 404, data: Data(), retryAfter: nil)
            }
            func stop(_ a: Airport) -> [String: Any] {
                ["name": a.nameEN, "icao": a.icao, "iata": a.iata, "location": a.cityEN, "countryiso2": a.country,
                 "lat": a.lat, "lon": a.lon, "alt_feet": a.elevationFt ?? 0]
            }
            return HTTPResult(status: 200, data: json([
                "callsign": callsign, "number": String(callsign.dropFirst(3)), "airline_code": String(callsign.prefix(3)),
                "_airports": [stop(route.origin), stop(route.destination)]
            ] as [String: Any]), retryAfter: nil)
        }

        return nil
    }

    private func pointQuery(_ parts: [String]) -> (point: GeoPoint, km: Double)? {
        // adsb.fi: /api/v3/lat/{lat}/lon/{lon}/dist/{nm}   adsb.lol: /v2/point/{lat}/{lon}/{nm}
        if let i = parts.firstIndex(of: "lat"), i + 5 < parts.count,
           let lat = Double(parts[i + 1]), let lon = Double(parts[i + 3]), let nm = Double(parts[i + 5]) {
            return (GeoPoint(lat, lon), nm * Geo.kmPerNM)
        }
        if let i = parts.firstIndex(of: "point"), i + 3 < parts.count,
           let lat = Double(parts[i + 1]), let lon = Double(parts[i + 2]), let nm = Double(parts[i + 3]) {
            return (GeoPoint(lat, lon), nm * Geo.kmPerNM)
        }
        return nil
    }

    // MARK: Seed logbook

    /// A believable month of history so the logbook and statistics have something to show in a demo.
    func seedRecords(calendar: Calendar) -> [FocusRecord] {
        let plan: [(day: Int, hour: Int, minutes: Int, callsign: String, from: String, to: String, type: String, tag: FocusTag, landed: Bool)] = [
            (0, 9, 82, "ANA920", "PVG", "HND", "B789", .coding, true),
            (1, 14, 55, "CCA1831", "PEK", "SHA", "A359", .deepWork, true),
            (1, 20, 96, "CPA368", "HKG", "PVG", "A333", .reading, true),
            (2, 10, 121, "SIA833", "PVG", "SIN", "A388", .coding, true),
            (3, 15, 44, "KAL894", "PVG", "ICN", "A333", .study, true),
            (4, 9, 63, "CES2315", "XIY", "PVG", "A21N", .writing, true),
            (4, 21, 32, "EVA711", "TPE", "PVG", "A321", .reading, false),
            (6, 13, 148, "UAE302", "DXB", "PVG", "A388", .deepWork, true),
            (7, 10, 71, "DKH1253", "PVG", "KIX", "B789", .coding, true),
            (8, 16, 90, "CSN3539", "CAN", "SHA", "B738", .study, true),
            (9, 9, 58, "CXA8502", "XMN", "SHA", "B38M", .creative, true),
            (11, 19, 133, "JAL82", "SHA", "HND", "B788", .coding, true),
            (12, 8, 46, "CCA1831", "PEK", "SHA", "A359", .deepWork, true),
            (14, 14, 105, "CHH7604", "PVG", "SZX", "B789", .writing, true),
            (15, 10, 176, "BAW169", "LHR", "PVG", "B789", .coding, true),
            (17, 15, 62, "ANA920", "PVG", "HND", "B789", .study, true),
            (19, 20, 88, "CSC8963", "CTU", "PVG", "A20N", .reading, true),
            (22, 9, 204, "QFA129", "SYD", "PVG", "A332", .deepWork, true),
            (25, 13, 51, "KAL894", "PVG", "ICN", "A333", .coding, false),
            (27, 10, 119, "CPA368", "HKG", "PVG", "A333", .creative, true)
        ]
        let today = calendar.startOfDay(for: now())
        var out: [FocusRecord] = []
        for (index, p) in plan.enumerated() {
            guard let o = reference.airport(code: p.from), let d = reference.airport(code: p.to),
                  let day = calendar.date(byAdding: .day, value: -p.day, to: today),
                  let start = calendar.date(byAdding: .minute, value: p.hour * 60 + (index * 7) % 40, to: day) else { continue }
            // Only history: nothing in the future.
            guard start.addingTimeInterval(Double(p.minutes) * 60) < now() else { continue }
            let code = String(p.callsign.prefix(3))
            let airline = reference.airline(icao: code)
            let routeKm = Geo.distanceKm(o.point, d.point)
            let km = min(routeKm * 0.96, SimFlight.remainingKm(forMinutes: Double(p.minutes)))
            let boarded = max(0, 1 - km / routeKm)
            let endFraction = p.landed ? 1.0 : min(0.97, boarded + 0.5 * (1 - boarded))
            let path = Geo.arc(Geo.interpolate(o.point, d.point, boarded), Geo.interpolate(o.point, d.point, endFraction), segments: 16)
            let cruise = min(38000, Int(8000 + routeKm * 22))
            let profile: [Int] = (0..<24).map { i in
                let f = boarded + (endFraction - boarded) * Double(i) / 23
                let remaining = routeKm * (1 - f)
                return Int(min(Double(cruise), remaining / FlightMath.terminalRadiusKm * Double(cruise)))
            }
            out.append(FocusRecord(
                id: UUID(),
                flightNumber: (airline?.iata.isEmpty == false ? airline!.iata : code) + String(p.callsign.dropFirst(3)),
                callsign: p.callsign,
                airlineICAO: code,
                airlineName: airline?.name,
                registration: legs.first(where: { $0.callsign == p.callsign })?.registration,
                typeCode: p.type,
                typeName: nil,
                origin: o,
                destination: d,
                tag: p.tag,
                seat: Seating.windowSeat(cabin: .business, seed: index * 37 + 5),
                cabin: .business,
                gate: Seating.gate(seed: index * 13 + 3),
                sequence: 12 + (index * 17) % 140,
                startedAt: start,
                endedAt: start.addingTimeInterval(Double(p.minutes) * 60),
                focusSeconds: p.minutes * 60,
                pausedSeconds: 0,
                pauseCount: 0,
                distanceKm: p.landed ? km : km * 0.5,
                routeKm: routeKm,
                boardedFraction: boarded,
                endFraction: endFraction,
                outcome: p.landed ? .landed : .endedEarly,
                simulated: false,
                landingEstimated: false,
                maxAltitudeFt: cruise,
                path: path,
                altitudeProfile: profile
            ))
        }
        return out.sorted { $0.startedAt > $1.startedAt }
    }
}

/// Serves `DemoWorld` to the networking layer in place of the internet.
final class DemoFetcher: HTTPFetching, @unchecked Sendable {
    let world: DemoWorld
    /// Requests the demo does not answer itself (map imagery is not routed through here).
    private let passthrough: HTTPFetching?

    init(world: DemoWorld, passthrough: HTTPFetching? = nil) {
        self.world = world
        self.passthrough = passthrough
    }

    func get(_ url: URL, timeout: TimeInterval) async throws -> HTTPResult {
        if let hit = world.respond(to: url) {
            // A little latency so loading states are visible, as they are on a real network.
            try? await Task.sleep(nanoseconds: 60_000_000)
            return hit
        }
        if let passthrough { return try await passthrough.get(url, timeout: timeout) }
        return HTTPResult(status: 404, data: Data(), retryAfter: nil)
    }
}

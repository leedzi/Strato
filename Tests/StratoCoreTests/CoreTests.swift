import XCTest
@testable import StratoCore

enum Fixtures {
    static let pvg = Airport(iata: "PVG", icao: "ZSPD", lat: 31.1443, lon: 121.8083, elevationFt: 13, country: "CN", tz: "Asia/Shanghai", size: .large, cityEN: "Shanghai", nameEN: "Shanghai Pudong International Airport", cityZH: "上海浦东", nameZH: "上海浦东国际机场")
    static let hnd = Airport(iata: "HND", icao: "RJTT", lat: 35.5494, lon: 139.7798, elevationFt: 21, country: "JP", tz: "Asia/Tokyo", size: .large, cityEN: "Tokyo", nameEN: "Tokyo Haneda Airport", cityZH: "东京羽田", nameZH: "东京国际机场")
    static let lhr = Airport(iata: "LHR", icao: "EGLL", lat: 51.4700, lon: -0.4543, elevationFt: 83, country: "GB", tz: "Europe/London", size: .large, cityEN: "London", nameEN: "London Heathrow Airport", cityZH: "伦敦希思罗", nameZH: "伦敦希思罗机场")
    static let jfk = Airport(iata: "JFK", icao: "KJFK", lat: 40.6413, lon: -73.7781, elevationFt: 13, country: "US", tz: "America/New_York", size: .large, cityEN: "New York", nameEN: "John F. Kennedy International Airport", cityZH: "纽约肯尼迪", nameZH: "肯尼迪国际机场")
    static let muc = Airport(iata: "MUC", icao: "EDDM", lat: 48.3538, lon: 11.7861, elevationFt: 1487, country: "DE", tz: "Europe/Berlin", size: .large, cityEN: "Munich", nameEN: "Munich Airport", cityZH: "慕尼黑", nameZH: "慕尼黑机场")
    static let dus = Airport(iata: "DUS", icao: "EDDL", lat: 51.2895, lon: 6.7668, elevationFt: 147, country: "DE", tz: "Europe/Berlin", size: .large, cityEN: "Düsseldorf", nameEN: "Düsseldorf Airport", cityZH: "杜塞尔多夫", nameZH: "杜塞尔多夫机场")

    static let reference = ReferenceData(
        airports: [pvg, hnd, lhr, jfk, muc, dus],
        airlines: [
            Airline(icao: "CCA", iata: "CA", nameEN: "Air China", nameZH: "中国国际航空", country: "CN", callsign: "AIR CHINA"),
            Airline(icao: "DLH", iata: "LH", nameEN: "Lufthansa", nameZH: "汉莎航空", country: "DE", callsign: "LUFTHANSA"),
            Airline(icao: "ANA", iata: "NH", nameEN: "All Nippon Airways", nameZH: "全日空", country: "JP", callsign: "ALL NIPPON")
        ]
    )

    static let t0 = Date(timeIntervalSince1970: 1_795_000_000)

    static func route(_ o: Airport, _ d: Airport, callsign: String = "ANA920", number: String? = "NH920") -> FlightRoute {
        FlightRoute(callsign: callsign, flightNumber: number, airlineICAO: String(callsign.prefix(3)), airlineName: nil, origin: o, destination: d, source: .vrs)
    }

    /// An airliner at `fraction` along a route, pointed at the destination.
    static func cruising(_ route: FlightRoute, fraction: Double, at time: Date = t0, alt: Int = 36000, gs: Double = 460, vs: Int = 0, hex: String = "abc123") -> AircraftState {
        let p = Geo.interpolate(route.origin.point, route.destination.point, fraction)
        return AircraftState(
            hex: hex, callsign: route.callsign, registration: "JA873A", typeCode: "B789", typeName: "BOEING 787-9",
            lat: p.lat, lon: p.lon, altitudeFt: alt, onGround: false, groundSpeedKt: gs,
            trackDeg: Geo.bearing(p, route.destination.point), verticalRateFpm: vs,
            positionTime: time, source: .adsbfi
        )
    }

    static func nearDestination(_ route: FlightRoute, km: Double, at time: Date = t0, alt: Int = 5675, gs: Double? = 160, vs: Int = -700, hex: String = "abc123") -> AircraftState {
        let p = Geo.destination(from: route.destination.point, bearing: Geo.bearing(route.destination.point, route.origin.point), distanceKm: km)
        var state = cruising(route, fraction: 1, at: time, alt: alt, gs: gs ?? 0, vs: vs, hex: hex)
        state.lat = p.lat
        state.lon = p.lon
        state.groundSpeedKt = gs
        return state
    }
}

final class GeoTests: XCTestCase {
    func testDistanceAndBearing() {
        let d = Geo.distanceKm(Fixtures.pvg.point, Fixtures.hnd.point)
        XCTAssertEqual(d, 1740, accuracy: 25) // PVG–HND great circle
        let lhrJfk = Geo.distanceKm(Fixtures.lhr.point, Fixtures.jfk.point)
        XCTAssertEqual(lhrJfk, 5540, accuracy: 30)
        XCTAssertEqual(Geo.bearing(GeoPoint(0, 0), GeoPoint(10, 0)), 0, accuracy: 0.001)
        XCTAssertEqual(Geo.bearing(GeoPoint(0, 0), GeoPoint(0, 10)), 90, accuracy: 0.001)
        XCTAssertEqual(Geo.angleDiff(350, 10), 20, accuracy: 0.001)
        XCTAssertEqual(Geo.angleDiff(10, 350), 20, accuracy: 0.001)
    }

    func testInterpolateAndDestinationAgree() {
        let a = Fixtures.lhr.point, b = Fixtures.jfk.point
        let mid = Geo.interpolate(a, b, 0.5)
        XCTAssertEqual(Geo.distanceKm(a, mid), Geo.distanceKm(mid, b), accuracy: 0.5)
        XCTAssertEqual(Geo.interpolate(a, b, 0).lat, a.lat, accuracy: 1e-6)
        XCTAssertEqual(Geo.interpolate(a, b, 1).lon, b.lon, accuracy: 1e-6)

        let moved = Geo.destination(from: a, bearing: Geo.bearing(a, b), distanceKm: 1000)
        XCTAssertEqual(Geo.distanceKm(a, moved), 1000, accuracy: 0.5)
        XCTAssertEqual(Geo.distanceKm(moved, b), Geo.distanceKm(a, b) - 1000, accuracy: 2)
    }

    func testDateLineWrap() {
        let p = Geo.destination(from: GeoPoint(0, 179.5), bearing: 90, distanceKm: 200)
        XCTAssertLessThan(p.lon, -178)
        XCTAssertEqual(Geo.normalizeLon(190), -170, accuracy: 1e-9)
        XCTAssertEqual(Geo.normalizeLon(-190), 170, accuracy: 1e-9)
    }

    func testGCJOffsetInBeijing() {
        // Tiananmen: WGS-84 (39.9075, 116.3913) is GCJ-02 (39.9089, 116.3975) to within a few metres.
        let g = GCJ02.fromWGS(GeoPoint(39.9075, 116.3913))
        XCTAssertEqual(g.lat, 39.9089, accuracy: 0.0004)
        XCTAssertEqual(g.lon, 116.3975, accuracy: 0.0004)
    }

    func testChinaRegion() {
        for inside in [GeoPoint(39.9, 116.4), GeoPoint(31.2, 121.5), GeoPoint(23.1, 113.3), GeoPoint(30.6, 104.1), GeoPoint(43.8, 87.6), GeoPoint(29.6, 91.1), GeoPoint(45.8, 126.5), GeoPoint(22.3, 114.2)] {
            XCTAssertTrue(ChinaRegion.contains(inside), "\(inside) should be inside")
        }
        for outside in [GeoPoint(35.68, 139.76), GeoPoint(37.56, 126.97), GeoPoint(25.03, 121.56), GeoPoint(21.03, 105.85), GeoPoint(47.9, 106.9), GeoPoint(27.7, 85.3), GeoPoint(43.1, 131.9), GeoPoint(1.35, 103.8), GeoPoint(51.5, -0.1)] {
            XCTAssertFalse(ChinaRegion.contains(outside), "\(outside) should be outside")
        }
        let shifted = ChinaRegion.displayPoint(GeoPoint(31.2, 121.5), gcjActive: true)
        XCTAssertGreaterThan(Geo.distanceKm(shifted, GeoPoint(31.2, 121.5)), 0.2)
        XCTAssertEqual(ChinaRegion.displayPoint(GeoPoint(35.68, 139.76), gcjActive: true), GeoPoint(35.68, 139.76))
        XCTAssertEqual(ChinaRegion.displayPoint(GeoPoint(31.2, 121.5), gcjActive: false), GeoPoint(31.2, 121.5))
    }

    func testSolarElevation() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let equinoxNoon = utc.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 12, minute: 8))!
        XCTAssertGreaterThan(Solar.elevation(at: GeoPoint(0, 0), date: equinoxNoon), 86)
        let midnight = utc.date(from: DateComponents(year: 2026, month: 3, day: 20, hour: 0, minute: 8))!
        XCTAssertLessThan(Solar.elevation(at: GeoPoint(0, 0), date: midnight), -86)
        // Shanghai at 04:00 UTC (noon local) in June is high sun; at 16:00 UTC (midnight local) it is night.
        let june = utc.date(from: DateComponents(year: 2026, month: 6, day: 21, hour: 4))!
        XCTAssertEqual(Solar.sky(at: Fixtures.pvg.point, date: june), .day)
        XCTAssertEqual(Solar.sky(at: Fixtures.pvg.point, date: june.addingTimeInterval(12 * 3600)), .night)
    }
}

final class FlightMathTests: XCTestCase {
    func testProgress() {
        let route = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        let s = Fixtures.cruising(route, fraction: 0.64)
        let p = FlightMath.progress(at: s.point, route: route)
        XCTAssertEqual(p.fraction, 0.64, accuracy: 0.005)
        XCTAssertEqual(p.flownKm + p.remainingKm, route.distanceKm, accuracy: 1)
    }

    func testPlausibility() {
        let route = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        XCTAssertTrue(FlightMath.isPlausible(state: Fixtures.cruising(route, fraction: 0.5), origin: route.origin, destination: route.destination))

        // Same callsign seen over Europe: not this route.
        var elsewhere = Fixtures.cruising(route, fraction: 0.5)
        elsewhere.lat = 50; elsewhere.lon = 8
        XCTAssertFalse(FlightMath.isPlausible(state: elsewhere, origin: route.origin, destination: route.destination))

        // On the route but flying away from the destination: the return leg.
        var reversed = Fixtures.cruising(route, fraction: 0.5)
        reversed.trackDeg = Geo.bearing(reversed.point, route.origin.point)
        XCTAssertFalse(FlightMath.isPlausible(state: reversed, origin: route.origin, destination: route.destination))

        // Near the destination any heading is fine (holding, downwind).
        var downwind = Fixtures.cruising(route, fraction: 0.97, alt: 6000, gs: 220)
        downwind.trackDeg = Geo.bearing(downwind.point, route.origin.point)
        XCTAssertTrue(FlightMath.isPlausible(state: downwind, origin: route.origin, destination: route.destination))
    }

    func testTimeToLandingIsMonotonicAndSane() {
        let route = Fixtures.route(Fixtures.lhr, Fixtures.jfk, callsign: "BAW117", number: "BA117")
        var previous = Double.infinity
        for f in stride(from: 0.05, through: 0.99, by: 0.02) {
            let s = Fixtures.cruising(route, fraction: f, gs: 450)
            let secs = FlightMath.secondsToLanding(state: s, route: route)
            XCTAssertLessThan(secs, previous, "time to landing must fall as the aircraft advances (f=\(f))")
            previous = secs
        }
        // Halfway across the Atlantic at 450 kt: about 2770 km to run, roughly 3.3–3.8 hours.
        let half = FlightMath.secondsToLanding(state: Fixtures.cruising(route, fraction: 0.5, gs: 450), route: route) / 60
        XCTAssertGreaterThan(half, 195)
        XCTAssertLessThan(half, 230)
    }

    func testZeroOrMissingSpeedDoesNotRestartAnAirborneRoute() {
        let route = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        for speed in [nil, 0, 45, 160] as [Double?] {
            for km in [10.0, 14.0] {
                let fix = Fixtures.nearDestination(route, km: km, gs: speed)
                XCTAssertFalse(FlightMath.isGrounded(state: fix, route: route))
                XCTAssertFalse(FlightMath.hasLanded(state: fix, route: route))
                XCTAssertTrue(FlightMath.isPlausible(state: fix, origin: route.origin, destination: route.destination))
                XCTAssertEqual(FlightMath.secondsToLanding(state: fix, route: route), FlightMath.terminalMinutes(forKm: km) * 60, accuracy: 0.01)
            }
            var cruise = Fixtures.cruising(route, fraction: 0.5, gs: 440)
            let airborneEstimate = FlightMath.secondsToLanding(state: cruise, route: route)
            cruise.groundSpeedKt = speed
            XCTAssertEqual(FlightMath.secondsToLanding(state: cruise, route: route), airborneEstimate, accuracy: 0.01)
        }
    }

    func testMissingAltitudeAndSpeedAreNotGroundEvidence() {
        let route = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        var fix = Fixtures.nearDestination(route, km: 10, gs: nil)
        fix.altitudeFt = nil
        XCTAssertFalse(FlightMath.isGrounded(state: fix, route: route))
        XCTAssertGreaterThan(FlightMath.secondsToLanding(state: fix, route: route), 120)
    }

    func testGroundDepartureStillIncludesTaxiAndUsesFieldElevation() {
        let route = Fixtures.route(Fixtures.muc, Fixtures.dus)
        var parked = Fixtures.cruising(route, fraction: 0, alt: Fixtures.muc.elevationFt! + 30, gs: 0)
        let departing = Fixtures.cruising(route, fraction: 0, alt: 9000, gs: 250, vs: 1800)
        let expected = FlightMath.secondsToLanding(state: departing, route: route) + 12 * 60
        XCTAssertTrue(FlightMath.isGrounded(state: parked, route: route))
        XCTAssertEqual(FlightMath.phase(state: parked, route: route), .ground)
        XCTAssertEqual(FlightMath.secondsToLanding(state: parked, route: route), expected, accuracy: 0.01)
        parked.onGround = true
        parked.altitudeFt = nil
        parked.groundSpeedKt = nil
        XCTAssertEqual(FlightMath.secondsToLanding(state: parked, route: route), expected, accuracy: 0.01)
    }

    func testTerminalProfileMatchesObservations() {
        // Medians observed from real arrivals (km to run -> minutes to touchdown), ±2.5 min.
        let observed: [(Double, Double)] = [(17.5, 4.5), (35, 8.0), (64, 12.8), (100, 16.2), (145, 20.7), (201, 25.2), (264, 30.0)]
        for (km, minutes) in observed {
            XCTAssertEqual(FlightMath.terminalMinutes(forKm: km), minutes, accuracy: 2.5, "at \(km) km")
        }
        XCTAssertEqual(FlightMath.terminalMinutes(forKm: 0), 0.7, accuracy: 0.01)
    }

    func testPhases() {
        let route = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        XCTAssertEqual(FlightMath.phase(state: Fixtures.cruising(route, fraction: 0.5), route: route), .cruise)
        XCTAssertEqual(FlightMath.phase(state: Fixtures.cruising(route, fraction: 0.04, alt: 9000, gs: 290, vs: 2200), route: route), .climb)
        XCTAssertEqual(FlightMath.phase(state: Fixtures.cruising(route, fraction: 0.90, alt: 21000, gs: 380, vs: -1800), route: route), .descent)
        XCTAssertEqual(FlightMath.phase(state: Fixtures.cruising(route, fraction: 0.99, alt: 2500, gs: 160, vs: -700), route: route), .approach)
        var down = Fixtures.cruising(route, fraction: 1.0, alt: 0, gs: 20)
        down.onGround = true
        XCTAssertEqual(FlightMath.phase(state: down, route: route), .landed)
        XCTAssertTrue(FlightMath.hasLanded(state: down, route: route))
        var parked = Fixtures.cruising(route, fraction: 0.0, alt: 0, gs: 0)
        parked.onGround = true
        XCTAssertEqual(FlightMath.phase(state: parked, route: route), .ground)
        XCTAssertFalse(FlightMath.hasLanded(state: parked, route: route))
    }

    func testProjectionNeverOvershootsDestination() {
        let route = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        let s = Fixtures.cruising(route, fraction: 0.9)
        let far = FlightMath.projected(state: s, route: route, after: 4 * 3600)
        XCTAssertEqual(Geo.distanceKm(far, route.destination.point), 0, accuracy: 0.01)
        let soon = FlightMath.projected(state: s, route: route, after: 60)
        XCTAssertEqual(Geo.distanceKm(s.point, soon), 460 * 1.852 / 60, accuracy: 0.2)
    }

    func testCallsignShapes() {
        XCTAssertTrue(Callsign.isAirline("CCA1831"))
        XCTAssertTrue(Callsign.isAirline("DLH2HT"))
        XCTAssertTrue(Callsign.isAirline("BAW9"))
        XCTAssertFalse(Callsign.isAirline("N123AB"))
        XCTAssertFalse(Callsign.isAirline("GABCD"))
        XCTAssertFalse(Callsign.isAirline(""))
        XCTAssertFalse(Callsign.isAirline("CCA"))
        XCTAssertFalse(Callsign.isSafeForURL("AB/../X"))
        XCTAssertEqual(Callsign.clean(" ana920  "), "ANA920")
    }
}

final class FeedTests: XCTestCase {
    func testReadsbDecoding() throws {
        let json = """
        {"ac":[
         {"hex":"3C66A2","type":"adsb_icao","flight":"DLH2HT  ","r":"D-AIUB","t":"A320","desc":"AIRBUS A-320","alt_baro":22225,"gs":373.6,"ias":252,"tas":448,"mach":0.848,"oat":-40,"wd":252,"ws":97,"track":320.43,"roll":-0.18,"baro_rate":-1408,"squawk":"1000","category":"A3","nav_altitude_mcp":14016,"lat":50.944839,"lon":8.399122,"seen_pos":0.37,"seen":0.2},
         {"hex":"780a1b","flight":"CCA1831 ","alt_baro":"ground","gs":12.5,"lat":40.07,"lon":116.6,"seen_pos":3.0},
         {"hex":"~2a0001","flight":"TEST    ","alt_baro":1000,"lat":1.0,"lon":1.0},
         {"hex":"abcdef","flight":"NOPOS   ","alt_baro":35000},
         {"hex":"aaaaaa","alt_baro":31000.0,"baro_rate":64.0,"lat":10.5,"lon":20.5}
        ],"msg":"No error","now":1795422788000,"total":5}
        """.data(using: .utf8)!
        let list = try XCTUnwrap(Feeds.decodeReadsb(json, source: .adsbfi, fetchedAt: Fixtures.t0))
        XCTAssertEqual(list.count, 3) // anonymised and position-less entries are dropped

        let dlh = list[0]
        XCTAssertEqual(dlh.hex, "3c66a2")
        XCTAssertEqual(dlh.callsign, "DLH2HT")
        XCTAssertEqual(dlh.altitudeFt, 22225)
        XCTAssertEqual(dlh.verticalRateFpm, -1408)
        XCTAssertEqual(dlh.outsideTempC, -40)
        XCTAssertEqual(dlh.typeCode, "A320")
        XCTAssertEqual(dlh.positionTime.timeIntervalSince(Fixtures.t0), -0.37, accuracy: 0.001)
        XCTAssertFalse(dlh.onGround)
        XCTAssertTrue(dlh.isAirborne)

        let cca = list[1]
        XCTAssertTrue(cca.onGround)
        XCTAssertEqual(cca.altitudeFt, 0)
        XCTAssertFalse(cca.isAirborne)

        XCTAssertEqual(list[2].altitudeFt, 31000) // fractional numbers still decode
        XCTAssertEqual(list[2].verticalRateFpm, 64)
        XCTAssertEqual(list[2].callsign, "")

        XCTAssertNil(Feeds.decodeReadsb(Data("not json".utf8), source: .adsbfi, fetchedAt: Fixtures.t0))
        XCTAssertEqual(Feeds.decodeReadsb(Data("{\"ac\":[],\"total\":0}".utf8), source: .adsblol, fetchedAt: Fixtures.t0)?.count, 0)
    }

    func testOpenSkyDecoding() throws {
        let json = """
        {"time":1795000000,"states":[
         ["39de4e","TVF55MC ","France",1794999990,1794999995,-0.9785,43.7736,11887.2,false,214.21,207.3,0,null,12047.22,"7640",false,0,6],
         ["780abc","CCA981  ","China",1794999998,1794999999,116.6,40.07,null,true,5.1,90.0,null,null,null,null,false,0],
         ["bad"]
        ]}
        """.data(using: .utf8)!
        let list = try XCTUnwrap(Feeds.decodeOpenSky(json, fetchedAt: Fixtures.t0))
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].callsign, "TVF55MC")
        XCTAssertEqual(list[0].category, "A5")
        XCTAssertNil(list[1].category)
        XCTAssertEqual(list[0].altitudeFt ?? 0, 39000, accuracy: 10)
        XCTAssertEqual(list[0].groundSpeedKt ?? 0, 416.4, accuracy: 0.5)
        XCTAssertEqual(list[0].positionTime.timeIntervalSince(Fixtures.t0), -10, accuracy: 0.001)
        XCTAssertTrue(list[1].onGround)
        XCTAssertEqual(Feeds.decodeOpenSky(Data("{\"time\":1,\"states\":null}".utf8), fetchedAt: Fixtures.t0)?.count, 0)
    }

    func testRouteDecodingAndLegSelection() throws {
        let vrs = """
        {"callsign":"DLH2HT","number":"2HT","airline_code":"DLH","airport_codes":"EDDM-EDDL","_airport_codes_iata":"MUC-DUS",
         "_airports":[
          {"name":"Munich International Airport","icao":"EDDM","iata":"MUC","location":"Munich","countryiso2":"DE","lat":48.353802,"lon":11.7861,"alt_feet":1487},
          {"name":"Düsseldorf International Airport","icao":"EDDL","iata":"DUS","location":"Düsseldorf","countryiso2":"DE","lat":51.289501,"lon":6.76678,"alt_feet":147}
         ]}
        """.data(using: .utf8)!
        let raw = try XCTUnwrap(Feeds.decodeVRSRoute(vrs, reference: Fixtures.reference))
        XCTAssertEqual(raw.airports.map { $0.code }, ["MUC", "DUS"])
        XCTAssertEqual(raw.flightNumber, "LH2HT")
        XCTAssertEqual(raw.airports[0].cityZH, "慕尼黑") // enriched from the bundled table

        let route = FlightRoute(callsign: "DLH2HT", flightNumber: nil, airlineICAO: "DLH", airlineName: nil, origin: Fixtures.muc, destination: Fixtures.dus, source: .vrs)
        let onRoute = Fixtures.cruising(route, fraction: 0.6, alt: 22000, gs: 370)
        XCTAssertEqual(Feeds.resolve(raw, for: onRoute)?.destination.code, "DUS")

        var wrongWay = onRoute
        wrongWay.trackDeg = Geo.bearing(onRoute.point, Fixtures.muc.point)
        XCTAssertNil(Feeds.resolve(raw, for: wrongWay))

        let adsbdb = """
        {"response":{"flightroute":{"callsign":"CCA1831","callsign_icao":"CCA1831","callsign_iata":"CA1831",
          "airline":{"name":"Air China","icao":"CCA","iata":"CA","country":"China","country_iso":"CN","callsign":"AIR CHINA"},
          "origin":{"country_iso_name":"CN","country_name":"China","elevation":116,"iata_code":"PEK","icao_code":"ZBAA","latitude":40.0801,"longitude":116.5846,"municipality":"Beijing","name":"Beijing Capital International Airport"},
          "destination":{"country_iso_name":"CN","country_name":"China","elevation":13,"iata_code":"PVG","icao_code":"ZSPD","latitude":31.1434,"longitude":121.8052,"municipality":"Shanghai","name":"Shanghai Pudong International Airport"}}}}
        """.data(using: .utf8)!
        let db = try XCTUnwrap(Feeds.decodeADSBDBRoute(adsbdb, reference: Fixtures.reference))
        XCTAssertEqual(db.flightNumber, "CA1831")
        XCTAssertEqual(db.airports[0].code, "PEK") // not in the fixture table: built from the response
        XCTAssertEqual(db.airports[0].cityEN, "Beijing")
        XCTAssertEqual(db.airports[1].cityZH, "上海浦东")

        XCTAssertNil(Feeds.decodeADSBDBRoute(Data("{\"response\":\"unknown callsign\"}".utf8), reference: Fixtures.reference))
    }

    func testMultiLegRoutePicksTheLegBeingFlown() {
        let raw = Feeds.RawRoute(callsign: "ANA920", flightNumber: "NH920", airlineICAO: "ANA", airlineName: nil, airports: [Fixtures.lhr, Fixtures.pvg, Fixtures.hnd], source: .vrs)
        let secondLeg = Fixtures.cruising(Fixtures.route(Fixtures.pvg, Fixtures.hnd), fraction: 0.5)
        let picked = Feeds.resolve(raw, for: secondLeg)
        XCTAssertEqual(picked?.origin.code, "PVG")
        XCTAssertEqual(picked?.destination.code, "HND")
    }

    func testReferenceTSVParsing() {
        let airports = "iata\ticao\tlat\tlon\telev_ft\tcountry\ttz\tsize\tcity_en\tname_en\tcity_zh\tname_zh\n"
            + "PVG\tZSPD\t31.1443\t121.8083\t13\tCN\tAsia/Shanghai\tL\tShanghai\tShanghai Pudong International Airport\t上海浦东\t上海浦东国际机场\n"
            + "XXX\t\t1.0\t2.0\t\tZZ\t\tS\tNowhere\tNowhere Strip\t\t\n"
            + "bad row\n"
        let airlines = "icao\tiata\tname_en\tname_zh\tcountry\tcallsign\nCCA\tCA\tAir China\t中国国际航空\tCN\tAIR CHINA\n"
        let ref = ReferenceData(airportsTSV: airports, airlinesTSV: airlines)
        XCTAssertEqual(ref.airports.count, 2)
        XCTAssertEqual(ref.airport(code: "pvg")?.city, "上海浦东")
        XCTAssertEqual(ref.airport(code: "ZSPD")?.iata, "PVG")
        XCTAssertEqual(ref.airport(code: "XXX")?.city, "Nowhere")
        XCTAssertNil(ref.airport(code: "XXX")?.elevationFt)
        XCTAssertNil(ref.airport(code: "XXX")?.timeZone)
        XCTAssertEqual(ref.airline(icao: "CCA")?.name, "中国国际航空")
        XCTAssertEqual(ref.callsignCandidates(forFlightNumber: "ca1831"), ["CCA1831"])
        XCTAssertEqual(ref.callsignCandidates(forFlightNumber: "CA 0981"), ["CCA981"])
        XCTAssertEqual(ref.callsignCandidates(forFlightNumber: "CCA1831"), ["CCA1831"])
        XCTAssertEqual(ref.callsignCandidates(forFlightNumber: "ZZ"), [])
        XCTAssertEqual(ref.searchAirports("上海").first?.iata, "PVG")
        XCTAssertEqual(ref.searchAirports("pvg").first?.iata, "PVG")
        XCTAssertEqual(ref.nearestAirport(to: GeoPoint(31.2, 121.5))?.airport.iata, "PVG")
    }
}

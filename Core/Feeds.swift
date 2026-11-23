import Foundation

/// Decoders for the public feeds Strato reads. Pure functions over bytes so they can be tested with fixtures.
enum Feeds {
    // MARK: readsb "v2" JSON (adsb.fi, adsb.lol)

    private struct ReadsbResponse: Decodable {
        var ac: [ReadsbAircraft]?
        var aircraft: [ReadsbAircraft]?
        var now: Double?
    }

    private struct LossyInt: Decodable {
        var value: Int?
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { value = i }
            else if let d = try? c.decode(Double.self) { value = Int(d.rounded()) }
            else { value = nil }
        }
    }

    private struct Altitude: Decodable {
        var feet: Int?
        var ground = false
        init(from decoder: Decoder) throws {
            let c = try decoder.singleValueContainer()
            if let i = try? c.decode(Int.self) { feet = i }
            else if let d = try? c.decode(Double.self) { feet = Int(d.rounded()) }
            else if let s = try? c.decode(String.self), s == "ground" { ground = true }
        }
    }

    private struct ReadsbAircraft: Decodable {
        var hex: String?
        var flight: String?
        var r: String?
        var t: String?
        var desc: String?
        var lat: Double?
        var lon: Double?
        var alt_baro: Altitude?
        var alt_geom: LossyInt?
        var gs: Double?
        var track: Double?
        var baro_rate: LossyInt?
        var geom_rate: LossyInt?
        var mach: Double?
        var ias: LossyInt?
        var tas: LossyInt?
        var roll: Double?
        var squawk: String?
        var category: String?
        var wd: LossyInt?
        var ws: LossyInt?
        var oat: LossyInt?
        var nav_altitude_mcp: LossyInt?
        var seen_pos: Double?
        var seen: Double?
    }

    /// Decodes a readsb aircraft list. Entries without a position are dropped.
    static func decodeReadsb(_ data: Data, source: DataSource, fetchedAt: Date) -> [AircraftState]? {
        guard let response = try? JSONDecoder().decode(ReadsbResponse.self, from: data) else { return nil }
        let list = response.ac ?? response.aircraft ?? []
        var out: [AircraftState] = []
        out.reserveCapacity(list.count)
        for a in list {
            guard let rawHex = a.hex, let lat = a.lat, let lon = a.lon,
                  abs(lat) <= 90, abs(lon) <= 180 else { continue }
            // "~" prefixes mark non-ICAO addresses (TIS-B, MLAT anonymised); they are not real airframes.
            guard !rawHex.hasPrefix("~") else { continue }
            let age = min(max(a.seen_pos ?? a.seen ?? 0, 0), 600)
            let onGround = a.alt_baro?.ground ?? false
            out.append(AircraftState(
                hex: rawHex.lowercased(),
                callsign: Callsign.clean(a.flight ?? ""),
                registration: a.r,
                typeCode: a.t,
                typeName: a.desc,
                lat: lat,
                lon: lon,
                altitudeFt: onGround ? 0 : (a.alt_baro?.feet ?? a.alt_geom?.value),
                onGround: onGround,
                groundSpeedKt: a.gs,
                trackDeg: a.track,
                verticalRateFpm: a.baro_rate?.value ?? a.geom_rate?.value,
                mach: a.mach,
                iasKt: a.ias?.value,
                tasKt: a.tas?.value,
                rollDeg: a.roll,
                squawk: a.squawk,
                category: a.category,
                windDirDeg: a.wd?.value,
                windSpeedKt: a.ws?.value,
                outsideTempC: a.oat?.value,
                selectedAltitudeFt: a.nav_altitude_mcp?.value,
                positionTime: fetchedAt.addingTimeInterval(-age),
                source: source
            ))
        }
        return out
    }

    // MARK: OpenSky /states/all

    /// OpenSky returns rows as heterogeneous arrays in SI units; convert to aviation units.
    static func decodeOpenSky(_ data: Data, fetchedAt: Date) -> [AircraftState]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        guard let rows = root["states"] as? [[Any]] else { return [] }
        var out: [AircraftState] = []
        out.reserveCapacity(rows.count)
        for row in rows {
            guard row.count >= 12,
                  let hex = row[0] as? String,
                  let lon = (row[5] as? NSNumber)?.doubleValue,
                  let lat = (row[6] as? NSNumber)?.doubleValue else { continue }
            let onGround = (row[8] as? Bool) ?? false
            let altMeters = (row[7] as? NSNumber)?.doubleValue ?? (row.count > 13 ? (row[13] as? NSNumber)?.doubleValue : nil)
            let speedMS = (row[9] as? NSNumber)?.doubleValue
            let vsMS = (row[11] as? NSNumber)?.doubleValue
            let timePosition = (row[3] as? NSNumber)?.doubleValue
            var when = fetchedAt
            if let timePosition {
                let t = Date(timeIntervalSince1970: timePosition)
                // Guard against clock skew between device and server.
                when = min(fetchedAt, max(t, fetchedAt.addingTimeInterval(-600)))
            }
            out.append(AircraftState(
                hex: hex.lowercased(),
                callsign: Callsign.clean((row[1] as? String) ?? ""),
                lat: lat,
                lon: lon,
                altitudeFt: onGround ? 0 : altMeters.map { Int(($0 * 3.28084).rounded()) },
                onGround: onGround,
                groundSpeedKt: speedMS.map { $0 * 1.943844 },
                trackDeg: (row[10] as? NSNumber)?.doubleValue,
                verticalRateFpm: vsMS.map { Int(($0 * 196.8504).rounded()) },
                squawk: row.count > 14 ? row[14] as? String : nil,
                positionTime: when,
                source: .opensky
            ))
        }
        return out
    }

    // MARK: Routes

    /// A route as published: an ordered list of airports (usually two; more for multi-stop flights).
    struct RawRoute: Sendable, Hashable, Codable {
        var callsign: String
        var flightNumber: String?
        var airlineICAO: String?
        var airlineName: String?
        var airports: [Airport]
        var source: RouteSource
    }

    private struct VRSRoute: Decodable {
        struct Stop: Decodable {
            var name: String?
            var icao: String?
            var iata: String?
            var location: String?
            var countryiso2: String?
            var lat: Double?
            var lon: Double?
            var alt_feet: Double?
        }
        var callsign: String?
        var number: String?
        var airline_code: String?
        var _airports: [Stop]?
    }

    /// vrs-standing-data.adsb.lol/routes/XX/CALLSIGN.json
    static func decodeVRSRoute(_ data: Data, reference: ReferenceData) -> RawRoute? {
        guard let r = try? JSONDecoder().decode(VRSRoute.self, from: data),
              let stops = r._airports, stops.count >= 2 else { return nil }
        var airports: [Airport] = []
        for s in stops {
            let known = (s.iata.flatMap { reference.airport(code: $0) }) ?? (s.icao.flatMap { reference.airport(code: $0) })
            if let known {
                airports.append(known)
            } else if let lat = s.lat, let lon = s.lon, let code = s.iata ?? s.icao, !code.isEmpty {
                airports.append(Airport(
                    iata: s.iata ?? "",
                    icao: s.icao ?? "",
                    lat: lat,
                    lon: lon,
                    elevationFt: s.alt_feet.map { Int($0) },
                    country: s.countryiso2 ?? "",
                    size: .small,
                    cityEN: s.location ?? "",
                    nameEN: s.name ?? ""
                ))
            } else {
                return nil
            }
        }
        let callsign = Callsign.clean(r.callsign ?? "")
        var flightNumber: String?
        if let code = r.airline_code, let number = r.number, !number.isEmpty,
           let airline = reference.airline(icao: code), !airline.iata.isEmpty {
            flightNumber = airline.iata + number
        }
        return RawRoute(
            callsign: callsign,
            flightNumber: flightNumber,
            airlineICAO: r.airline_code,
            airlineName: nil,
            airports: airports,
            source: .vrs
        )
    }

    private struct ADSBDBEnvelope: Decodable {
        struct Inner: Decodable {
            var flightroute: Route?
        }
        struct Route: Decodable {
            var callsign: String?
            var callsign_iata: String?
            var airline: AirlineInfo?
            var origin: Stop?
            var destination: Stop?
        }
        struct AirlineInfo: Decodable {
            var name: String?
            var icao: String?
        }
        struct Stop: Decodable {
            var iata_code: String?
            var icao_code: String?
            var name: String?
            var municipality: String?
            var country_iso_name: String?
            var latitude: Double?
            var longitude: Double?
            var elevation: Double?
        }
        var response: Inner?

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // "response" is a string ("unknown callsign") on misses.
            response = try? c.decode(Inner.self, forKey: .response)
        }
        enum CodingKeys: String, CodingKey { case response }
    }

    /// api.adsbdb.com/v0/callsign/CALLSIGN
    static func decodeADSBDBRoute(_ data: Data, reference: ReferenceData) -> RawRoute? {
        guard let env = try? JSONDecoder().decode(ADSBDBEnvelope.self, from: data),
              let r = env.response?.flightroute, let o = r.origin, let d = r.destination else { return nil }
        func airport(_ s: ADSBDBEnvelope.Stop) -> Airport? {
            if let known = (s.iata_code.flatMap { reference.airport(code: $0) }) ?? (s.icao_code.flatMap { reference.airport(code: $0) }) {
                return known
            }
            guard let lat = s.latitude, let lon = s.longitude, abs(lat) + abs(lon) > 0.01,
                  let code = s.iata_code ?? s.icao_code, !code.isEmpty else { return nil }
            return Airport(
                iata: s.iata_code ?? "",
                icao: s.icao_code ?? "",
                lat: lat,
                lon: lon,
                elevationFt: s.elevation.map { Int($0) },
                country: s.country_iso_name ?? "",
                size: .small,
                cityEN: s.municipality ?? "",
                nameEN: s.name ?? ""
            )
        }
        guard let origin = airport(o), let destination = airport(d) else { return nil }
        return RawRoute(
            callsign: Callsign.clean(r.callsign ?? ""),
            flightNumber: r.callsign_iata,
            airlineICAO: r.airline?.icao,
            airlineName: r.airline?.name,
            airports: [origin, destination],
            source: .adsbdb
        )
    }

    /// Picks the leg of a published route that the aircraft is actually flying, or nil if none fits.
    static func resolve(_ raw: RawRoute, for state: AircraftState) -> FlightRoute? {
        guard raw.airports.count >= 2 else { return nil }
        var best: (FlightRoute, Double)?
        for i in 0..<(raw.airports.count - 1) {
            let o = raw.airports[i], d = raw.airports[i + 1]
            guard o.code != d.code, FlightMath.isPlausible(state: state, origin: o, destination: d) else { continue }
            let direct = max(Geo.distanceKm(o.point, d.point), 1)
            let detour = (Geo.distanceKm(o.point, state.point) + Geo.distanceKm(state.point, d.point)) / direct
            let route = FlightRoute(
                callsign: raw.callsign,
                flightNumber: raw.flightNumber,
                airlineICAO: raw.airlineICAO ?? Callsign.airlinePrefix(raw.callsign),
                airlineName: raw.airlineName,
                origin: o,
                destination: d,
                source: raw.source
            )
            if detour < (best?.1 ?? .infinity) { best = (route, detour) }
        }
        return best?.0
    }
}

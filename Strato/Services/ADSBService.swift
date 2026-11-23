import Foundation
import CoreLocation

/// High-concurrency Global ADS-B Radar & Schedule Route Resolver.
/// - Scans 12 global aviation corridors in parallel via `opendata.adsb.fi` (and `api.adsb.lol` backup).
/// - Resolves real origin & destination airports via `api.adsbdb.com/v0/callsign/{CALLSIGN}` with an in-memory cache.
/// - Geometrically infers realistic origin & destination airports along the aircraft's heading cone if unlisted.
actor ADSBService {
    static let shared = ADSBService()

    private let session: URLSession
    private let userAgent = "Strato/2.0 (iOS 26 Liquid Glass Focus Flight Tracker)"

    private struct CachedRoute: Sendable {
        let iataFlight: String
        let airlineName: String
        let origin: Airport
        let destination: Airport
        let isVerified: Bool
    }

    private var routeCache: [String: CachedRoute] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 9
        config.timeoutIntervalForResource = 16
        config.httpMaximumConnectionsPerHost = 12
        self.session = URLSession(configuration: config)
    }

    // MARK: - Global / Multi-Hub Radar Scan

    /// Scans all hubs for the given `RadarScope` (default `.globalLive` scans 12 global hubs in parallel)
    /// and returns up to `maxResults` real airborne flights with resolved origin & destination airports.
    func scanGlobalOrScopedAirspace(
        scope: RadarScope,
        customCenter: CLLocationCoordinate2D? = nil,
        maxResults: Int = 90
    ) async -> [LiveFlight] {
        let hubs: [CLLocationCoordinate2D]
        if let customCenter {
            hubs = [customCenter]
        } else {
            hubs = scope.scanHubs
        }

        var rawPool: [ADSBV2Aircraft] = []
        await withTaskGroup(of: [ADSBV2Aircraft].self) { group in
            for hub in hubs {
                group.addTask {
                    await self.fetchRawAircraftAtPoint(center: hub, radiusNM: 250)
                }
            }
            for await batch in group {
                rawPool.append(contentsOf: batch)
            }
        }

        // Deduplicate by ICAO24 hex and filter airborne commercial jets
        var seenHex = Set<String>()
        let airborne = rawPool.filter { ac in
            guard seenHex.insert(ac.hex).inserted,
                  let lat = ac.lat, let lon = ac.lon,
                  let cs = ac.cleanCallsign, cs.count >= 4,
                  let alt = ac.altitudeFeet, alt >= 3_500,
                  let gs = ac.gs, gs >= 165 else {
                return false
            }
            return abs(lat) <= 85 && abs(lon) <= 180
        }

        // Prioritize recognized airline prefixes first so the user sees major carriers with rich liveries
        let sortedAirborne = airborne.sorted { lhs, rhs in
            let lKnown = AirlineThemeRegistry.branding(forCallsign: lhs.cleanCallsign ?? "").icaoPrefix != "STR"
            let rKnown = AirlineThemeRegistry.branding(forCallsign: rhs.cleanCallsign ?? "").icaoPrefix != "STR"
            if lKnown != rKnown { return lKnown }
            return (lhs.altitudeFeet ?? 0) > (rhs.altitudeFeet ?? 0)
        }

        let candidates = Array(sortedAirborne.prefix(maxResults))
        guard !candidates.isEmpty else { return [] }

        // Resolve routes concurrently via adsbdb + geometric fallback
        return await enrichAircraftWithRoutes(candidates)
    }

    /// Recommends live airborne flights whose real-time remaining duration matches `targetMinutes`.
    func recommendFlights(
        targetMinutes: Int,
        preferredDestination: Airport?,
        scope: RadarScope,
        existingPool: [LiveFlight] = []
    ) async -> [LiveFlight] {
        var pool: [LiveFlight] = existingPool

        if let dest = preferredDestination {
            // Scan around the target destination airport AND along major approach corridors (800-2000km out)
            let ringCenters = [
                dest.coordinate,
                GreatCircle.destination(from: dest.coordinate, bearingDegrees: 45, distanceNM: 380),
                GreatCircle.destination(from: dest.coordinate, bearingDegrees: 135, distanceNM: 380),
                GreatCircle.destination(from: dest.coordinate, bearingDegrees: 225, distanceNM: 380),
                GreatCircle.destination(from: dest.coordinate, bearingDegrees: 315, distanceNM: 380)
            ]
            var rawRing: [ADSBV2Aircraft] = []
            await withTaskGroup(of: [ADSBV2Aircraft].self) { group in
                for pt in ringCenters {
                    group.addTask {
                        await self.fetchRawAircraftAtPoint(center: pt, radiusNM: 250)
                    }
                }
                for await batch in group {
                    rawRing.append(contentsOf: batch)
                }
            }
            var seen = Set<String>()
            let filtered = rawRing.filter { ac in
                guard seen.insert(ac.hex).inserted,
                      let cs = ac.cleanCallsign, cs.count >= 4,
                      let alt = ac.altitudeFeet, alt >= 2500,
                      let gs = ac.gs, gs >= 150 else { return false }
                return true
            }
            let enriched = await enrichAircraftWithRoutes(Array(filtered.prefix(65)))
            pool.append(contentsOf: enriched)
        } else if pool.count < 25 {
            pool = await scanGlobalOrScopedAirspace(scope: scope, maxResults: 90)
        }

        // Deduplicate pool
        var seenIDs = Set<String>()
        let uniquePool = pool.filter { seenIDs.insert($0.id).inserted }

        let filteredPool: [LiveFlight]
        if let preferredDestination {
            let exactMatches = uniquePool.filter { $0.destination?.iata == preferredDestination.iata }
            if !exactMatches.isEmpty {
                filteredPool = exactMatches
            } else {
                // Also include aircraft heading toward that airport
                filteredPool = uniquePool.filter { flight in
                    let dist = GreatCircle.distanceKM(from: flight.coordinate, to: preferredDestination.coordinate)
                    let bearing = GreatCircle.bearingDegrees(from: flight.coordinate, to: preferredDestination.coordinate)
                    return dist < 2400 && GreatCircle.angleDifference(flight.trackDegrees, bearing) < 38
                }.map { flight in
                    var adjusted = flight
                    adjusted.destination = preferredDestination
                    return adjusted
                }
            }
        } else {
            filteredPool = uniquePool
        }

        let ranked = (filteredPool.isEmpty ? uniquePool : filteredPool).sorted { lhs, rhs in
            let lDiff = abs(lhs.estimatedRemainingMinutes - targetMinutes)
            let rDiff = abs(rhs.estimatedRemainingMinutes - targetMinutes)
            if abs(lDiff - rDiff) > 4 {
                return lDiff < rDiff
            }
            if lhs.isRouteVerified != rhs.isRouteVerified {
                return lhs.isRouteVerified
            }
            return lDiff < rDiff
        }

        return ranked
    }

    /// Polls a single live aircraft by ICAO24 hex code during an active focus session.
    func refreshFlight(hex: String, existing: LiveFlight) async -> LiveFlight? {
        let urls = [
            URL(string: "https://opendata.adsb.fi/api/v2/hex/\(hex)"),
            URL(string: "https://api.adsb.lol/v2/hex/\(hex)")
        ].compactMap { $0 }

        for url in urls {
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            if url.host?.contains("adsb.lol") == true {
                let key = SharedStore.shared.adsbLolApiKey
                if !key.isEmpty {
                    request.setValue(key, forHTTPHeaderField: "X-API-Key")
                }
            }

            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let decoded = try? JSONDecoder().decode(ADSBV2Response.self, from: data),
               let ac = decoded.aircraftList.first,
               let lat = ac.lat, let lon = ac.lon {
                var updated = existing
                updated.latitude = lat
                updated.longitude = lon
                updated.altitudeFeet = ac.altitudeFeet ?? existing.altitudeFeet
                updated.groundSpeedKnots = ac.gs ?? existing.groundSpeedKnots
                updated.indicatedAirspeedKnots = ac.ias ?? existing.indicatedAirspeedKnots
                updated.trueAirspeedKnots = ac.tas ?? existing.trueAirspeedKnots
                updated.mach = ac.mach ?? existing.mach
                updated.trackDegrees = ac.track ?? existing.trackDegrees
                updated.rollDegrees = ac.roll ?? existing.rollDegrees
                updated.verticalRateFpm = ac.baro_rate ?? existing.verticalRateFpm
                updated.squawk = ac.squawk ?? existing.squawk
                updated.updatedAt = Date()
                return updated
            }
        }
        return nil
    }

    /// Creates a custom charter flight between any two chosen airports, positioned at a realistic mid-flight point
    /// so its remaining flight time matches `durationMinutes`.
    nonisolated func makeCustomFlight(
        origin: Airport,
        destination: Airport,
        airlineCode: String = "CCA",
        durationMinutes: Int
    ) -> LiveFlight {
        let branding = AirlineThemeRegistry.branding(forCallsign: airlineCode)
        let totalNM = max(GreatCircle.distanceNM(from: origin.coordinate, to: destination.coordinate), 100)
        let cruiseKnots = 455.0
        let remainingNM = min(totalNM * 0.92, max(60, Double(durationMinutes) / 60.0 * cruiseKnots))
        let currentProgress = min(max(1.0 - (remainingNM / totalNM), 0.08), 0.88)
        let currentCoord = GreatCircle.interpolate(from: origin.coordinate, to: destination.coordinate, fraction: currentProgress)
        let heading = GreatCircle.bearingDegrees(from: currentCoord, to: destination.coordinate)
        let num = Int.random(in: 108...986)

        return LiveFlight(
            id: "CHARTER-\(UUID().uuidString.prefix(8))",
            callsign: "\(branding.icaoPrefix)\(num)",
            iataFlightNumber: "\(branding.iataCode)\(num)",
            registration: "B-\(Int.random(in: 2000...9999))",
            aircraftType: totalNM > 1600 ? "A359" : "A321",
            aircraftDescription: totalNM > 1600 ? "AIRBUS A350-900" : "AIRBUS A321neo",
            airlineName: branding.nameCN,
            origin: origin,
            destination: destination,
            isRouteVerified: true,
            latitude: currentCoord.latitude,
            longitude: currentCoord.longitude,
            altitudeFeet: totalNM > 1200 ? 37_000 : 33_000,
            groundSpeedKnots: cruiseKnots,
            indicatedAirspeedKnots: 275,
            trueAirspeedKnots: 462,
            mach: 0.84,
            trackDegrees: heading,
            rollDegrees: 0.0,
            verticalRateFpm: 0,
            squawk: "2341",
            isLiveADSB: false,
            updatedAt: Date()
        )
    }

    // MARK: - Route Enrichment Engine (adsbdb + geometric inference)

    private func enrichAircraftWithRoutes(_ aircraftList: [ADSBV2Aircraft]) async -> [LiveFlight] {
        // Resolve up to 36 uncached callsigns against api.adsbdb.com in parallel
        let uncachedCallsigns = aircraftList
            .compactMap(\.cleanCallsign)
            .filter { routeCache[$0] == nil }
            .prefix(36)

        await withTaskGroup(of: (String, CachedRoute?).self) { group in
            for callsign in uncachedCallsigns {
                group.addTask {
                    let resolved = await self.lookupRouteFromAdsbDB(callsign: callsign)
                    return (callsign, resolved)
                }
            }
            for await (cs, route) in group {
                if let route {
                    routeCache[cs] = route
                }
            }
        }

        return aircraftList.compactMap { ac -> LiveFlight? in
            guard let lat = ac.lat, let lon = ac.lon, let callsign = ac.cleanCallsign else { return nil }
            let coord = CLLocationCoordinate2D(latitude: lat, longitude: lon)
            let alt = ac.altitudeFeet ?? 33_000
            let track = ac.track ?? 90.0
            let vRate = ac.baro_rate ?? 0
            let branding = AirlineThemeRegistry.branding(forCallsign: callsign)

            let origin: Airport
            let destination: Airport
            let iataFlight: String
            let airlineName: String
            let isVerified: Bool

            if let cached = routeCache[callsign] {
                origin = cached.origin
                destination = cached.destination
                iataFlight = cached.iataFlight
                airlineName = branding.icaoPrefix != "STR" ? branding.nameCN : cached.airlineName
                isVerified = cached.isVerified
            } else {
                let inferred = AirportDatabase.inferRoute(
                    coordinate: coord,
                    trackDegrees: track,
                    altitudeFeet: alt,
                    verticalRateFpm: vRate
                )
                origin = inferred.origin
                destination = inferred.destination
                iataFlight = ""
                airlineName = branding.nameCN
                isVerified = false
            }

            return LiveFlight(
                id: ac.hex,
                callsign: callsign,
                iataFlightNumber: iataFlight,
                registration: ac.r ?? "",
                aircraftType: ac.t ?? "A320",
                aircraftDescription: ac.desc ?? (ac.t ?? "COMMERCIAL JET"),
                airlineName: airlineName,
                origin: origin,
                destination: destination,
                isRouteVerified: isVerified,
                latitude: lat,
                longitude: lon,
                altitudeFeet: alt,
                groundSpeedKnots: ac.gs ?? 445,
                indicatedAirspeedKnots: ac.ias,
                trueAirspeedKnots: ac.tas,
                mach: ac.mach,
                trackDegrees: track,
                rollDegrees: ac.roll,
                verticalRateFpm: vRate,
                squawk: ac.squawk,
                isLiveADSB: true,
                updatedAt: Date()
            )
        }
    }

    private func lookupRouteFromAdsbDB(callsign: String) async -> CachedRoute? {
        guard let url = URL(string: "https://api.adsbdb.com/v0/callsign/\(callsign)") else { return nil }
        var request = URLRequest(url: url)
        request.timeoutInterval = 4.5
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(ADSBDBCallsignResponse.self, from: data),
              let route = decoded.response.flightroute,
              let orig = route.origin,
              let dest = route.destination,
              let origIATA = orig.iata_code, !origIATA.isEmpty,
              let destIATA = dest.iata_code, !destIATA.isEmpty else {
            return nil
        }

        // Use local Chinese city name if in AirportDatabase, otherwise use dynamic coordinates from adsbdb
        let originAirport = AirportDatabase.find(code: origIATA) ?? Airport(
            iata: origIATA,
            icao: orig.icao_code ?? origIATA,
            name: orig.name ?? origIATA,
            city: orig.municipality ?? origIATA,
            country: orig.country_iso_name ?? "",
            latitude: orig.latitude ?? 0,
            longitude: orig.longitude ?? 0
        )

        let destAirport = AirportDatabase.find(code: destIATA) ?? Airport(
            iata: destIATA,
            icao: dest.icao_code ?? destIATA,
            name: dest.name ?? destIATA,
            city: dest.municipality ?? destIATA,
            country: dest.country_iso_name ?? "",
            latitude: dest.latitude ?? 0,
            longitude: dest.longitude ?? 0
        )

        guard abs(originAirport.latitude) > 0.01 && abs(destAirport.latitude) > 0.01 else {
            return nil
        }

        return CachedRoute(
            iataFlight: route.callsign_iata ?? "",
            airlineName: route.airline?.name ?? "商业航班",
            origin: originAirport,
            destination: destAirport,
            isVerified: true
        )
    }

    // MARK: - Raw Point Fetch

    private func fetchRawAircraftAtPoint(center: CLLocationCoordinate2D, radiusNM: Int) async -> [ADSBV2Aircraft] {
        let clamped = min(max(radiusNM, 25), 250)
        let fiURL = URL(string: String(
            format: "https://opendata.adsb.fi/api/v3/lat/%.4f/lon/%.4f/dist/%d",
            center.latitude, center.longitude, clamped
        ))
        if let fiURL, let list = await fetchADSBJSON(url: fiURL), !list.isEmpty {
            return list
        }

        let lolURL = URL(string: String(
            format: "https://api.adsb.lol/v2/point/%.4f/%.4f/%d",
            center.latitude, center.longitude, clamped
        ))
        if let lolURL, let list = await fetchADSBJSON(url: lolURL), !list.isEmpty {
            return list
        }
        return []
    }

    private func fetchADSBJSON(url: URL) async -> [ADSBV2Aircraft]? {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        if url.host?.contains("adsb.lol") == true {
            let key = SharedStore.shared.adsbLolApiKey
            if !key.isEmpty {
                request.setValue(key, forHTTPHeaderField: "X-API-Key")
            }
        }

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(ADSBV2Response.self, from: data) else {
            return nil
        }
        return decoded.aircraftList
    }
}

// MARK: - Wire Models

private struct ADSBV2Response: Decodable {
    let ac: [ADSBV2Aircraft]?
    let aircraft: [ADSBV2Aircraft]?

    var aircraftList: [ADSBV2Aircraft] {
        ac ?? aircraft ?? []
    }
}

private struct ADSBV2Aircraft: Decodable {
    let hex: String
    let flight: String?
    let r: String?
    let t: String?
    let desc: String?
    let lat: Double?
    let lon: Double?
    let gs: Double?
    let ias: Int?
    let tas: Int?
    let mach: Double?
    let track: Double?
    let roll: Double?
    let baro_rate: Int?
    let squawk: String?
    let alt_baro: AltBaroValue?

    var cleanCallsign: String? {
        guard let trimmed = flight?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    var altitudeFeet: Int? {
        alt_baro?.feet
    }
}

private enum AltBaroValue: Decodable {
    case feet(Int)
    case ground

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            self = .feet(intVal)
        } else if let doubleVal = try? container.decode(Double.self) {
            self = .feet(Int(doubleVal))
        } else {
            self = .ground
        }
    }

    var feet: Int {
        switch self {
        case .feet(let value): return value
        case .ground: return 0
        }
    }
}

private struct ADSBDBCallsignResponse: Decodable {
    struct Inner: Decodable {
        let flightroute: FlightRoute?
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            // adsbdb returns "unknown callsign" string when not found, or an object when found
            self.flightroute = try? c.decode(FlightRoute.self, forKey: .flightroute)
        }
        enum CodingKeys: String, CodingKey {
            case flightroute
        }
    }
    struct FlightRoute: Decodable {
        let callsign_iata: String?
        let airline: AirlineInfo?
        let origin: AirportInfo?
        let destination: AirportInfo?
    }
    struct AirlineInfo: Decodable {
        let name: String?
    }
    struct AirportInfo: Decodable {
        let iata_code: String?
        let icao_code: String?
        let name: String?
        let municipality: String?
        let country_iso_name: String?
        let latitude: Double?
        let longitude: Double?
    }
    let response: Inner
}

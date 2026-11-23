import Foundation
import CoreLocation

/// Real-time ADS-B radar & route enrichment client.
/// Uses free community ADS-B feeds (adsb.fi + adsb.lol) with zero required API keys.
actor ADSBService {
    static let shared = ADSBService()

    private let session: URLSession
    private let userAgent = "Strato/1.0 (iOS Liquid Glass Focus Flight Tracker)"

    init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 18
        self.session = URLSession(configuration: config)
    }

    // MARK: - Public API

    /// Fetches live airborne commercial flights around a coordinate (radius in nautical miles, max 250).
    func fetchNearbyFlights(
        center: CLLocationCoordinate2D,
        radiusNM: Int = 220,
        limit: Int = 36
    ) async -> [LiveFlight] {
        let clampedRadius = min(max(radiusNM, 25), 250)
        var rawAircraft: [ADSBV2Aircraft] = []

        // Primary: opendata.adsb.fi (free, no key)
        if let fiPlanes = await fetchFromAdsbFi(center: center, radiusNM: clampedRadius), !fiPlanes.isEmpty {
            rawAircraft = fiPlanes
        } else if let lolPlanes = await fetchFromAdsbLol(center: center, radiusNM: clampedRadius), !lolPlanes.isEmpty {
            rawAircraft = lolPlanes
        }

        // Filter airborne aircraft with valid coordinates and callsigns
        let airborne = rawAircraft.filter { ac in
            guard let lat = ac.lat, let lon = ac.lon,
                  let callsign = ac.cleanCallsign, callsign.count >= 4,
                  let alt = ac.altitudeFeet, alt >= 2500,
                  let gs = ac.gs, gs >= 140 else {
                return false
            }
            return abs(lat) <= 85 && abs(lon) <= 180
        }

        let selected = Array(airborne.prefix(limit))
        guard !selected.isEmpty else { return [] }

        // Batch-enrich origin & destination airports via adsb.lol routeset
        let routeMap = await fetchRoutes(for: selected)

        return selected.compactMap { ac -> LiveFlight? in
            guard let lat = ac.lat, let lon = ac.lon, let callsign = ac.cleanCallsign else { return nil }
            let route = routeMap[callsign]
            return LiveFlight(
                id: ac.hex,
                callsign: callsign,
                registration: ac.r ?? "",
                aircraftType: ac.t ?? "A320",
                airlineName: AirlineLookup.name(forCallsign: callsign),
                origin: route?.origin,
                destination: route?.destination,
                latitude: lat,
                longitude: lon,
                altitudeFeet: ac.altitudeFeet ?? 32_000,
                groundSpeedKnots: ac.gs ?? 440,
                trackDegrees: ac.track ?? 90,
                verticalRateFpm: ac.baro_rate ?? 0,
                isLiveADSB: true,
                updatedAt: Date()
            )
        }
    }

    /// Refreshes a single live aircraft by ICAO24 hex code during an active focus session.
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
                updated.trackDegrees = ac.track ?? existing.trackDegrees
                updated.verticalRateFpm = ac.baro_rate ?? existing.verticalRateFpm
                updated.updatedAt = Date()
                return updated
            }
        }
        return nil
    }

    /// Scans live airspace to recommend real flights whose remaining time to landing matches `targetMinutes`.
    func recommendFlights(
        targetMinutes: Int,
        preferredDestination: Airport?,
        region: RadarRegion
    ) async -> [LiveFlight] {
        var collected: [LiveFlight] = []

        if let dest = preferredDestination {
            // Scan around the desired destination airport (and slightly wider hubs)
            let nearby = await fetchNearbyFlights(center: dest.coordinate, radiusNM: 250, limit: 45)
            collected.append(contentsOf: nearby)
        } else {
            // Scan 2 primary hubs in the selected radar region in parallel
            let hubs = Array(region.scanCenters.prefix(2))
            await withTaskGroup(of: [LiveFlight].self) { group in
                for hub in hubs {
                    group.addTask {
                        await self.fetchNearbyFlights(center: hub, radiusNM: 240, limit: 28)
                    }
                }
                for await batch in group {
                    collected.append(contentsOf: batch)
                }
            }
        }

        // Deduplicate by ICAO hex
        var seen = Set<String>()
        let unique = collected.filter { seen.insert($0.id).inserted }

        // Prefer flights with known destination; optionally filter by user's target destination
        let withRoutes = unique.filter { flight in
            guard let dest = flight.destination else { return false }
            if let preferredDestination {
                return dest.iata == preferredDestination.iata
            }
            return true
        }

        // Rank by how closely real-time ETA matches the user's requested focus duration
        let ranked = withRoutes.sorted { lhs, rhs in
            abs(lhs.estimatedRemainingMinutes - targetMinutes)
            < abs(rhs.estimatedRemainingMinutes - targetMinutes)
        }

        if !ranked.isEmpty {
            return Array(ranked.prefix(12))
        }

        // If live ADS-B has no exact destination matches (e.g. offline or sparse coverage),
        // synthesize realistic flights calibrated to the user's exact duration & destination.
        return generateCalibratedFallbackFlights(
            targetMinutes: targetMinutes,
            preferredDestination: preferredDestination,
            region: region
        )
    }

    /// Creates a custom focus flight between any two chosen airports, calibrated to `durationMinutes`.
    nonisolated func makeCustomFlight(
        origin: Airport,
        destination: Airport,
        durationMinutes: Int
    ) -> LiveFlight {
        let totalNM = max(GreatCircle.distanceNM(from: origin.coordinate, to: destination.coordinate), 80)
        let speedKnots = min(max(totalNM / max(Double(durationMinutes) / 60.0, 0.25), 320), 520)
        let startCoord = GreatCircle.interpolate(from: origin.coordinate, to: destination.coordinate, fraction: 0.04)
        let heading = GreatCircle.bearingDegrees(from: startCoord, to: destination.coordinate)
        let flightNum = Int.random(in: 101...988)

        return LiveFlight(
            id: "STRATO-\(UUID().uuidString.prefix(8))",
            callsign: "STR\(flightNum)",
            registration: "B-\(Int.random(in: 1000...9999))",
            aircraftType: totalNM > 1800 ? "A359" : "A321",
            airlineName: "Strato Airways",
            origin: origin,
            destination: destination,
            latitude: startCoord.latitude,
            longitude: startCoord.longitude,
            altitudeFeet: totalNM > 1200 ? 37_000 : 31_000,
            groundSpeedKnots: speedKnots,
            trackDegrees: heading,
            verticalRateFpm: 0,
            isLiveADSB: false,
            updatedAt: Date()
        )
    }

    // MARK: - Private Network Helpers

    private func fetchFromAdsbFi(center: CLLocationCoordinate2D, radiusNM: Int) async -> [ADSBV2Aircraft]? {
        let urlString = String(
            format: "https://opendata.adsb.fi/api/v3/lat/%.4f/lon/%.4f/dist/%d",
            center.latitude, center.longitude, radiusNM
        )
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(ADSBV2Response.self, from: data) else {
            return nil
        }
        return decoded.aircraftList
    }

    private func fetchFromAdsbLol(center: CLLocationCoordinate2D, radiusNM: Int) async -> [ADSBV2Aircraft]? {
        let urlString = String(
            format: "https://api.adsb.lol/v2/point/%.4f/%.4f/%d",
            center.latitude, center.longitude, radiusNM
        )
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        let key = SharedStore.shared.adsbLolApiKey
        if !key.isEmpty {
            request.setValue(key, forHTTPHeaderField: "X-API-Key")
        }

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let decoded = try? JSONDecoder().decode(ADSBV2Response.self, from: data) else {
            return nil
        }
        return decoded.aircraftList
    }

    private func fetchRoutes(for aircraft: [ADSBV2Aircraft]) async -> [String: (origin: Airport?, destination: Airport?)] {
        guard let url = URL(string: "https://api.adsb.lol/api/0/routeset") else { return [:] }
        let planesPayload: [[String: Any]] = aircraft.compactMap { ac in
            guard let callsign = ac.cleanCallsign, let lat = ac.lat, let lon = ac.lon else { return nil }
            return ["callsign": callsign, "lat": lat, "lng": lon]
        }
        guard !planesPayload.isEmpty,
              let body = try? JSONSerialization.data(withJSONObject: ["planes": planesPayload]) else {
            return [:]
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")

        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              let entries = try? JSONDecoder().decode([RoutesetEntry].self, from: data) else {
            return [:]
        }

        var result: [String: (origin: Airport?, destination: Airport?)] = [:]
        for entry in entries {
            guard let callsign = entry.callsign?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let airportCodes = entry.airportCodes,
                  !airportCodes.isEmpty else { continue }
            let parts = airportCodes.split(separator: "-").map(String.init)
            if parts.count >= 2 {
                let origin = AirportDatabase.find(code: parts.first ?? "")
                let dest = AirportDatabase.find(code: parts.last ?? "")
                if origin != nil || dest != nil {
                    result[callsign] = (origin, dest)
                }
            }
        }
        return result
    }

    // MARK: - Calibrated Fallback Flights

    private func generateCalibratedFallbackFlights(
        targetMinutes: Int,
        preferredDestination: Airport?,
        region: RadarRegion
    ) -> [LiveFlight] {
        let pairs: [(String, String, String, String, String)] = [
            ("PVG", "HND", "ANA920", "A359", "全日空"),
            ("PEK", "ICN", "CCA123", "B789", "中国国际航空"),
            ("HKG", "TPE", "CPA494", "A333", "国泰航空"),
            ("SZX", "SIN", "SIA857", "A359", "新加坡航空"),
            ("CTU", "PVG", "CES5402", "A321", "中国东方航空"),
            ("LHR", "ZRH", "BAW714", "A320", "英国航空"),
            ("CDG", "FRA", "DLH1031", "A20N", "汉莎航空"),
            ("SFO", "SEA", "ASA1092", "B739", "阿拉斯加航空"),
            ("JFK", "ORD", "DAL482", "A223", "达美航空")
        ]

        var flights: [LiveFlight] = []
        let targetNM = max(Double(targetMinutes) / 60.0 * 440.0, 140)

        for (index, item) in pairs.enumerated() {
            guard let orig = AirportDatabase.find(code: item.0),
                  let rawDest = AirportDatabase.find(code: item.1) else { continue }
            let dest = preferredDestination ?? rawDest
            guard orig.iata != dest.iata else { continue }

            let totalNM = max(GreatCircle.distanceNM(from: orig.coordinate, to: dest.coordinate), 220)
            let frac = min(max(1.0 - (targetNM / totalNM), 0.12), 0.82)
            let pos = GreatCircle.interpolate(from: orig.coordinate, to: dest.coordinate, fraction: frac)
            let bearing = GreatCircle.bearingDegrees(from: pos, to: dest.coordinate)

            flights.append(
                LiveFlight(
                    id: "SIM-\(index)-\(item.2)",
                    callsign: item.2,
                    registration: "B-30\(10 + index)A",
                    aircraftType: item.3,
                    airlineName: item.4,
                    origin: orig,
                    destination: dest,
                    latitude: pos.latitude,
                    longitude: pos.longitude,
                    altitudeFeet: 34_000 + (index % 4) * 1_000,
                    groundSpeedKnots: 445 + Double(index % 3) * 15,
                    trackDegrees: bearing,
                    verticalRateFpm: 0,
                    isLiveADSB: false,
                    updatedAt: Date()
                )
            )
        }
        return flights
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
    let lat: Double?
    let lon: Double?
    let gs: Double?
    let track: Double?
    let baro_rate: Int?
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

private struct RoutesetEntry: Decodable {
    let callsign: String?
    let airportCodes: String?

    enum CodingKeys: String, CodingKey {
        case callsign
        case airportCodes = "_airport_codes_iata"
    }
}

private enum AirlineLookup {
    private static let prefixes: [String: String] = [
        "CCA": "中国国际航空",
        "CES": "中国东方航空",
        "CSN": "中国南方航空",
        "CHH": "海南航空",
        "CSC": "四川航空",
        "CXA": "厦门航空",
        "CPA": "国泰航空",
        "ANA": "全日空",
        "JAL": "日本航空",
        "KAL": "大韩航空",
        "AAR": "韩亚航空",
        "SIA": "新加坡航空",
        "EVA": "长荣航空",
        "CAL": "中华航空",
        "BAW": "英国航空",
        "DLH": "汉莎航空",
        "AFR": "法国航空",
        "KLM": "荷兰皇家航空",
        "SWR": "瑞士国际航空",
        "UAE": "阿联酋航空",
        "QTR": "卡塔尔航空",
        "THY": "土耳其航空",
        "UAL": "美联航",
        "DAL": "达美航空",
        "AAL": "美国航空",
        "ASA": "阿拉斯加航空",
        "QFA": "澳洲航空"
    ]

    static func name(forCallsign callsign: String) -> String {
        let prefix = String(callsign.prefix(3)).uppercased()
        return prefixes[prefix] ?? "商业航班"
    }
}

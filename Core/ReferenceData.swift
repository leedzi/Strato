import Foundation

struct Airline: Codable, Hashable, Sendable {
    var icao: String
    var iata: String
    var nameEN: String
    var nameZH: String
    var country: String
    var callsign: String

    var name: String { nameZH.isEmpty ? nameEN : nameZH }
}

/// Bundled airport and airline reference tables (see Scripts/data/build_reference_data.py).
struct ReferenceData: Sendable {
    let airports: [Airport]
    let majorAirports: [Airport]
    private let byIATA: [String: Int]
    private let byICAO: [String: Int]
    private let airlinesByICAO: [String: Airline]
    private let airlinesByIATA: [String: [Airline]]

    static let empty = ReferenceData(airports: [], airlines: [])

    /// Loaded once from the app bundle. Empty in targets that do not ship the tables (the widget).
    static let shared: ReferenceData = {
        guard let aURL = Bundle.main.url(forResource: "airports", withExtension: "tsv"),
              let aText = try? String(contentsOf: aURL, encoding: .utf8) else {
            return .empty
        }
        var airlineText = ""
        if let lURL = Bundle.main.url(forResource: "airlines", withExtension: "tsv"),
           let text = try? String(contentsOf: lURL, encoding: .utf8) {
            airlineText = text
        }
        return ReferenceData(airportsTSV: aText, airlinesTSV: airlineText)
    }()

    init(airports: [Airport], airlines: [Airline]) {
        self.airports = airports
        self.majorAirports = airports.filter { $0.size == .large }
        var iataIndex: [String: Int] = [:]
        var icaoIndex: [String: Int] = [:]
        for (i, a) in airports.enumerated() {
            if !a.iata.isEmpty, iataIndex[a.iata] == nil { iataIndex[a.iata] = i }
            if !a.icao.isEmpty, icaoIndex[a.icao] == nil { icaoIndex[a.icao] = i }
        }
        self.byIATA = iataIndex
        self.byICAO = icaoIndex
        var airlineIndex: [String: Airline] = [:]
        var iataAirlines: [String: [Airline]] = [:]
        for l in airlines where airlineIndex[l.icao] == nil {
            airlineIndex[l.icao] = l
            if !l.iata.isEmpty { iataAirlines[l.iata, default: []].append(l) }
        }
        self.airlinesByICAO = airlineIndex
        self.airlinesByIATA = iataAirlines
    }

    init(airportsTSV: String, airlinesTSV: String) {
        self.init(
            airports: ReferenceData.parseAirports(airportsTSV),
            airlines: ReferenceData.parseAirlines(airlinesTSV)
        )
    }

    // MARK: Parsing

    private static func rows(_ tsv: String) -> [[Substring]] {
        var out: [[Substring]] = []
        var first = true
        for line in tsv.split(omittingEmptySubsequences: true, whereSeparator: { $0 == "\n" || $0 == "\r\n" || $0 == "\r" }) {
            if first {
                first = false
                continue // header
            }
            out.append(line.split(separator: "\t", omittingEmptySubsequences: false))
        }
        return out
    }

    static func parseAirports(_ tsv: String) -> [Airport] {
        var result: [Airport] = []
        for f in rows(tsv) {
            guard f.count >= 12, let lat = Double(f[2]), let lon = Double(f[3]) else { continue }
            let iata = String(f[0])
            let icao = String(f[1])
            guard !iata.isEmpty || !icao.isEmpty else { continue }
            let country = String(f[5])
            var tz = String(f[6])
            // Mainland China keeps a single time zone, so a missing entry there is safe to fill in.
            if tz.isEmpty, country == "CN" { tz = "Asia/Shanghai" }
            // "Shanghai (Pudong)" -> "Shanghai": the bracketed district is noise on a boarding pass.
            var cityEN = String(f[8])
            if let bracket = cityEN.range(of: " (") { cityEN = String(cityEN[..<bracket.lowerBound]) }
            result.append(Airport(
                iata: iata,
                icao: icao,
                lat: lat,
                lon: lon,
                elevationFt: Int(f[4]),
                country: country,
                tz: tz,
                size: AirportSize(rawValue: String(f[7])) ?? .small,
                cityEN: cityEN,
                nameEN: String(f[9]),
                cityZH: String(f[10]),
                nameZH: String(f[11])
            ))
        }
        return result
    }

    static func parseAirlines(_ tsv: String) -> [Airline] {
        var result: [Airline] = []
        for f in rows(tsv) {
            guard f.count >= 6, f[0].count == 3 else { continue }
            result.append(Airline(
                icao: String(f[0]),
                iata: String(f[1]),
                nameEN: String(f[2]),
                nameZH: String(f[3]),
                country: String(f[4]),
                callsign: String(f[5])
            ))
        }
        return result
    }

    // MARK: Lookup

    func airport(code: String) -> Airport? {
        let c = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if c.count == 3, let i = byIATA[c] { return airports[i] }
        if c.count == 4, let i = byICAO[c] { return airports[i] }
        return nil
    }

    func airline(icao: String?) -> Airline? {
        guard let icao, icao.count == 3 else { return nil }
        return airlinesByICAO[icao.uppercased()]
    }

    /// Radio callsigns a typed flight number could mean: "CA1831" -> ["CCA1831"], "CCA1831" -> itself.
    /// IATA codes are reused between airlines, so there can be more than one candidate.
    func callsignCandidates(forFlightNumber text: String) -> [String] {
        let s = String(text.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) })
        guard s.count >= 3, s.count <= 8 else { return [] }
        var out: [String] = []
        if Callsign.isAirline(s) { out.append(s) }
        let prefix = String(s.prefix(2))
        let rest = String(s.dropFirst(2))
        if let first = rest.first, first.isNumber, let matches = airlinesByIATA[prefix] {
            // Airlines with a Chinese name are the well-known ones; try those first.
            let ordered = matches.sorted { !$0.nameZH.isEmpty && $1.nameZH.isEmpty }
            for airline in ordered.prefix(4) {
                // Operators usually drop leading zeros on the radio.
                let trimmed = String(rest.drop { $0 == "0" })
                out.append(airline.icao + (trimmed.isEmpty ? "0" : trimmed))
            }
        }
        var seen = Set<String>()
        return out.filter { Callsign.isSafeForURL($0) && seen.insert($0).inserted }
    }

    func airlineName(icao: String?, fallback: String? = nil) -> String {
        if let a = airline(icao: icao) { return a.name }
        if let fallback, !fallback.isEmpty { return fallback }
        return icao ?? ""
    }

    /// Nearest airport among `candidates` (defaults to large airports) within `maxKm`.
    func nearestAirport(to p: GeoPoint, maxKm: Double = 400, majorOnly: Bool = true) -> (airport: Airport, km: Double)? {
        let pool = majorOnly ? majorAirports : airports
        var best: (Airport, Double)?
        let latWindow = maxKm / 111.0
        for a in pool {
            if abs(a.lat - p.lat) > latWindow { continue }
            let d = Geo.distanceKm(p, a.point)
            if d <= maxKm, d < (best?.1 ?? .infinity) { best = (a, d) }
        }
        if let best { return (best.0, best.1) }
        return nil
    }

    /// Airport search for pickers: code prefix first, then Chinese / English name matches; bigger airports first.
    func searchAirports(_ query: String, limit: Int = 40) -> [Airport] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return Array(majorAirports.prefix(limit)) }
        let upper = q.uppercased()
        let lower = q.lowercased()
        var scored: [(Int, Int, Airport)] = []
        for (i, a) in airports.enumerated() {
            var score = -1
            if a.iata == upper { score = 0 }
            else if a.icao == upper { score = 1 }
            else if a.cityZH.hasPrefix(q) { score = 2 }
            else if a.cityEN.lowercased().hasPrefix(lower) { score = 3 }
            else if upper.count >= 2, a.iata.hasPrefix(upper) { score = 4 }
            else if a.cityZH.contains(q) || a.nameZH.contains(q) { score = 5 }
            else if lower.count >= 3, a.nameEN.lowercased().contains(lower) || a.cityEN.lowercased().contains(lower) { score = 6 }
            if score >= 0 { scored.append((score * 10 + a.size.rank, i, a)) }
        }
        scored.sort { $0.0 != $1.0 ? $0.0 < $1.0 : $0.1 < $1.1 }
        return scored.prefix(limit).map { $0.2 }
    }
}

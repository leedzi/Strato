import Foundation

// MARK: - Airports

enum AirportSize: String, Codable, Sendable {
    case large = "L"
    case medium = "M"
    case small = "S"

    var rank: Int {
        switch self {
        case .large: return 0
        case .medium: return 1
        case .small: return 2
        }
    }
}

struct Airport: Codable, Hashable, Identifiable, Sendable {
    var iata: String
    var icao: String
    var lat: Double
    var lon: Double
    var elevationFt: Int?
    var country: String
    var tz: String
    var size: AirportSize
    var cityEN: String
    var nameEN: String
    var cityZH: String
    var nameZH: String

    init(
        iata: String,
        icao: String = "",
        lat: Double,
        lon: Double,
        elevationFt: Int? = nil,
        country: String = "",
        tz: String = "",
        size: AirportSize = .medium,
        cityEN: String = "",
        nameEN: String = "",
        cityZH: String = "",
        nameZH: String = ""
    ) {
        self.iata = iata
        self.icao = icao
        self.lat = lat
        self.lon = lon
        self.elevationFt = elevationFt
        self.country = country
        self.tz = tz
        self.size = size
        self.cityEN = cityEN
        self.nameEN = nameEN
        self.cityZH = cityZH
        self.nameZH = nameZH
    }

    var id: String { code }
    var code: String { iata.isEmpty ? icao : iata }
    var point: GeoPoint { GeoPoint(lat, lon) }
    /// Short display name, Chinese when we have it.
    var city: String {
        if !cityZH.isEmpty { return cityZH }
        if !cityEN.isEmpty { return cityEN }
        return code
    }
    var fullName: String { nameZH.isEmpty ? nameEN : nameZH }
    var timeZone: TimeZone? { tz.isEmpty ? nil : TimeZone(identifier: tz) }
}

// MARK: - Live aircraft

enum DataSource: String, Codable, Sendable, CaseIterable {
    case adsbfi
    case adsblol
    case opensky
    case sim

    var title: String {
        switch self {
        case .adsbfi: return "adsb.fi"
        case .adsblol: return "adsb.lol"
        case .opensky: return "OpenSky"
        case .sim: return "模拟"
        }
    }
}

/// One position report for one aircraft. Aviation units throughout: feet, knots, feet per minute.
struct AircraftState: Codable, Hashable, Sendable {
    var hex: String
    var callsign: String
    var registration: String?
    var typeCode: String?
    var typeName: String?
    var lat: Double
    var lon: Double
    var altitudeFt: Int?
    var onGround: Bool
    var groundSpeedKt: Double?
    var trackDeg: Double?
    var verticalRateFpm: Int?
    var mach: Double?
    var iasKt: Int?
    var tasKt: Int?
    var rollDeg: Double?
    var squawk: String?
    var category: String?
    var windDirDeg: Int?
    var windSpeedKt: Int?
    var outsideTempC: Int?
    var selectedAltitudeFt: Int?
    /// When this position was valid (fetch time minus the feed's reported age).
    var positionTime: Date
    var source: DataSource

    init(
        hex: String,
        callsign: String,
        registration: String? = nil,
        typeCode: String? = nil,
        typeName: String? = nil,
        lat: Double,
        lon: Double,
        altitudeFt: Int? = nil,
        onGround: Bool = false,
        groundSpeedKt: Double? = nil,
        trackDeg: Double? = nil,
        verticalRateFpm: Int? = nil,
        mach: Double? = nil,
        iasKt: Int? = nil,
        tasKt: Int? = nil,
        rollDeg: Double? = nil,
        squawk: String? = nil,
        category: String? = nil,
        windDirDeg: Int? = nil,
        windSpeedKt: Int? = nil,
        outsideTempC: Int? = nil,
        selectedAltitudeFt: Int? = nil,
        positionTime: Date,
        source: DataSource
    ) {
        self.hex = hex
        self.callsign = callsign
        self.registration = registration
        self.typeCode = typeCode
        self.typeName = typeName
        self.lat = lat
        self.lon = lon
        self.altitudeFt = altitudeFt
        self.onGround = onGround
        self.groundSpeedKt = groundSpeedKt
        self.trackDeg = trackDeg
        self.verticalRateFpm = verticalRateFpm
        self.mach = mach
        self.iasKt = iasKt
        self.tasKt = tasKt
        self.rollDeg = rollDeg
        self.squawk = squawk
        self.category = category
        self.windDirDeg = windDirDeg
        self.windSpeedKt = windSpeedKt
        self.outsideTempC = outsideTempC
        self.selectedAltitudeFt = selectedAltitudeFt
        self.positionTime = positionTime
        self.source = source
    }

    var point: GeoPoint { GeoPoint(lat, lon) }

    /// True for callsigns shaped like an airline flight (three-letter ICAO designator then a digit).
    var hasAirlineCallsign: Bool { Callsign.isAirline(callsign) }

    var isAirborne: Bool {
        !onGround && (altitudeFt ?? 0) > 500 && (groundSpeedKt ?? 0) > 80
    }

    /// Fills in fields this report lacks from an earlier, richer report of the same aircraft.
    func inheritingDetails(from older: AircraftState) -> AircraftState {
        var s = self
        if s.registration == nil { s.registration = older.registration }
        if s.typeCode == nil { s.typeCode = older.typeCode }
        if s.typeName == nil { s.typeName = older.typeName }
        if s.callsign.isEmpty { s.callsign = older.callsign }
        if s.category == nil { s.category = older.category }
        return s
    }
}

enum Callsign {
    static func clean(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }

    /// e.g. CCA1831, DLH2HT, BAW9. Excludes registrations used as callsigns (N123AB, GABCD).
    static func isAirline(_ cs: String) -> Bool {
        let chars = Array(cs.unicodeScalars)
        guard chars.count >= 4 && chars.count <= 8 else { return false }
        for i in 0..<3 where !(chars[i].value >= 65 && chars[i].value <= 90) { return false }
        guard chars[3].value >= 48 && chars[3].value <= 57 else { return false }
        for c in chars[4...] {
            let isDigit = c.value >= 48 && c.value <= 57
            let isUpper = c.value >= 65 && c.value <= 90
            if !isDigit && !isUpper { return false }
        }
        return true
    }

    static func airlinePrefix(_ cs: String) -> String? {
        isAirline(cs) ? String(cs.prefix(3)) : nil
    }

    static func isSafeForURL(_ cs: String) -> Bool {
        guard cs.count >= 3 && cs.count <= 8 else { return false }
        return cs.unicodeScalars.allSatisfy { ($0.value >= 48 && $0.value <= 57) || ($0.value >= 65 && $0.value <= 90) }
    }
}

// MARK: - Routes

enum RouteSource: String, Codable, Sendable {
    case vrs
    case adsbdb
    case sim
}

struct FlightRoute: Codable, Hashable, Sendable {
    var callsign: String
    var flightNumber: String?
    var airlineICAO: String?
    var airlineName: String?
    var origin: Airport
    var destination: Airport
    var source: RouteSource

    var distanceKm: Double { Geo.distanceKm(origin.point, destination.point) }
}

struct LiveFlight: Codable, Hashable, Identifiable, Sendable {
    var state: AircraftState
    var route: FlightRoute?

    var id: String { state.hex }
    var callsign: String { state.callsign }
    /// "CA1831" when known, otherwise the radio callsign.
    var displayNumber: String {
        if let n = route?.flightNumber, !n.isEmpty { return n }
        return state.callsign.isEmpty ? state.hex.uppercased() : state.callsign
    }
    var airlineICAO: String? { route?.airlineICAO ?? Callsign.airlinePrefix(state.callsign) }
    var isSimulated: Bool { state.source == .sim }
}

// MARK: - Flight phase

enum FlightPhase: String, Codable, Sendable {
    case ground
    case climb
    case cruise
    case descent
    case approach
    case landed

    var title: String {
        switch self {
        case .ground: return "地面滑行"
        case .climb: return "爬升中"
        case .cruise: return "巡航中"
        case .descent: return "下降中"
        case .approach: return "进近中"
        case .landed: return "已落地"
        }
    }

    var symbol: String {
        switch self {
        case .ground: return "road.lanes"
        case .climb: return "airplane.departure"
        case .cruise: return "airplane"
        case .descent: return "arrow.down.right"
        case .approach: return "airplane.arrival"
        case .landed: return "checkmark.seal.fill"
        }
    }
}

// MARK: - Focus

enum FocusTag: String, Codable, CaseIterable, Identifiable, Sendable {
    case deepWork
    case coding
    case study
    case reading
    case writing
    case creative
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deepWork: return "深度工作"
        case .coding: return "写代码"
        case .study: return "学习"
        case .reading: return "阅读"
        case .writing: return "写作"
        case .creative: return "创作"
        case .other: return "其他"
        }
    }

    var symbol: String {
        switch self {
        case .deepWork: return "sparkles"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .study: return "graduationcap.fill"
        case .reading: return "book.fill"
        case .writing: return "pencil.line"
        case .creative: return "paintpalette.fill"
        case .other: return "circle.grid.2x2.fill"
        }
    }
}

enum CabinClass: String, Codable, CaseIterable, Sendable {
    case economy
    case premium
    case business
    case first

    var title: String {
        switch self {
        case .economy: return "经济舱"
        case .premium: return "超级经济舱"
        case .business: return "公务舱"
        case .first: return "头等舱"
        }
    }

    var english: String {
        switch self {
        case .economy: return "ECONOMY"
        case .premium: return "PREMIUM ECONOMY"
        case .business: return "BUSINESS"
        case .first: return "FIRST"
        }
    }

    /// IATA compartment code printed on passes and encoded in the barcode.
    var code: String {
        switch self {
        case .economy: return "Y"
        case .premium: return "W"
        case .business: return "J"
        case .first: return "F"
        }
    }
}

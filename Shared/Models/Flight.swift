import Foundation
import CoreLocation

public enum FlightPhase: String, Codable, Sendable {
    case boarding = "登机准备"
    case climbing = "爬升出港"
    case cruising = "平流层巡航"
    case descending = "下降进近"
    case finalApproach = "五边进近"
    case landed = "已安全降落"

    public var symbolName: String {
        switch self {
        case .boarding: return "airplane.departure"
        case .climbing: return "arrow.up.right.circle.fill"
        case .cruising: return "airplane"
        case .descending: return "arrow.down.right.circle.fill"
        case .finalApproach: return "airplane.arrival"
        case .landed: return "checkmark.seal.fill"
        }
    }
}

public enum FocusTag: String, CaseIterable, Codable, Identifiable, Sendable {
    case deepWork = "深度工作"
    case coding = "写代码"
    case study = "学习备考"
    case reading = "沉浸阅读"
    case writing = "写作输出"
    case creative = "设计创作"

    public var id: String { rawValue }

    public var symbol: String {
        switch self {
        case .deepWork: return "sparkles"
        case .coding: return "chevron.left.forwardslash.chevron.right"
        case .study: return "graduationcap.fill"
        case .reading: return "book.fill"
        case .writing: return "pencil.line"
        case .creative: return "paintpalette.fill"
        }
    }
}

public enum RadarScope: String, CaseIterable, Codable, Identifiable, Sendable {
    case globalLive = "全球实时全量"
    case eastAsia = "亚太走廊"
    case europe = "欧洲干线"
    case northAmerica = "北美空域"

    public var id: String { rawValue }

    /// Multi-point radar array scanned concurrently so the user sees hundreds of real flights worldwide without manual switching.
    public var scanHubs: [CLLocationCoordinate2D] {
        switch self {
        case .globalLive:
            return [
                CLLocationCoordinate2D(latitude: 31.14, longitude: 121.81), // Shanghai / East China Sea
                CLLocationCoordinate2D(latitude: 39.51, longitude: 116.41), // Beijing / North China
                CLLocationCoordinate2D(latitude: 22.64, longitude: 113.81), // Shenzhen / Hong Kong / GBA
                CLLocationCoordinate2D(latitude: 35.55, longitude: 139.78), // Tokyo / Kanto
                CLLocationCoordinate2D(latitude: 34.43, longitude: 135.24), // Osaka / Kansai
                CLLocationCoordinate2D(latitude: 37.46, longitude: 126.44), // Seoul / Incheon
                CLLocationCoordinate2D(latitude: 1.36, longitude: 103.99),  // Singapore / Malacca
                CLLocationCoordinate2D(latitude: 51.47, longitude: -0.45),  // London / UK
                CLLocationCoordinate2D(latitude: 50.04, longitude: 8.56),   // Frankfurt / Central Europe
                CLLocationCoordinate2D(latitude: 25.25, longitude: 55.36),  // Dubai / Middle East
                CLLocationCoordinate2D(latitude: 40.64, longitude: -73.78), // New York / US East
                CLLocationCoordinate2D(latitude: 37.62, longitude: -122.38) // San Francisco / US West
            ]
        case .eastAsia:
            return [
                CLLocationCoordinate2D(latitude: 31.14, longitude: 121.81),
                CLLocationCoordinate2D(latitude: 39.51, longitude: 116.41),
                CLLocationCoordinate2D(latitude: 22.64, longitude: 113.81),
                CLLocationCoordinate2D(latitude: 30.58, longitude: 103.95),
                CLLocationCoordinate2D(latitude: 35.55, longitude: 139.78),
                CLLocationCoordinate2D(latitude: 34.43, longitude: 135.24),
                CLLocationCoordinate2D(latitude: 37.46, longitude: 126.44),
                CLLocationCoordinate2D(latitude: 25.08, longitude: 121.23)
            ]
        case .europe:
            return [
                CLLocationCoordinate2D(latitude: 51.47, longitude: -0.45),
                CLLocationCoordinate2D(latitude: 49.01, longitude: 2.55),
                CLLocationCoordinate2D(latitude: 50.04, longitude: 8.56),
                CLLocationCoordinate2D(latitude: 52.31, longitude: 4.77),
                CLLocationCoordinate2D(latitude: 41.28, longitude: 28.75)
            ]
        case .northAmerica:
            return [
                CLLocationCoordinate2D(latitude: 40.64, longitude: -73.78),
                CLLocationCoordinate2D(latitude: 41.97, longitude: -87.91),
                CLLocationCoordinate2D(latitude: 33.64, longitude: -84.43),
                CLLocationCoordinate2D(latitude: 33.94, longitude: -118.41),
                CLLocationCoordinate2D(latitude: 37.62, longitude: -122.38)
            ]
        }
    }
}

public struct LiveFlight: Identifiable, Codable, Hashable, Sendable {
    public let id: String                 // ICAO24 hex (e.g. "84b81c")
    public let callsign: String           // e.g. "ANA975"
    public let iataFlightNumber: String   // e.g. "NH975"
    public let registration: String       // e.g. "JA217A"
    public let aircraftType: String       // e.g. "A20N"
    public let aircraftDescription: String // e.g. "AIRBUS A-320neo"
    public var airlineName: String        // e.g. "全日空 (ANA)"
    public var origin: Airport?
    public var destination: Airport?
    public var isRouteVerified: Bool      // True if verified from schedule DB, false if geometrically inferred
    public var latitude: Double
    public var longitude: Double
    public var altitudeFeet: Int
    public var groundSpeedKnots: Double
    public var indicatedAirspeedKnots: Int?
    public var trueAirspeedKnots: Int?
    public var mach: Double?
    public var trackDegrees: Double
    public var rollDegrees: Double?
    public var verticalRateFpm: Int
    public var squawk: String?
    public let isLiveADSB: Bool
    public var updatedAt: Date

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    public var displayCallsign: String {
        if !iataFlightNumber.isEmpty && iataFlightNumber != callsign {
            return "\(callsign) / \(iataFlightNumber)"
        }
        return callsign
    }

    public var routeTitle: String {
        let orig = origin?.iata ?? "LIVE"
        let dest = destination?.iata ?? "DEST"
        return "\(orig) → \(dest)"
    }

    public var flightLevelText: String {
        if altitudeFeet >= 10_000 {
            return String(format: "FL%03d", altitudeFeet / 100)
        } else if altitudeFeet > 0 {
            return "\(altitudeFeet) ft"
        }
        return "GND"
    }

    public var machText: String {
        if let mach, mach > 0.3 {
            return String(format: "M %.2f", mach)
        }
        // Estimate Mach from ground speed at cruise altitude
        if altitudeFeet >= 24_000 && groundSpeedKnots > 300 {
            let estMach = min(0.92, max(0.55, groundSpeedKnots / 576.0))
            return String(format: "M %.2f", estMach)
        }
        return "\(Int(groundSpeedKnots)) kt"
    }

    public var verticalRateText: String {
        if abs(verticalRateFpm) < 100 {
            return "0 fpm"
        }
        return verticalRateFpm > 0 ? "+\(verticalRateFpm) fpm" : "\(verticalRateFpm) fpm"
    }

    public var remainingDistanceNM: Double {
        guard let dest = destination else { return 0 }
        return GreatCircle.distanceNM(from: coordinate, to: dest.coordinate)
    }

    public var remainingDistanceKM: Double {
        remainingDistanceNM * 1.852
    }

    public var flownDistanceKM: Double {
        guard let origin else { return 0 }
        return GreatCircle.distanceKM(from: origin.coordinate, to: coordinate)
    }

    public var totalRouteDistanceKM: Double {
        guard let origin, let destination else { return max(remainingDistanceKM + flownDistanceKM, 600) }
        let direct = GreatCircle.distanceKM(from: origin.coordinate, to: destination.coordinate)
        return max(direct, flownDistanceKM + remainingDistanceKM, 80)
    }

    /// Real-time estimated remaining minutes based on the aircraft's ACTUAL current distance to destination and live ground speed.
    public var estimatedRemainingMinutes: Int {
        guard destination != nil else { return 60 }
        let effectiveSpeedKnots = max(groundSpeedKnots, 260)
        let hours = remainingDistanceNM / effectiveSpeedKnots
        let approachBuffer = altitudeFeet > 10_000 ? 7.0 : 2.0
        return max(3, Int((hours * 60.0 + approachBuffer).rounded()))
    }

    /// The aircraft's ACTUAL real-world completion ratio along its route (0.01 ... 0.99).
    /// When the user boards a flight mid-air, this starts at the plane's true progress (e.g. 0.64), NEVER 0!
    public var realFlightProgress: Double {
        guard origin != nil, destination != nil else { return 0.5 }
        let flown = flownDistanceKM
        let rem = remainingDistanceKM
        let total = flown + rem
        guard total > 5 else { return 0.5 }
        return min(max(flown / total, 0.02), 0.99)
    }

    public var phase: FlightPhase {
        if altitudeFeet < 600 && groundSpeedKnots < 80 {
            return .landed
        }
        if remainingDistanceNM < 25 && altitudeFeet < 6_500 {
            return .finalApproach
        }
        if verticalRateFpm > 350 {
            return .climbing
        }
        if verticalRateFpm < -350 || (remainingDistanceNM < 85 && altitudeFeet < 18_500) {
            return .descending
        }
        return .cruising
    }

    public init(
        id: String,
        callsign: String,
        iataFlightNumber: String = "",
        registration: String = "",
        aircraftType: String = "A320",
        aircraftDescription: String = "",
        airlineName: String = "商业航班",
        origin: Airport? = nil,
        destination: Airport? = nil,
        isRouteVerified: Bool = false,
        latitude: Double,
        longitude: Double,
        altitudeFeet: Int,
        groundSpeedKnots: Double,
        indicatedAirspeedKnots: Int? = nil,
        trueAirspeedKnots: Int? = nil,
        mach: Double? = nil,
        trackDegrees: Double,
        rollDegrees: Double? = nil,
        verticalRateFpm: Int = 0,
        squawk: String? = nil,
        isLiveADSB: Bool,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.callsign = callsign
        self.iataFlightNumber = iataFlightNumber
        self.registration = registration
        self.aircraftType = aircraftType
        self.aircraftDescription = aircraftDescription
        self.airlineName = airlineName
        self.origin = origin
        self.destination = destination
        self.isRouteVerified = isRouteVerified
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeFeet = altitudeFeet
        self.groundSpeedKnots = groundSpeedKnots
        self.indicatedAirspeedKnots = indicatedAirspeedKnots
        self.trueAirspeedKnots = trueAirspeedKnots
        self.mach = mach
        self.trackDegrees = trackDegrees
        self.rollDegrees = rollDegrees
        self.verticalRateFpm = verticalRateFpm
        self.squawk = squawk
        self.isLiveADSB = isLiveADSB
        self.updatedAt = updatedAt
    }
}

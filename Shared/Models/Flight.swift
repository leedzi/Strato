import Foundation
import CoreLocation

public enum FlightPhase: String, Codable, Sendable {
    case boarding = "登机中"
    case climbing = "爬升"
    case cruising = "平流层巡航"
    case descending = "下降进近"
    case landed = "已安全降落"

    public var symbolName: String {
        switch self {
        case .boarding: return "airplane.departure"
        case .climbing: return "airplane.departure"
        case .cruising: return "airplane"
        case .descending: return "airplane.arrival"
        case .landed: return "checkmark.seal.fill"
        }
    }
}

public enum FocusTag: String, CaseIterable, Codable, Identifiable, Sendable {
    case deepWork = "深度工作"
    case coding = "写代码"
    case study = "学习"
    case reading = "阅读"
    case writing = "写作"
    case creative = "创作"

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

public enum RadarRegion: String, CaseIterable, Codable, Identifiable, Sendable {
    case eastAsia = "东亚航路"
    case europe = "欧洲核心"
    case northAmerica = "北美走廊"
    case southeastAsia = "东南亚枢纽"

    public var id: String { rawValue }

    public var center: CLLocationCoordinate2D {
        switch self {
        case .eastAsia: return CLLocationCoordinate2D(latitude: 33.5, longitude: 126.5)
        case .europe: return CLLocationCoordinate2D(latitude: 49.8, longitude: 6.5)
        case .northAmerica: return CLLocationCoordinate2D(latitude: 38.5, longitude: -98.0)
        case .southeastAsia: return CLLocationCoordinate2D(latitude: 11.5, longitude: 105.0)
        }
    }

    /// Radar scan points (250 NM radius each) to pull rich live ADS-B traffic.
    public var scanCenters: [CLLocationCoordinate2D] {
        switch self {
        case .eastAsia:
            return [
                CLLocationCoordinate2D(latitude: 35.55, longitude: 139.78), // Tokyo
                CLLocationCoordinate2D(latitude: 37.46, longitude: 126.44), // Seoul
                CLLocationCoordinate2D(latitude: 22.31, longitude: 113.92), // Hong Kong / GBA
                CLLocationCoordinate2D(latitude: 31.14, longitude: 121.81)  // Shanghai
            ]
        case .europe:
            return [
                CLLocationCoordinate2D(latitude: 51.47, longitude: -0.45),  // London
                CLLocationCoordinate2D(latitude: 50.04, longitude: 8.56),   // Frankfurt
                CLLocationCoordinate2D(latitude: 49.01, longitude: 2.55)    // Paris
            ]
        case .northAmerica:
            return [
                CLLocationCoordinate2D(latitude: 40.64, longitude: -73.78), // New York
                CLLocationCoordinate2D(latitude: 41.97, longitude: -87.91), // Chicago
                CLLocationCoordinate2D(latitude: 33.94, longitude: -118.41) // Los Angeles
            ]
        case .southeastAsia:
            return [
                CLLocationCoordinate2D(latitude: 1.36, longitude: 103.99),  // Singapore
                CLLocationCoordinate2D(latitude: 13.69, longitude: 100.75)  // Bangkok
            ]
        }
    }
}

public struct LiveFlight: Identifiable, Codable, Hashable, Sendable {
    public let id: String          // ICAO24 hex or synthetic id
    public let callsign: String    // e.g., "ANA851", "CES575", "BAW117"
    public let registration: String
    public let aircraftType: String
    public let airlineName: String
    public var origin: Airport?
    public var destination: Airport?
    public var latitude: Double
    public var longitude: Double
    public var altitudeFeet: Int
    public var groundSpeedKnots: Double
    public var trackDegrees: Double
    public var verticalRateFpm: Int
    public let isLiveADSB: Bool
    public var updatedAt: Date

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
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

    public var remainingDistanceNM: Double {
        guard let dest = destination else { return 0 }
        return GreatCircle.distanceNM(from: coordinate, to: dest.coordinate)
    }

    public var remainingDistanceKM: Double {
        remainingDistanceNM * 1.852
    }

    public var totalRouteDistanceKM: Double {
        guard let origin, let destination else { return max(remainingDistanceKM, 600) }
        return max(GreatCircle.distanceKM(from: origin.coordinate, to: destination.coordinate), 100)
    }

    /// Real-time estimated remaining minutes based on current live ground speed and great-circle distance to destination.
    public var estimatedRemainingMinutes: Int {
        guard destination != nil else { return 60 }
        let effectiveSpeed = max(groundSpeedKnots, 280) // guard against climb/descent slow speeds
        let hours = remainingDistanceNM / effectiveSpeed
        // Add 8 min approach/taxi buffer when still airborne at cruise
        let approachBuffer = altitudeFeet > 8_000 ? 8.0 : 2.0
        return max(5, Int((hours * 60.0 + approachBuffer).rounded()))
    }

    public var progress: Double {
        guard let origin, let destination else { return 0.35 }
        let total = GreatCircle.distanceKM(from: origin.coordinate, to: destination.coordinate)
        guard total > 1 else { return 0.5 }
        let remaining = GreatCircle.distanceKM(from: coordinate, to: destination.coordinate)
        return min(max(1.0 - (remaining / total), 0.02), 0.99)
    }

    public var phase: FlightPhase {
        if altitudeFeet < 500 && groundSpeedKnots < 60 {
            return .landed
        }
        if verticalRateFpm > 350 {
            return .climbing
        }
        if verticalRateFpm < -350 || (remainingDistanceNM < 65 && altitudeFeet < 18_000) {
            return .descending
        }
        return .cruising
    }

    public init(
        id: String,
        callsign: String,
        registration: String = "",
        aircraftType: String = "A359",
        airlineName: String = "Strato Air",
        origin: Airport? = nil,
        destination: Airport? = nil,
        latitude: Double,
        longitude: Double,
        altitudeFeet: Int,
        groundSpeedKnots: Double,
        trackDegrees: Double,
        verticalRateFpm: Int = 0,
        isLiveADSB: Bool,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.callsign = callsign
        self.registration = registration
        self.aircraftType = aircraftType
        self.airlineName = airlineName
        self.origin = origin
        self.destination = destination
        self.latitude = latitude
        self.longitude = longitude
        self.altitudeFeet = altitudeFeet
        self.groundSpeedKnots = groundSpeedKnots
        self.trackDegrees = trackDegrees
        self.verticalRateFpm = verticalRateFpm
        self.isLiveADSB = isLiveADSB
        self.updatedAt = updatedAt
    }
}

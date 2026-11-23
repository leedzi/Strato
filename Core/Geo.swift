import Foundation

/// A WGS-84 coordinate. Core code uses this instead of CoreLocation types so it stays testable anywhere.
struct GeoPoint: Codable, Hashable, Sendable {
    var lat: Double
    var lon: Double

    init(_ lat: Double, _ lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

/// Great-circle maths on a spherical Earth. Distances in kilometres, angles in degrees.
enum Geo {
    static let earthRadiusKm = 6371.0088
    static let kmPerNM = 1.852

    private static func rad(_ d: Double) -> Double { d * .pi / 180 }
    private static func deg(_ r: Double) -> Double { r * 180 / .pi }

    static func normalizeLon(_ lon: Double) -> Double {
        var l = (lon + 180).truncatingRemainder(dividingBy: 360)
        if l < 0 { l += 360 }
        return l - 180
    }

    static func normalizeHeading(_ h: Double) -> Double {
        var v = h.truncatingRemainder(dividingBy: 360)
        if v < 0 { v += 360 }
        return v
    }

    static func distanceKm(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let lat1 = rad(a.lat), lat2 = rad(b.lat)
        let dLat = lat2 - lat1
        let dLon = rad(b.lon - a.lon)
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadiusKm * atan2(sqrt(h), sqrt(max(0, 1 - h)))
    }

    /// Initial bearing from `a` to `b`, 0...360 clockwise from true north.
    static func bearing(_ a: GeoPoint, _ b: GeoPoint) -> Double {
        let lat1 = rad(a.lat), lat2 = rad(b.lat)
        let dLon = rad(b.lon - a.lon)
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return normalizeHeading(deg(atan2(y, x)))
    }

    /// Smallest absolute difference between two headings, 0...180.
    static func angleDiff(_ a: Double, _ b: Double) -> Double {
        let d = abs(a - b).truncatingRemainder(dividingBy: 360)
        return d > 180 ? 360 - d : d
    }

    /// Point at fraction `t` (0...1) along the great circle from `a` to `b`.
    static func interpolate(_ a: GeoPoint, _ b: GeoPoint, _ t: Double) -> GeoPoint {
        let f = min(max(t, 0), 1)
        let lat1 = rad(a.lat), lon1 = rad(a.lon)
        let lat2 = rad(b.lat), lon2 = rad(b.lon)
        let x1 = cos(lat1) * cos(lon1), y1 = cos(lat1) * sin(lon1), z1 = sin(lat1)
        let x2 = cos(lat2) * cos(lon2), y2 = cos(lat2) * sin(lon2), z2 = sin(lat2)
        let dot = min(max(x1 * x2 + y1 * y2 + z1 * z2, -1), 1)
        let omega = acos(dot)
        if omega < 1e-9 { return a }
        let s = sin(omega)
        let k1 = sin((1 - f) * omega) / s
        let k2 = sin(f * omega) / s
        let x = k1 * x1 + k2 * x2, y = k1 * y1 + k2 * y2, z = k1 * z1 + k2 * z2
        return GeoPoint(deg(atan2(z, sqrt(x * x + y * y))), deg(atan2(y, x)))
    }

    /// Point reached by travelling `distanceKm` from `from` on the given initial bearing.
    static func destination(from: GeoPoint, bearing: Double, distanceKm: Double) -> GeoPoint {
        let delta = distanceKm / earthRadiusKm
        let theta = rad(bearing)
        let lat1 = rad(from.lat), lon1 = rad(from.lon)
        let lat2 = asin(sin(lat1) * cos(delta) + cos(lat1) * sin(delta) * cos(theta))
        let lon2 = lon1 + atan2(sin(theta) * sin(delta) * cos(lat1), cos(delta) - sin(lat1) * sin(lat2))
        return GeoPoint(deg(lat2), normalizeLon(deg(lon2)))
    }

    /// Evenly spaced points along the great circle, including both ends.
    static func arc(_ a: GeoPoint, _ b: GeoPoint, segments: Int) -> [GeoPoint] {
        let n = max(1, segments)
        return (0...n).map { interpolate(a, b, Double($0) / Double(n)) }
    }

    /// Total length of a polyline in kilometres.
    static func pathLengthKm(_ points: [GeoPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<points.count { total += distanceKm(points[i - 1], points[i]) }
        return total
    }
}

/// Sun position, used for the "what's outside the window" hint.
enum Solar {
    /// Sun elevation above the horizon in degrees at a place and time (accuracy ~0.5°, plenty for day/night).
    static func elevation(at p: GeoPoint, date: Date) -> Double {
        let rad = Double.pi / 180
        let d = date.timeIntervalSince1970 / 86400.0 - 10957.5 // days since J2000.0
        let g = (357.529 + 0.98560028 * d) * rad
        let q = 280.459 + 0.98564736 * d
        let lambda = (q + 1.915 * sin(g) + 0.020 * sin(2 * g)) * rad
        let eps = (23.439 - 0.00000036 * d) * rad
        let ra = atan2(cos(eps) * sin(lambda), cos(lambda))
        let dec = asin(sin(eps) * sin(lambda))
        var gmstHours = (18.697374558 + 24.06570982441908 * d).truncatingRemainder(dividingBy: 24)
        if gmstHours < 0 { gmstHours += 24 }
        let lst = (gmstHours * 15 + p.lon) * rad
        let ha = lst - ra
        let lat = p.lat * rad
        let sinEl = sin(lat) * sin(dec) + cos(lat) * cos(dec) * cos(ha)
        return asin(min(max(sinEl, -1), 1)) / rad
    }

    enum Sky: String, Sendable {
        case day, sunrise, sunset, night
    }

    /// Classifies the sky. `later` is where the aircraft will be a few minutes from now, to tell dawn from dusk.
    static func sky(at p: GeoPoint, date: Date, later: GeoPoint? = nil, laterDate: Date? = nil) -> Sky {
        let el = elevation(at: p, date: date)
        if el > 6 { return .day }
        if el < -6 { return .night }
        let p2 = later ?? p
        let d2 = laterDate ?? date.addingTimeInterval(600)
        return elevation(at: p2, date: d2) >= el ? .sunrise : .sunset
    }
}

/// WGS-84 → GCJ-02 ("Mars coordinates"). Gaode map tiles are drawn in GCJ-02, so anything we draw on
/// top of them inside mainland China must be shifted the same way or it lands a few hundred metres off.
enum GCJ02 {
    private static let a = 6378245.0
    private static let ee = 0.00669342162296594323

    private static func transformLat(_ x: Double, _ y: Double) -> Double {
        var r = -100.0 + 2.0 * x + 3.0 * y + 0.2 * y * y + 0.1 * x * y + 0.2 * sqrt(abs(x))
        r += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        r += (20.0 * sin(y * .pi) + 40.0 * sin(y / 3.0 * .pi)) * 2.0 / 3.0
        r += (160.0 * sin(y / 12.0 * .pi) + 320.0 * sin(y * .pi / 30.0)) * 2.0 / 3.0
        return r
    }

    private static func transformLon(_ x: Double, _ y: Double) -> Double {
        var r = 300.0 + x + 2.0 * y + 0.1 * x * x + 0.1 * x * y + 0.1 * sqrt(abs(x))
        r += (20.0 * sin(6.0 * x * .pi) + 20.0 * sin(2.0 * x * .pi)) * 2.0 / 3.0
        r += (20.0 * sin(x * .pi) + 40.0 * sin(x / 3.0 * .pi)) * 2.0 / 3.0
        r += (150.0 * sin(x / 12.0 * .pi) + 300.0 * sin(x / 30.0 * .pi)) * 2.0 / 3.0
        return r
    }

    /// Unconditional transform. Callers decide whether the point is in the region where it applies.
    static func fromWGS(_ p: GeoPoint) -> GeoPoint {
        var dLat = transformLat(p.lon - 105.0, p.lat - 35.0)
        var dLon = transformLon(p.lon - 105.0, p.lat - 35.0)
        let radLat = p.lat / 180.0 * .pi
        var magic = sin(radLat)
        magic = 1 - ee * magic * magic
        let sqrtMagic = sqrt(magic)
        dLat = (dLat * 180.0) / ((a * (1 - ee)) / (magic * sqrtMagic) * .pi)
        dLon = (dLon * 180.0) / (a / sqrtMagic * cos(radLat) * .pi)
        return GeoPoint(p.lat + dLat, p.lon + dLon)
    }
}

/// A deliberately conservative outline of mainland China (plus Hong Kong / Macau), used to decide
/// where Gaode tiles are shown. It sits slightly inside the real border so neighbouring countries
/// always get the global imagery source.
enum ChinaRegion {
    /// (lat, lon) vertices, clockwise from the far north.
    private static let outline: [(Double, Double)] = [
        (53.3, 122.0), (52.0, 126.0), (49.3, 129.5), (47.9, 134.0), (45.3, 132.6), (43.0, 130.6),
        (41.6, 127.6), (40.2, 124.4), (38.9, 121.6), (37.6, 122.5), (36.0, 120.6), (34.4, 119.8),
        (31.6, 121.9), (29.9, 122.3), (27.3, 120.9), (25.2, 119.6), (24.0, 118.0), (22.6, 115.6),
        (22.1, 114.4), (21.9, 113.3), (21.3, 110.9), (20.2, 110.4), (20.0, 111.0), (18.2, 110.0),
        (18.2, 108.7), (19.6, 108.6), (20.3, 109.8), (21.5, 109.0), (21.6, 108.0), (22.7, 106.6),
        (22.6, 104.0), (21.4, 101.6), (22.0, 100.2), (23.9, 98.0), (26.0, 98.6), (28.0, 98.0),
        (28.6, 96.0), (28.2, 92.2), (28.1, 89.0), (28.6, 86.0), (30.2, 82.0), (32.2, 79.4),
        (35.2, 78.4), (37.0, 75.4), (39.6, 74.2), (41.8, 79.6), (44.8, 80.6), (46.9, 83.4),
        (48.8, 87.2), (46.2, 90.8), (44.8, 93.8), (42.6, 96.8), (42.4, 101.8), (41.6, 105.2),
        (42.6, 109.8), (43.6, 111.9), (45.0, 114.2), (46.6, 119.4), (47.6, 117.2), (49.4, 117.8),
        (50.0, 119.6), (52.6, 120.6)
    ]

    static func contains(_ p: GeoPoint) -> Bool {
        // Cheap reject first.
        guard p.lat > 18 && p.lat < 53.6 && p.lon > 73.5 && p.lon < 134.8 else { return false }
        var inside = false
        var j = outline.count - 1
        for i in 0..<outline.count {
            let (yi, xi) = outline[i]
            let (yj, xj) = outline[j]
            if (yi > p.lat) != (yj > p.lat) {
                let xCross = (xj - xi) * (p.lat - yi) / (yj - yi) + xi
                if p.lon < xCross { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// Coordinate to hand to a map that is showing GCJ-02 tiles in China.
    static func displayPoint(_ p: GeoPoint, gcjActive: Bool) -> GeoPoint {
        guard gcjActive, contains(p) else { return p }
        return GCJ02.fromWGS(p)
    }
}

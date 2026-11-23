import MapKit
import UIKit

/// Satellite imagery from third-party tile servers, with automatic failover.
///
/// - Inside mainland China: Gaode (AutoNavi) imagery, which is sharp there and reachable without a proxy.
/// - Elsewhere: Google imagery; when Google cannot be reached (as in mainland China without a proxy)
///   it switches to Esri World Imagery and stops trying Google for a while.
final class SatelliteTileOverlay: MKTileOverlay {
    enum Source: String {
        case gaode, google, esri
    }

    let provider: MapProvider

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        config.timeoutIntervalForResource = 12
        config.httpMaximumConnectionsPerHost = 8
        config.urlCache = URLCache(memoryCapacity: 32 << 20, diskCapacity: 256 << 20)
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"
        ]
        return URLSession(configuration: config)
    }()

    /// Remembers which sources are failing so a blocked one costs a timeout once, not once per tile.
    private final class Health: @unchecked Sendable {
        private let lock = NSLock()
        private var failures: [Source: Int] = [:]
        private var downUntil: [Source: Date] = [:]

        func isDown(_ s: Source) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard let until = downUntil[s] else { return false }
            if until < Date() {
                downUntil[s] = nil
                failures[s] = 0
                return false
            }
            return true
        }

        func report(_ s: Source, ok: Bool) {
            lock.lock()
            defer { lock.unlock() }
            if ok {
                failures[s] = 0
                return
            }
            let n = (failures[s] ?? 0) + 1
            failures[s] = n
            if n >= 4 { downUntil[s] = Date().addingTimeInterval(600) }
        }
    }

    private static let health = Health()

    init(provider: MapProvider) {
        self.provider = provider
        super.init(urlTemplate: nil)
        canReplaceMapContent = true
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 1
        maximumZ = 18
    }

    /// Whether this overlay draws China in GCJ-02 coordinates (so markers must be shifted to match).
    var usesGCJInChina: Bool { provider == .auto || provider == .gaode }

    static func tileCenter(_ path: MKTileOverlayPath) -> GeoPoint {
        let n = pow(2.0, Double(path.z))
        let lon = (Double(path.x) + 0.5) / n * 360 - 180
        let lat = atan(sinh(.pi * (1 - 2 * (Double(path.y) + 0.5) / n))) * 180 / .pi
        return GeoPoint(lat, lon)
    }

    /// Sources to try for a tile, in order.
    func sources(for path: MKTileOverlayPath) -> [Source] {
        let inChina = ChinaRegion.contains(Self.tileCenter(path))
        switch provider {
        case .google:
            return [.google, .esri]
        case .gaode:
            // Gaode has no detailed imagery abroad; Esri covers the rest of the world without a proxy.
            return inChina && path.z >= 5 ? [.gaode, .esri] : [.esri, .google]
        default:
            // Below zoom 5 a tile spans countries; one source keeps the colours consistent.
            if path.z < 5 { return [.google, .esri] }
            return inChina ? [.gaode, .esri] : [.google, .esri]
        }
    }

    static func url(_ source: Source, _ path: MKTileOverlayPath) -> URL? {
        let x = path.x, y = path.y, z = path.z
        switch source {
        case .gaode:
            return URL(string: "https://webst0\((x + y) % 4 + 1).is.autonavi.com/appmaptile?style=6&x=\(x)&y=\(y)&z=\(z)")
        case .google:
            // "y" is imagery with place names; ask for them in Chinese.
            return URL(string: "https://mt\((x + y) % 4).google.com/vt/lyrs=y&hl=zh-CN&x=\(x)&y=\(y)&z=\(z)")
        case .esri:
            return URL(string: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/\(z)/\(y)/\(x)")
        }
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        var order = sources(for: path)
        let healthy = order.filter { !Self.health.isDown($0) }
        if !healthy.isEmpty { order = healthy }
        attempt(order, path, result)
    }

    private func attempt(_ order: [Source], _ path: MKTileOverlayPath, _ result: @escaping (Data?, Error?) -> Void) {
        guard let source = order.first, let url = Self.url(source, path) else {
            result(nil, URLError(.cannotLoadFromNetwork))
            return
        }
        Self.session.dataTask(with: url) { [weak self] data, response, error in
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if let data, status == 200, data.count > 200 {
                Self.health.report(source, ok: true)
                result(data, nil)
                return
            }
            // A 404 just means "no imagery at this zoom here", which is not the server being down.
            if status != 404 { Self.health.report(source, ok: false) }
            guard let self else {
                result(nil, error)
                return
            }
            self.attempt(Array(order.dropFirst()), path, result)
        }.resume()
    }
}

/// Place names over the imagery: Gaode's label layer inside China (Chinese names, GCJ-02 like its imagery).
final class LabelTileOverlay: MKTileOverlay {
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 6
        config.urlCache = URLCache(memoryCapacity: 16 << 20, diskCapacity: 96 << 20)
        config.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: config)
    }()

    init() {
        super.init(urlTemplate: nil)
        canReplaceMapContent = false
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 5
        maximumZ = 18
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        guard ChinaRegion.contains(SatelliteTileOverlay.tileCenter(path)),
              let url = URL(string: "https://webst0\((path.x + path.y) % 4 + 1).is.autonavi.com/appmaptile?style=8&x=\(path.x)&y=\(path.y)&z=\(path.z)") else {
            result(Self.emptyTile, nil)
            return
        }
        Self.session.dataTask(with: url) { data, response, _ in
            if let data, (response as? HTTPURLResponse)?.statusCode == 200, data.count > 100 {
                result(data, nil)
            } else {
                result(Self.emptyTile, nil)
            }
        }.resume()
    }

    /// A fully transparent tile, so areas without labels do not show as errors.
    private static let emptyTile: Data = {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4), format: format).pngData { _ in }
    }()
}

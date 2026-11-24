import MapKit
import UIKit

/// Satellite imagery from third-party tile servers, with automatic failover.
///
/// One overlay draws the whole screen from a single source, so there is never a seam between
/// two providers. In "auto" the map view swaps the overlay as the user moves:
/// - looking at mainland China: Gaode (AutoNavi), sharp there and reachable without a proxy;
/// - anywhere else: Google, and when Google cannot be reached (as in mainland China without a
///   proxy) Esri World Imagery, without retrying Google for a while.
final class SatelliteTileOverlay: MKTileOverlay {
    enum Source: String {
        case gaode, google, esri
    }

    /// Which part of the world the map is looking at.
    enum Zone {
        case china, world
    }

    let provider: MapProvider
    let zone: Zone

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

    init(provider: MapProvider, zone: Zone) {
        self.provider = provider
        self.zone = zone
        super.init(urlTemplate: nil)
        canReplaceMapContent = true
        tileSize = CGSize(width: 256, height: 256)
        minimumZ = 1
        maximumZ = 18
    }

    /// The source this overlay prefers; the others are fallbacks.
    var primary: Source {
        switch provider {
        case .gaode: return .gaode
        case .google: return .google
        default: return zone == .china ? .gaode : .google
        }
    }

    /// Gaode draws China in GCJ-02 coordinates, so markers there must be shifted to match.
    var usesGCJInChina: Bool { primary == .gaode }

    private var order: [Source] {
        primary == .gaode ? [.gaode, .esri] : [.google, .esri]
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
        var sources = order
        let healthy = sources.filter { !Self.health.isDown($0) }
        if !healthy.isEmpty { sources = healthy }
        attempt(sources, path, result)
    }

    private func attempt(_ sources: [Source], _ path: MKTileOverlayPath, _ result: @escaping (Data?, Error?) -> Void) {
        guard let source = sources.first, let url = Self.url(source, path) else {
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
            self.attempt(Array(sources.dropFirst()), path, result)
        }.resume()
    }
}

/// Chinese place names and main roads over Gaode imagery (Gaode serves them as a separate layer).
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
        minimumZ = 3
        maximumZ = 18
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        guard let url = URL(string: "https://webst0\((path.x + path.y) % 4 + 1).is.autonavi.com/appmaptile?style=8&x=\(path.x)&y=\(path.y)&z=\(path.z)") else {
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

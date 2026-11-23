import SwiftUI
import MapKit

public enum StratoMapProvider: String, CaseIterable, Identifiable, Sendable {
    case autoHybrid = "auto_hybrid"
    case apple3DFlyover = "apple_3d"
    case amapChina = "amap_china"
    case googleSatellite = "google_sat"

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .autoHybrid: return "智能混合 (国内高德 / 海外谷歌卫星)"
        case .apple3DFlyover: return "Apple 3D 立体地球地景 (Flyover)"
        case .amapChina: return "高德高清地图 (AutoNavi)"
        case .googleSatellite: return "Google 全球高清卫星"
        }
    }

    public var shortTitle: String {
        switch self {
        case .autoHybrid: return "高德/Google 智能"
        case .apple3DFlyover: return "3D 立体地景"
        case .amapChina: return "高德地图"
        case .googleSatellite: return "Google 卫星"
        }
    }
}

/// Smart Multi-Source Tile Overlay:
/// - Inside China -> AutoNavi (Gaode) HD tiles
/// - Outside China -> Google Hybrid Satellite HD tiles (`mt.google.com/vt/lyrs=y`)
/// - Automatic Domestic Network Failover -> If Google tiles time out (e.g. without VPN in China),
///   seamlessly falls back to ArcGIS World Imagery HD Global Satellite tiles so the map is NEVER blank.
final class SmartGlobalTileOverlay: MKTileOverlay {
    let provider: StratoMapProvider

    private static let tileSession: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 3.5
        cfg.timeoutIntervalForResource = 6.0
        cfg.urlCache = URLCache(memoryCapacity: 48 * 1024 * 1024, diskCapacity: 180 * 1024 * 1024)
        cfg.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: cfg)
    }()

    init(provider: StratoMapProvider) {
        self.provider = provider
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = true
        self.tileSize = CGSize(width: 256, height: 256)
        self.maximumZ = 18
        self.minimumZ = 2
    }

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        let primaryURL = primaryTileURL(for: path)
        var req = URLRequest(url: primaryURL)
        req.setValue(
            "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148",
            forHTTPHeaderField: "User-Agent"
        )

        Self.tileSession.dataTask(with: req) { [weak self] data, response, error in
            if let data, !data.isEmpty,
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode) {
                result(data, nil)
                return
            }

            // Failover to global direct-connect satellite imagery (ArcGIS World Imagery) if Google is unreachable
            guard let self else {
                result(nil, error)
                return
            }
            let fallbackURL = self.fallbackSatelliteURL(for: path)
            var fallbackReq = URLRequest(url: fallbackURL)
            fallbackReq.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")
            Self.tileSession.dataTask(with: fallbackReq) { fbData, _, fbErr in
                result(fbData, fbErr)
            }.resume()
        }.resume()
    }

    private func primaryTileURL(for path: MKTileOverlayPath) -> URL {
        let x = path.x
        let y = path.y
        let z = path.z
        let server14 = ((x + y) % 4) + 1
        let server03 = (x + y) % 4

        switch provider {
        case .amapChina:
            // Gaode bilingual HD road + terrain map
            return URL(string: "https://webrd0\(server14).is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x=\(x)&y=\(y)&z=\(z)")!

        case .googleSatellite, .apple3DFlyover:
            return URL(string: "https://mt\(server03).google.com/vt/lyrs=y&hl=zh-CN&x=\(x)&y=\(y)&z=\(z)")!

        case .autoHybrid:
            let coord = Self.tileToCoordinate(x: x, y: y, z: z)
            if Self.isInsideChina(coord) {
                if z <= 6 {
                    // Stratospheric overview: Gaode Satellite imagery for seamless stitching
                    return URL(string: "https://webst0\(server14).is.autonavi.com/appmaptile?style=6&x=\(x)&y=\(y)&z=\(z)")!
                } else {
                    // Regional / City / Airport zoom inside China: Gaode HD Chinese Vector Map
                    return URL(string: "https://webrd0\(server14).is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=1&style=8&x=\(x)&y=\(y)&z=\(z)")!
                }
            } else {
                // Overseas: Google Hybrid Satellite + Roads
                return URL(string: "https://mt\(server03).google.com/vt/lyrs=y&hl=zh-CN&x=\(x)&y=\(y)&z=\(z)")!
            }
        }
    }

    private func fallbackSatelliteURL(for path: MKTileOverlayPath) -> URL {
        // High-res global satellite imagery accessible worldwide without VPN
        return URL(string: "https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/\(path.z)/\(path.y)/\(path.x)")!
    }

    private static func tileToCoordinate(x: Int, y: Int, z: Int) -> CLLocationCoordinate2D {
        let n = pow(2.0, Double(z))
        let lonDeg = (Double(x) / n) * 360.0 - 180.0
        let latRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y) / n)))
        let latDeg = latRad * 180.0 / .pi
        return CLLocationCoordinate2D(latitude: latDeg, longitude: lonDeg)
    }

    private static func isInsideChina(_ coord: CLLocationCoordinate2D) -> Bool {
        return coord.latitude >= 18.0 && coord.latitude <= 53.6
            && coord.longitude >= 73.5 && coord.longitude <= 135.1
    }
}

// MARK: - 120Hz Diff-Updated UIKit MKMapView Bridge

struct HybridTileMapView: UIViewRepresentable {
    let provider: StratoMapProvider
    let flights: [LiveFlight]
    let focusedFlight: LiveFlight?
    let activeFlightID: String?
    let cameraTarget: CLLocationCoordinate2D?
    let cameraDistance: CLLocationDistance
    let cameraPitch: CGFloat
    let cameraHeading: CLLocationDirection
    let cameraTriggerID: Int
    let onSelectFlight: (LiveFlight) -> Void
    let onRegionChangedByUser: (CLLocationCoordinate2D) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.isPitchEnabled = true
        mapView.isRotateEnabled = true
        mapView.showsCompass = false
        mapView.overrideUserInterfaceStyle = .dark

        context.coordinator.configureTileOverlay(on: mapView, provider: provider)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.configureTileOverlay(on: mapView, provider: provider)
        context.coordinator.syncAnnotationsAndRoutes(on: mapView)
        context.coordinator.applyCameraIfNeeded(on: mapView)
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: HybridTileMapView
        private var currentProvider: StratoMapProvider?
        private var tileOverlay: SmartGlobalTileOverlay?
        private var lastCameraTriggerID: Int = -1

        // Route caching so we don't tear down overlays every 1-second tick
        private var renderedRouteFlightID: String?
        private var lastRouteOriginCoord: CLLocationCoordinate2D?

        init(parent: HybridTileMapView) {
            self.parent = parent
        }

        func configureTileOverlay(on mapView: MKMapView, provider: StratoMapProvider) {
            guard currentProvider != provider else { return }
            currentProvider = provider

            if let existing = tileOverlay {
                mapView.removeOverlay(existing)
                tileOverlay = nil
            }

            if provider == .apple3DFlyover {
                let config = MKHybridMapConfiguration(elevationStyle: .realistic)
                mapView.preferredConfiguration = config
            } else {
                let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
                mapView.preferredConfiguration = config
                let overlay = SmartGlobalTileOverlay(provider: provider)
                mapView.addOverlay(overlay, level: .aboveRoads)
                self.tileOverlay = overlay
            }
        }

        func applyCameraIfNeeded(on mapView: MKMapView) {
            guard parent.cameraTriggerID != lastCameraTriggerID,
                  let target = parent.cameraTarget else { return }
            lastCameraTriggerID = parent.cameraTriggerID

            let camera = MKMapCamera(
                lookingAtCenter: target,
                fromDistance: parent.cameraDistance,
                pitch: parent.cameraPitch,
                heading: parent.cameraHeading
            )
            mapView.setCamera(camera, animated: true)
        }

        func syncAnnotationsAndRoutes(on mapView: MKMapView) {
            // 1. Only rebuild route polyline if the focused flight changed or moved > 8 km
            let focused = parent.focusedFlight
            let shouldRebuildRoute: Bool = {
                guard let focused else { return renderedRouteFlightID != nil }
                if renderedRouteFlightID != focused.id { return true }
                if let lastCoord = lastRouteOriginCoord {
                    return GreatCircle.distanceKM(from: lastCoord, to: focused.coordinate) > 8.0
                }
                return true
            }()

            if shouldRebuildRoute {
                let routeOverlays = mapView.overlays.filter { !($0 is SmartGlobalTileOverlay) }
                mapView.removeOverlays(routeOverlays)
                renderedRouteFlightID = focused?.id
                lastRouteOriginCoord = focused?.coordinate

                if let focused, let dest = focused.destination {
                    if let orig = focused.origin {
                        var flownCoords = GreatCircle.arcCoordinates(from: orig.coordinate, to: focused.coordinate, segments: 28)
                        let flownLine = FlownRoutePolyline(coordinates: &flownCoords, count: flownCoords.count)
                        mapView.addOverlay(flownLine, level: .aboveLabels)
                    }
                    var remCoords = GreatCircle.arcCoordinates(from: focused.coordinate, to: dest.coordinate, segments: 32)
                    let remLine = RemainingRoutePolyline(coordinates: &remCoords, count: remCoords.count)
                    mapView.addOverlay(remLine, level: .aboveLabels)
                }
            }

            // 2. Diff-update aircraft annotations smoothly without interrupting user touches
            let existingByID: [String: FlightMapAnnotation] = Dictionary(
                uniqueKeysWithValues: mapView.annotations.compactMap { $0 as? FlightMapAnnotation }.map { ($0.flight.id, $0) }
            )
            let desiredIDs = Set(parent.flights.map(\.id))

            for (id, anno) in existingByID where !desiredIDs.contains(id) {
                mapView.removeAnnotation(anno)
            }

            for flight in parent.flights {
                let isSelected = flight.id == parent.focusedFlight?.id
                let isActive = flight.id == parent.activeFlightID
                if let existing = existingByID[flight.id] {
                    existing.coordinate = flight.coordinate
                    existing.flight = flight
                    existing.isSelected = isSelected
                    existing.isActive = isActive
                    if let view = mapView.view(for: existing) as? FlightAnnotationView {
                        view.configure(with: existing)
                    }
                } else {
                    let anno = FlightMapAnnotation(flight: flight, isSelected: isSelected, isActive: isActive)
                    mapView.addAnnotation(anno)
                }
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.onRegionChangedByUser(mapView.centerCoordinate)
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? SmartGlobalTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            if let flown = overlay as? FlownRoutePolyline {
                let r = MKPolylineRenderer(polyline: flown)
                r.strokeColor = UIColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 0.95)
                r.lineWidth = 3.2
                return r
            }
            if let rem = overlay as? RemainingRoutePolyline {
                let r = MKPolylineRenderer(polyline: rem)
                r.strokeColor = UIColor.white.withAlphaComponent(0.65)
                r.lineWidth = 2.2
                r.lineDashPattern = [6, 5]
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let flightAnno = annotation as? FlightMapAnnotation else { return nil }
            let id = "StratoFlightPin"
            let view = (mapView.dequeueReusableAnnotationView(withIdentifier: id) as? FlightAnnotationView)
                ?? FlightAnnotationView(annotation: flightAnno, reuseIdentifier: id)
            view.configure(with: flightAnno)
            return view
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let flightAnno = view.annotation as? FlightMapAnnotation else { return }
            mapView.deselectAnnotation(flightAnno, animated: false)
            parent.onSelectFlight(flightAnno.flight)
        }
    }
}

private final class FlownRoutePolyline: MKPolyline {}
private final class RemainingRoutePolyline: MKPolyline {}

private final class FlightMapAnnotation: NSObject, MKAnnotation {
    dynamic var coordinate: CLLocationCoordinate2D
    var flight: LiveFlight
    var isSelected: Bool
    var isActive: Bool

    init(flight: LiveFlight, isSelected: Bool, isActive: Bool) {
        self.coordinate = flight.coordinate
        self.flight = flight
        self.isSelected = isSelected
        self.isActive = isActive
    }
}

private final class FlightAnnotationView: MKAnnotationView {
    private let iconView = UIImageView()
    private let callsignLabel = UILabel()
    private let pulseRing = UIView()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        self.frame = CGRect(x: 0, y: 0, width: 56, height: 48)
        self.backgroundColor = .clear

        pulseRing.frame = CGRect(x: 11, y: 2, width: 34, height: 34)
        pulseRing.layer.cornerRadius = 17
        addSubview(pulseRing)

        iconView.frame = CGRect(x: 16, y: 7, width: 24, height: 24)
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)

        callsignLabel.frame = CGRect(x: -4, y: 31, width: 64, height: 15)
        callsignLabel.textAlignment = .center
        callsignLabel.font = UIFont.monospacedSystemFont(ofSize: 9.5, weight: .bold)
        callsignLabel.textColor = .white
        callsignLabel.backgroundColor = UIColor.black.withAlphaComponent(0.78)
        callsignLabel.layer.cornerRadius = 7
        callsignLabel.layer.masksToBounds = true
        addSubview(callsignLabel)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with anno: FlightMapAnnotation) {
        let highlight = anno.isSelected || anno.isActive
        let ptSize: CGFloat = highlight ? 19 : 13
        let cfg = UIImage.SymbolConfiguration(pointSize: ptSize, weight: .bold)
        iconView.image = UIImage(systemName: "airplane", withConfiguration: cfg)

        let tintColor: UIColor
        if anno.isActive {
            tintColor = UIColor(red: 0.25, green: 0.90, blue: 0.65, alpha: 1.0)
        } else if anno.isSelected {
            tintColor = UIColor(red: 0.35, green: 0.82, blue: 1.0, alpha: 1.0)
        } else {
            tintColor = UIColor.white.withAlphaComponent(0.92)
        }
        iconView.tintColor = tintColor

        let radians = CGFloat((anno.flight.trackDegrees - 90.0) * .pi / 180.0)
        iconView.transform = CGAffineTransform(rotationAngle: radians)

        pulseRing.isHidden = !highlight
        pulseRing.backgroundColor = tintColor.withAlphaComponent(0.24)

        callsignLabel.text = anno.flight.callsign
        callsignLabel.isHidden = !highlight
    }
}

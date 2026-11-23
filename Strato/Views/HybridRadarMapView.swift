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
        case .autoHybrid: return "智能混合 (国内高德 / 海外谷歌)"
        case .apple3DFlyover: return "Apple 3D 立体地球地景"
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

/// Custom MKTileOverlay that dynamically routes tile requests:
/// - Inside China bounding box (Lat 18...53.8, Lon 73...135.2) -> AutoNavi (Gaode / Amap) HD tiles
/// - Outside China -> Google Hybrid Satellite HD tiles
final class SmartGlobalTileOverlay: MKTileOverlay {
    let provider: StratoMapProvider

    init(provider: StratoMapProvider) {
        self.provider = provider
        super.init(urlTemplate: nil)
        self.canReplaceMapContent = true
        self.maximumZ = 19
        self.minimumZ = 2
    }

    override func url(forTilePath path: MKTileOverlayPath) -> URL {
        let x = path.x
        let y = path.y
        let z = path.z

        let useAmap: Bool
        switch provider {
        case .amapChina:
            useAmap = true
        case .googleSatellite, .apple3DFlyover:
            useAmap = false
        case .autoHybrid:
            let coord = Self.tileToCoordinate(x: x, y: y, z: z)
            useAmap = Self.isInsideChina(coord)
        }

        if useAmap {
            // AutoNavi (Gaode) satellite + road hybrid or dark road vector depending on zoom
            let server = ((x + y) % 4) + 1
            if z <= 8 {
                // High-altitude stratospheric view: Gaode Satellite imagery
                let urlStr = "https://webst0\(server).is.autonavi.com/appmaptile?style=6&x=\(x)&y=\(y)&z=\(z)"
                return URL(string: urlStr)!
            } else {
                // Detailed China city & airport view: Gaode HD bilingual vector map
                let urlStr = "https://webrd0\(server).is.autonavi.com/appmaptile?lang=zh_cn&size=1&scale=2&style=8&x=\(x)&y=\(y)&z=\(z)"
                return URL(string: urlStr)!
            }
        } else {
            // Google Hybrid Satellite + Roads & Labels (lyrs=y)
            let server = (x + y) % 4
            let urlStr = "https://mt\(server).google.com/vt/lyrs=y&hl=zh-CN&x=\(x)&y=\(y)&z=\(z)&scale=2"
            return URL(string: urlStr)!
        }
    }

    private static func tileToCoordinate(x: Int, y: Int, z: Int) -> CLLocationCoordinate2D {
        let n = pow(2.0, Double(z))
        let lonDeg = (Double(x) / n) * 360.0 - 180.0
        let latRad = atan(sinh(.pi * (1.0 - 2.0 * Double(y) / n)))
        let latDeg = latRad * 180.0 / .pi
        return CLLocationCoordinate2D(latitude: latDeg, longitude: lonDeg)
    }

    private static func isInsideChina(_ coord: CLLocationCoordinate2D) -> Bool {
        // Rough bounding box covering Mainland China, HK, Macau, and Taiwan
        return coord.latitude >= 18.0 && coord.latitude <= 53.6
            && coord.longitude >= 73.5 && coord.longitude <= 135.1
    }
}

// MARK: - UIKit MKMapView Bridge for Custom Tile Providers (Amap + Google + 3D Pitch)

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
                let config = MKImageryMapConfiguration(elevationStyle: .realistic)
                mapView.preferredConfiguration = config
            } else {
                let config = MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .muted)
                mapView.preferredConfiguration = config
                let overlay = SmartGlobalTileOverlay(provider: provider)
                mapView.addOverlay(overlay, level: .aboveLabels)
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
            // Remove old route polylines (keep tile overlay!)
            let nonTileOverlays = mapView.overlays.filter { !($0 is SmartGlobalTileOverlay) }
            mapView.removeOverlays(nonTileOverlays)

            // Draw Great Circle route for focused flight
            if let focused = parent.focusedFlight, let dest = focused.destination {
                if let orig = focused.origin {
                    var flownCoords = GreatCircle.arcCoordinates(from: orig.coordinate, to: focused.coordinate, segments: 28)
                    let flownLine = FlownRoutePolyline(coordinates: &flownCoords, count: flownCoords.count)
                    mapView.addOverlay(flownLine, level: .aboveLabels)
                }
                var remCoords = GreatCircle.arcCoordinates(from: focused.coordinate, to: dest.coordinate, segments: 32)
                let remLine = RemainingRoutePolyline(coordinates: &remCoords, count: remCoords.count)
                mapView.addOverlay(remLine, level: .aboveLabels)
            }

            // Sync aircraft annotations efficiently
            let existingByID: [String: FlightMapAnnotation] = Dictionary(
                uniqueKeysWithValues: mapView.annotations.compactMap { $0 as? FlightMapAnnotation }.map { ($0.flight.id, $0) }
            )
            let desiredIDs = Set(parent.flights.map(\.id))

            // Remove stale
            for (id, anno) in existingByID where !desiredIDs.contains(id) {
                mapView.removeAnnotation(anno)
            }

            // Update or add
            for flight in parent.flights {
                let isSelected = flight.id == parent.focusedFlight?.id
                let isActive = flight.id == parent.activeFlightID
                if let existing = existingByID[flight.id] {
                    UIView.animate(withDuration: 0.45) {
                        existing.coordinate = flight.coordinate
                    }
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
                r.strokeColor = UIColor.white.withAlphaComponent(0.6)
                r.lineWidth = 2.0
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
        callsignLabel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
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

        // UIImage("airplane") points East (90°); rotate to true track
        let radians = CGFloat((anno.flight.trackDegrees - 90.0) * .pi / 180.0)
        iconView.transform = CGAffineTransform(rotationAngle: radians)

        pulseRing.isHidden = !highlight
        pulseRing.backgroundColor = tintColor.withAlphaComponent(0.24)

        callsignLabel.text = anno.flight.callsign
        callsignLabel.isHidden = !highlight
    }
}

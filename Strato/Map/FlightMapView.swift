import MapKit
import SwiftUI
import UIKit

// MARK: - Artwork

@MainActor
enum PlaneArt {
    /// A top-down airliner pointing up (north), drawn in a 100×100 box.
    static func path(in size: CGFloat) -> UIBezierPath {
        let k = size / 100
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * k, y: y * k) }
        let path = UIBezierPath()
        path.move(to: p(50, 3))
        path.addCurve(to: p(55, 14), controlPoint1: p(53, 5), controlPoint2: p(55, 9))
        path.addLine(to: p(55, 38))
        path.addLine(to: p(97, 60))
        path.addLine(to: p(97, 66))
        path.addLine(to: p(55, 56))
        path.addLine(to: p(54.5, 80))
        path.addLine(to: p(70, 91))
        path.addLine(to: p(70, 95))
        path.addLine(to: p(52, 90))
        path.addLine(to: p(50, 97))
        path.addLine(to: p(48, 90))
        path.addLine(to: p(30, 95))
        path.addLine(to: p(30, 91))
        path.addLine(to: p(45.5, 80))
        path.addLine(to: p(45, 56))
        path.addLine(to: p(3, 66))
        path.addLine(to: p(3, 60))
        path.addLine(to: p(45, 38))
        path.addLine(to: p(45, 14))
        path.addCurve(to: p(50, 3), controlPoint1: p(45, 9), controlPoint2: p(47, 5))
        path.close()
        return path
    }

    private static var cache: [String: UIImage] = [:]

    static func image(size: CGFloat, fill: UIColor, glow: Bool) -> UIImage {
        let key = "\(Int(size))-\(fill.description)-\(glow)"
        if let hit = cache[key] { return hit }
        let pad: CGFloat = glow ? 8 : 3
        let canvas = CGSize(width: size + pad * 2, height: size + pad * 2)
        let image = UIGraphicsImageRenderer(size: canvas).image { ctx in
            let c = ctx.cgContext
            c.translateBy(x: pad, y: pad)
            let shape = path(in: size)
            c.setShadow(offset: .zero, blur: glow ? 7 : 2.5, color: (glow ? fill.withAlphaComponent(0.9) : UIColor.black.withAlphaComponent(0.7)).cgColor)
            fill.setFill()
            shape.fill()
            c.setShadow(offset: .zero, blur: 0, color: nil)
            UIColor.black.withAlphaComponent(0.55).setStroke()
            shape.lineWidth = max(0.8, size / 30)
            shape.stroke()
        }
        cache[key] = image
        return image
    }
}

// MARK: - Annotations

final class PlaneAnnotation: NSObject, MKAnnotation {
    @objc dynamic var coordinate: CLLocationCoordinate2D
    var flight: LiveFlight
    var isFocus = false

    init(flight: LiveFlight, coordinate: CLLocationCoordinate2D) {
        self.flight = flight
        self.coordinate = coordinate
    }
}

final class AirportAnnotation: NSObject, MKAnnotation {
    let coordinate: CLLocationCoordinate2D
    let code: String
    let isDestination: Bool

    init(coordinate: CLLocationCoordinate2D, code: String, isDestination: Bool) {
        self.coordinate = coordinate
        self.code = code
        self.isDestination = isDestination
    }
}

final class PlaneView: MKAnnotationView {
    static let reuseID = "plane"
    private let icon = UIImageView()
    private let label = UILabel()
    private var styleKey = ""

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 44, height: 44)
        backgroundColor = .clear
        collisionMode = .circle
        displayPriority = .required
        icon.contentMode = .center
        addSubview(icon)
        label.font = .monospacedSystemFont(ofSize: 10.5, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        addSubview(label)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { return nil }

    func apply(_ a: PlaneAnnotation, mapHeading: Double) {
        let wide = AircraftTypes.isWidebody(code: a.flight.state.typeCode, category: a.flight.state.category)
        let size: CGFloat = a.isFocus ? 34 : (wide ? 24 : 20)
        let key = "\(a.isFocus)-\(wide)"
        if key != styleKey {
            styleKey = key
            let color = a.isFocus ? UIColor(red: 0.36, green: 0.78, blue: 1, alpha: 1) : UIColor(red: 1, green: 0.82, blue: 0.25, alpha: 1)
            icon.image = PlaneArt.image(size: size, fill: color, glow: a.isFocus)
            icon.bounds = CGRect(origin: .zero, size: icon.image?.size ?? .zero)
            icon.center = CGPoint(x: bounds.midX, y: bounds.midY)
            zPriority = a.isFocus ? .max : .defaultUnselected
        }
        let degrees = (a.flight.state.trackDeg ?? 0) - mapHeading
        icon.transform = CGAffineTransform(rotationAngle: CGFloat(degrees * .pi / 180))
        label.isHidden = !a.isFocus
        if a.isFocus {
            label.text = a.flight.displayNumber
            let width = max(46, label.intrinsicContentSize.width + 12)
            label.frame = CGRect(x: bounds.midX - width / 2, y: bounds.maxY + 2, width: width, height: 17)
        }
        accessibilityLabel = a.flight.displayNumber
        accessibilityIdentifier = "plane-\(a.flight.callsign)"
    }
}

final class AirportView: MKAnnotationView {
    static let reuseID = "airport"
    private let dot = UIView()
    private let label = UILabel()

    override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: 14, height: 14)
        isUserInteractionEnabled = false
        displayPriority = .required
        dot.frame = bounds
        dot.layer.cornerRadius = 7
        dot.layer.borderWidth = 2.5
        dot.layer.borderColor = UIColor.white.cgColor
        addSubview(dot)
        label.font = .monospacedSystemFont(ofSize: 11, weight: .heavy)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        label.layer.cornerRadius = 6
        label.layer.masksToBounds = true
        addSubview(label)
    }

    required init?(coder: NSCoder) { return nil }

    func apply(_ a: AirportAnnotation) {
        dot.backgroundColor = a.isDestination ? UIColor(red: 0.31, green: 0.89, blue: 0.69, alpha: 1) : UIColor(white: 0.75, alpha: 1)
        label.text = a.code
        let width = label.intrinsicContentSize.width + 12
        label.frame = CGRect(x: bounds.midX - width / 2, y: -21, width: width, height: 17)
    }
}


// MARK: - Map view

struct FlightMapView: UIViewRepresentable {
    var provider: MapProvider
    /// Where the map opens.
    var initialCenter: GeoPoint
    var initialRadiusKm: Double = 420
    var flights: [LiveFlight]
    var focusID: String?
    /// Route drawn for the focused flight.
    var route: FlightRoute?
    /// The path actually flown while on board; empty to draw a great circle from the origin instead.
    var trail: [GeoPoint] = []
    var command: MapCommand?
    var follow = false
    /// Extra space the UI covers at the bottom, so "centre" means the centre of what is visible.
    var bottomInset: CGFloat = 0
    var clock: @Sendable () -> Date = { Date() }
    var onSelect: (String?) -> Void = { _ in }
    var onRegionChange: (GeoPoint, Double, Bool) -> Void = { _, _, _ in }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView(frame: .zero)
        map.delegate = context.coordinator
        map.overrideUserInterfaceStyle = .dark
        map.showsCompass = false
        map.showsScale = false
        map.isPitchEnabled = true
        map.pointOfInterestFilter = .excludingAll
        map.register(PlaneView.self, forAnnotationViewWithReuseIdentifier: PlaneView.reuseID)
        map.register(AirportView.self, forAnnotationViewWithReuseIdentifier: AirportView.reuseID)
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.backgroundTapped(_:)))
        tap.delegate = context.coordinator
        map.addGestureRecognizer(tap)
        let span = min(max(initialRadiusKm, 40), 3000) * 2000
        map.setRegion(MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: initialCenter.lat, longitude: initialCenter.lon),
            latitudinalMeters: span, longitudinalMeters: span
        ), animated: false)
        context.coordinator.attach(map)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(map)
    }

    static func dismantleUIView(_ map: MKMapView, coordinator: Coordinator) {
        coordinator.detach()
    }

    @MainActor
    final class Coordinator: NSObject, MKMapViewDelegate, UIGestureRecognizerDelegate {
        var parent: FlightMapView
        private weak var map: MKMapView?
        private var timer: Timer?
        private var planes: [String: PlaneAnnotation] = [:]
        private var airports: [AirportAnnotation] = []
        private var appliedProvider: MapProvider?
        private var tiles: SatelliteTileOverlay?
        private var labels: LabelTileOverlay?
        private var routeOverlays: [MKOverlay] = []
        // Overlays are told apart by identity: MKPolyline is created through a factory, so
        // subclassing it to tag the two lines is not reliable.
        private var flownOverlay: MKPolyline?
        private var aheadOverlay: MKPolyline?
        private var routeKey = ""
        private var lastCommandID = -1
        private var userIsMoving = false
        private var gcj = false

        init(_ parent: FlightMapView) {
            self.parent = parent
        }

        func attach(_ map: MKMapView) {
            self.map = map
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.tick() }
            }
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        }

        func detach() {
            timer?.invalidate()
            timer = nil
        }

        private func display(_ p: GeoPoint) -> CLLocationCoordinate2D {
            let d = ChinaRegion.displayPoint(p, gcjActive: gcj)
            return CLLocationCoordinate2D(latitude: d.lat, longitude: d.lon)
        }

        private func livePoint(_ flight: LiveFlight) -> GeoPoint {
            let age = parent.clock().timeIntervalSince(flight.state.positionTime)
            // Projection is only trusted for a short while; beyond that, hold the last known position.
            guard age > 0, age < 240 || flight.id == parent.focusID else { return flight.state.point }
            return FlightMath.projected(state: flight.state, route: flight.route, after: age)
        }

        // MARK: Sync from SwiftUI

        func sync(_ map: MKMapView) {
            applyProvider(map)
            map.layoutMargins = UIEdgeInsets(top: 0, left: 0, bottom: parent.bottomInset, right: 0)
            syncPlanes(map)
            syncRoute(map, force: false)
            applyCommand(map)
        }

        private func applyProvider(_ map: MKMapView) {
            guard appliedProvider != parent.provider else { return }
            appliedProvider = parent.provider
            map.removeOverlays(map.overlays)
            tiles = nil
            labels = nil
            routeKey = ""
            routeOverlays = []
            gcj = false
            switch parent.provider {
            case .apple3D:
                map.preferredConfiguration = MKHybridMapConfiguration(elevationStyle: .realistic)
            case .appleDark:
                let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
                config.pointOfInterestFilter = .excludingAll
                map.preferredConfiguration = config
            default:
                let config = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
                config.pointOfInterestFilter = .excludingAll
                map.preferredConfiguration = config
                let overlay = SatelliteTileOverlay(provider: parent.provider)
                map.addOverlay(overlay, level: .aboveLabels)
                tiles = overlay
                gcj = overlay.usesGCJInChina
                if gcj {
                    let l = LabelTileOverlay()
                    map.addOverlay(l, level: .aboveLabels)
                    labels = l
                }
            }
            // Markers were placed for the previous coordinate system.
            for a in planes.values { a.coordinate = display(livePoint(a.flight)) }
        }

        private func syncPlanes(_ map: MKMapView) {
            var wanted: [String: LiveFlight] = [:]
            for f in parent.flights { wanted[f.id] = f }
            for (id, a) in planes where wanted[id] == nil {
                map.removeAnnotation(a)
                planes[id] = nil
            }
            let heading = map.camera.heading
            for (id, f) in wanted {
                let focus = id == parent.focusID
                if let a = planes[id] {
                    let changed = a.flight.state.positionTime != f.state.positionTime || a.isFocus != focus || a.flight.route != f.route
                    a.flight = f
                    a.isFocus = focus
                    if changed, let view = map.view(for: a) as? PlaneView { view.apply(a, mapHeading: heading) }
                } else {
                    let a = PlaneAnnotation(flight: f, coordinate: display(livePoint(f)))
                    a.isFocus = focus
                    planes[id] = a
                    map.addAnnotation(a)
                }
            }
        }

        private func syncRoute(_ map: MKMapView, force: Bool) {
            guard let id = parent.focusID, let plane = planes[id], let route = parent.route else {
                if !routeKey.isEmpty {
                    map.removeOverlays(routeOverlays)
                    map.removeAnnotations(airports)
                    routeOverlays = []
                    airports = []
                    routeKey = ""
                }
                return
            }
            let here = livePoint(plane.flight)
            // Rebuild when the subject changes or the aircraft has moved enough to see.
            let key = "\(id)-\(route.origin.code)-\(route.destination.code)-\(parent.trail.count)-\(Int(here.lat * 20))-\(Int(here.lon * 20))-\(gcj)"
            guard force || key != routeKey else { return }
            let subjectChanged = !routeKey.hasPrefix("\(id)-\(route.origin.code)-\(route.destination.code)-")
            routeKey = key
            map.removeOverlays(routeOverlays)
            routeOverlays = []

            var flown: [CLLocationCoordinate2D]
            if parent.trail.count > 1 {
                // What happened before boarding is unknown: draw it as a great circle up to the first fix.
                flown = Geo.arc(route.origin.point, parent.trail[0], segments: 24).map(display) + parent.trail.map(display)
                flown.append(display(here))
            } else {
                flown = Geo.arc(route.origin.point, here, segments: 32).map(display)
            }
            let flownLine = MKPolyline(coordinates: flown, count: flown.count)
            let ahead = [display(here), display(route.destination.point)]
            let aheadLine = MKGeodesicPolyline(coordinates: ahead, count: 2)
            flownOverlay = flownLine
            aheadOverlay = aheadLine
            map.addOverlay(aheadLine, level: .aboveLabels)
            map.addOverlay(flownLine, level: .aboveLabels)
            routeOverlays = [aheadLine, flownLine]

            if subjectChanged || airports.isEmpty {
                map.removeAnnotations(airports)
                airports = [
                    AirportAnnotation(coordinate: display(route.origin.point), code: route.origin.code, isDestination: false),
                    AirportAnnotation(coordinate: display(route.destination.point), code: route.destination.code, isDestination: true)
                ]
                map.addAnnotations(airports)
            }
        }

        private func applyCommand(_ map: MKMapView) {
            guard let command = parent.command, command.id != lastCommandID else { return }
            lastCommandID = command.id
            switch command.kind {
            case .center(let point, let distance):
                let camera = MKMapCamera(lookingAtCenter: display(point), fromDistance: distance, pitch: 0, heading: 0)
                map.setCamera(camera, animated: map.window != nil)
            case .fit(let points):
                guard let rect = Self.mapRect(around: points.map { ChinaRegion.displayPoint($0, gcjActive: gcj) }) else { return }
                let padding = UIEdgeInsets(top: 150, left: 50, bottom: 60, right: 50)
                map.setVisibleMapRect(rect, edgePadding: padding, animated: map.window != nil)
            }
        }

        /// Bounding map rect of some points, taking the short way round across the date line.
        static func mapRect(around points: [GeoPoint]) -> MKMapRect? {
            guard !points.isEmpty else { return nil }
            var lons = points.map { $0.lon }
            if (lons.max() ?? 0) - (lons.min() ?? 0) > 180 {
                lons = lons.map { $0 < 0 ? $0 + 360 : $0 }
            }
            let world = MKMapSize.world.width
            let xs = lons.map { ($0 + 180) / 360 * world }
            let ys = points.map { MKMapPoint(CLLocationCoordinate2D(latitude: $0.lat, longitude: 0)).y }
            guard let minX = xs.min(), let maxX = xs.max(), let minY = ys.min(), let maxY = ys.max() else { return nil }
            let rect = MKMapRect(x: minX, y: minY, width: max(maxX - minX, world / 4000), height: max(maxY - minY, world / 4000))
            return rect.insetBy(dx: -rect.size.width * 0.08, dy: -rect.size.height * 0.08)
        }

        // MARK: Once a second

        private func tick() {
            guard let map, map.window != nil else { return }
            let heading = map.camera.heading
            UIView.animate(withDuration: 1, delay: 0, options: [.curveLinear, .allowUserInteraction, .beginFromCurrentState]) {
                for a in self.planes.values where !a.flight.state.onGround {
                    a.coordinate = self.display(self.livePoint(a.flight))
                }
            }
            for a in planes.values where a.isFocus {
                (map.view(for: a) as? PlaneView)?.apply(a, mapHeading: heading)
            }
            syncRoute(map, force: false)
            if parent.follow, !userIsMoving, let id = parent.focusID, let a = planes[id] {
                let centre = map.convert(a.coordinate, toPointTo: map)
                let visible = map.bounds.inset(by: map.layoutMargins)
                let target = CGPoint(x: visible.midX, y: visible.midY)
                let drift = hypot(centre.x - target.x, centre.y - target.y)
                if drift > min(visible.width, visible.height) * 0.12 {
                    map.setCenter(a.coordinate, animated: true)
                }
            }
        }

        // MARK: Delegate

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tile = overlay as? MKTileOverlay {
                return MKTileOverlayRenderer(tileOverlay: tile)
            }
            if let line = overlay as? MKPolyline, line === flownOverlay {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = UIColor(red: 0.36, green: 0.78, blue: 1, alpha: 0.95)
                r.lineWidth = 3
                r.lineCap = .round
                r.lineJoin = .round
                return r
            }
            if let line = overlay as? MKPolyline {
                let r = MKPolylineRenderer(polyline: line)
                r.strokeColor = UIColor.white.withAlphaComponent(0.8)
                r.lineWidth = 2
                r.lineDashPattern = [2, 7]
                r.lineCap = .round
                return r
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if let a = annotation as? PlaneAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: PlaneView.reuseID, for: a)
                (view as? PlaneView)?.apply(a, mapHeading: mapView.camera.heading)
                return view
            }
            if let a = annotation as? AirportAnnotation {
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: AirportView.reuseID, for: a)
                (view as? AirportView)?.apply(a)
                return view
            }
            return nil
        }

        func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView) {
            guard let a = view.annotation as? PlaneAnnotation else { return }
            mapView.deselectAnnotation(a, animated: false)
            parent.onSelect(a.flight.id)
        }

        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            let recognizers = mapView.subviews.first?.gestureRecognizers ?? []
            if recognizers.contains(where: { $0.state == .began || $0.state == .changed || $0.state == .ended }) {
                userIsMoving = true
            }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let byUser = userIsMoving
            userIsMoving = false
            let heading = mapView.camera.heading
            for a in planes.values {
                (mapView.view(for: a) as? PlaneView)?.apply(a, mapHeading: heading)
            }
            let region = mapView.region
            let c = region.center
            guard CLLocationCoordinate2DIsValid(c) else { return }
            let latKm = region.span.latitudeDelta * 111.0 / 2
            let lonKm = region.span.longitudeDelta * 111.0 * cos(c.latitude * .pi / 180) / 2
            parent.onRegionChange(GeoPoint(c.latitude, c.longitude), max(latKm, lonKm), byUser)
        }

        @objc func backgroundTapped(_ recognizer: UITapGestureRecognizer) {
            guard let map else { return }
            var hit = map.hitTest(recognizer.location(in: map), with: nil)
            while let view = hit {
                if view is MKAnnotationView { return }
                hit = view.superview
            }
            parent.onSelect(nil)
        }

        func gestureRecognizer(_ g: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
            true
        }
    }
}

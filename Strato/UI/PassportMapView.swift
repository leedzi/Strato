import MapKit
import SwiftUI

private enum PassportMapStyle: String, CaseIterable, Identifiable {
    case minimal, globe, standard
    var id: String { rawValue }
    var title: String {
        switch self {
        case .minimal: return "纯色地图"
        case .globe: return "3D 地球"
        case .standard: return "Apple 地图"
        }
    }
}

private struct PassportRoute: Identifiable, Sendable {
    var id: String
    var points: [GeoPoint]
    var count: Int
}

private struct PassportAirportPin: Identifiable, Sendable {
    var id: String
    var airport: Airport
    var count: Int
    var landed: Bool
}

private struct PassportFootprint: Sendable {
    var routes: [PassportRoute]
    var airports: [PassportAirportPin]
    var totalRoutes: Int
    var focus: GeoPoint?
    var signature: String

    init(records: [FocusRecord]) {
        var routes: [String: PassportRoute] = [:]
        var airports: [String: PassportAirportPin] = [:]
        for record in records.sorted(by: { $0.startedAt > $1.startedAt }) {
            let key = "\(record.origin.code)-\(record.destination.code)"
            let points = Self.track(record)
            if var route = routes[key] {
                route.count += 1
                // A later partial session must not hide a route that was flown farther before.
                if Geo.pathLengthKm(points) > Geo.pathLengthKm(route.points) { route.points = points }
                routes[key] = route
            } else if points.count > 1 {
                routes[key] = PassportRoute(id: key, points: points, count: 1)
            }
            for airport in [record.origin, record.destination] where Self.valid(airport.point) {
                let id = airport.code.isEmpty ? "\(airport.lat),\(airport.lon)" : airport.code
                var pin = airports[id] ?? PassportAirportPin(id: id, airport: airport, count: 0, landed: false)
                pin.count += 1
                if airport.code == record.destination.code && record.outcome == .landed { pin.landed = true }
                airports[id] = pin
            }
        }
        totalRoutes = routes.count
        self.routes = Array(routes.values.sorted {
            $0.count == $1.count ? $0.id < $1.id : $0.count > $1.count
        }.prefix(80))
        self.airports = Array(airports.values.sorted {
            $0.count == $1.count ? $0.id < $1.id : $0.count > $1.count
        }.prefix(160))
        focus = records.max(by: { $0.startedAt < $1.startedAt })?.destination.point
        signature = records.map { $0.id.uuidString }.sorted().joined(separator: ",")
    }

    private static func valid(_ point: GeoPoint) -> Bool {
        point.lat.isFinite && point.lon.isFinite && abs(point.lat) <= 90 && abs(point.lon) <= 180
    }

    private static func track(_ record: FocusRecord) -> [GeoPoint] {
        let recorded = record.path.filter(valid)
        if recorded.count > 1 { return FocusRecord.thin(recorded, to: 64) }
        guard valid(record.origin.point), valid(record.destination.point),
              record.boardedFraction.isFinite, record.endFraction.isFinite else { return [] }
        let start = Geo.interpolate(record.origin.point, record.destination.point, record.boardedFraction)
        let end = Geo.interpolate(record.origin.point, record.destination.point, record.endFraction)
        return Geo.arc(start, end, segments: 48).filter(valid)
    }
}

/// The default overview and globe are rendered entirely from bundled geography and actual records.
struct PassportMapCard: View {
    var records: [FocusRecord]
    @AppStorage("passportMapStyle") private var storedStyle = PassportMapStyle.minimal.rawValue

    var body: some View {
        let footprint = PassportFootprint(records: records)
        let style = PassportMapStyle(rawValue: storedStyle) ?? .minimal
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(text: "飞过的世界", trailing: "\(footprint.totalRoutes) 条航线")
            HStack(spacing: 5) {
                ForEach(PassportMapStyle.allCases) { option in
                    Button { storedStyle = option.rawValue } label: {
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(option == style ? Palette.sky : Color.white.opacity(0.55))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(option == style ? Palette.sky.opacity(0.13) : Color.white.opacity(0.035), in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("passport-map-\(option.rawValue)")
                    .accessibilityAddTraits(option == style ? .isSelected : [])
                }
            }
            Group {
                switch style {
                case .minimal: PassportFlatMap(footprint: footprint)
                case .globe: PassportGlobe(footprint: footprint)
                case .standard: PassportStandardMap(footprint: footprint)
                }
            }
            .frame(height: 250)
            .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
            .accessibilityIdentifier("passport-map-canvas-\(style.rawValue)")
            HStack(spacing: 12) {
                legend("航线", tint: Palette.sky)
                legend("已落地", tint: Palette.mint)
                Spacer(minLength: 0)
                Text(style == .standard ? "Apple 地图 · 可缩放" : style == .globe ? "拖动旋转 · 双击复位" : "离线世界地图")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if footprint.totalRoutes > footprint.routes.count {
                Text("地图显示最常飞的 \(footprint.routes.count) 条航线")
                    .font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 24)
    }

    private func legend(_ title: String, tint: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(tint).frame(width: 5, height: 5)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct PassportFlatMap: View {
    var footprint: PassportFootprint

    var body: some View {
        RouteAtlasView(routes: footprint.routes.map(\.points),
                       places: footprint.airports.map { RouteAtlasView.Place(point: $0.airport.point, code: $0.airport.code, highlighted: $0.landed) },
                       showsLabels: true, showsGrid: true)
            .accessibilityLabel("离线纯色世界地图，\(footprint.totalRoutes) 条真实航线")
    }
}

/// The passport adds interaction to the same offline globe used by widgets.
private struct PassportGlobe: View {
    var footprint: PassportFootprint
    @State private var longitude: Double
    @State private var latitude: Double
    @State private var dragLongitude: Double?
    @State private var dragLatitude: Double?

    init(footprint: PassportFootprint) {
        self.footprint = footprint
        _longitude = State(initialValue: footprint.focus?.lon ?? 105)
        _latitude = State(initialValue: min(65, max(-65, footprint.focus?.lat ?? 18)))
    }

    var body: some View {
        RouteAtlasGlobeView(routes: footprint.routes.map(\.points),
                            places: footprint.airports.map { RouteAtlasView.Place(point: $0.airport.point, code: $0.airport.code, highlighted: $0.landed) },
                            center: GeoPoint(latitude, longitude), showsLabels: true)
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 5)
            .onChanged { value in
                if dragLongitude == nil { dragLongitude = longitude; dragLatitude = latitude }
                longitude = Geo.normalizeLon((dragLongitude ?? longitude) - Double(value.translation.width) * 0.65)
                latitude = min(80, max(-80, (dragLatitude ?? latitude) + Double(value.translation.height) * 0.45))
            }
            .onEnded { _ in dragLongitude = nil; dragLatitude = nil })
        .onTapGesture(count: 2, perform: reset)
        .onChange(of: footprint.signature) { _, _ in reset() }
        .overlay(alignment: .topTrailing) {
            Button(action: reset) { Image(systemName: "arrow.counterclockwise").font(.caption.weight(.semibold)).padding(10) }
                .buttonStyle(.plain).foregroundStyle(.white.opacity(0.6))
                .accessibilityLabel("复位地球")
                .accessibilityIdentifier("passport-globe-reset")
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("可旋转的离线三维地球，\(footprint.totalRoutes) 条真实航线")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: longitude = Geo.normalizeLon(longitude + 30)
            case .decrement: longitude = Geo.normalizeLon(longitude - 30)
            @unknown default: break
            }
        }
    }

    private func reset() {
        longitude = footprint.focus?.lon ?? 105
        latitude = min(65, max(-65, footprint.focus?.lat ?? 18))
        dragLongitude = nil
        dragLatitude = nil
    }
}

private struct PassportStandardMap: View {
    var footprint: PassportFootprint
    @State private var position: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $position, interactionModes: [.pan, .zoom]) {
            ForEach(footprint.routes) { route in
                MapPolyline(coordinates: route.points.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lon) }, contourStyle: .geodesic)
                    .stroke(Palette.sky.opacity(0.9), lineWidth: 2)
            }
            ForEach(footprint.airports) { pin in
                Annotation(pin.airport.code, coordinate: CLLocationCoordinate2D(latitude: pin.airport.lat, longitude: pin.airport.lon)) {
                    Circle().fill(pin.landed ? Palette.mint : Palette.sky).frame(width: 6, height: 6)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat))
        .onChange(of: footprint.signature) { _, _ in position = .automatic }
        .accessibilityLabel("系统航线地图")
    }
}

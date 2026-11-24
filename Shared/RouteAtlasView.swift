import SwiftUI

/// Local world-route overview shared by the passport and widgets. Coordinates remain WGS-84.
struct RouteAtlasView: View {
    struct Place: Identifiable, Sendable {
        var point: GeoPoint
        var code: String
        var highlighted: Bool = false
        var id: String { "\(code):\(point.lat):\(point.lon)" }
    }

    var routes: [[GeoPoint]]
    var places: [Place] = []
    var showsLabels = true
    var showsGrid = true
    var routeColor: Color = Palette.sky
    var background: Color = Palette.night.opacity(0.7)

    var body: some View {
        Canvas { context, size in
            let width = max(0, min(size.width - 16, (size.height - 12) * 2))
            let world = CGRect(x: (size.width - width) / 2, y: (size.height - width / 2) / 2, width: width, height: width / 2)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))
            if showsGrid {
                for latitude in stride(from: -60.0, through: 60.0, by: 30.0) {
                    var line = Path()
                    line.move(to: project(GeoPoint(latitude, -180), in: world))
                    line.addLine(to: project(GeoPoint(latitude, 180), in: world))
                    context.stroke(line, with: .color(.white.opacity(0.045)), style: StrokeStyle(lineWidth: 0.6, dash: [3, 5]))
                }
                for longitude in stride(from: -180.0, through: 180.0, by: 60.0) {
                    var line = Path()
                    line.move(to: project(GeoPoint(-90, longitude), in: world))
                    line.addLine(to: project(GeoPoint(90, longitude), in: world))
                    context.stroke(line, with: .color(.white.opacity(0.045)), style: StrokeStyle(lineWidth: 0.6, dash: [3, 5]))
                }
            }
            for polygon in RouteAtlasGeography.polygons {
                var path = Path()
                guard let first = polygon.points.first else { continue }
                path.move(to: project(first, in: world))
                for point in polygon.points.dropFirst() { path.addLine(to: project(point, in: world)) }
                path.closeSubpath()
                context.fill(path, with: .color(Color(rgb: 0x263F51)))
                context.stroke(path, with: .color(Color(rgb: 0x73919E).opacity(0.32)), lineWidth: 0.5)
            }
            let lineWidth = max(0.9, min(1.5, width / 210))
            for points in routes {
                let path = routePath(points.filter(valid), in: world)
                context.stroke(path, with: .color(routeColor.opacity(0.11)), lineWidth: lineWidth + 3)
                context.stroke(path, with: .color(routeColor.opacity(0.9)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            }
            var labels: [CGRect] = []
            let radius = max(1.4, min(2.2, width / 120))
            let fontSize = max(6, min(9, width / 33))
            for (index, place) in places.enumerated() where valid(place.point) {
                let point = project(place.point, in: world)
                let tint = place.highlighted ? Palette.mint : routeColor
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius * 2, y: point.y - radius * 2, width: radius * 4, height: radius * 4)), with: .color(tint.opacity(0.13)))
                context.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(tint))
                let box = CGRect(x: point.x + 4, y: point.y - 10, width: fontSize * 3.5, height: 12)
                if showsLabels && index < 12 && !place.code.isEmpty && !labels.contains(where: { $0.intersects(box) }) {
                    labels.append(box)
                    context.draw(Text(place.code).font(.system(size: fontSize, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.8)),
                                 at: CGPoint(x: box.minX, y: box.midY), anchor: .leading)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("离线世界航线地图")
        .accessibilityValue("\(routes.count) 条航线，\(places.count) 个位置")
    }

    private func valid(_ point: GeoPoint) -> Bool {
        point.lat.isFinite && point.lon.isFinite && abs(point.lat) <= 90 && abs(point.lon) <= 180
    }

    private func project(_ point: GeoPoint, in world: CGRect) -> CGPoint {
        CGPoint(x: world.minX + CGFloat((point.lon + 180) / 360) * world.width,
                y: world.minY + CGFloat((90 - point.lat) / 180) * world.height)
    }

    /// Sampled tracks split at both edges of the map instead of crossing the whole world.
    private func routePath(_ points: [GeoPoint], in world: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        var previous = GeoPoint(first.lat, Geo.normalizeLon(first.lon))
        path.move(to: project(previous, in: world))
        for raw in points.dropFirst() {
            let point = GeoPoint(raw.lat, Geo.normalizeLon(raw.lon))
            if abs(point.lon - previous.lon) > 180 {
                let unwrapped = point.lon < previous.lon ? point.lon + 360 : point.lon - 360
                let edge = unwrapped > 180 ? 180.0 : -180.0
                let fraction = (edge - previous.lon) / (unwrapped - previous.lon)
                let latitude = previous.lat + (point.lat - previous.lat) * fraction
                path.addLine(to: project(GeoPoint(latitude, edge), in: world))
                path.move(to: project(GeoPoint(latitude, -edge), in: world))
            }
            path.addLine(to: project(point, in: world))
            previous = point
        }
        return path
    }
}

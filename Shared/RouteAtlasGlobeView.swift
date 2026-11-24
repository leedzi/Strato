import SwiftUI

/// An offline orthographic globe. The passport supplies rotation; widgets use a fixed center.
struct RouteAtlasGlobeView: View {
    var routes: [[GeoPoint]]
    var places: [RouteAtlasView.Place] = []
    var center: GeoPoint = GeoPoint(20, 110)
    var showsLabels = true
    var showsGrid = true
    var routeColor: Color = Palette.sky
    var background: Color = Palette.night.opacity(0.75)

    var body: some View {
        Canvas { context, size in
            let origin = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.44
            let projection = AtlasGlobeProjection(center: center)
            let circle = Path(ellipseIn: CGRect(x: origin.x - radius, y: origin.y - radius, width: radius * 2, height: radius * 2))
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(background))
            var ocean = context
            ocean.addFilter(.shadow(color: routeColor.opacity(0.13), radius: max(4, radius * 0.16)))
            ocean.fill(circle, with: .radialGradient(Gradient(colors: [Color(rgb: 0x23526C), Color(rgb: 0x071429)]),
                                                   center: CGPoint(x: origin.x - radius * 0.35, y: origin.y - radius * 0.35),
                                                   startRadius: 0, endRadius: radius * 1.5))
            var surface = context
            surface.clip(to: circle)
            var land = Path()
            for polygon in AtlasGlobeMesh.polygons {
                let vertices = polygon.points.map(projection.project)
                for index in stride(from: 0, to: polygon.triangles.count, by: 3) {
                    let triangle = [vertices[polygon.triangles[index]], vertices[polygon.triangles[index + 1]], vertices[polygon.triangles[index + 2]]]
                    let visible = AtlasGlobeVector.clip(triangle)
                    guard let first = visible.first, visible.count >= 3 else { continue }
                    land.move(to: first.screen(center: origin, radius: radius))
                    for point in visible.dropFirst() { land.addLine(to: point.screen(center: origin, radius: radius)) }
                    land.closeSubpath()
                }
            }
            // A single filled path prevents seams between adjacent triangle edges.
            surface.fill(land, with: .color(Color(rgb: 0x3B6371)))
            for polygon in AtlasGlobeMesh.polygons {
                surface.stroke(line(polygon.coast, projection: projection, center: origin, radius: radius),
                               with: .color(Color(rgb: 0x9BB7BE).opacity(0.24)), lineWidth: 0.5)
            }
            if showsGrid {
                for parallel in stride(from: -60.0, through: 60.0, by: 30.0) {
                    let points = stride(from: -180.0, through: 180.0, by: 5.0).map { GeoPoint(parallel, $0) }
                    surface.stroke(line(points, projection: projection, center: origin, radius: radius), with: .color(.white.opacity(0.075)), lineWidth: 0.5)
                }
                for meridian in stride(from: -180.0, through: 150.0, by: 30.0) {
                    let points = stride(from: -90.0, through: 90.0, by: 5.0).map { GeoPoint($0, meridian) }
                    surface.stroke(line(points, projection: projection, center: origin, radius: radius), with: .color(.white.opacity(0.075)), lineWidth: 0.5)
                }
            }
            surface.fill(circle, with: .radialGradient(Gradient(stops: [.init(color: .clear, location: 0.55), .init(color: .black.opacity(0.65), location: 1)]),
                                                       center: origin, startRadius: 0, endRadius: radius))
            let lineWidth = max(0.7, min(1.4, radius / 78))
            for points in routes {
                let path = line(points.filter(valid), projection: projection, center: origin, radius: radius)
                surface.stroke(path, with: .color(routeColor.opacity(0.16)), lineWidth: lineWidth + 2.6)
                surface.stroke(path, with: .color(routeColor.opacity(0.95)), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            }
            let dotRadius = max(1.1, min(2, radius / 55))
            let fontSize = max(6, min(9, radius / 12))
            var labels: [CGRect] = []
            for (index, place) in places.enumerated() where valid(place.point) {
                let vector = projection.project(place.point)
                guard vector.z >= 0 else { continue }
                let point = vector.screen(center: origin, radius: radius)
                let tint = place.highlighted ? Palette.mint : routeColor
                surface.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius * 2.25, y: point.y - dotRadius * 2.25, width: dotRadius * 4.5, height: dotRadius * 4.5)), with: .color(tint.opacity(0.17)))
                surface.fill(Path(ellipseIn: CGRect(x: point.x - dotRadius, y: point.y - dotRadius, width: dotRadius * 2, height: dotRadius * 2)), with: .color(tint))
                let box = CGRect(x: point.x + dotRadius + 3, y: point.y - 10, width: fontSize * 3.5, height: 12)
                if showsLabels && index < 10 && vector.z > 0.12 && !place.code.isEmpty && !labels.contains(where: { $0.intersects(box) }) {
                    labels.append(box)
                    surface.draw(Text(place.code).font(.system(size: fontSize, weight: .semibold, design: .rounded)).foregroundColor(.white.opacity(0.8)),
                                 at: CGPoint(x: box.minX, y: box.midY), anchor: .leading)
                }
            }
            context.stroke(circle, with: .color(routeColor.opacity(0.22)), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("离线三维地球")
        .accessibilityValue("\(routes.count) 条航线，\(places.count) 个位置")
    }

    private func valid(_ point: GeoPoint) -> Bool {
        point.lat.isFinite && point.lon.isFinite && abs(point.lat) <= 90 && abs(point.lon) <= 180
    }

    private func line(_ points: [GeoPoint], projection: AtlasGlobeProjection, center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        var previous = projection.project(first)
        if previous.z >= 0 { path.move(to: previous.screen(center: center, radius: radius)) }
        for raw in points.dropFirst() {
            let point = projection.project(raw)
            if previous.z >= 0 && point.z >= 0 {
                path.addLine(to: point.screen(center: center, radius: radius))
            } else if previous.z >= 0 {
                path.addLine(to: AtlasGlobeVector.horizon(previous, point).screen(center: center, radius: radius))
            } else if point.z >= 0 {
                path.move(to: AtlasGlobeVector.horizon(previous, point).screen(center: center, radius: radius))
                path.addLine(to: point.screen(center: center, radius: radius))
            }
            previous = point
        }
        return path
    }
}

private struct AtlasGlobeVector {
    var x: Double
    var y: Double
    var z: Double

    func screen(center: CGPoint, radius: CGFloat) -> CGPoint {
        CGPoint(x: center.x + CGFloat(x) * radius, y: center.y - CGFloat(y) * radius)
    }

    static func horizon(_ a: Self, _ b: Self) -> Self {
        let fraction = a.z / (a.z - b.z)
        let x = a.x + (b.x - a.x) * fraction
        let y = a.y + (b.y - a.y) * fraction
        let length = max(sqrt(x * x + y * y), 0.000_001)
        return Self(x: x / length, y: y / length, z: 0)
    }

    static func clip(_ points: [Self]) -> [Self] {
        guard var previous = points.last else { return [] }
        var result: [Self] = []
        for point in points {
            if (point.z >= 0) != (previous.z >= 0) { result.append(horizon(previous, point)) }
            if point.z >= 0 { result.append(point) }
            previous = point
        }
        return result
    }
}

private struct AtlasGlobeProjection {
    let longitude: Double
    let sinLatitude: Double
    let cosLatitude: Double

    init(center: GeoPoint) {
        longitude = (center.lon.isFinite ? Geo.normalizeLon(center.lon) : 110) * .pi / 180
        let latitude = (center.lat.isFinite ? min(90, max(-90, center.lat)) : 20) * .pi / 180
        sinLatitude = sin(latitude)
        cosLatitude = cos(latitude)
    }

    func project(_ point: GeoPoint) -> AtlasGlobeVector {
        let phi = point.lat * .pi / 180
        let lambda = point.lon * .pi / 180 - longitude
        let sinPhi = sin(phi), cosPhi = cos(phi), cosLambda = cos(lambda)
        return AtlasGlobeVector(x: cosPhi * sin(lambda),
                               y: cosLatitude * sinPhi - sinLatitude * cosPhi * cosLambda,
                               z: sinLatitude * sinPhi + cosLatitude * cosPhi * cosLambda)
    }
}

private enum AtlasGlobeMesh {
    struct Polygon: Sendable {
        var points: [GeoPoint]
        var triangles: [Int]
        var coast: [GeoPoint]
    }

    /// Cached once, with shared edge vertices. Small geographic triangles follow the sphere.
    static let polygons: [Polygon] = RouteAtlasGeography.polygons.map(refine)

    private static func refine(_ polygon: RouteAtlasLandPolygon) -> Polygon {
        var points = polygon.points
        var pointIndices: [GeoPoint: Int] = [:]
        for (index, point) in points.enumerated() { pointIndices[point] = index }
        var triangles: [Int] = []

        func edgeLength(_ a: Int, _ b: Int) -> Double {
            let latitude = points[a].lat - points[b].lat
            let longitude = points[a].lon - points[b].lon
            return latitude * latitude + longitude * longitude
        }

        func vertex(_ point: GeoPoint) -> Int {
            if let index = pointIndices[point] { return index }
            let index = points.count
            points.append(point)
            pointIndices[point] = index
            return index
        }

        func append(_ a: Int, _ b: Int, _ c: Int) {
            let ab = edgeLength(a, b), bc = edgeLength(b, c), ca = edgeLength(c, a)
            guard max(ab, max(bc, ca)) > 36 else {
                triangles.append(contentsOf: [a, b, c])
                return
            }
            let u: Int, v: Int, w: Int
            if ab >= bc && ab >= ca { u = a; v = b; w = c }
            else if bc >= ca { u = b; v = c; w = a }
            else { u = c; v = a; w = b }
            // Interpolate in the source's geographic plane before projecting, preserving coastlines.
            let midpoint = vertex(GeoPoint((points[u].lat + points[v].lat) / 2, (points[u].lon + points[v].lon) / 2))
            append(u, midpoint, w)
            append(midpoint, v, w)
        }

        for index in stride(from: 0, to: polygon.triangles.count, by: 3) {
            append(polygon.triangles[index], polygon.triangles[index + 1], polygon.triangles[index + 2])
        }
        var coast: [GeoPoint] = []
        for index in polygon.points.indices {
            let a = polygon.points[index], b = polygon.points[(index + 1) % polygon.points.count]
            let steps = max(1, Int(ceil(max(abs(a.lat - b.lat), abs(a.lon - b.lon)) / 3)))
            for step in 0..<steps {
                let fraction = Double(step) / Double(steps)
                coast.append(GeoPoint(a.lat + (b.lat - a.lat) * fraction, a.lon + (b.lon - a.lon) * fraction))
            }
        }
        if let first = coast.first { coast.append(first) }
        return Polygon(points: points, triangles: triangles, coast: coast)
    }
}

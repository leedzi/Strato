import GoogleMaps3D
import SwiftUI

/// A separate, rectangular map so Google's attribution remains fully visible.
@MainActor
struct GoogleFlightScene: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var access = GoogleSceneAccess.shared
    @State private var mapReady = false

    var body: some View {
        NavigationStack {
            TimelineView(.periodic(from: .now, by: 5)) { context in
                if let session = model.session {
                    scene(session, date: model.now, refreshDate: context.date)
                } else {
                    unavailable("航程已经结束", detail: "可以回到护照查看这趟航程。")
                }
            }
            .background(Palette.night)
            .navigationTitle("Google 3D 外景")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                        .accessibilityIdentifier("google3d-close")
                }
            }
            .onAppear { access.refreshConfiguration() }
        }
    }

    @ViewBuilder
    private func scene(_ session: FocusSession, date: Date, refreshDate: Date) -> some View {
        if !access.isEnabled || !access.isConfigured {
            unavailable("3D 外景尚未开启", detail: "在设置中保存你自己的 Google 密钥并打开开关，离线舷窗仍可直接使用。")
        } else if access.requiresRestart {
            unavailable("重新打开 Strato 后可用", detail: "密钥已变更，请退出并重新打开 App，以便 3D 外景使用新的配置。")
        } else if !Self.isSupportedLocation(session.position(at: date)) {
            unavailable("当前区域使用离线舷窗", detail: "中国大陆及澳门没有 Google 3D 数据覆盖；可以关闭此页继续专注。")
        } else if mapReady && access.canOpenScene {
            VStack(spacing: 0) {
                GoogleFlightMap(session: session, date: date, refreshDate: refreshDate)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Text("按航班位置每 5 秒更新。真实地形数据，不代表实时天气或实拍；部分地区可能没有 3D 数据。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
        } else {
            ProgressView("准备 3D 外景")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .task {
                    guard let current = model.session,
                          Self.isSupportedLocation(current.position(at: model.now)) else { return }
                    mapReady = access.prepareMap()
                }
        }
    }

    private func unavailable(_ title: String, detail: String) -> some View {
        ContentUnavailableView(title, systemImage: "globe", description: Text(detail))
            .accessibilityIdentifier("google3d-unavailable")
    }

    /// Conservative mainland mask with clearly supported Hong Kong city/airport areas excluded.
    /// Other regions remain subject to Google's actual imagery coverage and built-in error UI.
    static func isSupportedLocation(_ point: GeoPoint) -> Bool {
        guard point.lat.isFinite, point.lon.isFinite,
              (-90...90).contains(point.lat), (-180...180).contains(point.lon) else { return false }
        let hongKongCity = (22.16...22.39).contains(point.lat) && (114.02...114.34).contains(point.lon)
        let hongKongAirport = (22.23...22.36).contains(point.lat) && (113.87...114.02).contains(point.lon)
        if hongKongCity || hongKongAirport { return true }
        return !ChinaRegion.contains(point)
    }
}

@MainActor
private struct GoogleFlightMap: View {
    var session: FocusSession
    var date: Date
    var refreshDate: Date
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var camera: GoogleMaps3D.Camera

    init(session: FocusSession, date: Date, refreshDate: Date) {
        self.session = session
        self.date = date
        self.refreshDate = refreshDate
        _camera = State(initialValue: Self.followCamera(session, date: date))
    }

    var body: some View {
        GoogleMaps3D.Map(camera: $camera, mode: .satellite)
            .accessibilityIdentifier("google3d-map-view")
            .onChange(of: refreshDate) { _, _ in
                guard scenePhase == .active else { return }
                let next = Self.followCamera(session, date: date)
                let crossesDateLine = abs(next.center.longitude - camera.center.longitude) > 180
                let crossesNorth = abs(next.heading - camera.heading) > 180
                if reduceMotion || crossesDateLine || crossesNorth {
                    camera = next
                } else {
                    withAnimation(.easeInOut(duration: 1.2)) { camera = next }
                }
            }
    }

    private static func followCamera(_ session: FocusSession, date: Date) -> GoogleMaps3D.Camera {
        let point = session.position(at: date)
        let state = session.flight.state
        let bearing = state.trackDeg.flatMap { $0.isFinite ? $0 : nil }
            ?? Geo.bearing(point, session.route.destination.point)
        let heading = Geo.normalizeHeading(bearing + 90)
        let height = min(max(Double(state.altitudeFt ?? 12000) * 0.3048, 600), 16000)
        let tilt = 55.0
        let tiltRadians = tilt * .pi / 180
        let target = Geo.destination(from: point, bearing: heading, distanceKm: height * tan(tiltRadians) / 1000)
        let roll = state.rollDeg.flatMap { $0.isFinite ? $0 : nil } ?? 0
        return GoogleMaps3D.Camera(
            center: .init(latitude: target.lat, longitude: target.lon, altitude: 0),
            heading: heading,
            tilt: tilt,
            roll: min(max(roll, -8), 8),
            range: height / cos(tiltRadians),
            fieldOfView: .degrees(70)
        )
    }
}

import SwiftUI
import WidgetKit

enum WidgetDesign {
    static var background: LinearGradient {
        LinearGradient(colors: [Palette.night, Palette.dusk, Palette.horizon], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    static func takeoff(origin: String?, destination: String? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "strato"
        components.host = "takeoff"
        components.queryItems = [
            origin.map { URLQueryItem(name: "origin", value: $0) },
            destination.map { URLQueryItem(name: "destination", value: $0) }
        ].compactMap { $0 }
        return components.url ?? URL(string: "strato://takeoff")!
    }

    static func atlasPlaces(_ airport: WidgetSnapshot.Place?) -> [RouteAtlasView.Place] {
        airport.map { [RouteAtlasView.Place(point: $0.point, code: $0.code, highlighted: true)] } ?? []
    }

    static func number(_ km: Double) -> String { Int(max(0, km).rounded()).formatted() }
    static func duration(_ minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        let hours = minutes / 60, remainder = minutes % 60
        return remainder == 0 ? "\(hours) 小时" : "\(hours) 小时 \(remainder) 分"
    }
}

/// Airport and route shortcuts stay useful while a Live Activity handles the current flight.
struct StratoLocationView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StratoEntry

    var body: some View {
        Group {
            switch family {
            case .systemMedium, .systemLarge: medium
            case .accessoryCircular: accessoryCircular
            case .accessoryRectangular: accessoryRectangular
            case .accessoryInline:
                Label(entry.snapshot.airport.map { "\($0.city) · 今日 \(entry.snapshot.stats.todayMinutes) 分钟" } ?? "打开 Strato，开始旅程", systemImage: "airplane.departure")
            default: small
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetDesign.background }
        .widgetURL(WidgetDesign.takeoff(origin: entry.snapshot.airport?.code))
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text("我的机场").font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "mappin.and.ellipse").foregroundStyle(Palette.mint)
            }
            if let airport = entry.snapshot.airport {
                Text(airport.city).font(.headline).lineLimit(1).minimumScaleFactor(0.75)
                ZStack(alignment: .bottomTrailing) {
                    RouteAtlasView(routes: [], places: WidgetDesign.atlasPlaces(airport), showsLabels: false, showsGrid: false)
                    Text(airport.code).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(Palette.mint)
                }
                .frame(maxHeight: .infinity)
                Link(destination: WidgetDesign.takeoff(origin: airport.code)) {
                    Label("快速起飞", systemImage: "airplane.departure")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.16), in: Capsule())
                }
            } else {
                Spacer(minLength: 0)
                Image(systemName: "airplane.circle").font(.largeTitle).foregroundStyle(Palette.sky)
                Text(entry.connected ? "从第一座机场出发" : "打开 Strato 同步")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
        }
    }

    private var medium: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("我的机场").font(.caption).foregroundStyle(.secondary)
                Text(entry.snapshot.airport?.city ?? "开启首程")
                    .font(.title3.bold()).lineLimit(1).minimumScaleFactor(0.7)
                RouteAtlasView(routes: [], places: WidgetDesign.atlasPlaces(entry.snapshot.airport), showsLabels: false, showsGrid: false)
                    .frame(maxHeight: .infinity)
                Link(destination: WidgetDesign.takeoff(origin: entry.snapshot.airport?.code)) {
                    Label("快速起飞", systemImage: "airplane.departure")
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                        .background(.white.opacity(0.15), in: Capsule())
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text("附近目的地 · 全程约").font(.caption2).foregroundStyle(.secondary)
                if let destinations = entry.snapshot.destinations, !destinations.isEmpty {
                    ForEach(destinations.prefix(3)) { destination in
                        Link(destination: WidgetDesign.takeoff(origin: entry.snapshot.airport?.code, destination: destination.place.code)) {
                            HStack(spacing: 4) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(destination.place.city).font(.caption.weight(.semibold)).lineLimit(1)
                                    Text(destination.place.code).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 2)
                                Text(FlightMath.shortDuration(minutes: destination.minutes))
                                    .font(.caption2.monospacedDigit()).foregroundStyle(Palette.sky)
                            }
                        }
                    }
                } else {
                    Text(entry.connected ? "打开应用选择目的地" : "打开 Strato 同步机场")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if entry.snapshot.flight != nil {
                    Label("旅程进行中", systemImage: "airplane")
                        .font(.caption2).foregroundStyle(Palette.mint)
                } else if let since = entry.snapshot.airportSince {
                    Text(since, style: .relative).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accessoryCircular: some View {
        Gauge(value: min(Double(entry.snapshot.stats.todayMinutes), 120), in: 0...120) {
            Image(systemName: "sparkles")
        } currentValueLabel: {
            Text("\(entry.snapshot.stats.todayMinutes)")
        }
        .gaugeStyle(.accessoryCircular)
    }

    private var accessoryRectangular: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.snapshot.airport.map { "\($0.city) · \($0.code)" } ?? "Strato").font(.headline).lineLimit(1)
            Text("今日专注 \(entry.snapshot.stats.todayMinutes) 分钟").font(.subheadline)
            Text("连续 \(entry.snapshot.stats.streak) 天 · 快速起飞").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct StratoJourneyView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StratoEntry

    var body: some View {
        Group {
            if let journey = entry.snapshot.lastJourney {
                if family == .systemSmall { compact(journey) } else { expanded(journey) }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Label("航程回顾", systemImage: "book.closed.fill").font(.headline)
                    RouteAtlasView(routes: [], places: [], showsLabels: false, showsGrid: false)
                    Text("第一段旅程会出现在这里").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetDesign.background }
        .widgetURL(URL(string: "strato://logbook")!)
    }

    private func atlas(_ journey: WidgetSnapshot.Journey) -> some View {
        RouteAtlasView(
            routes: [journey.path],
            places: [
                RouteAtlasView.Place(point: journey.origin.point, code: journey.origin.code),
                RouteAtlasView.Place(point: journey.destination.point, code: journey.destination.code, highlighted: journey.landed)
            ], showsLabels: true, showsGrid: false
        )
    }

    private func compact(_ journey: WidgetSnapshot.Journey) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("上一程").font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Image(systemName: journey.landed ? "checkmark.seal.fill" : "ticket.fill").foregroundStyle(Palette.mint)
            }
            Text("\(journey.origin.code) → \(journey.destination.code)")
                .font(.subheadline.bold()).lineLimit(1)
            atlas(journey).frame(maxHeight: .infinity)
            Text("\(journey.focusMinutes) 分钟 · \(WidgetDesign.number(journey.distanceKm)) km")
                .font(.caption2.monospacedDigit()).lineLimit(1).minimumScaleFactor(0.7)
            Text(journey.flightNumber + (journey.simulated ? " · 模拟" : ""))
                .font(.caption2).foregroundStyle(.secondary)
        }
    }

    private func expanded(_ journey: WidgetSnapshot.Journey) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Label("航程回顾", systemImage: "ticket.fill").font(.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text(journey.endedAt, format: .dateTime.month().day()).font(.caption2).foregroundStyle(.secondary)
            }
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(journey.origin.code) → \(journey.destination.code)").font(.headline).lineLimit(1)
                    Text("\(journey.origin.city) → \(journey.destination.city)")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(journey.focusMinutes)").font(.system(size: 27, weight: .bold, design: .rounded))
                    + Text(" 分钟").font(.caption)
                    Text("陪飞 \(WidgetDesign.number(journey.distanceKm)) km")
                        .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                atlas(journey).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            HStack {
                Text(journey.flightNumber + (journey.simulated ? " · 模拟" : "")).font(.caption2).foregroundStyle(.secondary)
                Spacer()
                Text(journey.landed ? "已落地" : journey.completed ? "专注完成" : "保存航段")
                    .font(.caption2.weight(.semibold)).foregroundStyle(journey.completed ? Palette.mint : Palette.amber)
            }
        }
    }
}

struct StratoEarthView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StratoEntry
    private var laps: Double { max(0, entry.snapshot.stats.totalKm) / 40_075 }

    var body: some View {
        Group {
            if family == .systemSmall {
                VStack(alignment: .leading, spacing: 4) {
                    Text("绕地球里程").font(.caption.weight(.semibold)).foregroundStyle(Palette.mint)
                    globe.frame(maxHeight: .infinity)
                    Text(laps, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    + Text(" 圈").font(.caption)
                    Text("\(WidgetDesign.number(entry.snapshot.stats.totalKm)) km").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                }
            } else {
                HStack(spacing: 16) {
                    globe.frame(maxWidth: .infinity)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("绕地球里程").font(.caption.weight(.semibold)).foregroundStyle(Palette.mint)
                        Text(laps, format: .number.precision(.fractionLength(2)))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        + Text(" 圈").font(.caption)
                        Text("\(WidgetDesign.number(entry.snapshot.stats.totalKm)) km").font(.subheadline.monospacedDigit())
                        Spacer(minLength: 0)
                        Text("\(entry.snapshot.stats.sessions) 段航程 · \(entry.snapshot.stats.tierTitle)")
                            .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                        Text("赤道一圈约 40,075 km").font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetDesign.background }
        .widgetURL(URL(string: "strato://stats")!)
    }

    private var globe: some View {
        ZStack {
            RouteAtlasGlobeView(
                routes: entry.snapshot.routes ?? [],
                places: WidgetDesign.atlasPlaces(entry.snapshot.airport),
                center: entry.snapshot.airport?.point ?? GeoPoint(20, 110),
                showsLabels: false,
                showsGrid: true,
                routeColor: Palette.mint,
                background: .clear
            )
            Circle().stroke(.white.opacity(0.12), lineWidth: 1)
            Circle().trim(from: 0, to: laps > 0 && laps.truncatingRemainder(dividingBy: 1) == 0 ? 1 : laps.truncatingRemainder(dividingBy: 1))
                .stroke(Palette.mint, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("累计绕地球 \(String(format: "%.2f", laps)) 圈")
    }
}

struct StratoFocusSummaryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StratoEntry

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("今日专注").font(.caption.weight(.semibold)).foregroundStyle(Palette.sky)
                    Spacer(minLength: 0)
                    if family == .systemSmall {
                        Image(systemName: "sparkles").font(.caption)
                    }
                }
                Spacer(minLength: 0)
                Text("\(entry.snapshot.stats.todayMinutes)").font(.system(size: 34, weight: .bold, design: .rounded))
                + Text(" 分钟").font(.caption)
                Text("连续 \(entry.snapshot.stats.streak) 天").font(.caption2).foregroundStyle(Palette.amber)
                if family == .systemSmall {
                    WidgetWeekBars(values: entry.snapshot.stats.week).frame(height: 24)
                } else {
                    Text("累计 \(WidgetDesign.duration(entry.snapshot.stats.totalMinutes))")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            if family != .systemSmall {
                VStack(alignment: .leading, spacing: 6) {
                    Text("最近七天").font(.caption).foregroundStyle(.secondary)
                    WidgetWeekBars(values: entry.snapshot.stats.week).frame(height: 58)
                    Text("近七天 \(WidgetDesign.duration(entry.snapshot.stats.weekMinutes))")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .foregroundStyle(.white)
        .containerBackground(for: .widget) { WidgetDesign.background }
        .widgetURL(URL(string: "strato://stats")!)
    }
}

private struct WidgetWeekBars: View {
    var values: [Int]
    var body: some View {
        GeometryReader { geometry in
            let peak = max(1, values.max() ?? 0)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    RoundedRectangle(cornerRadius: 3)
                        .fill(index == values.count - 1 ? Palette.sky : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .frame(height: max(3, geometry.size.height * CGFloat(value) / CGFloat(peak)))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
        .accessibilityLabel(values.map { "\($0) 分钟" }.joined(separator: "，"))
    }
}

struct StratoJourneyWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StratoJourneyWidget", provider: StratoProvider()) { StratoJourneyView(entry: $0) }
            .configurationDisplayName("航程回顾")
            .description("上一段航程、专注时间与实际陪飞路线。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StratoEarthWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StratoEarthWidget", provider: StratoProvider()) { StratoEarthView(entry: $0) }
            .configurationDisplayName("绕地球里程")
            .description("累计航迹、绕地球圈数与陪飞里程。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct StratoFocusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StratoFocusWidget", provider: StratoProvider()) { StratoFocusSummaryView(entry: $0) }
            .configurationDisplayName("专注回顾")
            .description("今日专注、连续天数与最近七天的趋势。")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

import ActivityKit
import SwiftUI
import WidgetKit

// MARK: - Timeline

struct StratoEntry: TimelineEntry {
    var date: Date
    var snapshot: WidgetSnapshot
    /// False when the widget cannot reach the data the app shares.
    var connected: Bool
}

struct StratoProvider: TimelineProvider {
    static var sample: WidgetSnapshot {
        var s = WidgetSnapshot()
        let now = Date()
        s.flight = WidgetSnapshot.Flight(
            flightNumber: "NH920", airlineICAO: "ANA", originCode: "PVG", originCity: "上海浦东",
            destinationCode: "HND", destinationCity: "东京羽田", tagTitle: "深度工作", seat: "12A",
            startedAt: now.addingTimeInterval(-1500), plannedEnd: now.addingTimeInterval(2700),
            routeStart: now.addingTimeInterval(-4200), isPaused: false, pausedRemaining: nil,
            phaseTitle: "巡航中", altitudeFt: 38000, groundSpeedKt: 468, simulated: false
        )
        s.stats = WidgetSnapshot.Stats(
            todayMinutes: 95, weekMinutes: 540, totalMinutes: 3120, totalKm: 28400, sessions: 41, streak: 6,
            tierTitle: "金卡", week: [40, 95, 0, 120, 60, 130, 95], lastFlightNumber: "CA1831",
            lastRoute: "PEK → SHA", lastEndedAt: now.addingTimeInterval(-7200)
        )
        return s
    }

    func placeholder(in context: Context) -> StratoEntry {
        StratoEntry(date: Date(), snapshot: Self.sample, connected: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (StratoEntry) -> Void) {
        if context.isPreview {
            completion(StratoEntry(date: Date(), snapshot: Self.sample, connected: true))
        } else {
            completion(StratoEntry(date: Date(), snapshot: SharedContainer.read(), connected: SharedContainer.isAvailable))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StratoEntry>) -> Void) {
        let now = Date()
        var snapshot = SharedContainer.read()
        let connected = SharedContainer.isAvailable
        var entries: [StratoEntry] = []
        if let flight = snapshot.flight, !flight.isPaused {
            if flight.plannedEnd > now {
                // The countdown and bar animate by themselves; one more entry clears the flight
                // shortly after it is due, in case the app is not running to do it.
                entries.append(StratoEntry(date: now, snapshot: snapshot, connected: connected))
                var after = snapshot
                after.flight = nil
                entries.append(StratoEntry(date: flight.plannedEnd.addingTimeInterval(120), snapshot: after, connected: connected))
            } else {
                snapshot.flight = nil
                entries.append(StratoEntry(date: now, snapshot: snapshot, connected: connected))
            }
        } else {
            entries.append(StratoEntry(date: now, snapshot: snapshot, connected: connected))
        }
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(1800))))
    }
}

// MARK: - Shared pieces

private struct FlightProgress: View {
    var flight: WidgetSnapshot.Flight
    var tint: Color

    var body: some View {
        if flight.isPaused {
            ProgressView(value: flight.fraction(at: Date())).tint(tint)
        } else {
            ProgressView(timerInterval: flight.routeStart...max(flight.plannedEnd, flight.routeStart.addingTimeInterval(1)), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(tint)
        }
    }
}

private struct Countdown: View {
    var flight: WidgetSnapshot.Flight

    var body: some View {
        if flight.isPaused {
            Text("已暂停")
        } else {
            Text(timerInterval: Date()...max(flight.plannedEnd, Date().addingTimeInterval(1)), countsDown: true)
                .monospacedDigit()
        }
    }
}

private func brandColor(_ icao: String?) -> Color {
    AirlineBrand.forICAO(icao).accentColor
}

private var widgetBackground: some View {
    LinearGradient(colors: [Palette.night, Palette.dusk, Palette.horizon], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Home Screen widget

struct StratoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StratoEntry

    var body: some View {
        Group {
            switch family {
            case .accessoryCircular: circular
            case .accessoryRectangular: rectangular
            case .accessoryInline: inline
            case .systemMedium: medium
            default: small
            }
        }
        .containerBackground(for: .widget) { widgetBackground }
    }

    private var stats: WidgetSnapshot.Stats { entry.snapshot.stats }

    // Small

    @ViewBuilder
    private var small: some View {
        if let f = entry.snapshot.flight {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(f.flightNumber).font(.caption.weight(.heavy)).foregroundStyle(brandColor(f.airlineICAO))
                    Spacer()
                    Image(systemName: "airplane").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Countdown(flight: f)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(f.originCode) → \(f.destinationCode)").font(.caption.weight(.semibold))
                FlightProgress(flight: f, tint: brandColor(f.airlineICAO))
                Text(f.tagTitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
            }
            .foregroundStyle(.white)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("STRATO").font(.caption2.weight(.heavy)).tracking(1.5).foregroundStyle(Palette.sky)
                    Spacer()
                    if stats.streak > 0 {
                        Label("\(stats.streak)", systemImage: "flame.fill").font(.caption2.weight(.bold)).foregroundStyle(Palette.amber)
                    }
                }
                Spacer(minLength: 0)
                Text("\(stats.todayMinutes)")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                + Text(" 分钟").font(.caption.weight(.semibold))
                Text(entry.connected ? "今天专注" : "打开 Strato 同步").font(.caption2).foregroundStyle(.secondary)
                WeekBars(values: stats.week).frame(height: 22)
            }
            .foregroundStyle(.white)
        }
    }

    // Medium

    @ViewBuilder
    private var medium: some View {
        if let f = entry.snapshot.flight {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(f.flightNumber).font(.subheadline.weight(.heavy)).foregroundStyle(brandColor(f.airlineICAO))
                    Text(f.simulated ? "模拟航班" : f.phaseTitle).font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Text(f.tagTitle).font(.caption).foregroundStyle(.secondary)
                }
                HStack(alignment: .lastTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(f.originCode).font(.system(size: 26, weight: .bold, design: .rounded))
                        Text(f.originCity).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Countdown(flight: f)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(f.destinationCode).font(.system(size: 26, weight: .bold, design: .rounded))
                        Text(f.destinationCity).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                FlightProgress(flight: f, tint: brandColor(f.airlineICAO))
            }
            .foregroundStyle(.white)
        } else {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("STRATO").font(.caption2.weight(.heavy)).tracking(1.5).foregroundStyle(Palette.sky)
                    Spacer(minLength: 0)
                    Text("\(stats.todayMinutes)").font(.system(size: 34, weight: .bold, design: .rounded))
                    + Text(" 分钟").font(.caption.weight(.semibold))
                    Text("今天专注").font(.caption2).foregroundStyle(.secondary)
                    if let last = stats.lastFlightNumber, let route = stats.lastRoute {
                        Text("上一程 \(last) \(route)").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("\(stats.streak) 天", systemImage: "flame.fill").foregroundStyle(Palette.amber)
                        Spacer()
                        Text(stats.tierTitle).foregroundStyle(.secondary)
                    }
                    .font(.caption.weight(.semibold))
                    WeekBars(values: stats.week)
                    Text("累计 \(Int(stats.totalKm.rounded())) km · \(stats.sessions) 段").font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            .foregroundStyle(.white)
        }
    }

    // Lock Screen

    @ViewBuilder
    private var circular: some View {
        if let f = entry.snapshot.flight, !f.isPaused {
            ProgressView(timerInterval: f.routeStart...max(f.plannedEnd, f.routeStart.addingTimeInterval(1)), countsDown: false) {
                Image(systemName: "airplane")
            } currentValueLabel: {
                Text(f.destinationCode).font(.system(size: 11, weight: .bold))
            }
            .progressViewStyle(.circular)
        } else {
            Gauge(value: min(Double(stats.todayMinutes), 240), in: 0...240) {
                Image(systemName: "airplane")
            } currentValueLabel: {
                Text("\(stats.todayMinutes)")
            }
            .gaugeStyle(.accessoryCircular)
        }
    }

    @ViewBuilder
    private var rectangular: some View {
        if let f = entry.snapshot.flight {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(f.flightNumber)  \(f.originCode) → \(f.destinationCode)").font(.headline).lineLimit(1)
                Countdown(flight: f).font(.subheadline)
                FlightProgress(flight: f, tint: .white)
            }
        } else {
            VStack(alignment: .leading, spacing: 2) {
                Text("Strato").font(.headline)
                Text("今天专注 \(stats.todayMinutes) 分钟")
                Text("连续 \(stats.streak) 天 · \(stats.tierTitle)").foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    @ViewBuilder
    private var inline: some View {
        if let f = entry.snapshot.flight {
            Label("\(f.flightNumber) → \(f.destinationCode)", systemImage: "airplane")
        } else {
            Label("今天专注 \(stats.todayMinutes) 分钟", systemImage: "airplane")
        }
    }
}

/// Seven small bars: focus minutes for each of the last seven days.
private struct WeekBars: View {
    var values: [Int]

    var body: some View {
        let peak = max(values.max() ?? 0, 1)
        HStack(alignment: .bottom, spacing: 4) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(index == values.count - 1 ? Palette.sky : Color.white.opacity(0.35))
                    .frame(maxWidth: .infinity)
                    .frame(height: max(3, 34 * CGFloat(value) / CGFloat(peak)))
            }
        }
        .frame(maxHeight: 34, alignment: .bottom)
    }
}

struct StratoHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "StratoHomeWidget", provider: StratoProvider()) { entry in
            StratoWidgetView(entry: entry)
        }
        .configurationDisplayName("Strato")
        .description("正在飞的专注航班，或者今天的专注时间。")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

// MARK: - Live Activity

struct StratoLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StratoFlightAttributes.self) { context in
            lockScreen(context)
                .activityBackgroundTint(Palette.night.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let tint = brandColor(context.attributes.airlineICAO)
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(context.attributes.originCode).font(.title3.weight(.bold))
                        Text(context.attributes.originCity).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 0) {
                        Text(context.attributes.destinationCode).font(.title3.weight(.bold))
                        Text(context.attributes.destinationCity).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 0) {
                        Text(context.attributes.flightNumber).font(.caption.weight(.heavy)).foregroundStyle(tint)
                        timer(context.state).font(.title3.weight(.bold))
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 4) {
                        bar(context.state, tint: tint)
                        HStack {
                            Text(context.state.phaseTitle)
                            Spacer()
                            Text(context.attributes.tagTitle)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                HStack(spacing: 3) {
                    Image(systemName: "airplane").foregroundStyle(tint)
                    Text(context.attributes.destinationCode).font(.caption.weight(.bold))
                }
            } compactTrailing: {
                timer(context.state)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: 52)
            } minimal: {
                Image(systemName: context.state.landed ? "checkmark.seal.fill" : "airplane").foregroundStyle(tint)
            }
            .keylineTint(tint)
        }
    }

    @ViewBuilder
    private func timer(_ state: StratoFlightAttributes.ContentState) -> some View {
        if state.landed {
            Text("已落地")
        } else if state.isPaused {
            Text("已暂停")
        } else {
            Text(timerInterval: Date()...max(state.plannedEnd, Date().addingTimeInterval(1)), countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private func bar(_ state: StratoFlightAttributes.ContentState, tint: Color) -> some View {
        if state.landed || state.isPaused {
            ProgressView(value: state.fraction(at: Date())).tint(tint)
        } else {
            ProgressView(timerInterval: state.routeStart...max(state.plannedEnd, state.routeStart.addingTimeInterval(1)), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(tint)
        }
    }

    private func lockScreen(_ context: ActivityViewContext<StratoFlightAttributes>) -> some View {
        let tint = brandColor(context.attributes.airlineICAO)
        return VStack(spacing: 10) {
            HStack {
                Text(context.attributes.flightNumber).font(.subheadline.weight(.heavy)).foregroundStyle(tint)
                Text(context.attributes.simulated ? "模拟航班" : context.state.phaseTitle).font(.caption).foregroundStyle(.secondary)
                Spacer()
                Label(context.attributes.tagTitle, systemImage: "airplane").font(.caption).foregroundStyle(.secondary)
            }
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(context.attributes.originCode).font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(context.attributes.originCity).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                timer(context.state).font(.system(size: 26, weight: .bold, design: .rounded))
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(context.attributes.destinationCode).font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(context.attributes.destinationCity).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            bar(context.state, tint: tint)
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

@main
struct StratoWidgets: WidgetBundle {
    var body: some Widget {
        StratoHomeWidget()
        StratoLiveActivity()
    }
}

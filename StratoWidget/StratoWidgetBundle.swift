import WidgetKit
import SwiftUI
import ActivityKit

private let skyCyan = Color(red: 0.35, green: 0.82, blue: 1.0)
private let radarEmerald = Color(red: 0.25, green: 0.90, blue: 0.65)

// MARK: - Home Screen Widget Timeline

struct StratoWidgetEntry: TimelineEntry {
    let date: Date
    let activeFlight: ActiveFlightSnapshot?
    let totalFlights: Int
    let totalFocusHours: Double
    let totalDistanceKM: Int
}

struct StratoTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> StratoWidgetEntry {
        StratoWidgetEntry(
            date: Date(),
            activeFlight: ActiveFlightSnapshot(
                callsign: "ANA851",
                originIATA: "HND",
                destinationIATA: "TSA",
                aircraftType: "B788",
                focusTag: "深度工作",
                seatNumber: "12A",
                progress: 0.62,
                altitudeFeet: 36_000,
                groundSpeedKnots: 468,
                phase: "平流层巡航",
                startedAt: Date().addingTimeInterval(-3600),
                etaDate: Date().addingTimeInterval(2400),
                isPaused: false,
                isLiveADSB: true
            ),
            totalFlights: 12,
            totalFocusHours: 24.5,
            totalDistanceKM: 18_420
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (StratoWidgetEntry) -> Void) {
        completion(loadCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StratoWidgetEntry>) -> Void) {
        let entry = loadCurrentEntry()
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(refreshDate)))
    }

    private func loadCurrentEntry() -> StratoWidgetEntry {
        let active = SharedStore.shared.loadActiveFlight()
        let records = SharedStore.shared.loadLogbook()
        let totalMins = records.reduce(0) { $0 + $1.durationMinutes }
        let totalKM = records.reduce(0) { $0 + $1.distanceKM }
        return StratoWidgetEntry(
            date: Date(),
            activeFlight: active,
            totalFlights: records.count,
            totalFocusHours: Double(totalMins) / 60.0,
            totalDistanceKM: totalKM
        )
    }
}

struct StratoHomeWidgetView: View {
    var entry: StratoTimelineProvider.Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            if let active = entry.activeFlight {
                activeFlightWidget(active)
            } else {
                idlePassportWidget
            }
        }
        .containerBackground(for: .widget) {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.08, blue: 0.16),
                    Color(red: 0.09, green: 0.16, blue: 0.28)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private func activeFlightWidget(_ active: ActiveFlightSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(active.callsign)
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(skyCyan)
                Spacer()
                Text("FL\(active.altitudeFeet / 100)")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(active.originIATA)
                    .font(.title3.bold().monospaced())
                Image(systemName: "airplane")
                    .font(.caption)
                    .foregroundStyle(radarEmerald)
                Text(active.destinationIATA)
                    .font(.title3.bold().monospaced())
            }

            ProgressView(value: active.progress)
                .tint(skyCyan)

            HStack {
                Text(active.focusTag)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(active.etaDate, style: .timer)
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(.white)
            }
        }
    }

    private var idlePassportWidget: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "airplane.circle.fill")
                    .foregroundStyle(skyCyan)
                Text("STRATO")
                    .font(.caption.monospaced().bold())
                    .foregroundStyle(skyCyan)
                Spacer()
            }

            Spacer()

            Text(String(format: "%.1f 小时", entry.totalFocusHours))
                .font(.title3.bold().monospacedDigit())

            Text("\(entry.totalFlights) 次航程 · \(entry.totalDistanceKM) km")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

struct StratoHomeWidget: Widget {
    let kind: String = "StratoHomeWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StratoTimelineProvider()) { entry in
            StratoHomeWidgetView(entry: entry)
        }
        .configurationDisplayName("Strato 航迹雷达")
        .description("实时查看当前专注航班进度或累计飞行护照里程。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Dynamic Island & Lock Screen Live Activity

struct StratoLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StratoFlightAttributes.self) { context in
            // Lock Screen / StandBy banner
            VStack(spacing: 10) {
                HStack {
                    Label(context.attributes.callsign, systemImage: "airplane")
                        .font(.subheadline.monospaced().bold())
                        .foregroundStyle(skyCyan)
                    Spacer()
                    Text(context.attributes.focusTag)
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(skyCyan.opacity(0.2), in: Capsule())
                }

                HStack(alignment: .center) {
                    Text(context.attributes.originIATA)
                        .font(.title2.bold().monospaced())
                    ProgressView(value: context.state.progress)
                        .tint(skyCyan)
                        .padding(.horizontal, 8)
                    Text(context.attributes.destinationIATA)
                        .font(.title2.bold().monospaced())
                }

                HStack {
                    Text(String(format: "FL%03d · %d kt", context.state.altitudeFeet / 100, context.state.groundSpeedKnots))
                        .font(.caption2.monospaced())
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(context.state.etaDate, style: .timer)
                        .font(.subheadline.monospacedDigit().bold())
                        .foregroundStyle(radarEmerald)
                }
            }
            .padding(16)
            .activityBackgroundTint(Color.black.opacity(0.75))
            .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.originIATA)
                            .font(.headline.monospaced().bold())
                        Text(context.attributes.callsign)
                            .font(.caption2.monospaced())
                            .foregroundStyle(skyCyan)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.attributes.destinationIATA)
                            .font(.headline.monospaced().bold())
                        Text(context.state.etaDate, style: .timer)
                            .font(.caption.monospacedDigit().bold())
                            .foregroundStyle(radarEmerald)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ProgressView(value: context.state.progress)
                            .tint(skyCyan)
                        HStack {
                            Text(context.state.phase)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(String(format: "FL%03d · %d kt", context.state.altitudeFeet / 100, context.state.groundSpeedKnots))
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .foregroundStyle(skyCyan)
                    Text(context.attributes.destinationIATA)
                        .font(.caption.monospaced().bold())
                }
            } compactTrailing: {
                Text("\(context.state.remainingMinutes)m")
                    .font(.caption.monospacedDigit().bold())
                    .foregroundStyle(radarEmerald)
            } minimal: {
                Image(systemName: "airplane")
                    .foregroundStyle(skyCyan)
            }
        }
    }
}

@main
struct StratoWidgetBundle: WidgetBundle {
    var body: some Widget {
        StratoHomeWidget()
        StratoLiveActivityWidget()
    }
}

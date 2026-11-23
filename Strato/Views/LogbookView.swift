import SwiftUI
import MapKit

struct LogbookView: View {
    @Environment(StratoStore.self) private var store

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    // World Route Map
                    passportMapCard

                    // Cumulative Stats
                    HStack(spacing: 12) {
                        statCard(
                            title: "累计专注",
                            value: String(format: "%.1fh", Double(store.totalFocusMinutes) / 60.0),
                            icon: "clock.fill",
                            color: StratoTheme.skyCyan
                        )
                        statCard(
                            title: "飞行里程",
                            value: "\(store.totalDistanceKM) km",
                            icon: "airplane",
                            color: StratoTheme.radarEmerald
                        )
                        statCard(
                            title: "打卡机场",
                            value: "\(store.visitedAirportsCount)",
                            icon: "mappin.and.ellipse",
                            color: StratoTheme.amberBeacon
                        )
                    }

                    // Boarding Pass History
                    VStack(alignment: .leading, spacing: 12) {
                        Text("登机牌存档 (\(store.logbook.count))")
                            .font(.headline)
                            .padding(.horizontal, 4)

                        if store.logbook.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "airplane.circle")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("还没有飞行记录")
                                    .font(.headline)
                                Text("去雷达页挑一班正在天上飞的飞机，陪它一起降落吧")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .stratoGlassCard(cornerRadius: 24)
                        } else {
                            ForEach(store.logbook) { record in
                                LogbookTicketCard(record: record)
                                    .contextMenu {
                                        Button("删除此记录", role: .destructive) {
                                            store.deleteLogRecord(record)
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding(16)
            }
            .navigationTitle("飞行护照")
        }
    }

    private var passportMapCard: some View {
        Map {
            ForEach(store.logbook) { record in
                let orig = CLLocationCoordinate2D(latitude: record.originLat, longitude: record.originLon)
                let dest = CLLocationCoordinate2D(latitude: record.destinationLat, longitude: record.destinationLon)
                let arc = GreatCircle.arcCoordinates(from: orig, to: dest, segments: 24)
                MapPolyline(coordinates: arc)
                    .stroke(StratoTheme.skyCyan.opacity(0.85), lineWidth: 2)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .frame(height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func statCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.subheadline)
            Text(value)
                .font(.headline.bold().monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .stratoGlassCard(cornerRadius: 20)
    }
}

private struct LogbookTicketCard: View {
    let record: FocusSessionRecord

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                HStack(spacing: 6) {
                    Text(record.callsign)
                        .font(.subheadline.bold().monospaced())
                    Text(record.focusTag.rawValue)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(StratoTheme.skyCyan.opacity(0.2), in: Capsule())
                        .foregroundStyle(StratoTheme.skyCyan)
                }
                Spacer()
                Text(record.completedAt, format: .dateTime.month().day().hour().minute())
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(record.originIATA)
                        .font(.title3.bold().monospaced())
                    Text(record.originCity)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(spacing: 2) {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundStyle(StratoTheme.radarEmerald)
                    Text("\(record.durationMinutes) min · \(record.distanceKM) km")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(record.destinationIATA)
                        .font(.title3.bold().monospaced())
                    Text(record.destinationCity)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .stratoGlassCard(cornerRadius: 22)
    }
}

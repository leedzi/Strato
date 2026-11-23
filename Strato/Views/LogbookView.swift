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

                    // Boarding Pass History with Airline Liveries & Customs Stamps
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text("航司登机牌收藏夹 (\(store.logbook.count))")
                                .font(.headline)
                            Spacer()
                            Text("长按可管理")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 4)

                        if store.logbook.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "ticket")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.secondary)
                                Text("还没有登机牌存档")
                                    .font(.headline)
                                Text("去实时雷达挑一班正在天上飞的飞机，陪它降落后会自动盖上入境章收入这里")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 36)
                            .stratoGlassCard(cornerRadius: 24)
                        } else {
                            ForEach(store.logbook) { record in
                                AirlineBoardingPassCard(
                                    callsign: record.callsign,
                                    airlineName: record.airlineName,
                                    aircraftType: record.aircraftType,
                                    originIATA: record.originIATA,
                                    originCity: record.originCity,
                                    destinationIATA: record.destinationIATA,
                                    destinationCity: record.destinationCity,
                                    seatNumber: record.seatNumber,
                                    gateNumber: record.gateNumber,
                                    cabinClass: record.cabinClass,
                                    sequenceNumber: record.sequenceNumber,
                                    flightLevelText: "FL360",
                                    durationMinutes: record.durationMinutes,
                                    distanceKM: record.distanceKM,
                                    realProgress: record.landedAtProgress,
                                    focusTag: record.focusTag,
                                    date: record.completedAt,
                                    showArrivedStamp: true
                                )
                                .contextMenu {
                                    Button("删除此登机牌", role: .destructive) {
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
                    .stroke(StratoTheme.skyCyan.opacity(0.88), lineWidth: 2.4)
            }
        }
        .mapStyle(.imagery(elevation: .realistic))
        .frame(height: 210)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
    }
}

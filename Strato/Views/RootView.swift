import SwiftUI

struct RootView: View {
    @Environment(StratoStore.self) private var store
    @State private var selectedTab: AppTab = .radar

    enum AppTab: Hashable {
        case radar
        case analytics
        case logbook
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("实时雷达", systemImage: "airplane.circle.fill", value: AppTab.radar) {
                RadarFocusView()
            }

            Tab("专注分析", systemImage: "chart.bar.xaxis", value: AppTab.analytics) {
                AnalyticsView()
            }

            Tab("飞行护照", systemImage: "ticket.fill", value: AppTab.logbook) {
                LogbookView()
            }

            Tab("设置", systemImage: "slider.horizontal.3", value: AppTab.settings) {
                SettingsView()
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .tint(StratoTheme.skyCyan)
        .task {
            if store.radarFlights.isEmpty {
                await store.refreshRadar()
            }
        }
        .sheet(item: Binding(
            get: { store.recentlyCompletedRecord },
            set: { store.recentlyCompletedRecord = $0 }
        )) { record in
            LandingStampSheet(record: record)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct LandingStampSheet: View {
    let record: FocusSessionRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.title2)
                        .foregroundStyle(StratoTheme.radarEmerald)
                    Text("已安全降落 · 登机牌已盖入境章")
                        .font(.title3.bold())
                }
                .padding(.top, 8)

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
                    flightLevelText: "ARRIVED",
                    durationMinutes: record.durationMinutes,
                    distanceKM: record.distanceKM,
                    realProgress: 1.0,
                    focusTag: record.focusTag,
                    date: record.completedAt,
                    showArrivedStamp: true
                )

                Button {
                    dismiss()
                } label: {
                    Text("收入飞行护照与专注统计")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.glassProminent)
                .tint(StratoTheme.skyCyan)
            }
            .padding(20)
        }
    }
}

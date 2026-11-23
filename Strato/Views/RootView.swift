import SwiftUI

struct RootView: View {
    @Environment(StratoStore.self) private var store
    @State private var selectedTab: AppTab = .radar

    enum AppTab: Hashable {
        case radar
        case logbook
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("雷达", systemImage: "airplane.circle.fill", value: AppTab.radar) {
                RadarFocusView()
            }

            Tab("飞行日志", systemImage: "book.pages.fill", value: AppTab.logbook) {
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
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }
}

private struct LandingStampSheet: View {
    let record: FocusSessionRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(StratoTheme.radarEmerald)
                .symbolEffect(.bounce)

            VStack(spacing: 6) {
                Text("已安全降落")
                    .font(.title2.bold())
                Text("\(record.callsign) · \(record.originIATA) → \(record.destinationIATA)")
                    .font(.headline.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 20) {
                statBlock(title: "专注时长", value: "\(record.durationMinutes) 分钟")
                Divider().frame(height: 36)
                statBlock(title: "飞行里程", value: "\(record.distanceKM) km")
                Divider().frame(height: 36)
                statBlock(title: "座位", value: record.seatNumber)
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 20)
            .stratoGlassCard(cornerRadius: 20)

            Button {
                dismiss()
            } label: {
                Text("收入飞行护照")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(StratoTheme.skyCyan)
        }
        .padding(24)
    }

    private func statBlock(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

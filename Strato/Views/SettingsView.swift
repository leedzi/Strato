import SwiftUI

struct SettingsView: View {
    @Environment(StratoStore.self) private var store
    @State private var adsbKey: String = SharedStore.shared.adsbLolApiKey

    var body: some View {
        @Bindable var bindableStore = store

        NavigationStack {
            Form {
                Section("地图源与全球雷达") {
                    Picker("地图引擎", selection: $bindableStore.mapProvider) {
                        ForEach(StratoMapProvider.allCases) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }

                    Picker("默认扫描范围", selection: $bindableStore.selectedScope) {
                        ForEach(RadarScope.allCases) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .onChange(of: store.selectedScope) { _, _ in
                        Task { await store.refreshRadar() }
                    }
                }

                Section {
                    SecureField("可选：adsb.lol API Key（留空免费直连）", text: $adsbKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: adsbKey) { _, newValue in
                            SharedStore.shared.adsbLolApiKey = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                } header: {
                    Text("实时 ADS-B 航空数据源")
                } footer: {
                    Text("Strato 2.0 并发直连 opendata.adsb.fi 全球 12 大空域与 api.adsbdb.com 航线库，无需填 Key 即可实时追踪数百架在飞航班。")
                }

                Section("系统能力与版本") {
                    HStack {
                        Text("灵动岛 / 锁屏实时活动")
                        Spacer()
                        Text(LiveActivityManager.shared.isSupported ? "已启用" : "LiveContainer 环境受限")
                            .foregroundStyle(LiveActivityManager.shared.isSupported ? StratoTheme.radarEmerald : .secondary)
                    }
                    HStack {
                        Text("当前版本")
                        Spacer()
                        Text("Strato 2.0.0 (Liquid Glass + Amap/Google Hybrid)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

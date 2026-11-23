import SwiftUI

struct SettingsView: View {
    @Environment(StratoStore.self) private var store
    @State private var adsbKey: String = SharedStore.shared.adsbLolApiKey

    var body: some View {
        @Bindable var bindableStore = store

        NavigationStack {
            Form {
                Section("实时雷达设置") {
                    Picker("默认扫描空域", selection: $bindableStore.selectedRegion) {
                        ForEach(RadarRegion.allCases) { region in
                            Text(region.rawValue).tag(region)
                        }
                    }
                    .onChange(of: store.selectedRegion) { _, _ in
                        Task { await store.refreshRadar() }
                    }

                    Picker("地图风格", selection: $bindableStore.mapStyleOption) {
                        ForEach(StratoMapStyleOption.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                }

                Section {
                    SecureField("可选：adsb.lol API Key（留空免费可用）", text: $adsbKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: adsbKey) { _, newValue in
                            SharedStore.shared.adsbLolApiKey = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                } header: {
                    Text("ADS-B 数据源")
                } footer: {
                    Text("Strato 默认直连 opendata.adsb.fi 与 adsb.lol 开源 ADS-B 雷达，无需填写任何 Key 即可免费实时追踪航班。")
                }

                Section("系统能力状态") {
                    HStack {
                        Text("灵动岛 / 实时活动")
                        Spacer()
                        Text(LiveActivityManager.shared.isSupported ? "已启用" : "未开启或受签名限制")
                            .foregroundStyle(LiveActivityManager.shared.isSupported ? StratoTheme.radarEmerald : .secondary)
                    }
                    HStack {
                        Text("当前版本")
                        Spacer()
                        Text("Strato 1.0.0 (Liquid Glass)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
        }
    }
}

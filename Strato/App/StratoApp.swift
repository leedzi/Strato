import SwiftUI
import UIKit

@main
struct StratoApp: App {
    @State private var model: AppModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // `-demo 1` runs against a built-in world of flights instead of the network (used for
        // screenshots and UI tests); `-demoSpeed N` makes that world run N times faster.
        let defaults = UserDefaults.standard
        var speed: Double?
        if defaults.bool(forKey: "demo") {
            speed = max(1, defaults.double(forKey: "demoSpeed"))
        }
        if defaults.bool(forKey: "uitest") {
            // UI tests wait for the app to settle before every step; continuous animations make that crawl.
            UIView.setAnimationsEnabled(false)
        }
        _model = State(initialValue: AppModel(demoSpeed: speed))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(model)
                .preferredColorScheme(.dark)
                .tint(Palette.sky)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: model.sceneBecameActive()
            case .background, .inactive: model.sceneResignedActive()
            @unknown default: break
            }
        }
    }
}

// MARK: - Settings

struct SettingsScreen: View {
    @Environment(AppModel.self) private var model
    @State private var exportURL: URL?
    @State private var confirmErase = false
    @State private var notificationsAllowed = true

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    TextField("登机牌上的名字，如 LI/MING", text: $model.settings.passengerName)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Picker("默认舱位", selection: $model.settings.cabin) {
                        ForEach(CabinClass.allCases, id: \.self) { Text($0.title).tag($0) }
                    }
                } header: {
                    Text("旅客")
                }

                Section {
                    Picker("地图", selection: $model.settings.mapProvider) {
                        ForEach(MapProvider.allCases) { p in
                            Text(p.title).tag(p)
                        }
                    }
                    NavigationLink {
                        Google3DSettingsView()
                    } label: {
                        Label("Google 3D 外景", systemImage: "globe.asia.australia.fill")
                    }
                    .accessibilityIdentifier("google3d-settings")
                    Toggle("全球搜索用一次性快照", isOn: $model.settings.useGlobalSnapshot)
                } header: {
                    Text("地图与数据")
                } footer: {
                    Text("\(model.settings.mapProvider.title)：\(model.settings.mapProvider.detail)。\n快照来自 OpenSky，一次拿到全球在飞的航班，找航班更快更全；每天次数有限，用完会自动改为分区域扫描。")
                }

                Section {
                    Picker("环境音", selection: Binding(get: { model.settings.ambient }, set: { model.setAmbient($0) })) {
                        ForEach(AmbientPreset.allCases) { Text($0.title).tag($0) }
                    }
                    Toggle("登机、进近与落地提示音", isOn: $model.settings.chimes)
                        .accessibilityIdentifier("settings-chimes-toggle")
                    Toggle("触感反馈", isOn: $model.settings.haptics)
                    Toggle("飞行中保持屏幕常亮", isOn: $model.settings.keepAwake)
                } header: {
                    Text("飞行中")
                } footer: {
                    Text("环境音在登机后播放，会和你正在听的音乐混在一起。提示音开关同时控制登机、下降、进近和落地通知的声音。")
                }

                Section {
                    Toggle("落地通知", isOn: Binding(
                        get: { model.settings.notifications },
                        set: { on in
                            model.settings.notifications = on
                            if on { model.enableNotifications() }
                        }
                    ))
                    status("灵动岛与锁屏实时活动", ok: model.activity.isAvailable, off: "当前环境不可用")
                    status("桌面小组件数据", ok: SharedContainer.isAvailable, off: "未共享")
                } header: {
                    Text("系统")
                } footer: {
                    Text(systemFootnote)
                }

                Section {
                    NavigationLink {
                        ICloudSyncView()
                    } label: {
                        Label("iCloud Drive 同步", systemImage: "icloud")
                    }
                    .accessibilityIdentifier("icloud-settings")
                    if let exportURL {
                        ShareLink(item: exportURL) {
                            Label("导出飞行记录（JSON）", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button(role: .destructive) {
                        confirmErase = true
                    } label: {
                        Label("清空全部飞行记录", systemImage: "trash")
                    }
                    .disabled(model.records.isEmpty)
                } header: {
                    Text("数据")
                } footer: {
                    Text(model.cloudSync.isConnected ? "记录保存在本机，并与选定文件夹自动合并。删除记录会同步；可先导出备份。" : "记录保存在本机。可选择 iCloud Drive 文件夹，在其他设备自动同步。")
                }

                Section {
                    credit("实时航班位置", "adsb.fi", "https://adsb.fi")
                    credit("备用位置源", "adsb.lol（ODbL）", "https://adsb.lol")
                    credit("全球快照", "The OpenSky Network", "https://opensky-network.org")
                    credit("航线", "adsb.lol 航线库、adsbdb", "https://www.adsbdb.com")
                    credit("机身照片", "Planespotters.net", "https://www.planespotters.net")
                    credit("机场数据", "OurAirports、OpenFlights", "https://ourairports.com")
                } header: {
                    Text("数据来源")
                } footer: {
                    Text("Strato \(version)\n位置数据由全球爱好者的接收机提供，覆盖不到的地方会暂时看不到飞机；落地时间为估算。仅供个人非商业使用，请勿用于任何与飞行安全有关的用途。")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Palette.backdrop.ignoresSafeArea())
            .navigationTitle("设置")
            .confirmationDialog("清空全部飞行记录？", isPresented: $confirmErase, titleVisibility: .visible) {
                Button("清空 \(model.records.count) 条记录", role: .destructive) {
                    model.eraseAllRecords()
                    exportURL = nil
                }
            } message: {
                Text(model.cloudSync.isConnected ? "登机牌、专注时间和里程都会删除，并同步到已连接的设备。可以先导出一份。" : "登机牌、专注时间和里程都会删除。可以先导出一份。")
            }
            .task(id: model.records.count) {
                exportURL = model.records.isEmpty ? nil : model.exportLogbook()
            }
        }
    }

    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return "\(v) (\(b))"
    }

    private var systemFootnote: String {
        var lines: [String] = []
        if !model.activity.isAvailable {
            lines.append("实时活动不可用：在 LiveContainer 里运行时属于正常现象，或者是在系统设置里关掉了。")
        }
        if !SharedContainer.isAvailable {
            lines.append("小组件拿不到数据：需要把 Strato 作为独立 App 安装，并在签名时保留小组件扩展和 App Group。")
        }
        if lines.isEmpty { lines.append("落地时会发一条通知，锁屏和灵动岛会显示航程进度。") }
        return lines.joined(separator: "\n")
    }

    private func status(_ title: String, ok: Bool, off: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(ok ? "可用" : off)
                .foregroundStyle(ok ? Palette.mint : Color.secondary)
        }
    }

    private func credit(_ what: String, _ who: String, _ link: String) -> some View {
        Link(destination: URL(string: link)!) {
            HStack {
                Text(what).foregroundStyle(.primary)
                Spacer()
                Text(who).foregroundStyle(.secondary).font(.subheadline)
                Image(systemName: "arrow.up.right").font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

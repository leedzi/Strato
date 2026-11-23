import SwiftUI

struct FlightMatcherSheet: View {
    @Environment(StratoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let onSelectFlight: (LiveFlight, Int?) -> Void

    @State private var mode: MatchMode = .liveRadar
    @State private var minutes: Double = 120
    @State private var selectedDestCode: String = "ANY"
    @State private var customOriginCode: String = "PVG"
    @State private var customDestCode: String = "HND"

    private let presets = [25, 45, 60, 90, 120, 180]

    enum MatchMode: String, CaseIterable, Identifiable {
        case liveRadar = "实时天上找飞机"
        case customRoute = "自选航线起飞"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("模式", selection: $mode) {
                        ForEach(MatchMode.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)

                    // Duration Selector
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("计划专注时长")
                                .font(.headline)
                            Spacer()
                            Text(formattedDuration(Int(minutes)))
                                .font(.title3.bold().monospacedDigit())
                                .foregroundStyle(StratoTheme.skyCyan)
                        }

                        Slider(value: $minutes, in: 15...240, step: 5)
                            .tint(StratoTheme.skyCyan)

                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    minutes = Double(preset)
                                } label: {
                                    Text(preset >= 60 ? "\(preset / 60)h\(preset % 60 == 0 ? "" : "\(preset % 60)m")" : "\(preset)m")
                                        .font(.caption.bold().monospacedDigit())
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(.plain)
                                .stratoGlassCapsule(
                                    interactive: true,
                                    tint: Int(minutes) == preset ? StratoTheme.skyCyan.opacity(0.32) : nil
                                )
                            }
                        }
                    }
                    .padding(16)
                    .stratoGlassCard(cornerRadius: 22)

                    if mode == .liveRadar {
                        liveRadarMatcherSection
                    } else {
                        customRouteSection
                    }
                }
                .padding(16)
            }
            .navigationTitle("匹配专注航班")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
            .onAppear {
                minutes = Double(store.targetFocusMinutes)
                selectedDestCode = store.selectedDestination?.iata ?? "ANY"
            }
        }
    }

    private var liveRadarMatcherSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("目的地筛选")
                    .font(.headline)
                Spacer()
                Picker("目的地", selection: $selectedDestCode) {
                    Text("全球热门任意").tag("ANY")
                    ForEach(AirportDatabase.all) { airport in
                        Text("\(airport.iata) · \(airport.city)").tag(airport.iata)
                    }
                }
                .tint(StratoTheme.skyCyan)
            }
            .padding(16)
            .stratoGlassCard(cornerRadius: 20)

            Button {
                store.targetFocusMinutes = Int(minutes)
                store.selectedDestination = selectedDestCode == "ANY" ? nil : AirportDatabase.find(code: selectedDestCode)
                Task {
                    await store.matchFlightsForDuration()
                }
            } label: {
                HStack {
                    if store.isMatchingFlights {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "dot.radiowaves.left.and.right")
                    }
                    Text(store.isMatchingFlights ? "正在扫描实时空域…" : "搜索还剩 \(formattedDuration(Int(minutes))) 降落的航班")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(StratoTheme.skyCyan)

            // Results list
            VStack(spacing: 10) {
                ForEach(store.recommendedFlights.prefix(8)) { flight in
                    Button {
                        onSelectFlight(flight, Int(minutes))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(flight.callsign)
                                        .font(.headline.monospaced().bold())
                                    Text(flight.isLiveADSB ? "LIVE" : "SIM")
                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                        .foregroundStyle(flight.isLiveADSB ? StratoTheme.radarEmerald : StratoTheme.amberBeacon)
                                }
                                Text("\(flight.origin?.iata ?? "LIVE") → \(flight.destination?.iata ?? "DEST") · \(flight.destination?.city ?? flight.airlineName)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("约 \(flight.estimatedRemainingMinutes) 分钟")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(StratoTheme.skyCyan)
                                Text("\(flight.flightLevelText) · \(Int(flight.groundSpeedKnots))kt")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .stratoGlassCard(cornerRadius: 18, interactive: true)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var customRouteSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 12) {
                HStack {
                    Text("出发机场")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("出发", selection: $customOriginCode) {
                        ForEach(AirportDatabase.all) { airport in
                            Text("\(airport.iata) · \(airport.city)").tag(airport.iata)
                        }
                    }
                    .tint(StratoTheme.skyCyan)
                }
                Divider()
                HStack {
                    Text("目的机场")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("目的地", selection: $customDestCode) {
                        ForEach(AirportDatabase.all) { airport in
                            Text("\(airport.iata) · \(airport.city)").tag(airport.iata)
                        }
                    }
                    .tint(StratoTheme.radarEmerald)
                }
            }
            .padding(16)
            .stratoGlassCard(cornerRadius: 20)

            Button {
                let origin = AirportDatabase.find(code: customOriginCode) ?? AirportDatabase.all[2]
                let dest = AirportDatabase.find(code: customDestCode) ?? AirportDatabase.all[17]
                let customFlight = ADSBService.shared.makeCustomFlight(
                    origin: origin,
                    destination: dest,
                    durationMinutes: Int(minutes)
                )
                onSelectFlight(customFlight, Int(minutes))
            } label: {
                Label("生成登机牌并准备起飞", systemImage: "airplane.departure")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(StratoTheme.radarEmerald)
        }
    }

    private func formattedDuration(_ mins: Int) -> String {
        let h = mins / 60
        let m = mins % 60
        if h > 0 && m > 0 { return "\(h) 小时 \(m) 分" }
        if h > 0 { return "\(h) 小时" }
        return "\(m) 分钟"
    }
}

// MARK: - Boarding Pass Sheet

struct BoardingPassSheet: View {
    let flight: LiveFlight
    let onTakeOff: (Int, FocusTag, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTag: FocusTag = .deepWork
    @State private var seatNumber: String = ["1A", "6A", "12A", "14F", "18A", "22K"].randomElement() ?? "12A"
    @State private var syncToLiveETA: Bool = true
    @State private var customMinutes: Double = 60

    private var effectiveDuration: Int {
        syncToLiveETA ? flight.estimatedRemainingMinutes : Int(customMinutes)
    }

    var body: some View {
        VStack(spacing: 18) {
            // Boarding Pass Ticket
            VStack(spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("STRATO BOARDING PASS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(StratoTheme.skyCyan)
                        Text("\(flight.callsign) · \(flight.airlineName)")
                            .font(.headline.monospaced())
                    }
                    Spacer()
                    Text(flight.aircraftType)
                        .font(.caption.monospaced().bold())
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.12), in: Capsule())
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(flight.origin?.iata ?? "LIVE")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                        Text(flight.origin?.city ?? "当前空域")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "airplane")
                        .font(.title2)
                        .foregroundStyle(StratoTheme.skyCyan)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(flight.destination?.iata ?? "DEST")
                            .font(.system(size: 32, weight: .bold, design: .monospaced))
                        Text(flight.destination?.city ?? "目的地")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                HStack {
                    ticketField(title: "SEAT", value: seatNumber)
                    Spacer()
                    ticketField(title: "FLIGHT LEVEL", value: flight.flightLevelText)
                    Spacer()
                    ticketField(title: "DURATION", value: "\(effectiveDuration) min")
                }
            }
            .padding(20)
            .stratoGlassCard(cornerRadius: 26)

            // Focus Tag Picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FocusTag.allCases) { tag in
                        Button {
                            selectedTag = tag
                        } label: {
                            Label(tag.rawValue, systemImage: tag.symbol)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.plain)
                        .stratoGlassCapsule(
                            interactive: true,
                            tint: selectedTag == tag ? StratoTheme.skyCyan.opacity(0.32) : nil
                        )
                    }
                }
            }

            // Duration sync toggle
            VStack(spacing: 8) {
                Toggle("同步航班实时预计降落时间（约 \(flight.estimatedRemainingMinutes) 分钟）", isOn: $syncToLiveETA)
                    .font(.subheadline)
                    .tint(StratoTheme.skyCyan)

                if !syncToLiveETA {
                    HStack {
                        Text("自定义专注")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Slider(value: $customMinutes, in: 10...240, step: 5)
                            .tint(StratoTheme.skyCyan)
                        Text("\(Int(customMinutes))m")
                            .font(.caption.monospacedDigit().bold())
                    }
                }
            }
            .padding(14)
            .stratoGlassCard(cornerRadius: 18)

            Button {
                onTakeOff(effectiveDuration, selectedTag, seatNumber)
            } label: {
                Label("滑行起飞 · 开始专注", systemImage: "airplane.departure")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .tint(StratoTheme.skyCyan)
        }
        .padding(20)
        .onAppear {
            customMinutes = Double(min(max(flight.estimatedRemainingMinutes, 15), 240))
        }
    }

    private func ticketField(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospaced())
        }
    }
}

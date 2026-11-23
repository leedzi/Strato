import SwiftUI

struct FlightMatcherSheet: View {
    @Environment(StratoStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    let onSelectFlight: (LiveFlight, Int?) -> Void

    @State private var mode: MatchMode = .liveRadar
    @State private var minutes: Double = 90
    @State private var selectedDestCode: String = "ANY"
    @State private var customOriginCode: String = "PVG"
    @State private var customDestCode: String = "HND"
    @State private var customAirlineCode: String = "ANA"

    private let presets = [30, 45, 60, 90, 120, 180]
    private let airlineOptions = ["CCA", "CES", "CSN", "CHH", "CPA", "ANA", "JAL", "SIA", "EVA", "BAW", "DLH", "UAE", "DAL", "UAL"]

    enum MatchMode: String, CaseIterable, Identifiable {
        case liveRadar = "实时天上真飞机匹配"
        case customRoute = "自选航司与起降航线"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
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

                        Slider(value: $minutes, in: 15...300, step: 5)
                            .tint(StratoTheme.skyCyan)

                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                Button {
                                    minutes = Double(preset)
                                } label: {
                                    Text(preset >= 60 ? "\(preset / 60)h\(preset % 60 == 0 ? "" : "\(preset % 60)m")" : "\(preset)m")
                                        .font(.caption.bold().monospacedDigit())
                                        .foregroundStyle(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 8)
                                        .stratoGlassCapsule(
                                            tint: Int(minutes) == preset ? StratoTheme.skyCyan.opacity(0.35) : nil
                                        )
                                }
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
            .navigationTitle("匹配专注伴飞航班")
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
                Text("指定降落目的地")
                    .font(.headline)
                Spacer()
                Picker("目的地", selection: $selectedDestCode) {
                    Text("全球任意机场").tag("ANY")
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
                    Text(store.isMatchingFlights ? "正在扫描全球空域…" : "检索还剩约 \(formattedDuration(Int(minutes))) 降落的真飞机")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .tint(StratoTheme.skyCyan)

            // Results list
            VStack(spacing: 10) {
                ForEach(store.recommendedFlights.prefix(15)) { flight in
                    let branding = AirlineThemeRegistry.branding(forCallsign: flight.callsign, fallbackName: flight.airlineName)
                    Button {
                        onSelectFlight(flight, Int(minutes))
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(branding.primaryColor)
                                        .frame(width: 8, height: 8)
                                    Text(flight.displayCallsign)
                                        .font(.headline.monospaced().bold())
                                    Text(branding.nameCN)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(branding.accentColor)
                                }
                                Text("\(flight.origin?.iata ?? "LIVE") \(flight.origin?.city ?? "") → \(flight.destination?.iata ?? "DEST") \(flight.destination?.city ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text("剩 \(flight.estimatedRemainingMinutes) 分钟")
                                    .font(.subheadline.bold().monospacedDigit())
                                    .foregroundStyle(StratoTheme.skyCyan)
                                Text("已飞 \(Int((flight.realFlightProgress * 100).rounded()))% · \(flight.flightLevelText)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(14)
                        .stratoGlassCard(cornerRadius: 18)
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
                    Text("执飞航司涂装")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Picker("航司", selection: $customAirlineCode) {
                        ForEach(airlineOptions, id: \.self) { code in
                            let b = AirlineThemeRegistry.branding(forCallsign: code)
                            Text("\(b.nameCN) (\(b.iataCode))").tag(code)
                        }
                    }
                    .tint(StratoTheme.skyCyan)
                }
                Divider()
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
                let dest = AirportDatabase.find(code: customDestCode) ?? AirportDatabase.all[33]
                let customFlight = ADSBService.shared.makeCustomFlight(
                    origin: origin,
                    destination: dest,
                    airlineCode: customAirlineCode,
                    durationMinutes: Int(minutes)
                )
                onSelectFlight(customFlight, Int(minutes))
            } label: {
                Label("打印航司专属登机牌", systemImage: "ticket.fill")
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

// MARK: - Boarding Pass Sheet (With Real Airline Livery Ticket!)

struct BoardingPassSheet: View {
    let flight: LiveFlight
    let onTakeOff: (Int, FocusTag, String, String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTag: FocusTag = .deepWork
    @State private var seatNumber: String = ["01A", "02K", "06A", "12A", "15F", "18K"].randomElement() ?? "06A"
    @State private var gateNumber: String = ["G12", "G18", "C36", "E08", "B22", "A15"].randomElement() ?? "G18"
    @State private var cabinClass: String = "BUSINESS · 公务舱"
    @State private var syncToLiveETA: Bool = true
    @State private var customMinutes: Double = 60

    private var branding: AirlineBranding {
        AirlineThemeRegistry.branding(forCallsign: flight.callsign, fallbackName: flight.airlineName)
    }

    private var effectiveDuration: Int {
        syncToLiveETA ? flight.estimatedRemainingMinutes : Int(customMinutes)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Realistic Airline Boarding Pass Preview
                    AirlineBoardingPassCard(
                        callsign: flight.callsign,
                        airlineName: flight.airlineName,
                        aircraftType: flight.aircraftType,
                        originIATA: flight.origin?.iata ?? "LIVE",
                        originCity: flight.origin?.city ?? "当前空域",
                        destinationIATA: flight.destination?.iata ?? "DEST",
                        destinationCity: flight.destination?.city ?? "目的地",
                        seatNumber: seatNumber,
                        gateNumber: gateNumber,
                        cabinClass: cabinClass,
                        sequenceNumber: "SEQ 018",
                        flightLevelText: flight.flightLevelText,
                        durationMinutes: effectiveDuration,
                        distanceKM: Int(flight.remainingDistanceKM),
                        realProgress: flight.realFlightProgress,
                        focusTag: selectedTag,
                        date: Date(),
                        showArrivedStamp: false
                    )

                    // Seat & Cabin Customization
                    HStack(spacing: 12) {
                        Menu {
                            ForEach(["01A (头等窗)", "02K (头等窗)", "06A (公务前排)", "12A (机翼视野)", "18K (静谧后舱)"], id: \.self) { item in
                                Button(item) {
                                    seatNumber = String(item.prefix(3))
                                }
                            }
                        } label: {
                            Label("选座: \(seatNumber)", systemImage: "airline.seat.recline.extra")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .stratoGlassCapsule()
                        }

                        Menu {
                            ForEach(branding.cabinClasses, id: \.self) { c in
                                Button(c) { cabinClass = c }
                            }
                        } label: {
                            Label(cabinClass, systemImage: "crown.fill")
                                .font(.caption.bold())
                                .foregroundStyle(branding.accentColor)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .stratoGlassCapsule()
                        }
                    }

                    // Focus Tag Picker
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FocusTag.allCases) { tag in
                                Button {
                                    selectedTag = tag
                                } label: {
                                    Label(tag.rawValue, systemImage: tag.symbol)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .stratoGlassCapsule(
                                            tint: selectedTag == tag ? branding.primaryColor.opacity(0.45) : nil
                                        )
                                }
                            }
                        }
                    }

                    // Duration sync toggle
                    VStack(spacing: 8) {
                        Toggle("同步该航班实时剩余降落时间（\(flight.estimatedRemainingMinutes) 分钟）", isOn: $syncToLiveETA)
                            .font(.subheadline)
                            .tint(StratoTheme.skyCyan)

                        if !syncToLiveETA {
                            HStack {
                                Text("自定义伴飞时长")
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
                        onTakeOff(effectiveDuration, selectedTag, seatNumber, gateNumber, cabinClass)
                    } label: {
                        Label("切入实时机位 (\(Int((flight.realFlightProgress * 100).rounded()))%) · 开始伴飞专注", systemImage: "airplane")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(branding.primaryColor)
                }
                .padding(16)
            }
            .navigationTitle("核对登机牌")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("返回") { dismiss() }
                }
            }
            .onAppear {
                customMinutes = Double(min(max(flight.estimatedRemainingMinutes, 15), 240))
                cabinClass = branding.cabinClasses.first ?? "BUSINESS · 公务舱"
            }
        }
    }
}

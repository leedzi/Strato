import SwiftUI

// MARK: - Finder

/// "Find me a flight landing in N minutes", plus the custom-route option.
struct FinderView: View {
    var startInCustomMode = false
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var mode: Mode = .live
    @State private var picking: PickTarget?
    @State private var customOrigin: Airport?
    @State private var customDestination: Airport?
    @State private var customAirline = "CCA"

    enum Mode: String, CaseIterable, Identifiable {
        case live = "真实航班"
        case custom = "自选航线"
        var id: String { rawValue }
    }

    enum PickTarget: String, Identifiable {
        case liveDestination, customOrigin, customDestination
        var id: String { rawValue }
    }

    private let presets = [15, 25, 45, 60, 90, 120, 180, 240]
    private let airlineChoices = ["CCA", "CES", "CSN", "CHH", "CPA", "ANA", "JAL", "KAL", "SIA", "UAE", "QTR", "DLH", "BAW", "AFR", "DAL", "UAL", "QFA"]

    var body: some View {
        @Bindable var model = model
        ScrollView {
            VStack(spacing: 16) {
                Picker("方式", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                durationCard

                if mode == .live {
                    liveSection
                } else {
                    customSection
                }
            }
            .padding(16)
        }
        .navigationTitle("找一班航班")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") {
                    model.cancelFinder()
                    dismiss()
                }
                .accessibilityIdentifier("finder-close")
            }
        }
        .navigationDestination(item: $model.boarding) { flight in
            BoardingView(flight: flight)
        }
        .sheet(item: $picking) { target in
            NavigationStack {
                AirportPicker(allowAny: target == .liveDestination, origin: target == .customDestination ? customOrigin : nil) { airport in
                    switch target {
                    case .liveDestination: model.finder.destination = airport
                    case .customOrigin: customOrigin = airport
                    case .customDestination: customDestination = airport
                    }
                }
            }
        }
        .onAppear {
            if startInCustomMode { mode = .custom }
            consumeQuickTakeoff()
            if customOrigin == nil { customOrigin = model.quickTakeoffRequest?.origin ?? model.homeAirport }
            if customDestination == nil {
                customDestination = model.quickTakeoffRequest?.destination
                    ?? model.reference.airport(code: customOrigin?.code == "HND" ? "PVG" : "HND")
            }
        }
        .onChange(of: model.quickTakeoffRequest?.id) { _, id in
            if id != nil { consumeQuickTakeoff() }
        }
        .onChange(of: customOrigin?.id) { _, id in
            if id == customDestination?.id { customDestination = nearbyDestinations.first }
        }
    }

    // MARK: Duration

    private func consumeQuickTakeoff() {
        guard startInCustomMode, let request = model.quickTakeoffRequest else { return }
        mode = .custom
        customOrigin = request.origin
        customDestination = request.destination
            ?? model.reference.airport(code: request.origin.code == "HND" ? "PVG" : "HND")
        model.quickTakeoffRequest = nil
    }

    private var durationCard: some View {
        @Bindable var model = model
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("专注时长").font(.headline)
                Spacer()
                Text(model.finder.isUnlimited ? (mode == .live ? "不限" : "全程") : FlightMath.durationText(minutes: model.finder.targetMinutes))
                    .font(.system(size: 22, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Palette.sky)
                    .contentTransition(.numericText())
                    .accessibilityIdentifier("finder-duration-label")
            }
            Toggle(mode == .live ? "不限时长，只找目的地" : "从出发机场飞完全程", isOn: $model.finder.isUnlimited)
                .font(.subheadline)
                .tint(Palette.sky)
                .accessibilityIdentifier("finder-unlimited")
            if !model.finder.isUnlimited {
                Slider(
                    value: Binding(get: { Double(model.finder.targetMinutes) }, set: { model.finder.targetMinutes = Int($0) }),
                    in: 10...600, step: 5
                )
                .tint(Palette.sky)
                .accessibilityIdentifier("duration-slider")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(presets, id: \.self) { m in
                        Button {
                            withAnimation(.snappy) {
                                model.finder.isUnlimited = false
                                model.finder.targetMinutes = m
                            }
                        } label: {
                            Chip(title: FlightMath.shortDuration(minutes: m), symbol: nil, selected: !model.finder.isUnlimited && model.finder.targetMinutes == m)
                        }
                        .accessibilityIdentifier("finder-preset-\(m)")
                    }
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    // MARK: Live

    private var liveSection: some View {
        VStack(spacing: 14) {
            Button {
                picking = .liveDestination
            } label: {
                HStack {
                    Label("目的地", systemImage: "mappin.and.ellipse").font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(model.finder.destination.map { "\($0.city) \($0.code)" } ?? "不限")
                        .font(.subheadline)
                        .foregroundStyle(model.finder.destination == nil ? Color.secondary : Palette.sky)
                    Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
                }
                .padding(16)
                .glassCard(cornerRadius: 18)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("pick-destination")

            Button {
                if model.finder.isSearching { model.cancelFinder() } else { model.findFlights() }
            } label: {
                HStack(spacing: 8) {
                    if model.finder.isSearching {
                        ProgressView().controlSize(.small)
                        Text(searchingText)
                    } else {
                        Image(systemName: "dot.radiowaves.left.and.right")
                        Text(model.finder.isUnlimited
                             ? model.finder.destination.map { "搜索飞往\($0.city)的航班" } ?? "搜索正在飞行的航班"
                             : "搜索 \(FlightMath.durationText(minutes: model.finder.targetMinutes))后落地的航班")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("search-flights")

            if let note = model.finder.note {
                Label(note, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if model.finder.relaxed {
                Label("没有刚好合适的，下面是最接近的几班", systemImage: "arrow.left.and.right")
                    .font(.footnote)
                    .foregroundStyle(Palette.amber)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            LazyVStack(spacing: 10) {
                ForEach(model.finder.results) { match in
                    Button {
                        model.prepareBoarding(match.flight)
                    } label: {
                        MatchRow(match: match)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("match-\(match.flight.callsign)")
                }
            }

            if model.finder.phase == .finished, !model.finder.results.isEmpty {
                Text("在 \(model.finder.scanned) 架在飞航班里找到的。落地时间按当前位置和速度估算，起降排队时会有几分钟出入。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var searchingText: String {
        switch model.finder.phase {
        case .resolving(let done, let total): return "正在核对航线 \(done)/\(total) · 点按停止"
        default: return "正在接收全球航班…"
        }
    }

    // MARK: Custom route

    private var customFullMinutes: Int? {
        guard let o = customOrigin, let d = customDestination, o.code != d.code else { return nil }
        return Int(SimFlight.fullMinutes(routeKm: Geo.distanceKm(o.point, d.point)).rounded())
    }

    private var nearbyDestinations: [Airport] {
        guard let origin = customOrigin else { return [] }
        return Array(model.reference.majorAirports
            .filter { $0.code != origin.code && Geo.distanceKm(origin.point, $0.point) > 60 }
            .sorted { Geo.distanceKm(origin.point, $0.point) < Geo.distanceKm(origin.point, $1.point) }
            .prefix(6))
    }

    private var customRequestedMinutes: Int {
        if model.finder.isUnlimited, let origin = customOrigin, let destination = customDestination {
            return Int(ceil(SimFlight.fullMinutes(routeKm: Geo.distanceKm(origin.point, destination.point))))
        }
        return model.finder.targetMinutes
    }

    private var customSection: some View {
        VStack(spacing: 14) {
            VStack(spacing: 0) {
                pickRow("出发", customOrigin) { picking = .customOrigin }
                    .accessibilityIdentifier("custom-origin")
                Divider().padding(.leading, 16)
                pickRow("到达", customDestination) { picking = .customDestination }
                    .accessibilityIdentifier("custom-destination")
                Divider().padding(.leading, 16)
                HStack {
                    Text("航司").font(.subheadline.weight(.semibold))
                    Spacer()
                    Picker("航司", selection: $customAirline) {
                        ForEach(airlineChoices, id: \.self) { code in
                            Text(model.reference.airlineName(icao: code)).tag(code)
                        }
                    }
                    .tint(Palette.sky)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .glassCard(cornerRadius: 18)

            if let origin = customOrigin, !nearbyDestinations.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("从\(origin.city)出发").font(.subheadline.weight(.semibold))
                    Text("附近目的地 · 预计全程时间").font(.caption).foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(nearbyDestinations) { airport in
                            Button {
                                customDestination = airport
                            } label: {
                                HStack(spacing: 6) {
                                    Text(airport.city).lineLimit(1)
                                    Spacer(minLength: 2)
                                    Text(FlightMath.shortDuration(minutes: Int(SimFlight.fullMinutes(routeKm: Geo.distanceKm(origin.point, airport.point)).rounded())))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(Palette.sky)
                                }
                                .font(.caption.weight(.semibold))
                                .padding(10)
                                .background(.white.opacity(customDestination?.id == airport.id ? 0.16 : 0.06), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("nearby-\(airport.code)")
                        }
                    }
                    Button("查看所有机场与预计时间") { picking = .customDestination }
                        .font(.footnote.weight(.semibold))
                        .accessibilityIdentifier("browse-route-times")
                }
                .padding(16)
                .glassCard(cornerRadius: 18)
            }

            if let full = customFullMinutes {
                let minutes = min(model.finder.targetMinutes, full)
                Text(model.finder.isUnlimited
                     ? "从\(customOrigin?.city ?? "出发机场")起飞，全程约 \(FlightMath.durationText(minutes: full))。"
                     : minutes < model.finder.targetMinutes
                     ? "这条航线全程约 \(FlightMath.durationText(minutes: full))，会从起飞开始陪你飞完全程。"
                     : "全程约 \(FlightMath.durationText(minutes: full))。会从离落地还有 \(FlightMath.durationText(minutes: minutes))的位置登机。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("custom-route-estimate")
            }

            Button {
                guard let o = customOrigin, let d = customDestination else { return }
                let flight = model.makeSimulatedFlight(origin: o, destination: d, airlineICAO: customAirline, minutes: customRequestedMinutes)
                model.prepareBoarding(flight)
            } label: {
                Label("生成登机牌", systemImage: "ticket.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .disabled(customFullMinutes == nil)
            .accessibilityIdentifier("make-custom")

            Label("自选航线是模拟飞行，不对应真实航班，登机牌和记录上都会标明。", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func pickRow(_ title: String, _ airport: Airport?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.subheadline.weight(.semibold))
                Spacer()
                Text(airport.map { "\($0.city) \($0.code)" } ?? "选择机场")
                    .font(.subheadline)
                    .foregroundStyle(Palette.sky)
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// One search result.
struct MatchRow: View {
    @Environment(AppModel.self) private var model
    var match: FlightMatch

    var body: some View {
        let flight = match.flight
        let brand = model.brand(for: flight)
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(flight.displayNumber)
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                AirlineLabel(brand: brand, name: model.airlineName(for: flight))
                Spacer()
                Text(FlightMath.durationText(minutes: match.minutesToLanding))
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Palette.sky)
            }
            if let route = flight.route {
                HStack {
                    Text("\(route.origin.city) → \(route.destination.city)")
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer()
                    if let text = deltaText {
                        Text(text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            RouteProgressBar(boarded: nil, current: match.progress.fraction, tint: brand.accentColor)
        }
        .padding(14)
        .glassCard(cornerRadius: 20)
        .contentShape(RoundedRectangle(cornerRadius: 20))
    }

    private var deltaText: String? {
        guard let d = match.deltaMinutes else { return nil }
        if d == 0 { return "刚好" }
        return d > 0 ? "多 \(d) 分钟" : "少 \(-d) 分钟"
    }
}

// MARK: - Airport picker

struct AirportPicker: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    var allowAny: Bool
    var origin: Airport? = nil
    var onPick: (Airport?) -> Void
    @State private var query = ""

    var body: some View {
        List {
            if allowAny, query.isEmpty {
                Button {
                    onPick(nil)
                    dismiss()
                } label: {
                    Label("不限目的地", systemImage: "globe.asia.australia")
                }
            }
            ForEach(airports) { airport in
                Button {
                    onPick(airport)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(airport.city).font(.body.weight(.semibold))
                            Text(airport.fullName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(airport.code)
                                .font(.system(.body, design: .monospaced).weight(.bold))
                                .foregroundStyle(Palette.sky)
                            if let origin {
                                Text("约 \(FlightMath.shortDuration(minutes: Int(SimFlight.fullMinutes(routeKm: Geo.distanceKm(origin.point, airport.point)).rounded())))")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("airport-time-\(airport.code)")
                            }
                        }
                    }
                }
                .accessibilityIdentifier("airport-\(airport.code)")
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "城市、机场或三字码")
        .navigationTitle(origin.map { "从\($0.code)出发" } ?? "选择机场")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
        }
    }

    private var airports: [Airport] {
        if let origin, query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Array(model.reference.majorAirports.filter { $0.id != origin.id }
                .sorted { Geo.distanceKm(origin.point, $0.point) < Geo.distanceKm(origin.point, $1.point) }
                .prefix(60))
        }
        return model.reference.searchAirports(query, limit: 60).filter { $0.id != origin?.id }
    }
}

// MARK: - Boarding

/// Review the pass, choose what to work on, and start.
struct BoardingView: View {
    @Environment(AppModel.self) private var model
    var flight: LiveFlight

    @State private var tag: FocusTag = .deepWork
    @State private var cabin: CabinClass = .business
    @State private var seed = Int.random(in: 0..<100_000)
    @State private var untilLanding = true
    @State private var timerMinutes = 45

    /// The freshest copy of the flight (the model refreshes its position after the sheet opens).
    private var current: LiveFlight {
        if let b = model.boarding, b.id == flight.id { return b }
        return flight
    }

    private var seat: String { Seating.windowSeat(cabin: cabin, seed: seed) }
    private var gate: String { Seating.gate(seed: seed) }

    private var minutesToLanding: Int? {
        guard let route = current.route else { return nil }
        if current.isSimulated {
            let remaining = Geo.distanceKm(current.state.point, route.destination.point)
            return Int((SimFlight.minutes(forRemainingKm: remaining) + (current.state.onGround ? 4 : 0)).rounded())
        }
        let landing = FlightMath.estimatedLanding(state: current.state, route: route)
        return max(1, Int((landing.timeIntervalSince(model.now) / 60).rounded()))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let route = current.route {
                    BoardingPassView(pass: PassData(
                        flight: current, route: route, tag: tag, seat: seat, gate: gate, cabin: cabin,
                        sequence: model.nextSequence(), model: model
                    ))
                    options
                    lengthCard
                    Button {
                        start()
                    } label: {
                        Label("登机，开始专注", systemImage: "airplane.departure")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(model.brand(for: current).primaryColor)
                    .accessibilityIdentifier("start-focus")
                } else {
                    ContentUnavailableView("航线未知", systemImage: "questionmark.circle", description: Text("没有查到这架飞机的起降机场，暂时不能登机。"))
                }
            }
            .padding(16)
        }
        .navigationTitle("登机")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            cabin = model.settings.cabin
            if let m = minutesToLanding { timerMinutes = min(max(5, model.finder.targetMinutes), max(5, m)) }
        }
    }

    private var options: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("这一程做什么").font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(FocusTag.allCases) { t in
                        Button {
                            tag = t
                        } label: {
                            Chip(title: t.title, symbol: t.symbol, selected: tag == t)
                        }
                        .accessibilityIdentifier("tag-\(t.rawValue)")
                    }
                }
            }
            HStack {
                Picker("舱位", selection: $cabin) {
                    ForEach(CabinClass.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.menu)
                .tint(Palette.sky)
                Spacer()
                Button {
                    seed = Int.random(in: 0..<100_000)
                } label: {
                    Label("换个靠窗座位", systemImage: "arrow.triangle.2.circlepath")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private var lengthCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("时长", selection: $untilLanding) {
                Text("飞到落地").tag(true)
                Text("自定时长").tag(false)
            }
            .pickerStyle(.segmented)

            if untilLanding {
                if let m = minutesToLanding, let route = current.route {
                    let landing = model.now.addingTimeInterval(Double(m) * 60)
                    Label {
                        Text("预计 \(FlightMath.durationText(minutes: m))后落地\(route.destination.city)（当地 \(Fmt.time(landing, zone: route.destination.timeZone))）。落地时间会跟着飞机实时调整，它落地，专注结束。")
                    } icon: {
                        Image(systemName: "airplane.arrival")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            } else {
                Stepper(value: $timerMinutes, in: 5...600, step: 5) {
                    Text("专注 \(FlightMath.durationText(minutes: timerMinutes))")
                        .font(.subheadline.weight(.semibold).monospacedDigit())
                }
                Text("到点就结束，飞机继续飞它的。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 22)
    }

    private func start() {
        model.board(current, tag: tag, seat: seat, cabin: cabin, gate: gate, timerMinutes: untilLanding ? nil : timerMinutes)
        if model.settings.notifications { model.enableNotifications() }
    }
}

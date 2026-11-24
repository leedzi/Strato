import SwiftUI

struct RadarScreen: View {
    @Environment(AppModel.self) private var model
    @State private var sheet: RadarSheet?
    @State private var query = ""
    @FocusState private var searching: Bool

    enum RadarSheet: Identifiable {
        case finder
        case quickTakeoff
        case boarding(LiveFlight)

        var id: String {
            switch self {
            case .finder: return "finder"
            case .quickTakeoff: return "quick-takeoff"
            case .boarding(let f): return "boarding-\(f.id)"
            }
        }
    }

    private let quickDurations = [25, 45, 60, 90, 120, 180]

    var body: some View {
        ZStack {
            if model.session == nil {
                FlightMapView(
                    provider: model.settings.mapProvider,
                    initialCenter: model.radarCenter,
                    initialRadiusKm: model.radarRadiusKm,
                    flights: model.flights + extraFocus,
                    focusID: model.focus?.id,
                    route: model.focus?.route,
                    command: model.mapCommand,
                    bottomInset: model.focus == nil ? 150 : 300,
                    clock: model.clock,
                    onSelect: { id in
                        searching = false
                        if let id { model.select(id) } else { model.clearFocus() }
                    },
                    onRegionChange: { center, radius, byUser in
                        model.mapRegionChanged(center: center, radiusKm: radius, byUser: byUser)
                    }
                )
                .ignoresSafeArea()
            } else {
                Palette.night.ignoresSafeArea()
            }

            VStack(spacing: 10) {
                topBar
                if let note = model.lookupNote ?? (model.focus == nil ? model.radarNote : nil) {
                    Text(note)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .glassPill()
                        .transition(.opacity)
                }
                Spacer(minLength: 0)
                if let flight = model.focus {
                    FlightCard(
                        flight: flight,
                        onBoard: {
                            model.prepareBoarding(flight)
                            sheet = .boarding(flight)
                        },
                        onClose: { model.clearFocus() }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    finderDeck.transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 10)
            .animation(.smooth(duration: 0.3), value: model.focus?.id)
            .animation(.smooth(duration: 0.3), value: model.radarNote)
        }
        .onAppear {
            model.radarAppeared()
            if model.quickTakeoffRequest != nil { sheet = .quickTakeoff }
        }
        .onDisappear { model.radarDisappeared() }
        .sheet(item: $sheet, onDismiss: {
            model.cancelFinder()
            model.boarding = nil
        }) { which in
            NavigationStack {
                switch which {
                case .finder:
                    FinderView()
                case .quickTakeoff:
                    FinderView(startInCustomMode: true)
                case .boarding(let flight):
                    BoardingView(flight: flight)
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(.ultraThinMaterial)
        }
        .onChange(of: model.session?.id) { _, id in
            if id != nil { sheet = nil }
        }
        .onChange(of: model.quickTakeoffRequest?.id) { _, id in
            if id != nil { sheet = .quickTakeoff }
        }
    }

    /// A flight found by number may be outside the scanned area; keep it on the map anyway.
    private var extraFocus: [LiveFlight] {
        guard let f = model.focus, !model.flights.contains(where: { $0.id == f.id }) else { return [] }
        return [f]
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("航班号，如 CA1831", text: $query)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .submitLabel(.search)
                    .focused($searching)
                    .onSubmit {
                        let text = query.trimmingCharacters(in: .whitespaces)
                        if !text.isEmpty { model.lookUp(flightNumber: text) }
                    }
                    .accessibilityIdentifier("flight-search")
                if model.isLookingUp {
                    ProgressView().controlSize(.small)
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        model.lookupNote = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .glassPill()

            Menu {
                Picker("地图", selection: Binding(get: { model.settings.mapProvider }, set: { model.settings.mapProvider = $0 })) {
                    ForEach(MapProvider.allCases) { p in
                        Label(p.title, systemImage: p.symbol).tag(p)
                    }
                }
            } label: {
                Image(systemName: "square.2.layers.3d.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .glassPill()
            }
            .accessibilityLabel("地图样式")

            Button {
                model.goToMyLocation()
            } label: {
                Image(systemName: "location.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .glassPill()
            }
            .accessibilityLabel("我头顶的航班")
        }
        .foregroundStyle(.white)
    }

    // MARK: Bottom deck (nothing selected)

    private var finderDeck: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let airport = model.homeAirport {
                HStack(spacing: 10) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.title3)
                        .foregroundStyle(Palette.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.settings.lastAirportCode == nil ? "出发机场" : "上次落地")
                            .font(.caption2).foregroundStyle(.secondary)
                        Text("\(airport.city) · \(airport.code)")
                            .font(.subheadline.weight(.semibold)).lineLimit(1)
                            .accessibilityIdentifier("home-airport")
                    }
                    Spacer(minLength: 0)
                    Button { model.requestQuickTakeoff() } label: {
                        Label("快速起飞", systemImage: "airplane.departure")
                            .font(.caption.weight(.semibold))
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.glass)
                    .accessibilityIdentifier("quick-takeoff")
                }
                Divider().overlay(.white.opacity(0.08))
            }
            HStack(alignment: .firstTextBaseline) {
                Text("想专注多久？").font(.headline)
                Spacer()
                HStack(spacing: 5) {
                    if model.isScanning { ProgressView().controlSize(.mini) }
                    Text(statusText).font(.caption).foregroundStyle(.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(quickDurations, id: \.self) { minutes in
                        Button {
                            model.finder.targetMinutes = minutes
                            model.finder.isUnlimited = false
                            model.finder.destination = nil
                            model.boarding = nil
                            sheet = .finder
                            model.findFlights()
                        } label: {
                            Chip(title: FlightMath.shortDuration(minutes: minutes), symbol: nil, selected: false)
                        }
                        .accessibilityIdentifier("quick-\(minutes)")
                    }
                }
            }
            Button {
                model.finder.targetMinutes = model.settings.finderMinutes
                model.finder.isUnlimited = model.settings.finderUnlimited
                model.boarding = nil
                sheet = .finder
            } label: {
                Label("找一班航班陪我专注", systemImage: "airplane.departure")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glassProminent)
            .accessibilityIdentifier("open-finder")
        }
        .padding(16)
        .glassCard(cornerRadius: 28)
    }

    private var statusText: String {
        if model.flights.isEmpty { return model.isScanning ? "正在接收…" : "点地图上的飞机看详情" }
        return "视野内 \(model.flights.count) 架"
    }
}

// MARK: - Flight card

/// Details of the selected aircraft.
struct FlightCard: View {
    @Environment(AppModel.self) private var model
    var flight: LiveFlight
    var onBoard: () -> Void
    var onClose: () -> Void

    var body: some View {
        let brand = model.brand(for: flight)
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(flight.displayNumber)
                        .font(.system(size: 26, weight: .heavy, design: .rounded))
                    AirlineLabel(brand: brand, name: subtitle)
                }
                Spacer()
                if let photo = model.focusPhoto {
                    AsyncImage(url: photo.image) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.white.opacity(0.08)
                    }
                    .frame(width: 92, height: 58)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(alignment: .bottomLeading) {
                        Text("© \(photo.photographer)")
                            .font(.system(size: 7, weight: .medium))
                            .padding(.horizontal, 4).padding(.vertical, 1)
                            .background(.black.opacity(0.55), in: Capsule())
                            .padding(3)
                    }
                    .accessibilityLabel("机身照片，摄影 \(photo.photographer)")
                }
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 30)
                        .background(.white.opacity(0.14), in: Circle())
                }
                .accessibilityLabel("关闭")
                .accessibilityIdentifier("card-close")
            }

            if let route = flight.route {
                routeBlock(route, brand: brand)
            } else {
                Label(flight.state.hasAirlineCallsign ? "正在查询航线…" : "这架飞机没有公开的航线信息", systemImage: "questionmark.circle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Readout(title: "高度", value: FlightMath.flightLevel(flight.state.altitudeFt), detail: Fmt.altitudeMeters(flight.state.altitudeFt))
                Readout(title: "地速", value: "\(Int(flight.state.groundSpeedKt ?? 0)) kt", detail: Fmt.speedKmh(flight.state.groundSpeedKt))
                Readout(title: "机型", value: flight.state.typeCode ?? "—", detail: flight.state.registration)
            }

            if flight.route != nil {
                HStack(spacing: 10) {
                    Button(action: onBoard) {
                        Label("登机专注", systemImage: "figure.seated.seatbelt")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(brand.primaryColor)
                    .accessibilityIdentifier("board-button")

                    Button {
                        model.showWholeRoute()
                    } label: {
                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath.fill")
                            .font(.headline)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 4)
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel("看全程航线")
                }
            }
        }
        .padding(16)
        .glassCard(cornerRadius: 28)
        .foregroundStyle(.white)
    }

    private var subtitle: String {
        let airline = model.airlineName(for: flight)
        let type = AircraftTypes.name(code: flight.state.typeCode, fallback: flight.state.typeName)
        if airline.isEmpty { return type }
        return flight.state.typeCode == nil ? airline : "\(airline) · \(type)"
    }

    private func routeBlock(_ route: FlightRoute, brand: AirlineBrand) -> some View {
        let progress = FlightMath.progress(at: flight.state.point, route: route)
        let landing = FlightMath.estimatedLanding(state: flight.state, route: route)
        let minutes = max(0, Int((landing.timeIntervalSince(model.now) / 60).rounded()))
        return VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(route.origin.code).font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(route.origin.city).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                VStack(spacing: 0) {
                    Text(flight.state.onGround ? "尚未起飞" : "约 \(FlightMath.durationText(minutes: minutes))后落地")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(brand.accentColor)
                    Text("当地 \(Fmt.time(landing, zone: route.destination.timeZone)) · 还有 \(Fmt.km(progress.remainingKm)) km")
                        .font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 0) {
                    Text(route.destination.code).font(.system(size: 22, weight: .bold, design: .rounded))
                    Text(route.destination.city).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
            }
            RouteProgressBar(boarded: nil, current: progress.fraction, tint: brand.accentColor)
        }
    }
}

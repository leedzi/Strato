import SwiftUI
import MapKit

struct RadarFocusView: View {
    @Environment(StratoStore.self) private var store

    @State private var cameraTarget: CLLocationCoordinate2D? = CLLocationCoordinate2D(latitude: 33.5, longitude: 126.5)
    @State private var cameraDistance: CLLocationDistance = 4_800_000
    @State private var cameraPitch: CGFloat = 28
    @State private var cameraHeading: CLLocationDirection = 0
    @State private var cameraTriggerID: Int = 1

    @State private var showMatcherSheet = false
    @State private var boardingCandidate: LiveFlight?
    @State private var showEarlyLandDialog = false
    @State private var showBoardingPassInspector = false
    @State private var currentMapCenter = CLLocationCoordinate2D(latitude: 33.5, longitude: 126.5)

    private var displayedFlight: LiveFlight? {
        store.activeFlight ?? store.selectedFlight
    }

    private var flightsOnMap: [LiveFlight] {
        if let active = store.activeFlight {
            return [active]
        }
        return store.filteredRadarFlights
    }

    var body: some View {
        ZStack {
            // 1. Smart Hybrid Map Layer (AutoNavi China / Google Satellite / Apple 3D Flyover)
            HybridTileMapView(
                provider: store.mapProvider,
                flights: flightsOnMap,
                focusedFlight: displayedFlight,
                activeFlightID: store.activeFlight?.id,
                cameraTarget: cameraTarget,
                cameraDistance: cameraDistance,
                cameraPitch: cameraPitch,
                cameraHeading: cameraHeading,
                cameraTriggerID: cameraTriggerID,
                onSelectFlight: { flight in
                    if !store.isFlying {
                        store.selectedFlight = flight
                        focusCamera(on: flight, mode: .follow3D)
                    }
                },
                onRegionChangedByUser: { newCenter in
                    currentMapCenter = newCenter
                }
            )
            .ignoresSafeArea()

            // 2. Top & Bottom HUD Controls (explicitly placed above map with clean hit-testing)
            VStack(spacing: 0) {
                topHUD
                    .padding(.horizontal, 14)
                    .padding(.top, 6)

                if let active = store.activeFlight, store.cockpitViewMode == .cockpitHUD {
                    cockpitPFDInstrumentOverlay(flight: active)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }

                Spacer(minLength: 12)

                if let active = store.activeFlight {
                    activeCockpitPanel(flight: active)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                } else {
                    discoveryBottomDeck
                        .padding(.bottom, 10)
                }
            }
        }
        .sheet(isPresented: $showMatcherSheet) {
            FlightMatcherSheet { chosenFlight, customMinutes in
                showMatcherSheet = false
                if let customMinutes {
                    store.targetFocusMinutes = customMinutes
                }
                boardingCandidate = chosenFlight
                focusCamera(on: chosenFlight, mode: .follow3D)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $boardingCandidate) { flight in
            BoardingPassSheet(flight: flight) { durationMinutes, tag, seat, gate, cabinClass in
                boardingCandidate = nil
                store.boardAndTakeOff(
                    flight: flight,
                    durationMinutes: durationMinutes,
                    focusTag: tag,
                    seatNumber: seat,
                    gateNumber: gate,
                    cabinClass: cabinClass
                )
                focusCamera(on: flight, mode: .follow3D, zoomedIn: true)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showBoardingPassInspector) {
            if let active = store.activeFlight {
                NavigationStack {
                    ScrollView {
                        AirlineBoardingPassCard(
                            callsign: active.callsign,
                            airlineName: active.airlineName,
                            aircraftType: active.aircraftType,
                            originIATA: active.origin?.iata ?? "LIVE",
                            originCity: active.origin?.city ?? "起点",
                            destinationIATA: active.destination?.iata ?? "DEST",
                            destinationCity: active.destination?.city ?? "目的地",
                            seatNumber: store.activeSeatNumber,
                            gateNumber: store.activeGateNumber,
                            cabinClass: store.activeCabinClass,
                            sequenceNumber: store.activeSequenceNumber,
                            flightLevelText: active.flightLevelText,
                            durationMinutes: max(1, store.remainingSeconds / 60),
                            distanceKM: Int(active.totalRouteDistanceKM),
                            realProgress: store.liveAircraftProgress,
                            focusTag: store.selectedFocusTag,
                            date: store.sessionStartedAt ?? Date(),
                            showArrivedStamp: false
                        )
                        .padding(18)
                    }
                    .navigationTitle("当前航班登机牌")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("完成") { showBoardingPassInspector = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
        }
        .confirmationDialog("提前结束本次航程？", isPresented: $showEarlyLandDialog, titleVisibility: .visible) {
            Button("保存已专注航段并盖章降落") {
                store.landEarly(saveToLogbook: true)
            }
            Button("放弃本次航程", role: .destructive) {
                store.landEarly(saveToLogbook: false)
            }
            Button("继续平流层巡航", role: .cancel) {}
        } message: {
            Text("保存后将按当前已伴飞时长生成对应航司登机牌并计入专注数据分析。")
        }
    }

    // MARK: - Top HUD Bar

    private var topHUD: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Status Pill
                HStack(spacing: 8) {
                    Circle()
                        .fill(store.isFlying ? StratoTheme.radarEmerald : StratoTheme.skyCyan)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.isFlying ? "IN FLIGHT · 实时伴飞" : store.selectedScope.rawValue)
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(store.isFlying ? (store.activeFlight?.phase.rawValue ?? "巡航中") : store.radarStatusMessage)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .stratoGlassCapsule()

                Spacer()

                // Smart Map Source Switcher Menu (AutoNavi / Google / Apple 3D)
                Menu {
                    Picker("地图引擎", selection: Binding(
                        get: { store.mapProvider },
                        set: { store.mapProvider = $0 }
                    )) {
                        ForEach(StratoMapProvider.allCases) { provider in
                            Label(provider.title, systemImage: provider == .apple3DFlyover ? "globe.asia.australia.fill" : "map.fill")
                                .tag(provider)
                        }
                    }

                    if !store.isFlying {
                        Divider()
                        Button {
                            Task { await store.refreshRadar(customCenter: currentMapCenter) }
                        } label: {
                            Label("扫描当前地图中心空域 (250NM)", systemImage: "dot.radiowaves.left.and.right")
                        }
                        Picker("默认扫描范围", selection: Binding(
                            get: { store.selectedScope },
                            set: { newScope in
                                store.selectedScope = newScope
                                Task { await store.refreshRadar() }
                            }
                        )) {
                            ForEach(RadarScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: store.mapProvider == .apple3DFlyover ? "globe.asia.australia.fill" : "map.fill")
                        Text(store.mapProvider.shortTitle)
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .stratoGlassCapsule(tint: StratoTheme.skyCyan.opacity(0.22))
                }

                if !store.isFlying {
                    Button {
                        Task { await store.refreshRadar() }
                    } label: {
                        Group {
                            if store.isLoadingRadar {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline.bold())
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .stratoGlassCapsule()
                    }
                }
            }

            // Search & Quick Duration Matcher Bar (when browsing radar)
            if !store.isFlying {
                HStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("搜航班号 / 城市 / 机场 (如 ANA, PVG, 东京)", text: Binding(
                            get: { store.searchText },
                            set: { store.searchText = $0 }
                        ))
                        .font(.caption)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        if !store.searchText.isEmpty {
                            Button {
                                store.searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .stratoGlassCapsule()

                    Button {
                        showMatcherSheet = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "scope")
                            Text("推 \(formatDurationShort(store.targetFocusMinutes)) 航班")
                        }
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .stratoGlassCapsule(tint: StratoTheme.skyCyan.opacity(0.3))
                    }
                }
            }
        }
    }

    // MARK: - Cockpit PFD Attitude & Telemetry Overlay

    private func cockpitPFDInstrumentOverlay(flight: LiveFlight) -> some View {
        VStack(spacing: 12) {
            HStack {
                Label("PRIMARY FLIGHT DISPLAY · 驾驶舱主飞仪表", systemImage: "gauge.with.dots.needle.67percent")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(StratoTheme.skyCyan)
                Spacer()
                Text("SQUAWK \(flight.squawk ?? "2341")")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(StratoTheme.radarEmerald)
            }

            HStack(spacing: 14) {
                // Speed Tape
                VStack(alignment: .leading, spacing: 4) {
                    Text("SPEED")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("\(Int(flight.groundSpeedKnots)) KT")
                        .font(.title3.monospaced().bold())
                        .foregroundStyle(StratoTheme.skyCyan)
                    Text("IAS \(flight.indicatedAirspeedKnots ?? Int(flight.groundSpeedKnots * 0.62)) · \(flight.machText)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Artificial Horizon / Heading Indicator
                ZStack {
                    Circle()
                        .stroke(StratoTheme.skyCyan.opacity(0.45), lineWidth: 1.5)
                        .frame(width: 68, height: 68)
                    Rectangle()
                        .fill(StratoTheme.radarEmerald)
                        .frame(width: 44, height: 2)
                        .rotationEffect(.degrees(flight.rollDegrees ?? 0))
                    VStack(spacing: 2) {
                        Text(String(format: "HDG %03d°", Int(flight.trackDegrees)))
                            .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                        Text(String(format: "ROLL %.1f°", flight.rollDegrees ?? 0.0))
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                // Altitude Tape
                VStack(alignment: .trailing, spacing: 4) {
                    Text("ALTITUDE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(flight.flightLevelText)
                        .font(.title3.monospaced().bold())
                        .foregroundStyle(StratoTheme.radarEmerald)
                    Text("V/S \(flight.verticalRateText)")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(14)
        .stratoGlassCard(cornerRadius: 22)
    }

    // MARK: - Discovery Deck (Before Takeoff)

    private var discoveryBottomDeck: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Quick Duration Filter Chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach([30, 60, 90, 120, 180, 240], id: \.self) { mins in
                        Button {
                            store.targetFocusMinutes = mins
                            Task { await store.matchFlightsForDuration() }
                        } label: {
                            Text("剩 \(formatDurationShort(mins)) 降落")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .stratoGlassCapsule(
                                    tint: store.targetFocusMinutes == mins ? StratoTheme.skyCyan.opacity(0.35) : nil
                                )
                        }
                    }

                    Button {
                        showMatcherSheet = true
                    } label: {
                        Label("自选航线/目的地", systemImage: "slider.horizontal.3")
                            .font(.caption.bold())
                            .foregroundStyle(StratoTheme.amberBeacon)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .stratoGlassCapsule()
                    }
                }
                .padding(.horizontal, 14)
            }

            // Recommended Live Flights Carousel
            let displayList = store.searchText.isEmpty ? store.recommendedFlights : store.filteredRadarFlights
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(displayList.prefix(20)) { flight in
                        FlightDiscoveryCard(
                            flight: flight,
                            isSelected: store.selectedFlight?.id == flight.id,
                            onSelect: {
                                store.selectedFlight = flight
                                focusCamera(on: flight, mode: .follow3D)
                            },
                            onBoard: {
                                store.selectedFlight = flight
                                boardingCandidate = flight
                            }
                        )
                    }
                }
                .padding(.horizontal, 14)
            }
        }
    }

    // MARK: - Active Focus Cockpit HUD (100% Responsive Buttons + Real Flight Progress!)

    private func activeCockpitPanel(flight: LiveFlight) -> some View {
        let branding = AirlineThemeRegistry.branding(forCallsign: flight.callsign, fallbackName: flight.airlineName)
        let realPct = Int((store.liveAircraftProgress * 100).rounded())
        let boardedPct = Int((store.boardedAtFlightProgress * 100).rounded())

        return VStack(spacing: 12) {
            // 1. Top Airline Header & Live Countdown
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(branding.primaryColor)
                            .frame(width: 10, height: 10)
                        Text(flight.displayCallsign)
                            .font(.headline.monospaced().bold())
                        Text(flight.airlineName)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(branding.accentColor)
                            .lineLimit(1)
                    }
                    Text("\(flight.origin?.iata ?? "LIVE") \(flight.origin?.city ?? "") → \(flight.destination?.iata ?? "DEST") \(flight.destination?.city ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.formattedRemainingTime)
                        .font(.system(size: 27, weight: .black, design: .monospaced))
                        .contentTransition(.numericText())
                    Text("\(store.activeSeatNumber) · \(store.selectedFocusTag.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // 2. Real-World Aircraft Route Progress Track (Shows Pre-Boarded + Live Accompanied Segment!)
            VStack(spacing: 4) {
                HStack {
                    Text("登机切入点 \(boardedPct)%")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(StratoTheme.amberBeacon)
                    Spacer()
                    Text("航班真实总进度 \(realPct)% · 剩余 \(Int(flight.remainingDistanceKM)) km")
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(StratoTheme.skyCyan)
                }

                GeometryReader { geo in
                    let w = geo.size.width
                    let boardX = w * store.boardedAtFlightProgress
                    let currentX = w * store.liveAircraftProgress

                    ZStack(alignment: .leading) {
                        // Full route track
                        Capsule()
                            .fill(.white.opacity(0.15))
                            .frame(height: 6)

                        // Segment already flown by the aircraft BEFORE user boarded
                        Capsule()
                            .fill(.white.opacity(0.32))
                            .frame(width: max(6, boardX), height: 6)

                        // Segment accompanied by the user's active focus session
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [StratoTheme.amberBeacon, StratoTheme.skyCyan, StratoTheme.radarEmerald],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(6, currentX - boardX), height: 6)
                            .offset(x: boardX)

                        // Boarding anchor pin
                        Circle()
                            .fill(StratoTheme.amberBeacon)
                            .frame(width: 9, height: 9)
                            .offset(x: max(0, min(w - 9, boardX - 4.5)))

                        // Live aircraft position icon
                        Image(systemName: "airplane")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(x: max(0, min(w - 14, currentX - 7)))
                    }
                }
                .frame(height: 16)
            }

            // 3. Telemetry Strip
            HStack(spacing: 14) {
                telemetryBadge(label: "ALT", value: flight.flightLevelText)
                telemetryBadge(label: "GS", value: "\(Int(flight.groundSpeedKnots)) kt")
                telemetryBadge(label: "MACH", value: flight.machText)
                telemetryBadge(label: "TYPE", value: flight.aircraftType)
                Spacer()
                Button {
                    showBoardingPassInspector = true
                } label: {
                    Label("登机牌", systemImage: "ticket.fill")
                        .font(.caption.bold())
                        .foregroundStyle(branding.accentColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.white.opacity(0.1), in: Capsule())
                }
            }

            Divider().overlay(.white.opacity(0.15))

            // 4. Direct High-Response Action Buttons (No gesture-blocking wrappers!)
            HStack(spacing: 10) {
                // Camera / PFD View Mode Switcher
                Button {
                    let modes = CockpitViewMode.allCases
                    let idx = modes.firstIndex(of: store.cockpitViewMode) ?? 0
                    let next = modes[(idx + 1) % modes.count]
                    store.cockpitViewMode = next
                    focusCamera(on: flight, mode: next, zoomedIn: true)
                } label: {
                    Label(store.cockpitViewMode.rawValue, systemImage: "camera.viewfinder")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(.white.opacity(0.12), in: Capsule())
                }

                // Multi-mode Ambient Audio Button
                Menu {
                    ForEach(CabinAudioPreset.allCases) { preset in
                        Button {
                            store.setCabinAudio(preset)
                        } label: {
                            Label(
                                preset.rawValue,
                                systemImage: store.audioPreset == preset ? "checkmark.circle.fill" : preset.symbolName
                            )
                        }
                    }
                } label: {
                    Label(
                        store.audioPreset == .off ? "环境音" : store.audioPreset.rawValue,
                        systemImage: store.audioPreset.symbolName
                    )
                    .font(.caption.bold())
                    .lineLimit(1)
                    .foregroundStyle(store.audioPreset == .off ? .white : StratoTheme.skyCyan)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        (store.audioPreset == .off ? Color.white.opacity(0.12) : StratoTheme.skyCyan.opacity(0.24)),
                        in: Capsule()
                    )
                }

                // Pause / Resume Button
                Button {
                    store.togglePause()
                } label: {
                    Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .frame(width: 42, height: 38)
                        .background(
                            store.isPaused ? StratoTheme.radarEmerald.opacity(0.35) : Color.white.opacity(0.14),
                            in: Capsule()
                        )
                }

                // Land Early / Complete Button
                Button {
                    showEarlyLandDialog = true
                } label: {
                    Image(systemName: "airplane.arrival")
                        .font(.subheadline.bold())
                        .foregroundStyle(StratoTheme.amberBeacon)
                        .frame(width: 42, height: 38)
                        .background(StratoTheme.amberBeacon.opacity(0.2), in: Capsule())
                }
            }
        }
        .padding(16)
        .stratoGlassCard(cornerRadius: 28)
    }

    private func telemetryBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().bold())
        }
    }

    private func focusCamera(on flight: LiveFlight, mode: CockpitViewMode, zoomedIn: Bool = false) {
        switch mode {
        case .follow3D, .cockpitHUD:
            cameraTarget = flight.coordinate
            cameraDistance = zoomedIn ? 780_000 : 2_200_000
            cameraPitch = zoomedIn ? 48 : 30
            cameraHeading = zoomedIn ? flight.trackDegrees : 0
        case .fullRoute:
            if let orig = flight.origin, let dest = flight.destination {
                cameraTarget = GreatCircle.interpolate(from: orig.coordinate, to: dest.coordinate, fraction: 0.5)
                let routeKM = GreatCircle.distanceKM(from: orig.coordinate, to: dest.coordinate)
                cameraDistance = max(1_400_000, routeKM * 1450)
                cameraPitch = 15
                cameraHeading = 0
            } else {
                cameraTarget = flight.coordinate
                cameraDistance = 2_600_000
                cameraPitch = 20
                cameraHeading = 0
            }
        }
        cameraTriggerID &+= 1
    }

    private func formatDurationShort(_ minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h)h" : "\(h)h\(m)m"
        }
        return "\(minutes)m"
    }
}

// MARK: - Discovery Flight Card with Airline Livery Accent

private struct FlightDiscoveryCard: View {
    let flight: LiveFlight
    let isSelected: Bool
    let onSelect: () -> Void
    let onBoard: () -> Void

    private var branding: AirlineBranding {
        AirlineThemeRegistry.branding(forCallsign: flight.callsign, fallbackName: flight.airlineName)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            // Airline Livery Top Bar
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(branding.primaryColor)
                        .frame(width: 8, height: 8)
                    Text(flight.callsign)
                        .font(.subheadline.monospaced().bold())
                    Text(branding.nameCN)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(branding.accentColor)
                        .lineLimit(1)
                }
                Spacer()
                Text("剩 \(flight.estimatedRemainingMinutes)m")
                    .font(.caption.monospacedDigit().bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(StratoTheme.skyCyan.opacity(0.22), in: Capsule())
                    .foregroundStyle(StratoTheme.skyCyan)
            }

            // Route & Real Progress
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(flight.origin?.iata ?? "LIVE")
                        .font(.title3.bold().monospaced())
                    Text(flight.origin?.city ?? "起点")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(spacing: 2) {
                    Image(systemName: "airplane")
                        .font(.caption)
                        .foregroundStyle(branding.accentColor)
                    Text("已飞 \(Int((flight.realFlightProgress * 100).rounded()))%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(flight.destination?.iata ?? "DEST")
                        .font(.title3.bold().monospaced())
                    Text(flight.destination?.city ?? "目的地")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            // Real progress bar
            ProgressView(value: flight.realFlightProgress)
                .tint(branding.accentColor)

            HStack {
                Text("\(flight.aircraftType) · \(flight.flightLevelText) · \(Int(flight.groundSpeedKnots))kt")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("登机伴飞", action: onBoard)
                    .font(.caption.bold())
                    .buttonStyle(.glassProminent)
                    .tint(branding.primaryColor)
            }
        }
        .padding(14)
        .frame(width: 262)
        .stratoGlassCard(
            cornerRadius: 24,
            tint: isSelected ? branding.primaryColor.opacity(0.26) : nil
        )
        .onTapGesture(perform: onSelect)
    }
}

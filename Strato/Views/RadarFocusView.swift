import SwiftUI
import MapKit

struct RadarFocusView: View {
    @Environment(StratoStore.self) private var store
    @State private var cameraPosition: MapCameraPosition = .camera(
        MapCamera(
            centerCoordinate: CLLocationCoordinate2D(latitude: 33.5, longitude: 126.5),
            distance: 4_200_000,
            heading: 0,
            pitch: 28
        )
    )
    @State private var showMatcherSheet = false
    @State private var boardingCandidate: LiveFlight?
    @State private var showEarlyLandAlert = false

    private var displayedFlight: LiveFlight? {
        store.activeFlight ?? store.selectedFlight
    }

    var body: some View {
        ZStack {
            radarMapLayer
                .ignoresSafeArea()

            VStack(spacing: 0) {
                topLiquidGlassHUD
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer()

                if let active = store.activeFlight {
                    activeCockpitHUD(flight: active)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    discoveryDeckHUD
                        .padding(.bottom, 12)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: store.isFlying)
        .sheet(isPresented: $showMatcherSheet) {
            FlightMatcherSheet { chosenFlight, customMinutes in
                showMatcherSheet = false
                if let customMinutes {
                    store.targetFocusMinutes = customMinutes
                }
                boardingCandidate = chosenFlight
                focusCamera(on: chosenFlight)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $boardingCandidate) { flight in
            BoardingPassSheet(flight: flight) { durationMinutes, tag, seat in
                boardingCandidate = nil
                store.boardAndTakeOff(
                    flight: flight,
                    durationMinutes: durationMinutes,
                    focusTag: tag,
                    seatNumber: seat
                )
                focusCamera(on: flight, zoomedIn: true)
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("提前结束本次航程？", isPresented: $showEarlyLandAlert) {
            Button("保存已专注记录并降落") {
                store.landEarly(saveToLogbook: true)
            }
            Button("放弃本次记录", role: .destructive) {
                store.landEarly(saveToLogbook: false)
            }
            Button("继续巡航", role: .cancel) {}
        } message: {
            Text("你已经专注飞行了一段时间，要将它盖章记入飞行护照吗？")
        }
    }

    // MARK: - Map Layer

    private var radarMapLayer: some View {
        Map(position: $cameraPosition) {
            // Draw glowing great-circle route for the active or selected flight
            if let focused = displayedFlight, let dest = focused.destination {
                if let orig = focused.origin {
                    let flownArc = GreatCircle.arcCoordinates(from: orig.coordinate, to: focused.coordinate, segments: 28)
                    MapPolyline(coordinates: flownArc)
                        .stroke(StratoTheme.skyCyan.opacity(0.9), lineWidth: 3)

                    Annotation(orig.iata, coordinate: orig.coordinate) {
                        AirportPinView(code: orig.iata, isDestination: false)
                    }
                }

                let remainingArc = GreatCircle.arcCoordinates(from: focused.coordinate, to: dest.coordinate, segments: 32)
                MapPolyline(coordinates: remainingArc)
                    .stroke(
                        .white.opacity(0.55),
                        style: StrokeStyle(lineWidth: 2, dash: [6, 5])
                    )

                Annotation(dest.iata, coordinate: dest.coordinate) {
                    AirportPinView(code: dest.iata, isDestination: true)
                }
            }

            // Render live aircraft markers
            let flightsToRender = store.activeFlight.map { [$0] } ?? store.radarFlights
            ForEach(flightsToRender) { flight in
                let isSelected = flight.id == displayedFlight?.id
                Annotation("", coordinate: flight.coordinate, anchor: .center) {
                    Button {
                        if !store.isFlying {
                            store.selectedFlight = flight
                            focusCamera(on: flight)
                        }
                    } label: {
                        AircraftMarkerView(
                            flight: flight,
                            isSelected: isSelected,
                            isActive: store.activeFlight?.id == flight.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(store.mapStyleOption.mapStyle)
        .mapControls {
            MapCompass()
            MapScaleView()
        }
    }

    // MARK: - Top Liquid Glass HUD

    private var topLiquidGlassHUD: some View {
        GlassEffectContainer(spacing: 10) {
            HStack(spacing: 10) {
                // Live Radar Pill
                HStack(spacing: 8) {
                    Circle()
                        .fill(store.isFlying ? StratoTheme.radarEmerald : StratoTheme.skyCyan)
                        .frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(store.isFlying ? "STRATO LIVE" : store.selectedRegion.rawValue)
                            .font(.caption2.bold().monospaced())
                            .foregroundStyle(.secondary)
                        Text(store.isFlying ? (store.activeFlight?.phase.rawValue ?? "巡航中") : store.radarStatusMessage)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .stratoGlassCapsule(interactive: false)

                Spacer()

                if !store.isFlying {
                    // Quick duration matcher trigger
                    Button {
                        showMatcherSheet = true
                    } label: {
                        Label("专注 \(formatDurationShort(store.targetFocusMinutes))", systemImage: "scope")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                    .stratoGlassCapsule(interactive: true, tint: StratoTheme.skyCyan.opacity(0.22))

                    // Refresh radar
                    Button {
                        Task { await store.refreshRadar() }
                    } label: {
                        Group {
                            if store.isLoadingRadar {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Image(systemName: "arrow.clockwise")
                                    .font(.subheadline.weight(.semibold))
                            }
                        }
                        .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .stratoGlassCapsule(interactive: true)
                } else {
                    // Re-center on active plane
                    Button {
                        if let active = store.activeFlight {
                            focusCamera(on: active, zoomedIn: true)
                        }
                    } label: {
                        Image(systemName: "location.fill")
                            .font(.subheadline.weight(.semibold))
                            .frame(width: 40, height: 40)
                    }
                    .buttonStyle(.plain)
                    .stratoGlassCapsule(interactive: true)
                }
            }
        }
    }

    // MARK: - Discovery Deck (Before Takeoff)

    private var discoveryDeckHUD: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("推荐伴飞航班 · 约 \(formatDurationShort(store.targetFocusMinutes)) 后降落")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .stratoGlassCapsule(interactive: false)

                Spacer()

                Button {
                    showMatcherSheet = true
                } label: {
                    Label("自选目的地", systemImage: "slider.horizontal.3")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)
                .stratoGlassCapsule(interactive: true)
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.recommendedFlights.prefix(10)) { flight in
                        FlightDiscoveryCard(
                            flight: flight,
                            isSelected: store.selectedFlight?.id == flight.id,
                            onSelect: {
                                store.selectedFlight = flight
                                focusCamera(on: flight)
                            },
                            onBoard: {
                                store.selectedFlight = flight
                                boardingCandidate = flight
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Active Focus Cockpit HUD

    private func activeCockpitHUD(flight: LiveFlight) -> some View {
        VStack(spacing: 14) {
            // Header: Callsign + Route + Countdown
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(flight.callsign)
                            .font(.headline.monospaced().bold())
                        Text(flight.isLiveADSB ? "LIVE ADS-B" : "SIM")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                (flight.isLiveADSB ? StratoTheme.radarEmerald : StratoTheme.amberBeacon).opacity(0.22),
                                in: Capsule()
                            )
                            .foregroundStyle(flight.isLiveADSB ? StratoTheme.radarEmerald : StratoTheme.amberBeacon)
                    }
                    Text("\(flight.origin?.iata ?? "LIVE") \(flight.origin?.city ?? "") → \(flight.destination?.iata ?? "DEST") \(flight.destination?.city ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text(store.formattedRemainingTime)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .contentTransition(.numericText())
                    Text("座位 \(store.activeSeatNumber) · \(store.selectedFocusTag.rawValue)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Progress Track
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.16))
                        .frame(height: 5)

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [StratoTheme.skyCyan, StratoTheme.radarEmerald],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(12, geo.size.width * store.sessionProgress), height: 5)

                    Image(systemName: "airplane")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .offset(x: max(0, min(geo.size.width - 16, geo.size.width * store.sessionProgress - 8)))
                }
            }
            .frame(height: 16)

            // Telemetry Strip + Controls
            HStack(spacing: 12) {
                telemetryBadge(label: "ALT", value: flight.flightLevelText)
                telemetryBadge(label: "GS", value: "\(Int(flight.groundSpeedKnots)) kt")
                telemetryBadge(label: "DIST", value: "\(Int(flight.remainingDistanceKM)) km")

                Spacer()

                GlassEffectContainer(spacing: 8) {
                    HStack(spacing: 8) {
                        Button {
                            store.toggleCabinSound()
                        } label: {
                            Image(systemName: store.isCabinSoundOn ? "waveform.circle.fill" : "waveform.circle")
                                .font(.title3)
                                .foregroundStyle(store.isCabinSoundOn ? StratoTheme.skyCyan : .primary)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .stratoGlassCapsule(interactive: true)

                        Button {
                            store.togglePause()
                        } label: {
                            Image(systemName: store.isPaused ? "play.fill" : "pause.fill")
                                .font(.subheadline.bold())
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .stratoGlassCapsule(interactive: true)

                        Button {
                            showEarlyLandAlert = true
                        } label: {
                            Image(systemName: "airplane.arrival")
                                .font(.subheadline.bold())
                                .foregroundStyle(StratoTheme.amberBeacon)
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(.plain)
                        .stratoGlassCapsule(interactive: true)
                    }
                }
            }
        }
        .padding(18)
        .stratoGlassCard(cornerRadius: 28)
    }

    private func telemetryBadge(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().bold())
        }
    }

    private func focusCamera(on flight: LiveFlight, zoomedIn: Bool = false) {
        withAnimation(.easeInOut(duration: 0.9)) {
            cameraPosition = .camera(
                MapCamera(
                    centerCoordinate: flight.coordinate,
                    distance: zoomedIn ? 950_000 : 2_600_000,
                    heading: 0,
                    pitch: zoomedIn ? 42 : 26
                )
            )
        }
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

// MARK: - Map Annotations & Cards

private struct AircraftMarkerView: View {
    let flight: LiveFlight
    let isSelected: Bool
    let isActive: Bool

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                if isSelected || isActive {
                    Circle()
                        .fill((isActive ? StratoTheme.radarEmerald : StratoTheme.skyCyan).opacity(0.28))
                        .frame(width: 38, height: 38)
                }
                Image(systemName: "airplane")
                    .font(.system(size: isSelected || isActive ? 18 : 13, weight: .bold))
                    .foregroundStyle(isActive ? StratoTheme.radarEmerald : (isSelected ? StratoTheme.skyCyan : .white))
                    .rotationEffect(.degrees(flight.trackDegrees - 90))
                    .shadow(color: .black.opacity(0.6), radius: 4, y: 2)
            }

            if isSelected || isActive {
                Text(flight.callsign)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.black.opacity(0.65), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
    }
}

private struct AirportPinView: View {
    let code: String
    let isDestination: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isDestination ? StratoTheme.radarEmerald : StratoTheme.skyCyan)
                .frame(width: 7, height: 7)
            Text(code)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(.black.opacity(0.68), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.25), lineWidth: 0.7))
    }
}

private struct FlightDiscoveryCard: View {
    let flight: LiveFlight
    let isSelected: Bool
    let onSelect: () -> Void
    let onBoard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(flight.callsign)
                        .font(.headline.monospaced().bold())
                    Text("\(flight.airlineName) · \(flight.aircraftType)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("约 \(flight.estimatedRemainingMinutes)m")
                    .font(.caption.monospacedDigit().bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(StratoTheme.skyCyan.opacity(0.22), in: Capsule())
                    .foregroundStyle(StratoTheme.skyCyan)
            }

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(flight.origin?.iata ?? "LIVE")
                    .font(.title3.bold().monospaced())
                Image(systemName: "airplane")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(flight.destination?.iata ?? "DEST")
                    .font(.title3.bold().monospaced())
                Spacer()
                Text(flight.flightLevelText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text(flight.destination?.city ?? "实时追踪")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("登机专注", action: onBoard)
                    .font(.caption.bold())
                    .buttonStyle(.glassProminent)
                    .tint(StratoTheme.skyCyan)
            }
        }
        .padding(14)
        .frame(width: 248)
        .stratoGlassCard(
            cornerRadius: 24,
            interactive: true,
            tint: isSelected ? StratoTheme.skyCyan.opacity(0.16) : nil
        )
        .onTapGesture(perform: onSelect)
    }
}

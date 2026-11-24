import SwiftUI
import UIKit

private enum FlightPerspective: String, CaseIterable {
    case map
    case window

    var title: String { self == .map ? "地图" : "舷窗" }
    var symbol: String { self == .map ? "map.fill" : "rectangle.portrait" }
    var accessibilityID: String { self == .map ? "flight-view-map" : "flight-view-window" }
}

/// The screen shown while a focus session is running.
struct FlightScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showPass = false
    @State private var confirmEnd = false
    @State private var perspective = FlightPerspective.map
    @State private var googleAccess = GoogleSceneAccess.shared
    @State private var showGoogle3D = false

    var body: some View {
        if let session = model.session {
            content(session)
        }
    }

    private func content(_ s: FocusSession) -> some View {
        let brand = model.brand(for: s.flight)
        return GeometryReader { geometry in
            let size = geometry.size
            let wide = size.width > 520 && size.width > size.height * 1.12
            let sideWidth = min(370, size.width * 0.43)
            ZStack {
                flightBackground(s, size: size, wide: wide, sideWidth: sideWidth)

                if perspective == .map {
                    // Keeps the top controls readable over bright imagery.
                    LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 150)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                }

                if wide {
                    wideLayout(s, brand: brand, sideWidth: sideWidth)
                } else {
                    portraitLayout(s, brand: brand, size: size)
                }

                if showPass {
                    passOverlay(s)
                }
            }
            .animation(.smooth(duration: 0.35), value: model.announcement)
        }
        .foregroundStyle(.white)
        .background(Palette.night)
        .confirmationDialog("结束这趟航程？", isPresented: $confirmEnd, titleVisibility: .visible) {
            Button("保存并下机") { model.endEarly(save: true) }
            Button("不保存，直接结束", role: .destructive) { model.endEarly(save: false) }
            Button("继续飞", role: .cancel) {}
        } message: {
            Text("保存后，已经专注的这一段会记进护照。不足一分钟的不会记录。")
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = model.settings.keepAwake }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        .onAppear { googleAccess.refreshConfiguration() }
        .sheet(isPresented: $showGoogle3D) {
            GoogleFlightScene()
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func flightBackground(_ s: FocusSession, size: CGSize, wide: Bool, sideWidth: CGFloat) -> some View {
        if perspective == .map {
            FlightMapView(
                provider: model.settings.mapProvider,
                initialCenter: s.flight.state.point,
                initialRadiusKm: 260,
                flights: [s.flight],
                focusID: s.flight.id,
                route: s.route,
                trail: s.track.map { $0.point },
                command: model.mapCommand,
                follow: true,
                bottomInset: wide ? 24 : 380,
                clock: model.clock
            )
            .frame(width: wide ? max(120, size.width - sideWidth - 42) : size.width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .ignoresSafeArea()
        } else {
            LinearGradient(colors: [Palette.night, Palette.dusk, Palette.night], startPoint: .topLeading, endPoint: .bottomTrailing)
                .ignoresSafeArea()
        }
    }

    private func portraitLayout(_ s: FocusSession, brand: AirlineBrand, size: CGSize) -> some View {
        VStack(spacing: 10) {
            topBar(s, brand: brand)
            viewControls(s)
            announcement(compact: perspective == .window)

            if size.height < 460 || (perspective == .window && size.height < 610) {
                ScrollView {
                    VStack(spacing: 12) {
                        if perspective == .window {
                            cabinWindow(s).frame(height: 200)
                        }
                        livePanel(s, brand: brand, compact: true)
                    }
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
            } else {
                if perspective == .window {
                    cabinWindow(s)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }

                if size.height < 610 {
                    ScrollView {
                        livePanel(s, brand: brand, compact: true)
                    }
                    .scrollIndicators(.hidden)
                    .frame(height: max(196, size.height * 0.46))
                } else {
                    livePanel(s, brand: brand, compact: perspective == .window)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func wideLayout(_ s: FocusSession, brand: AirlineBrand, sideWidth: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 10) {
                topBar(s, brand: brand)
                viewControls(s)
                announcement(compact: perspective == .window)
                if perspective == .window {
                    cabinWindow(s)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Spacer(minLength: 0)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            ScrollView {
                livePanel(s, brand: brand, compact: perspective == .window)
            }
            .scrollIndicators(.hidden)
            .frame(width: sideWidth)
            .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 8)
    }

    private func viewControls(_ s: FocusSession) -> some View {
        HStack(spacing: 8) {
            perspectiveSelector
            if googleAccess.canOpenScene && GoogleFlightScene.isSupportedLocation(s.position(at: model.now)) {
                Button { showGoogle3D = true } label: {
                    Label("3D", systemImage: "globe")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .glassPill()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Google 3D 外景")
                .accessibilityIdentifier("flight-google3d-button")
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var perspectiveSelector: some View {
        HStack(spacing: 4) {
            ForEach(FlightPerspective.allCases, id: \.self) { item in
                let selected = perspective == item
                Button {
                    withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.25)) {
                        perspective = item
                    }
                } label: {
                    Label(item.title, systemImage: item.symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(selected ? Color.white : Color.white.opacity(0.65))
                        .padding(.horizontal, 16)
                        .frame(height: 34)
                        .background(selected ? Color.white.opacity(0.16) : Color.clear, in: Capsule())
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.title)
                .accessibilityAddTraits(selected ? .isSelected : [])
                .accessibilityIdentifier(item.accessibilityID)
            }
        }
        .padding(4)
        .glassPill()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("flight-view-selector")
    }

    @ViewBuilder
    private func announcement(compact: Bool) -> some View {
        if let text = model.announcement {
            Label(text, systemImage: "bell.fill")
                .font(compact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                .lineLimit(compact ? 2 : 3)
                .padding(.horizontal, 16)
                .padding(.vertical, compact ? 8 : 10)
                .glassPill(tint: Palette.amber.opacity(0.35))
                .transition(.move(edge: .top).combined(with: .opacity))
                .accessibilityIdentifier("announcement")
        }
    }

    private func cabinWindow(_ s: FocusSession) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let now = model.now
            CabinWindowView(cabin: s.cabin, state: s.flight.state, position: s.position(at: now), date: now)
        }
    }

    private func livePanel(_ s: FocusSession, brand: AirlineBrand, compact: Bool) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            panel(s, brand: brand, now: model.now, compact: compact)
        }
    }

    // MARK: Top bar

    private func topBar(_ s: FocusSession, brand: AirlineBrand) -> some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                Circle()
                    .fill(s.isPaused ? Palette.amber : (s.signalLost ? Palette.coral : Palette.mint))
                    .frame(width: 8, height: 8)
                VStack(alignment: .leading, spacing: 0) {
                    Text(statusTitle(s))
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                    Text("\(s.flight.displayNumber) · \(model.airlineName(for: s.flight))")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 14)
            .frame(height: 46)
            .glassPill()

            Spacer(minLength: 0)

            Button {
                withAnimation(.smooth(duration: 0.3)) { showPass = true }
            } label: {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 46, height: 46)
                    .glassPill(tint: brand.primaryColor.opacity(0.4))
            }
            .accessibilityLabel("登机牌")
            .accessibilityIdentifier("show-pass")
        }
    }

    private func statusTitle(_ s: FocusSession) -> String {
        if s.isPaused { return "已暂停" }
        if s.flight.isSimulated { return "模拟航班" }
        if s.signalLost { return "信号中断 · 按航迹推算" }
        return "实时跟踪中"
    }

    // MARK: Panel

    private func panel(_ s: FocusSession, brand: AirlineBrand, now: Date, compact: Bool) -> some View {
        let progress = s.progress(at: now)
        let state = s.flight.state
        let end = s.plannedEnd(at: now)
        let sky = Solar.sky(at: s.position(at: now), date: now)
        return VStack(spacing: compact ? 10 : 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.followsLanding ? "距落地" : "专注剩余")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(Fmt.countdown(s.remainingSeconds(at: now)))
                        .font(.system(size: compact ? 36 : 50, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityIdentifier("countdown")
                    HStack(spacing: 5) {
                        Text("已专注 \(Fmt.countdown(s.focusSeconds(at: now)))")
                            .accessibilityIdentifier("focused-time")
                        if s.isPaused {
                            // A real flight does not wait: the landing countdown carries on.
                            Text(s.followsLanding ? "· 暂停中，飞机还在飞" : "· 暂停中")
                                .foregroundStyle(Palette.amber)
                        }
                    }
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 3) {
                    Label(s.phase.title, systemImage: s.phase.symbol)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(brand.accentColor)
                    Text(s.followsLanding
                         ? "当地 \(Fmt.time(end, zone: s.route.destination.timeZone)) 落地"
                         : "\(Fmt.time(end)) 结束")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Label(s.tag.title, systemImage: s.tag.symbol)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 4) {
                RouteProgressBar(boarded: s.boardedFraction, current: progress.fraction, tint: brand.accentColor)
                HStack {
                    Text("\(s.route.origin.code) \(s.route.origin.city)")
                    Spacer()
                    Text("还有 \(Fmt.km(progress.remainingKm)) km")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(s.route.destination.city) \(s.route.destination.code)")
                }
                .font(.caption.weight(.semibold))
                .lineLimit(1)
            }

            if !compact {
                HStack(spacing: 8) {
                    Readout(title: "高度", value: FlightMath.flightLevel(state.altitudeFt), detail: Fmt.altitudeMeters(state.altitudeFt))
                    Readout(title: "地速", value: "\(Int(state.groundSpeedKt ?? 0)) kt", detail: Fmt.speedKmh(state.groundSpeedKt))
                    Readout(title: "升降", value: verticalText(state.verticalRateFpm), detail: "英尺/分")
                    Readout(title: "机型", value: state.typeCode ?? "—", detail: state.registration ?? s.seat)
                }
            }

            window(sky: sky, state: state, compact: compact)

            controls(s)
        }
        .padding(compact ? 14 : 18)
        .glassCard(cornerRadius: 32)
    }

    private func verticalText(_ fpm: Int?) -> String {
        guard let fpm, abs(fpm) >= 100 else { return "平飞" }
        return fpm > 0 ? "+\(fpm)" : "\(fpm)"
    }

    /// A strip in the colours of the sky outside right now, with what the aircraft reports about the air.
    private func window(sky: Solar.Sky, state: AircraftState, compact: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: sky.symbol)
                .font(.system(size: compact ? 14 : 17))
                .symbolRenderingMode(.hierarchical)
            Text("窗外 · \(sky.title)")
                .font(compact ? .caption.weight(.semibold) : .footnote.weight(.semibold))
            Spacer()
            if let temp = state.outsideTempC {
                Text("\(temp)°C").font(.footnote.monospacedDigit())
            }
            if let dir = state.windDirDeg, let speed = state.windSpeedKt {
                Label("\(String(format: "%03d", dir))° \(speed) kt", systemImage: "wind")
                    .font(.footnote.monospacedDigit())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, compact ? 6 : 9)
        .background(
            LinearGradient(colors: sky.colors, startPoint: .leading, endPoint: .trailing).opacity(0.85),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .accessibilityElement(children: .combine)
    }

    private func controls(_ s: FocusSession) -> some View {
        HStack(spacing: 10) {
            Button {
                model.togglePause()
            } label: {
                Label(s.isPaused ? "继续" : "暂停", systemImage: s.isPaused ? "play.fill" : "pause.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("pause-button")

            Menu {
                Picker("环境音", selection: Binding(get: { model.settings.ambient }, set: { model.setAmbient($0) })) {
                    ForEach(AmbientPreset.allCases) { preset in
                        Label(preset.title, systemImage: preset.symbol).tag(preset)
                    }
                }
                Divider()
                Toggle("登机与进近提示音", isOn: Binding(get: { model.settings.chimes }, set: { model.settings.chimes = $0 }))
                    .accessibilityIdentifier("flight-chimes-toggle")
            } label: {
                Label(model.settings.ambient == .off ? "环境音" : model.settings.ambient.title, systemImage: model.settings.ambient == .off ? "speaker.wave.2.fill" : model.settings.ambient.symbol)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
            }
            .buttonStyle(.glass)
            .accessibilityIdentifier("ambient-menu")

            Button {
                confirmEnd = true
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.bold))
                    .padding(.vertical, 5)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glass)
            .tint(Palette.coral)
            .accessibilityLabel("结束航程")
            .accessibilityIdentifier("end-button")
        }
    }

    // MARK: Boarding pass overlay

    private func passOverlay(_ s: FocusSession) -> some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.smooth(duration: 0.3)) { showPass = false } }
                if geometry.size.height < 470 {
                    VStack(spacing: 12) {
                        ScrollView {
                            BoardingPassView(pass: PassData(session: s, model: model))
                                .frame(maxWidth: 540)
                                .padding(.horizontal, 20)
                                .frame(maxWidth: .infinity)
                        }
                        .scrollIndicators(.hidden)
                        closePassButton
                    }
                    .padding(.vertical, 8)
                } else {
                    VStack(spacing: 16) {
                        BoardingPassView(pass: PassData(session: s, model: model))
                            .frame(maxWidth: 540)
                            .padding(.horizontal, 20)
                        closePassButton
                    }
                }
            }
        }
        .transition(.opacity)
        .zIndex(2)
    }

    private var closePassButton: some View {
        Button("收起") {
            withAnimation(.smooth(duration: 0.3)) { showPass = false }
        }
        .buttonStyle(.glass)
        .accessibilityIdentifier("hide-pass")
    }
}

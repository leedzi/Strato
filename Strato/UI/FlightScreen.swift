import SwiftUI
import UIKit

/// The screen shown while a focus session is running.
struct FlightScreen: View {
    @Environment(AppModel.self) private var model
    @State private var showPass = false
    @State private var confirmEnd = false

    var body: some View {
        if let session = model.session {
            content(session)
        }
    }

    private func content(_ s: FocusSession) -> some View {
        let brand = model.brand(for: s.flight)
        return ZStack {
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
                bottomInset: 380,
                clock: model.clock
            )
            .ignoresSafeArea()

            // Keeps the status bar and the top controls readable over bright imagery.
            LinearGradient(colors: [.black.opacity(0.55), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .frame(maxHeight: .infinity, alignment: .top)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack(spacing: 10) {
                topBar(s, brand: brand)
                if let text = model.announcement {
                    Label(text, systemImage: "bell.fill")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .glassPill(tint: Palette.amber.opacity(0.35))
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .accessibilityIdentifier("announcement")
                }
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    panel(s, brand: brand, now: model.now)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 6)
            .padding(.bottom, 8)
            .animation(.smooth(duration: 0.35), value: model.announcement)

            if showPass {
                passOverlay(s)
            }
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

    private func panel(_ s: FocusSession, brand: AirlineBrand, now: Date) -> some View {
        let progress = s.progress(at: now)
        let state = s.flight.state
        let end = s.plannedEnd(at: now)
        let sky = Solar.sky(at: s.position(at: now), date: now)
        return VStack(spacing: 14) {
            HStack(alignment: .lastTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(s.followsLanding ? "距落地" : "专注剩余")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(Fmt.countdown(s.remainingSeconds(at: now)))
                        .font(.system(size: 50, weight: .bold, design: .rounded).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityIdentifier("countdown")
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

            HStack(spacing: 8) {
                Readout(title: "高度", value: FlightMath.flightLevel(state.altitudeFt), detail: Fmt.altitudeMeters(state.altitudeFt))
                Readout(title: "地速", value: "\(Int(state.groundSpeedKt ?? 0)) kt", detail: Fmt.speedKmh(state.groundSpeedKt))
                Readout(title: "升降", value: verticalText(state.verticalRateFpm), detail: "英尺/分")
                Readout(title: "机型", value: state.typeCode ?? "—", detail: state.registration ?? s.seat)
            }

            window(sky: sky, state: state)

            controls(s)
        }
        .padding(18)
        .glassCard(cornerRadius: 32)
    }

    private func verticalText(_ fpm: Int?) -> String {
        guard let fpm, abs(fpm) >= 100 else { return "平飞" }
        return fpm > 0 ? "+\(fpm)" : "\(fpm)"
    }

    /// A strip in the colours of the sky outside right now, with what the aircraft reports about the air.
    private func window(sky: Solar.Sky, state: AircraftState) -> some View {
        HStack(spacing: 10) {
            Image(systemName: sky.symbol)
                .font(.system(size: 17))
                .symbolRenderingMode(.hierarchical)
            Text("窗外 · \(sky.title)")
                .font(.footnote.weight(.semibold))
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
        .padding(.vertical, 9)
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
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { withAnimation(.smooth(duration: 0.3)) { showPass = false } }
            VStack(spacing: 16) {
                BoardingPassView(pass: PassData(session: s, model: model))
                    .padding(.horizontal, 20)
                Button("收起") {
                    withAnimation(.smooth(duration: 0.3)) { showPass = false }
                }
                .buttonStyle(.glass)
                .accessibilityIdentifier("hide-pass")
            }
        }
        .transition(.opacity)
        .zIndex(2)
    }
}

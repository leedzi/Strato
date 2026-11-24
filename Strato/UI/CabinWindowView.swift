import SwiftUI

/// An offline cabin atmosphere driven by the flight's position and sky.
struct CabinWindowView: View {
    var cabin: CabinClass
    var state: AircraftState
    var position: GeoPoint
    var date: Date
    /// Optional scenery under the shared window frame and wing.
    var landscape: AnyView? = nil
    var landscapeTitle: String = "氛围舷窗"

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    private var sky: Solar.Sky { Solar.sky(at: position, date: date) }
    private var animates: Bool { !reduceMotion && scenePhase == .active && !UserDefaults.standard.bool(forKey: "uitest") }

    var body: some View {
        let style = CabinWindowStyle(cabin)
        let currentSky = sky
        GeometryReader { geometry in
            let height = min(620, max(64, geometry.size.height - 42))
            let width = min(max(54, geometry.size.width - 48), height * 0.76 * style.widthScale)
            let shape = RoundedRectangle(cornerRadius: width * 0.43, style: .continuous)
            VStack(spacing: 12) {
                scenery(currentSky)
                    .clipShape(shape)
                    .overlay {
                        shape.strokeBorder(
                            LinearGradient(colors: [.white.opacity(0.25), .clear, .black.opacity(0.30)], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: 7
                        )
                    }
                    .overlay {
                        shape.strokeBorder(.white.opacity(0.13), lineWidth: 1)
                    }
                    .background {
                        shape.fill(
                            LinearGradient(colors: style.rim, startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .padding(-11)
                        .shadow(color: .black.opacity(0.55), radius: 16, y: 9)
                        .shadow(color: style.light.opacity(currentSky == .night ? 0.12 : 0.20), radius: 26)
                    }
                    .frame(width: width, height: height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                HStack(spacing: 8) {
                    Label("\(landscapeTitle) · \(currentSky.title)", systemImage: currentSky.symbol)
                    Spacer(minLength: 6)
                    Text(cabin.title)
                    Text(FlightMath.flightLevel(state.altitudeFt))
                        .monospacedDigit()
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.65))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: 460)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(landscapeTitle)
        .accessibilityValue("\(cabin.title)，\(currentSky.title)，高度 \(Fmt.altitudeMeters(state.altitudeFt))")
        .accessibilityIdentifier("cabin-window-view")
    }

    @ViewBuilder
    private func scenery(_ currentSky: Solar.Sky) -> some View {
        if let landscape {
            ZStack {
                landscape
                CabinScenery(state: state, position: position, sky: currentSky, seconds: 0).wingOverlay
            }
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !animates)) { context in
                let seconds = animates ? context.date.timeIntervalSinceReferenceDate : 0
                CabinScenery(state: state, position: position, sky: currentSky, seconds: seconds)
            }
        }
    }
}

private struct CabinWindowStyle {
    let widthScale: CGFloat
    let rim: [Color]
    let light: Color

    init(_ cabin: CabinClass) {
        switch cabin {
        case .economy:
            widthScale = 1
            rim = [Color(rgb: 0x9AABB8), Color(rgb: 0x45515F), Color(rgb: 0x263140)]
            light = Color(rgb: 0xB4D7F2)
        case .premium:
            widthScale = 1.03
            rim = [Color(rgb: 0xB2B8B5), Color(rgb: 0x606B70), Color(rgb: 0x333D48)]
            light = Color(rgb: 0xD1DEDC)
        case .business:
            widthScale = 1.06
            rim = [Color(rgb: 0xB9AD96), Color(rgb: 0x716A61), Color(rgb: 0x3A3D43)]
            light = Color(rgb: 0xF2D7AD)
        case .first:
            widthScale = 1.08
            rim = [Color(rgb: 0xC8BDA9), Color(rgb: 0x80756A), Color(rgb: 0x43434A)]
            light = Color(rgb: 0xFFE3BC)
        }
    }
}

private struct CabinScenery: View {
    let state: AircraftState
    let position: GeoPoint
    let sky: Solar.Sky
    let seconds: TimeInterval

    var body: some View {
        Canvas(opaque: true) { context, size in
            draw(in: context, size: size)
        }
        .accessibilityHidden(true)
    }

    var wingOverlay: some View {
        Canvas { context, size in
            drawWing(in: context, size: size)
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func draw(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        let altitude = CGFloat(min(max(Double(state.altitudeFt ?? 12000) / 40000, 0), 1))
        let heading = finite(state.trackDeg, fallback: 0) * .pi / 180
        let bank = finite(state.rollDeg, fallback: 0)
        let speed = min(max(finite(state.groundSpeedKt, fallback: 350), 0), 650)
        let lat = position.lat.isFinite ? position.lat : 0
        let lon = position.lon.isFinite ? position.lon : 0
        let seed = lat * 0.013 + lon * 0.009 + sin(heading) * 0.08
        let horizon = h * (0.60 - altitude * 0.12)
        let night = sky == .night

        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(Gradient(colors: sky.colors), startPoint: .zero, endPoint: CGPoint(x: 0, y: h))
        )

        if night {
            for index in 0..<24 {
                let x = w * CGFloat(unit(Double(index) * 0.618 + seed))
                let y = h * CGFloat(unit(Double(index) * 0.381 + seed * 0.3)) * 0.40
                let radius: CGFloat = index.isMultiple(of: 4) ? 1.0 : 0.65
                context.fill(
                    Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)),
                    with: .color(.white.opacity(index.isMultiple(of: 3) ? 0.38 : 0.20))
                )
            }
        }

        var world = context
        world.translateBy(x: w / 2, y: h / 2)
        world.rotate(by: .degrees(-min(max(bank, -9), 9)))
        world.translateBy(x: -w / 2, y: -h / 2)

        let glowColor: Color
        switch sky {
        case .sunrise: glowColor = Color(rgb: 0xFFE0A6).opacity(0.48)
        case .sunset: glowColor = Color(rgb: 0xFFB691).opacity(0.40)
        case .day: glowColor = .white.opacity(0.24)
        case .night: glowColor = Color(rgb: 0x7188BC).opacity(0.12)
        }
        world.fill(
            Path(ellipseIn: CGRect(x: -w * 0.4, y: horizon - h * 0.15, width: w * 1.8, height: h * 0.35)),
            with: .radialGradient(
                Gradient(colors: [glowColor, .clear]),
                center: CGPoint(x: w * (0.5 + CGFloat(sin(heading)) * 0.18), y: horizon),
                startRadius: 0,
                endRadius: w * 0.85
            )
        )

        var earth = Path()
        earth.move(to: CGPoint(x: -w * 0.3, y: horizon))
        for step in 0...24 {
            let fraction = CGFloat(step) / 24
            let x = -w * 0.3 + w * 1.6 * fraction
            let wave = sin(Double(fraction) * .pi * 2.5 + seed * 3)
            let y = horizon + h * CGFloat(wave) * (0.012 + (1 - altitude) * 0.012)
            earth.addLine(to: CGPoint(x: x, y: y))
        }
        earth.addLine(to: CGPoint(x: w * 1.3, y: h * 1.3))
        earth.addLine(to: CGPoint(x: -w * 0.3, y: h * 1.3))
        earth.closeSubpath()
        let groundTop = night ? Color(rgb: 0x111B34) : Color(rgb: 0x7C9CA5)
        let groundBottom = night ? Color(rgb: 0x080F20) : Color(rgb: 0xBCD1DB)
        world.fill(
            earth,
            with: .linearGradient(
                Gradient(colors: [groundTop.opacity(0.45), groundBottom.opacity(0.85)]),
                startPoint: CGPoint(x: 0, y: horizon),
                endPoint: CGPoint(x: 0, y: h)
            )
        )

        drawClouds(in: world, size: size, horizon: horizon, altitude: altitude, seed: seed, speed: speed, near: false)
        drawClouds(in: world, size: size, horizon: horizon, altitude: altitude, seed: seed + 0.31, speed: speed, near: true)
        drawWing(in: context, size: size)

        // A faint reflection keeps the view feeling like glass.
        context.fill(
            Path(CGRect(origin: .zero, size: size)),
            with: .linearGradient(
                Gradient(colors: [.white.opacity(night ? 0.035 : 0.09), .clear, .black.opacity(0.08)]),
                startPoint: .zero,
                endPoint: CGPoint(x: w, y: h)
            )
        )
    }

    private func drawClouds(
        in context: GraphicsContext,
        size: CGSize,
        horizon: CGFloat,
        altitude: CGFloat,
        seed: Double,
        speed: Double,
        near: Bool
    ) {
        let w = size.width
        let h = size.height
        let drift = seconds / (near ? 640 : 1200) * (0.35 + speed / 650)
        let baseY = horizon + h * (near ? 0.03 + altitude * 0.14 : -0.045)
        let color = sky == .night ? Color(rgb: 0x9AACD0) : Color.white
        context.drawLayer { layer in
            layer.addFilter(.blur(radius: near ? 4 : 2))
            for index in 0..<12 {
                let fraction = CGFloat(unit(Double(index) * 0.079 + seed - drift))
                let x = w * (fraction * 1.75 - 0.40)
                let span = w * (near ? 0.52 : 0.32) * (1 + CGFloat(index % 3) * 0.14)
                let height = h * (near ? 0.14 : 0.065)
                let y = baseY + h * CGFloat(index % 4) * (near ? 0.045 : 0.014)
                var cloud = Path(ellipseIn: CGRect(x: x, y: y, width: span, height: height))
                cloud.addEllipse(in: CGRect(x: x + span * 0.20, y: y - height * 0.35, width: span * 0.45, height: height))
                cloud.addEllipse(in: CGRect(x: x + span * 0.53, y: y - height * 0.12, width: span * 0.40, height: height * 0.80))
                layer.fill(cloud, with: .color(color.opacity(sky == .night ? (near ? 0.12 : 0.08) : (near ? 0.45 : 0.27))))
            }
        }
    }

    private func drawWing(in context: GraphicsContext, size: CGSize) {
        let w = size.width
        let h = size.height
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: w * x, y: h * y) }
        var wing = Path()
        wing.move(to: p(-0.12, 0.84))
        wing.addLine(to: p(0.24, 0.79))
        wing.addLine(to: p(0.80, 0.64))
        wing.addQuadCurve(to: p(0.94, 0.63), control: p(0.91, 0.61))
        wing.addLine(to: p(0.92, 0.68))
        wing.addLine(to: p(0.62, 0.79))
        wing.addLine(to: p(0.24, 0.98))
        wing.addLine(to: p(-0.12, 1.05))
        wing.closeSubpath()
        let top = sky == .night ? Color(rgb: 0x66738B) : Color(rgb: 0xDCE2E5)
        let bottom = sky == .night ? Color(rgb: 0x252E43) : Color(rgb: 0x7B8C9E)
        context.fill(
            wing,
            with: .linearGradient(Gradient(colors: [top, bottom]), startPoint: p(0.5, 0.65), endPoint: p(0.2, 1))
        )
        context.stroke(wing, with: .color(.white.opacity(sky == .night ? 0.10 : 0.22)), lineWidth: 0.8)
        var seams = Path()
        seams.move(to: p(0.02, 0.86))
        seams.addLine(to: p(0.56, 0.74))
        seams.move(to: p(0.22, 0.80))
        seams.addLine(to: p(0.29, 0.94))
        seams.move(to: p(0.47, 0.72))
        seams.addLine(to: p(0.54, 0.81))
        context.stroke(seams, with: .color(.black.opacity(0.13)), lineWidth: 0.7)
    }

    private func finite(_ value: Double?, fallback: Double) -> Double {
        guard let value, value.isFinite else { return fallback }
        return value
    }

    private func unit(_ value: Double) -> Double {
        let remainder = value.truncatingRemainder(dividingBy: 1)
        return remainder < 0 ? remainder + 1 : remainder
    }
}

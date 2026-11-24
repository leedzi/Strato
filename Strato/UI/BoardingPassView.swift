import SwiftUI

/// Everything printed on a boarding pass.
struct PassData: Hashable {
    enum Stamp: Hashable {
        case none
        case arrived(Date, estimated: Bool)
        case focusDone(Date)
        case leftEarly(Date)
    }

    var id: UUID
    var airlineICAO: String?
    var airlineName: String
    var airlineEnglish: String
    var flightNumber: String
    var origin: Airport
    var destination: Airport
    var date: Date
    var seat: String
    var gate: String
    var cabin: CabinClass
    var sequence: Int
    var passenger: String
    var tag: FocusTag
    var simulated: Bool
    var stamp: Stamp = .none
    /// e.g. "专注 82 分钟 · 1,240 km", shown on the stub of a used pass.
    var footnote: String?

    var brand: AirlineBrand { AirlineBrand.forICAO(airlineICAO) }
    var pnr: String { BoardingPassCode.pnr(for: id) }

    var barcodeText: String {
        BoardingPassCode.make(
            passenger: passenger, pnr: pnr, fromIATA: origin.code, toIATA: destination.code,
            flightNumber: flightNumber, date: date, cabin: cabin, seat: seat, sequence: sequence
        )
    }
}

@MainActor
extension PassData {
    private static func names(_ icao: String?, fallback: String?, reference: ReferenceData) -> (String, String) {
        let airline = reference.airline(icao: icao)
        let zh = airline?.name ?? fallback ?? (icao ?? "STRATO")
        let en = (airline?.nameEN ?? fallback ?? icao ?? "STRATO AIRWAYS").uppercased()
        return (zh, en)
    }

    /// A pass about to be issued.
    init(flight: LiveFlight, route: FlightRoute, tag: FocusTag, seat: String, gate: String, cabin: CabinClass, sequence: Int, model: AppModel) {
        let n = PassData.names(flight.airlineICAO, fallback: route.airlineName, reference: model.reference)
        self.init(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000000")!, airlineICAO: flight.airlineICAO,
            airlineName: n.0, airlineEnglish: n.1, flightNumber: flight.displayNumber,
            origin: route.origin, destination: route.destination, date: model.now, seat: seat, gate: gate,
            cabin: cabin, sequence: sequence, passenger: model.settings.passengerDisplay, tag: tag,
            simulated: flight.isSimulated
        )
    }

    init(session s: FocusSession, model: AppModel) {
        let n = PassData.names(s.flight.airlineICAO, fallback: s.route.airlineName, reference: model.reference)
        self.init(
            id: s.id, airlineICAO: s.flight.airlineICAO, airlineName: n.0, airlineEnglish: n.1,
            flightNumber: s.flight.displayNumber, origin: s.route.origin, destination: s.route.destination,
            date: s.startedAt, seat: s.seat, gate: s.gate, cabin: s.cabin, sequence: s.sequence,
            passenger: model.settings.passengerDisplay, tag: s.tag, simulated: s.flight.isSimulated
        )
    }

    init(record r: FocusRecord, model: AppModel) {
        let n = PassData.names(r.airlineICAO, fallback: r.airlineName, reference: model.reference)
        let stamp: Stamp
        switch r.outcome {
        case .landed: stamp = .arrived(r.endedAt, estimated: r.landingEstimated)
        case .timerDone: stamp = .focusDone(r.endedAt)
        case .endedEarly: stamp = .leftEarly(r.endedAt)
        }
        self.init(
            id: r.id, airlineICAO: r.airlineICAO, airlineName: n.0, airlineEnglish: n.1,
            flightNumber: r.flightNumber, origin: r.origin, destination: r.destination, date: r.startedAt,
            seat: r.seat, gate: r.gate, cabin: r.cabin, sequence: r.sequence,
            passenger: model.settings.passengerDisplay, tag: r.tag, simulated: r.simulated, stamp: stamp,
            footnote: "专注 \(r.focusMinutes) 分钟 · \(Fmt.km(r.distanceKm)) km"
        )
    }
}

/// The outline of a pass: a rounded card with a notch on each side where the stub tears off.
struct PassShape: Shape {
    var notchY: CGFloat
    var corner: CGFloat = 22
    var notch: CGFloat = 11

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let y = min(max(notchY, corner + notch), rect.height - corner - notch)
        p.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.minY + corner), radius: corner, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: y - notch))
        p.addArc(center: CGPoint(x: rect.maxX, y: y), radius: notch, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner), radius: corner, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner), radius: corner, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: y + notch))
        p.addArc(center: CGPoint(x: rect.minX, y: y), radius: notch, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.minY + corner), radius: corner, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// A paper boarding pass dressed in the airline's colours.
struct BoardingPassView: View {
    var pass: PassData
    @State private var stubTop: CGFloat = 260

    private var brand: AirlineBrand { pass.brand }

    var body: some View {
        VStack(spacing: 0) {
            header
            main
                .overlay(alignment: .top) { stampView.padding(.top, 4) }
                .background(GeometryReader { geo in
                    Color.clear.preference(key: StubKey.self, value: geo.frame(in: .named("pass")).maxY)
                })
            perforation
            stub
        }
        .coordinateSpace(.named("pass"))
        .onPreferenceChange(StubKey.self) { stubTop = $0 }
        .background(Palette.paper)
        .clipShape(PassShape(notchY: stubTop))
        .shadow(color: .black.opacity(0.35), radius: 16, y: 8)
        .environment(\.colorScheme, .light)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("boarding-pass")
    }

    private struct StubKey: PreferenceKey {
        static var defaultValue: CGFloat = 260
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 1) {
                Text(pass.airlineName)
                    .font(.system(size: 17, weight: .bold))
                Text(pass.airlineEnglish)
                    .font(.system(size: 9.5, weight: .semibold))
                    .tracking(1.4)
                    .opacity(0.85)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("BOARDING PASS")
                    .font(.system(size: 9.5, weight: .heavy))
                    .tracking(1.6)
                Text(pass.simulated ? "登机牌 · 模拟航班" : "登机牌")
                    .font(.system(size: 11, weight: .semibold))
                    .opacity(0.9)
            }
        }
        .foregroundStyle(brand.onPrimary)
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .background(LinearGradient(colors: [brand.primaryColor, brand.secondaryColor], startPoint: .topLeading, endPoint: .bottomTrailing))
        .overlay(alignment: .bottom) { Rectangle().fill(brand.accentColor).frame(height: 3) }
    }

    private var main: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top) {
                endpoint(code: pass.origin.code, city: pass.origin.city, alignment: .leading)
                Spacer(minLength: 4)
                VStack(spacing: 3) {
                    Image(systemName: "airplane")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(brand.primaryColor)
                    Text(pass.flightNumber)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(Palette.ink)
                }
                .padding(.top, 10)
                // On a used pass the stamp takes this spot (the flight number is printed below anyway).
                .opacity(pass.stamp == .none ? 1 : 0)
                Spacer(minLength: 4)
                endpoint(code: pass.destination.code, city: pass.destination.city, alignment: .trailing)
            }

            HStack(alignment: .top, spacing: 0) {
                field("旅客 NAME", pass.passenger)
                field("日期 DATE", Fmt.passDate(pass.date), width: 74)
                field("舱位 CLASS", pass.cabin.title, width: 78)
            }
            HStack(alignment: .top, spacing: 0) {
                field("航班 FLIGHT", pass.flightNumber)
                field("登机口 GATE", pass.gate, big: true)
                field("座位 SEAT", pass.seat, big: true)
                field("序号 SEQ", String(format: "%03d", pass.sequence), width: 64)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 14)
    }

    private func endpoint(code: String, city: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(code)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .foregroundStyle(Palette.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(city)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
                .lineLimit(1)
        }
    }

    private func field(_ title: String, _ value: String, big: Bool = false, width: CGFloat? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 8.5, weight: .semibold))
                .foregroundStyle(Palette.inkSoft)
            Text(value)
                .font(.system(size: big ? 20 : 14, weight: .bold, design: .monospaced))
                .foregroundStyle(big ? brand.primaryColor : Palette.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
        .frame(width: width, alignment: .leading)
    }

    private var perforation: some View {
        Line()
            .stroke(Palette.inkSoft.opacity(0.45), style: StrokeStyle(lineWidth: 1.2, dash: [5, 5]))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var p = Path()
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return p
        }
    }

    private var stub: some View {
        VStack(spacing: 8) {
            HStack {
                Label(pass.tag.title, systemImage: pass.tag.symbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text(pass.footnote ?? "PNR \(pass.pnr)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Palette.inkSoft)
            }
            if let image = Barcode.pdf417(pass.barcodeText) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(height: 46)
                    .blendMode(.multiply)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(Palette.paperShade.opacity(0.55))
    }

    @ViewBuilder
    private var stampView: some View {
        switch pass.stamp {
        case .none:
            EmptyView()
        case .arrived(let date, let estimated):
            InkStamp(top: estimated ? "ARRIVED · EST" : "ARRIVED", middle: pass.destination.code, bottom: Fmt.passDate(date) + " " + Fmt.time(date), color: Color(rgb: 0xC2343F))
                .rotationEffect(.degrees(-13))
        case .focusDone(let date):
            InkStamp(top: "FOCUS DONE", middle: "✓", bottom: Fmt.passDate(date) + " " + Fmt.time(date), color: Color(rgb: 0x2463B8))
                .rotationEffect(.degrees(-11))
        case .leftEarly(let date):
            InkStamp(top: "LEFT EARLY", middle: "—", bottom: Fmt.passDate(date) + " " + Fmt.time(date), color: Color(rgb: 0x6B7180))
                .rotationEffect(.degrees(9))
        }
    }
}

/// A round rubber stamp.
struct InkStamp: View {
    var top: String
    var middle: String
    var bottom: String
    var color: Color

    var body: some View {
        ZStack {
            Circle().stroke(color, lineWidth: 3)
            Circle().stroke(color, lineWidth: 1).padding(5)
            VStack(spacing: 1) {
                Text(top).font(.system(size: 8.5, weight: .heavy)).tracking(0.8)
                Text(middle).font(.system(size: 25, weight: .black, design: .rounded))
                Text(bottom).font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(color)
        }
        .frame(width: 92, height: 92)
        .opacity(0.9)
        .allowsHitTesting(false)
    }
}

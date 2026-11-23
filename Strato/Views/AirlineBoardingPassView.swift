import SwiftUI

/// Realistic Airline Livery Boarding Pass with perforated tear-off stub, airline colors,
/// cabin class, gate, sequence number, PDF417 barcode, and arrival customs stamp.
struct AirlineBoardingPassCard: View {
    let callsign: String
    let airlineName: String
    let aircraftType: String
    let originIATA: String
    let originCity: String
    let destinationIATA: String
    let destinationCity: String
    let seatNumber: String
    let gateNumber: String
    let cabinClass: String
    let sequenceNumber: String
    let flightLevelText: String
    let durationMinutes: Int
    let distanceKM: Int
    let realProgress: Double
    let focusTag: FocusTag
    let date: Date
    let showArrivedStamp: Bool

    private var branding: AirlineBranding {
        AirlineThemeRegistry.branding(forCallsign: callsign, fallbackName: airlineName)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // 1. Airline Livery Header Strip
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(branding.nameCN)
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text("·")
                                .foregroundStyle(.white.opacity(0.6))
                            Text(branding.nameEN)
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                        Text(branding.alliance)
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundStyle(branding.accentColor)
                    }

                    Spacer()

                    Text(cabinClass)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.28), in: Capsule())
                        .overlay(Capsule().stroke(branding.accentColor.opacity(0.6), lineWidth: 0.8))
                        .foregroundStyle(branding.accentColor)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [branding.primaryColor, branding.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

                // 2. Main Ticket Body
                VStack(spacing: 14) {
                    // Origin -> Aircraft -> Destination
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("FROM · 出发")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(originIATA)
                                .font(.system(size: 34, weight: .black, design: .monospaced))
                            Text(originCity)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(spacing: 4) {
                            Text(callsign)
                                .font(.caption.monospaced().bold())
                                .foregroundStyle(branding.accentColor)
                            ZStack {
                                Capsule()
                                    .fill(.white.opacity(0.15))
                                    .frame(width: 78, height: 3)
                                Image(systemName: "airplane")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                            Text("\(aircraftType) · \(flightLevelText)")
                                .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 3) {
                            Text("TO · 目的地")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(destinationIATA)
                                .font(.system(size: 34, weight: .black, design: .monospaced))
                            Text(destinationCity)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Real-time Air Progress Bar
                    VStack(spacing: 4) {
                        HStack {
                            Text("航班实时空中进度")
                                .font(.system(size: 9.5, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("已飞 \(Int((realProgress * 100).rounded()))% · 距落地约 \(durationMinutes)m")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(StratoTheme.skyCyan)
                        }
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(.white.opacity(0.14))
                                    .frame(height: 5)
                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [branding.primaryColor, branding.accentColor],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: max(10, geo.size.width * realProgress), height: 5)
                            }
                        }
                        .frame(height: 6)
                    }

                    // Boarding Fields Grid
                    HStack {
                        boardingField(label: "GATE", value: gateNumber, highlight: true)
                        Spacer()
                        boardingField(label: "SEAT", value: seatNumber, highlight: true)
                        Spacer()
                        boardingField(label: "FOCUS TASK", value: focusTag.rawValue, highlight: false)
                        Spacer()
                        boardingField(label: "SEQ", value: sequenceNumber, highlight: false)
                    }
                }
                .padding(18)

                // 3. Perforated Tear-Off Divider with Side Notches
                PerforatedTearLine()
                    .frame(height: 18)

                // 4. Ticket Stub & Realistic PDF417 Barcode
                HStack(alignment: .center, spacing: 14) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("ETKT \(abs(callsign.hashValue % 900 + 100))-\(abs(originIATA.hashValue % 8999999 + 1000000))")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(date, format: .dateTime.year().month().day().hour().minute())
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text("MILEAGE + \(distanceKM) KM")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundStyle(StratoTheme.radarEmerald)
                    }

                    Spacer()

                    SimulatedBarcodeView(seed: "\(callsign)-\(originIATA)-\(destinationIATA)-\(seatNumber)")
                        .frame(width: 128, height: 34)
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
                .padding(.top, 4)
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(red: 0.08, green: 0.11, blue: 0.18).opacity(0.92))
            )
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(.white.opacity(0.22), lineWidth: 1)
            )

            // 5. Customs Arrival Stamp Overlay
            if showArrivedStamp {
                ArrivalCustomsStamp(airportCode: destinationIATA, city: destinationCity, date: date)
                    .rotationEffect(.degrees(-14))
                    .padding(.trailing, 18)
                    .padding(.bottom, 42)
                    .allowsHitTesting(false)
            }
        }
    }

    private func boardingField(label: String, value: String, highlight: Bool) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                .foregroundStyle(highlight ? branding.accentColor : .white)
        }
    }
}

private struct PerforatedTearLine: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 16, y: geo.size.height / 2))
                    path.addLine(to: CGPoint(x: geo.size.width - 16, y: geo.size.height / 2))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                .foregroundStyle(.white.opacity(0.22))

                HStack {
                    Circle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .offset(x: -9)
                    Spacer()
                    Circle()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 18, height: 18)
                        .offset(x: 9)
                }
            }
        }
    }
}

private struct SimulatedBarcodeView: View {
    let seed: String

    var body: some View {
        Canvas { context, size in
            var hash = UInt64(5381)
            for byte in seed.utf8 {
                hash = ((hash << 5) &+ hash) &+ UInt64(byte)
            }
            let columns = 38
            let barWidth = size.width / CGFloat(columns)
            for col in 0..<columns {
                let bit = (hash >> (col % 60)) & 1
                let tall = (col % 5 == 0) || bit == 1
                if tall || col % 2 == 0 {
                    let w = (bit == 1) ? barWidth * 0.78 : barWidth * 0.42
                    let rect = CGRect(
                        x: CGFloat(col) * barWidth,
                        y: 2,
                        width: max(1.2, w),
                        height: size.height - 4
                    )
                    context.fill(Path(rect), with: .color(.white.opacity(bit == 1 ? 0.88 : 0.45)))
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct ArrivalCustomsStamp: View {
    let airportCode: String
    let city: String
    let date: Date

    var body: some View {
        VStack(spacing: 1) {
            Text("STRATO IMMIGRATION")
                .font(.system(size: 7, weight: .black, design: .monospaced))
            Text("ARRIVED · \(airportCode)")
                .font(.system(size: 12, weight: .black, design: .monospaced))
            Text(city)
                .font(.system(size: 8.5, weight: .bold))
        }
        .foregroundStyle(StratoTheme.radarEmerald)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(StratoTheme.radarEmerald, style: StrokeStyle(lineWidth: 1.8, dash: [14, 2]))
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
        )
    }
}

import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

// MARK: - Liquid Glass helpers

extension View {
    /// A Liquid Glass panel.
    func glassCard(cornerRadius: CGFloat = 26, tint: Color? = nil) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return Group {
            if let tint {
                self.glassEffect(.regular.tint(tint), in: shape)
            } else {
                self.glassEffect(.regular, in: shape)
            }
        }
    }

    /// A Liquid Glass capsule, for chips and small controls.
    func glassPill(tint: Color? = nil) -> some View {
        Group {
            if let tint {
                self.glassEffect(.regular.tint(tint), in: Capsule())
            } else {
                self.glassEffect(.regular, in: Capsule())
            }
        }
    }
}

// MARK: - Formatting

enum Fmt {
    /// 3723 -> "1:02:03", 723 -> "12:03".
    static func countdown(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        let h = s / 3600, m = (s % 3600) / 60, r = s % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, r) : String(format: "%02d:%02d", m, r)
    }

    static func km(_ value: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: value.rounded())) ?? "\(Int(value))"
    }

    static func time(_ date: Date, zone: TimeZone? = nil) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        f.timeZone = zone ?? .current
        return f.string(from: date)
    }

    static func day(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }

    static func dayWithWeekday(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 EEE"
        return f.string(from: date)
    }

    /// "23NOV" as printed on boarding passes.
    static func passDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "ddMMM"
        return f.string(from: date).uppercased()
    }

    static func hours(minutes: Int) -> String {
        if minutes < 60 { return "\(minutes) 分钟" }
        return String(format: "%.1f 小时", Double(minutes) / 60)
    }

    static func altitudeMeters(_ feet: Int?) -> String {
        guard let feet else { return "—" }
        return "\(km(Double(feet) * 0.3048)) m"
    }

    static func speedKmh(_ knots: Double?) -> String {
        guard let knots else { return "—" }
        return "\(Int((knots * Geo.kmPerNM).rounded())) km/h"
    }
}

// MARK: - Small shared views

/// Route progress: the part flown before boarding, the part flown together, and what is ahead.
struct RouteProgressBar: View {
    var boarded: Double?
    var current: Double
    var tint: Color = Palette.sky

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let now = min(max(current, 0), 1)
            let start = min(max(boarded ?? 0, 0), now)
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.16)).frame(height: 5)
                if boarded != nil {
                    Capsule().fill(.white.opacity(0.42)).frame(width: max(5, w * start), height: 5)
                }
                Capsule()
                    .fill(LinearGradient(colors: [tint.opacity(0.7), tint], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(5, w * (now - (boarded == nil ? 0 : start))), height: 5)
                    .offset(x: boarded == nil ? 0 : w * start)
                if let boarded, boarded > 0.01 {
                    Circle().fill(.white).frame(width: 7, height: 7).offset(x: w * start - 3.5)
                }
                Image(systemName: "airplane")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 2)
                    .offset(x: min(max(w * now - 9, 0), w - 18))
            }
            .frame(height: geo.size.height)
        }
        .frame(height: 20)
        .accessibilityElement()
        .accessibilityLabel("航程进度")
        .accessibilityValue("\(Int((current * 100).rounded()))%")
    }
}

/// A label / value pair in the monospaced style of flight instruments.
struct Readout: View {
    var title: String
    var value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.system(size: 10.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Chip: View {
    var title: String
    var symbol: String?
    var selected: Bool
    var tint: Color = Palette.sky

    var body: some View {
        HStack(spacing: 5) {
            if let symbol { Image(systemName: symbol).font(.caption) }
            Text(title).font(.subheadline.weight(.semibold))
        }
        .foregroundStyle(selected ? Color.black : Color.white)
        .padding(.horizontal, 13)
        .padding(.vertical, 8)
        .background(selected ? AnyShapeStyle(tint) : AnyShapeStyle(.white.opacity(0.12)), in: Capsule())
    }
}

/// A coloured dot plus airline name, used wherever a flight is listed.
struct AirlineLabel: View {
    var brand: AirlineBrand
    var name: String

    var body: some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(LinearGradient(colors: [brand.primaryColor, brand.accentColor], startPoint: .top, endPoint: .bottom))
                .frame(width: 5, height: 16)
            Text(name)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }
}

struct SectionTitle: View {
    var text: String
    var trailing: String?

    var body: some View {
        HStack {
            Text(text).font(.headline)
            Spacer()
            if let trailing {
                Text(trailing).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Barcode

@MainActor
enum Barcode {
    private static var cache: [String: UIImage] = [:]
    private static let context = CIContext()

    /// PDF417, the symbology printed on real boarding passes.
    static func pdf417(_ text: String) -> UIImage? {
        if let hit = cache[text] { return hit }
        let filter = CIFilter.pdf417BarcodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = 2
        filter.preferredAspectRatio = 4
        guard let output = filter.outputImage else { return nil }
        let scaled = output.transformed(by: CGAffineTransform(scaleX: 4, y: 4))
        guard let cg = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        let image = UIImage(cgImage: cg)
        cache[text] = image
        return image
    }
}

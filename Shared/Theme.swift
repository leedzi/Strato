import SwiftUI

extension Color {
    /// 0xRRGGBB.
    init(rgb: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Colours shared by the app and its widgets.
enum Palette {
    static let sky = Color(rgb: 0x5BC8FF)
    static let mint = Color(rgb: 0x4FE3B0)
    static let amber = Color(rgb: 0xFFB84D)
    static let coral = Color(rgb: 0xFF6B6B)
    static let indigo = Color(rgb: 0x7C8CFF)

    /// Deep stratosphere blues used behind content.
    static let night = Color(rgb: 0x060B18)
    static let dusk = Color(rgb: 0x101C36)
    static let horizon = Color(rgb: 0x1E3A68)

    /// Boarding pass paper.
    static let paper = Color(rgb: 0xF6F2E8)
    static let paperShade = Color(rgb: 0xE9E3D3)
    static let ink = Color(rgb: 0x1B1F2A)
    static let inkSoft = Color(rgb: 0x6B7180)

    static var backdrop: LinearGradient {
        LinearGradient(colors: [night, dusk, horizon], startPoint: .top, endPoint: .bottom)
    }
}

extension AirlineBrand {
    var primaryColor: Color { Color(rgb: primary) }
    var secondaryColor: Color { Color(rgb: secondary) }
    var accentColor: Color { Color(rgb: accent) }
    /// Text colour that reads on the primary colour.
    var onPrimary: Color { prefersLightText ? .white : Color(rgb: 0x14161C) }
}

extension Solar.Sky {
    var title: String {
        switch self {
        case .day: return "白昼"
        case .sunrise: return "日出"
        case .sunset: return "日落"
        case .night: return "夜航"
        }
    }

    var symbol: String {
        switch self {
        case .day: return "sun.max.fill"
        case .sunrise: return "sunrise.fill"
        case .sunset: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    /// The colours outside the window right now, top to bottom.
    var colors: [Color] {
        switch self {
        case .day: return [Color(rgb: 0x1F6FD6), Color(rgb: 0x6FB6FF), Color(rgb: 0xCFE8FF)]
        case .sunrise: return [Color(rgb: 0x24306E), Color(rgb: 0xE08A6A), Color(rgb: 0xFFD79A)]
        case .sunset: return [Color(rgb: 0x2A1B5C), Color(rgb: 0xD9566B), Color(rgb: 0xFFB36B)]
        case .night: return [Color(rgb: 0x04060F), Color(rgb: 0x0C1530), Color(rgb: 0x1B2A55)]
        }
    }
}

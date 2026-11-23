import SwiftUI

public struct AirlineBranding: Sendable, Hashable {
    public let icaoPrefix: String
    public let iataCode: String
    public let nameCN: String
    public let nameEN: String
    public let alliance: String
    public let primaryHex: UInt32
    public let secondaryHex: UInt32
    public let accentHex: UInt32
    public let cabinClasses: [String]

    public var primaryColor: Color { Color(hex: primaryHex) }
    public var secondaryColor: Color { Color(hex: secondaryHex) }
    public var accentColor: Color { Color(hex: accentHex) }
}

extension Color {
    public init(hex: UInt32, opacity: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: opacity)
    }
}

public enum AirlineThemeRegistry {
    private static let themes: [String: AirlineBranding] = [
        // Mainland China & Greater China
        "CCA": AirlineBranding(icaoPrefix: "CCA", iataCode: "CA", nameCN: "中国国际航空", nameEN: "AIR CHINA", alliance: "STAR ALLIANCE", primaryHex: 0xB81C22, secondaryHex: 0x7A0E13, accentHex: 0xF5C242, cabinClasses: ["FIRST · 头等舱", "BUSINESS · 公务舱"]),
        "CES": AirlineBranding(icaoPrefix: "CES", iataCode: "MU", nameCN: "中国东方航空", nameEN: "CHINA EASTERN", alliance: "SKYTEAM", primaryHex: 0x1A2E5A, secondaryHex: 0x0F1C3A, accentHex: 0xE60012, cabinClasses: ["BUSINESS · 公务舱", "ECONOMY · 经济舱"]),
        "CSN": AirlineBranding(icaoPrefix: "CSN", iataCode: "CZ", nameCN: "中国南方航空", nameEN: "CHINA SOUTHERN", alliance: "SKY PARTNER", primaryHex: 0x008ACB, secondaryHex: 0x005288, accentHex: 0xD81E06, cabinClasses: ["BUSINESS · 公务舱", "PEARL · 明珠经济"]),
        "CHH": AirlineBranding(icaoPrefix: "CHH", iataCode: "HU", nameCN: "海南航空", nameEN: "HAINAN AIRLINES", alliance: "FORTUNE WINGS", primaryHex: 0xC8161D, secondaryHex: 0x8F0B10, accentHex: 0xE5B85B, cabinClasses: ["BUSINESS · 公务舱", "ECONOMY · 经济舱"]),
        "CSC": AirlineBranding(icaoPrefix: "CSC", iataCode: "3U", nameCN: "四川航空", nameEN: "SICHUAN AIRLINES", alliance: "GOLDEN PANDA", primaryHex: 0xB5121B, secondaryHex: 0x6E0B10, accentHex: 0xF3B63F, cabinClasses: ["BUSINESS · 公务舱", "ECONOMY · 经济舱"]),
        "CXA": AirlineBranding(icaoPrefix: "CXA", iataCode: "MF", nameCN: "厦门航空", nameEN: "XIAMEN AIR", alliance: "SKYTEAM", primaryHex: 0x005BAC, secondaryHex: 0x00376B, accentHex: 0x4EC3FF, cabinClasses: ["FIRST · 头等舱", "BUSINESS · 公务舱"]),
        "CSZ": AirlineBranding(icaoPrefix: "CSZ", iataCode: "ZH", nameCN: "深圳航空", nameEN: "SHENZHEN AIRLINES", alliance: "STAR ALLIANCE", primaryHex: 0xD71920, secondaryHex: 0x8C0E13, accentHex: 0xFFD100, cabinClasses: ["BUSINESS · 公务舱", "ECONOMY · 经济舱"]),
        "DKH": AirlineBranding(icaoPrefix: "DKH", iataCode: "HO", nameCN: "吉祥航空", nameEN: "JUNEYAO AIR", alliance: "STAR CONNECT", primaryHex: 0x8C1D40, secondaryHex: 0x591128, accentHex: 0xE8C07D, cabinClasses: ["BUSINESS · 公务舱", "ECONOMY · 经济舱"]),
        "CQH": AirlineBranding(icaoPrefix: "CQH", iataCode: "9C", nameCN: "春秋航空", nameEN: "SPRING AIRLINES", alliance: "SPRING PLUS", primaryHex: 0x009944, secondaryHex: 0x00602B, accentHex: 0x8CE6B0, cabinClasses: ["SPRING PLUS · 尊享飞"]),
        "CPA": AirlineBranding(icaoPrefix: "CPA", iataCode: "CX", nameCN: "国泰航空", nameEN: "CATHAY PACIFIC", alliance: "ONEWORLD", primaryHex: 0x006564, secondaryHex: 0x003D3C, accentHex: 0x74D4C8, cabinClasses: ["FIRST · 头等舱", "BUSINESS · 公务舱"]),
        "EVA": AirlineBranding(icaoPrefix: "EVA", iataCode: "BR", nameCN: "长荣航空", nameEN: "EVA AIR", alliance: "STAR ALLIANCE", primaryHex: 0x006940, secondaryHex: 0x004228, accentHex: 0xF37021, cabinClasses: ["ROYAL LAUREL · 皇玺桂冠舱"]),
        "CAL": AirlineBranding(icaoPrefix: "CAL", iataCode: "CI", nameCN: "中华航空", nameEN: "CHINA AIRLINES", alliance: "SKYTEAM", primaryHex: 0x2B3990, secondaryHex: 0x1B235B, accentHex: 0xF06488, cabinClasses: ["PREMIUM BUSINESS · 豪华商务舱"]),
        "SJX": AirlineBranding(icaoPrefix: "SJX", iataCode: "JX", nameCN: "星宇航空", nameEN: "STARLUX AIRLINES", alliance: "COSMILE", primaryHex: 0x3D352E, secondaryHex: 0x1F1B18, accentHex: 0xD4AF37, cabinClasses: ["FIRST · 头等舱", "BUSINESS · 商务舱"]),

        // Japan, Korea & SE Asia
        "ANA": AirlineBranding(icaoPrefix: "ANA", iataCode: "NH", nameCN: "全日空", nameEN: "ALL NIPPON AIRWAYS", alliance: "STAR ALLIANCE", primaryHex: 0x13448F, secondaryHex: 0x0A2552, accentHex: 0x00A0E9, cabinClasses: ["THE ROOM · 商务舱", "THE SUITE · 头等舱"]),
        "JAL": AirlineBranding(icaoPrefix: "JAL", iataCode: "JL", nameCN: "日本航空", nameEN: "JAPAN AIRLINES", alliance: "ONEWORLD", primaryHex: 0xC8102E, secondaryHex: 0x6E0819, accentHex: 0xFFFFFF, cabinClasses: ["JAL SUITE · 头等舱", "SKY SUITE · 商务舱"]),
        "SJO": AirlineBranding(icaoPrefix: "SJO", iataCode: "IJ", nameCN: "日本春秋", nameEN: "SPRING JAPAN", alliance: "JAL GROUP", primaryHex: 0x008A3C, secondaryHex: 0x005223, accentHex: 0x7EE6A3, cabinClasses: ["SPRING PLUS"]),
        "KAL": AirlineBranding(icaoPrefix: "KAL", iataCode: "KE", nameCN: "大韩航空", nameEN: "KOREAN AIR", alliance: "SKYTEAM", primaryHex: 0x006496, secondaryHex: 0x003C5A, accentHex: 0x68C8F2, cabinClasses: ["PRESTIGE SUITE · 商务舱"]),
        "AAR": AirlineBranding(icaoPrefix: "AAR", iataCode: "OZ", nameCN: "韩亚航空", nameEN: "ASIANA AIRLINES", alliance: "STAR ALLIANCE", primaryHex: 0x635951, secondaryHex: 0x3A342F, accentHex: 0xD71920, cabinClasses: ["BUSINESS SMARTIUM"]),
        "SIA": AirlineBranding(icaoPrefix: "SIA", iataCode: "SQ", nameCN: "新加坡航空", nameEN: "SINGAPORE AIRLINES", alliance: "STAR ALLIANCE", primaryHex: 0x1D2F5D, secondaryHex: 0x0F1936, accentHex: 0xF5A800, cabinClasses: ["SUITES · 新航套房", "BUSINESS · 商务舱"]),
        "THA": AirlineBranding(icaoPrefix: "THA", iataCode: "TG", nameCN: "泰国国际航空", nameEN: "THAI AIRWAYS", alliance: "STAR ALLIANCE", primaryHex: 0x522377, secondaryHex: 0x31144A, accentHex: 0xF3B229, cabinClasses: ["ROYAL SILK · 皇家丝绸舱"]),

        // Europe & Middle East
        "BAW": AirlineBranding(icaoPrefix: "BAW", iataCode: "BA", nameCN: "英国航空", nameEN: "BRITISH AIRWAYS", alliance: "ONEWORLD", primaryHex: 0x075AAA, secondaryHex: 0x032E5A, accentHex: 0xEB2226, cabinClasses: ["CLUB SUITE · 公务舱", "FIRST · 头等舱"]),
        "DLH": AirlineBranding(icaoPrefix: "DLH", iataCode: "LH", nameCN: "汉莎航空", nameEN: "LUFTHANSA", alliance: "STAR ALLIANCE", primaryHex: 0x05164D, secondaryHex: 0x020B29, accentHex: 0xFFAD00, cabinClasses: ["ALLEGRIS BUSINESS", "FIRST CLASS"]),
        "AFR": AirlineBranding(icaoPrefix: "AFR", iataCode: "AF", nameCN: "法国航空", nameEN: "AIR FRANCE", alliance: "SKYTEAM", primaryHex: 0x002157, secondaryHex: 0x001333, accentHex: 0xFF2822, cabinClasses: ["LA PREMIÈRE", "AFFAIRES · 商务舱"]),
        "KLM": AirlineBranding(icaoPrefix: "KLM", iataCode: "KL", nameCN: "荷兰皇家航空", nameEN: "KLM ROYAL DUTCH", alliance: "SKYTEAM", primaryHex: 0x00A1DE, secondaryHex: 0x005B82, accentHex: 0xFFFFFF, cabinClasses: ["WORLD BUSINESS"]),
        "SWR": AirlineBranding(icaoPrefix: "SWR", iataCode: "LX", nameCN: "瑞士国际航空", nameEN: "SWISS INTL AIR LINES", alliance: "STAR ALLIANCE", primaryHex: 0xCC0000, secondaryHex: 0x7A0000, accentHex: 0xFFFFFF, cabinClasses: ["SWISS SENSES BUSINESS"]),
        "UAE": AirlineBranding(icaoPrefix: "UAE", iataCode: "EK", nameCN: "阿联酋航空", nameEN: "EMIRATES", alliance: "SKYWARDS", primaryHex: 0xD71921, secondaryHex: 0x7D0D12, accentHex: 0xC69C6D, cabinClasses: ["FIRST CLASS PRIVATE SUITE", "BUSINESS"]),
        "QTR": AirlineBranding(icaoPrefix: "QTR", iataCode: "QR", nameCN: "卡塔尔航空", nameEN: "QATAR AIRWAYS", alliance: "ONEWORLD", primaryHex: 0x5C0632, secondaryHex: 0x36031D, accentHex: 0xD9A76A, cabinClasses: ["QSUITE · 空中私人套房"]),
        "THY": AirlineBranding(icaoPrefix: "THY", iataCode: "TK", nameCN: "土耳其航空", nameEN: "TURKISH AIRLINES", alliance: "STAR ALLIANCE", primaryHex: 0xC70A0C, secondaryHex: 0x750507, accentHex: 0xFFFFFF, cabinClasses: ["BUSINESS CLASS"]),

        // North America & Oceania
        "DAL": AirlineBranding(icaoPrefix: "DAL", iataCode: "DL", nameCN: "达美航空", nameEN: "DELTA AIR LINES", alliance: "SKYTEAM", primaryHex: 0x003366, secondaryHex: 0x001A38, accentHex: 0xE01933, cabinClasses: ["DELTA ONE SUITE"]),
        "UAL": AirlineBranding(icaoPrefix: "UAL", iataCode: "UA", nameCN: "美国联合航空", nameEN: "UNITED AIRLINES", alliance: "STAR ALLIANCE", primaryHex: 0x0033A0, secondaryHex: 0x001B57, accentHex: 0x62B5E5, cabinClasses: ["UNITED POLARIS"]),
        "AAL": AirlineBranding(icaoPrefix: "AAL", iataCode: "AA", nameCN: "美国航空", nameEN: "AMERICAN AIRLINES", alliance: "ONEWORLD", primaryHex: 0x0078D2, secondaryHex: 0x004175, accentHex: 0xC30019, cabinClasses: ["FLAGSHIP BUSINESS"]),
        "ASA": AirlineBranding(icaoPrefix: "ASA", iataCode: "AS", nameCN: "阿拉斯加航空", nameEN: "ALASKA AIRLINES", alliance: "ONEWORLD", primaryHex: 0x01426A, secondaryHex: 0x00243B, accentHex: 0x4CBB17, cabinClasses: ["FIRST CLASS"]),
        "ACA": AirlineBranding(icaoPrefix: "ACA", iataCode: "AC", nameCN: "加拿大航空", nameEN: "AIR CANADA", alliance: "STAR ALLIANCE", primaryHex: 0x1F252D, secondaryHex: 0x111419, accentHex: 0xF01428, cabinClasses: ["SIGNATURE CLASS"]),
        "QFA": AirlineBranding(icaoPrefix: "QFA", iataCode: "QF", nameCN: "澳洲航空", nameEN: "QANTAS", alliance: "ONEWORLD", primaryHex: 0xE40000, secondaryHex: 0x8A0000, accentHex: 0xFFFFFF, cabinClasses: ["FIRST SUITE", "BUSINESS"])
    ]

    public static let defaultBranding = AirlineBranding(
        icaoPrefix: "STR",
        iataCode: "ST",
        nameCN: "平流层航空",
        nameEN: "STRATO AIRWAYS",
        alliance: "STRATOSPHERE ALLIANCE",
        primaryHex: 0x14365D,
        secondaryHex: 0x0A1B32,
        accentHex: 0x59D1FF,
        cabinClasses: ["STRATO FIRST · 平流层头等舱"]
    )

    public static func branding(forCallsign callsign: String, fallbackName: String? = nil) -> AirlineBranding {
        let prefix = String(callsign.trimmingCharacters(in: .whitespacesAndNewlines).prefix(3)).uppercased()
        if let found = themes[prefix] {
            return found
        }
        if let fallbackName, !fallbackName.isEmpty, fallbackName != "商业航班" {
            return AirlineBranding(
                icaoPrefix: prefix.isEmpty ? "AIR" : prefix,
                iataCode: String(prefix.prefix(2)),
                nameCN: fallbackName,
                nameEN: fallbackName.uppercased(),
                alliance: "GLOBAL CARRIER",
                primaryHex: 0x1A365D,
                secondaryHex: 0x0C1C33,
                accentHex: 0x59D1FF,
                cabinClasses: ["BUSINESS · 公务舱"]
            )
        }
        return defaultBranding
    }
}

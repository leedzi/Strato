import Foundation

/// Colours used to dress a boarding pass and flight card for an airline. Plain RGB values so the
/// table is usable from any target; no logos or trademarks are bundled.
struct AirlineBrand: Hashable, Sendable {
    var primary: UInt32
    var secondary: UInt32
    var accent: UInt32
    /// True when the colours come from the curated table rather than being derived.
    var curated: Bool

    private static func b(_ p: UInt32, _ s: UInt32, _ a: UInt32) -> AirlineBrand {
        AirlineBrand(primary: p, secondary: s, accent: a, curated: true)
    }

    private static let table: [String: AirlineBrand] = [
        // Greater China
        "CCA": b(0xB81C22, 0x7A0E13, 0xF5C242), "CES": b(0x1A2E5A, 0x0F1C3A, 0xE6394A),
        "CSN": b(0x008ACB, 0x005288, 0xE8483A), "CHH": b(0xC8161D, 0x8F0B10, 0xE5B85B),
        "CSC": b(0xB5121B, 0x6E0B10, 0xF3B63F), "CXA": b(0x005BAC, 0x00376B, 0x4EC3FF),
        "CSZ": b(0xD71920, 0x8C0E13, 0xFFD100), "CDG": b(0x0A4DA2, 0x062E63, 0xF5A623),
        "DKH": b(0x8C1D40, 0x591128, 0xE8C07D), "CQH": b(0x009944, 0x00602B, 0x8CE6B0),
        "CSH": b(0xC8102E, 0x7F0A1D, 0xF2F2F2), "CBJ": b(0xC8102E, 0x7A0A1C, 0xF0C75E),
        "GCR": b(0x0066B3, 0x003D6B, 0xF28C28), "CPA": b(0x006564, 0x003D3C, 0x74D4C8),
        "HKE": b(0x6A1B9A, 0x3F0F5C, 0xE1BEE7), "CRK": b(0xC8102E, 0x7A0A1C, 0xD4AF37),
        "EVA": b(0x006940, 0x004228, 0xF37021), "CAL": b(0x2B3990, 0x1B235B, 0xF06488),
        "SJX": b(0x3D352E, 0x1F1B18, 0xD4AF37), "AMU": b(0xB8232F, 0x70141C, 0xE8C36A),
        "CKK": b(0x1A2E5A, 0x0F1C3A, 0xE6394A), "CSS": b(0x1B1B1B, 0x000000, 0xE60012),
        "CGZ": b(0x0072BC, 0x00447A, 0xF7941D), "OKA": b(0x003F87, 0x002654, 0xF5A800),
        "LKE": b(0xD0021B, 0x8A0112, 0xF8E71C), "CUA": b(0x0057A8, 0x00346B, 0xE31B23),
        "TBA": b(0xC8102E, 0x7A0A1C, 0xF5C242), "KNA": b(0xC8102E, 0x7A0A1C, 0xF0C75E),
        // Japan & Korea
        "ANA": b(0x13448F, 0x0A2552, 0x00A0E9), "JAL": b(0xC8102E, 0x6E0819, 0xFFFFFF),
        "APJ": b(0xC2298A, 0x7A1757, 0xF7B5DE), "SKY": b(0x004EA2, 0x002E63, 0xFFD200),
        "JJP": b(0xFF5000, 0xB33800, 0xFFFFFF), "SFJ": b(0x1A1A1A, 0x000000, 0xFFFFFF),
        "KAL": b(0x0064A8, 0x003C66, 0x8ED8F8), "AAR": b(0x635951, 0x3A342F, 0xD9434B),
        "JJA": b(0xFF5A00, 0xB33F00, 0xFFFFFF), "JNA": b(0x8DC63F, 0x56802A, 0xFFFFFF),
        "TWB": b(0xD22C26, 0x8A1C18, 0xFFFFFF),
        // South-East & South Asia
        "SIA": b(0x1D2F5D, 0x0F1936, 0xF5A800), "TGW": b(0xFFD200, 0xC79F00, 0x1A1A1A),
        "THA": b(0x522377, 0x31144A, 0xF3B229), "MAS": b(0x0E3A7C, 0x08234B, 0xE03A3E),
        "AXM": b(0xE32526, 0x9A1819, 0xFFFFFF), "GIA": b(0x00607A, 0x003B4B, 0x4FC3C8),
        "PAL": b(0x0038A8, 0x002066, 0xFCD116), "CEB": b(0xFFD100, 0xC7A300, 0x0057B8),
        "HVN": b(0x005F6B, 0x003A42, 0xD4AF37), "VJC": b(0xE31837, 0x9A1025, 0xFFD200),
        "AIC": b(0xD91E36, 0x8F1323, 0xF5A623), "IGO": b(0x001B94, 0x000F57, 0x7FB3FF),
        // Europe
        "BAW": b(0x075AAA, 0x032E5A, 0xEB2226), "VIR": b(0xE10A0A, 0x8F0606, 0x5B2A86),
        "EZY": b(0xFF6600, 0xB34700, 0xFFFFFF), "RYR": b(0x073590, 0x041F57, 0xF1C933),
        "DLH": b(0x05164D, 0x020B29, 0xFFAD00), "EWG": b(0x8F174F, 0x5A0E31, 0x4FC3F7),
        "AFR": b(0x002157, 0x001333, 0xFF4B46), "KLM": b(0x00A1DE, 0x005B82, 0xFFFFFF),
        "SWR": b(0xCC0000, 0x7A0000, 0xFFFFFF), "AUA": b(0xD81E05, 0x8A1303, 0xFFFFFF),
        "IBE": b(0xD7192D, 0x8A101D, 0xFFCC00), "VLG": b(0xFFCC00, 0xC79F00, 0x4A4A4A),
        "ITY": b(0x0A2E6E, 0x061C44, 0xC9A45C), "SAS": b(0x00287A, 0x00184A, 0x7FB3FF),
        "FIN": b(0x0B1560, 0x060C38, 0xFFFFFF), "TAP": b(0x00A651, 0x006632, 0xE4002B),
        "THY": b(0xC70A0C, 0x750507, 0xFFFFFF), "AFL": b(0x003D7C, 0x00244A, 0xF28C28),
        "WZZ": b(0xC6007E, 0x7D0050, 0x06038D), "NAX": b(0xD81939, 0x8A1024, 0x003251),
        "LOT": b(0x11397E, 0x0A224B, 0xC9A45C), "BEL": b(0x0B1F5C, 0x061236, 0xE4002B),
        "EIN": b(0x006272, 0x003B45, 0x8CC63F),
        // Middle East & Africa
        "UAE": b(0xD71921, 0x7D0D12, 0xC69C6D), "QTR": b(0x5C0632, 0x36031D, 0xD9A76A),
        "ETD": b(0xBD8B13, 0x7A5A0C, 0x1A1A1A), "SVA": b(0x006C35, 0x004221, 0xC9A45C),
        "ELY": b(0x003DA5, 0x002466, 0xFFFFFF), "ETH": b(0x078930, 0x04561E, 0xFCDD09),
        "FDB": b(0x00539F, 0x003261, 0xF58220), "MSR": b(0x00256F, 0x001645, 0xC9A45C),
        // Americas
        "DAL": b(0x003366, 0x001A38, 0xE01933), "UAL": b(0x0033A0, 0x001B57, 0x62B5E5),
        "AAL": b(0x0078D2, 0x004175, 0xC30019), "SWA": b(0x304CB2, 0x1D2E6D, 0xFFBF27),
        "JBU": b(0x003876, 0x002148, 0x0090DA), "ASA": b(0x01426A, 0x00243B, 0x4CBB17),
        "ACA": b(0x1F252D, 0x111419, 0xF01428), "WJA": b(0x00AAA5, 0x006663, 0x003D5B),
        "AMX": b(0x0B2343, 0x061426, 0xE4002B), "LAN": b(0x1B0088, 0x100052, 0xE8114B),
        "TAM": b(0x1B0088, 0x100052, 0xE8114B), "AVA": b(0xE4002B, 0x8F001B, 0xFFFFFF),
        "NKS": b(0xFFEC00, 0xC7B800, 0x1A1A1A), "FFT": b(0x006643, 0x003F29, 0xFFFFFF),
        // Oceania
        "QFA": b(0xE40000, 0x8A0000, 0xFFFFFF), "VOZ": b(0xE1163C, 0x8F0E26, 0x5B2A86),
        "JST": b(0xFF5115, 0xB3390F, 0x1A1A1A), "ANZ": b(0x1A1A1A, 0x000000, 0xFFFFFF),
        // Cargo
        "FDX": b(0x4D148C, 0x2E0C54, 0xFF6600), "UPS": b(0x351C15, 0x1F100C, 0xFFB500),
        "CLX": b(0x00205B, 0x001236, 0xE4002B), "GTI": b(0x003DA5, 0x002466, 0xF5A800)
    ]

    /// Brand for an ICAO airline code. Unknown airlines get a stable colour derived from the code,
    /// so the same airline always looks the same.
    static func forICAO(_ icao: String?) -> AirlineBrand {
        guard let icao, !icao.isEmpty else {
            return AirlineBrand(primary: 0x14365D, secondary: 0x0A1B32, accent: 0x59D1FF, curated: false)
        }
        if let known = table[icao.uppercased()] { return known }
        let h = Double(icao.uppercased().hashValueStable % 360)
        return AirlineBrand(
            primary: hsl(h, 0.55, 0.30),
            secondary: hsl(h, 0.60, 0.16),
            accent: hsl((h + 28).truncatingRemainder(dividingBy: 360), 0.80, 0.72),
            curated: false
        )
    }

    static func hsl(_ h: Double, _ s: Double, _ l: Double) -> UInt32 {
        let c = (1 - abs(2 * l - 1)) * s
        let hp = h / 60
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        var r = 0.0, g = 0.0, b = 0.0
        switch Int(hp) {
        case 0: (r, g, b) = (c, x, 0)
        case 1: (r, g, b) = (x, c, 0)
        case 2: (r, g, b) = (0, c, x)
        case 3: (r, g, b) = (0, x, c)
        case 4: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        let m = l - c / 2
        func ch(_ v: Double) -> UInt32 { UInt32(min(max((v + m) * 255, 0), 255).rounded()) }
        return (ch(r) << 16) | (ch(g) << 8) | ch(b)
    }

    /// Relative luminance of a colour, 0 (black) ... 1 (white), for choosing readable text.
    static func luminance(_ rgb: UInt32) -> Double {
        func lin(_ v: UInt32) -> Double {
            let c = Double(v) / 255
            return c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin((rgb >> 16) & 0xFF) + 0.7152 * lin((rgb >> 8) & 0xFF) + 0.0722 * lin(rgb & 0xFF)
    }

    /// Whether white text is readable on the primary colour.
    var prefersLightText: Bool { AirlineBrand.luminance(primary) < 0.42 }
}

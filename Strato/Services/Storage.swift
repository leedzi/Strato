import Foundation

/// JSON files in Application Support. Small, atomic, and readable if something ever needs rescuing.
enum Storage {
    /// Set once at launch; demo runs use a separate folder so they never touch real data.
    static var folderName = "Strato"

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = base.appendingPathComponent(folderName, isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    static func url(_ name: String) -> URL { root.appendingPathComponent(name) }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: url(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    @discardableResult
    static func save<T: Encodable>(_ value: T, to name: String) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else { return false }
        return write(data, to: name)
    }

    @discardableResult
    static func write(_ data: Data, to name: String) -> Bool {
        do {
            try data.write(to: url(name), options: .atomic)
            return true
        } catch {
            return false
        }
    }

    static func data(_ name: String) -> Data? { try? Data(contentsOf: url(name)) }

    static func remove(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }

    enum File {
        static let logbook = "logbook.json"
        static let session = "session.json"
        static let routes = "routes.json"
        static let settings = "settings.json"
    }
}

enum MapProvider: String, Codable, CaseIterable, Identifiable, Sendable {
    case auto
    case appleDark
    case apple3D
    case gaode
    case google

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "智能卫星图"
        case .appleDark: return "Apple 深色"
        case .apple3D: return "Apple 3D 地球"
        case .gaode: return "高德卫星图"
        case .google: return "Google 卫星图"
        }
    }

    var detail: String {
        switch self {
        case .auto: return "国内高德，海外 Google，连不上自动换 Esri"
        case .appleDark: return "简洁深色矢量地图"
        case .apple3D: return "真实地形与立体地球"
        case .gaode: return "全球都用高德"
        case .google: return "全球都用 Google"
        }
    }

    var symbol: String {
        switch self {
        case .auto: return "wand.and.stars"
        case .appleDark: return "moon.fill"
        case .apple3D: return "globe.asia.australia.fill"
        case .gaode: return "map.fill"
        case .google: return "globe"
        }
    }

    var usesTiles: Bool { self == .auto || self == .gaode || self == .google }
}

enum AmbientPreset: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case cabin
    case wind
    case rain

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: return "静音"
        case .cabin: return "巡航机舱"
        case .wind: return "高空气流"
        case .rain: return "雨夜"
        }
    }

    var symbol: String {
        switch self {
        case .off: return "speaker.slash.fill"
        case .cabin: return "airplane"
        case .wind: return "wind"
        case .rain: return "cloud.rain.fill"
        }
    }
}

/// User preferences. Every field has a default so older files keep loading as fields are added.
struct AppSettings: Codable, Equatable, Sendable {
    var mapProvider: MapProvider = .auto
    var passengerName = ""
    var cabin: CabinClass = .business
    var ambient: AmbientPreset = .off
    var chimes = true
    var haptics = true
    var notifications = true
    var useGlobalSnapshot = true
    var keepAwake = false
    var finderMinutes = 60
    var lastLat = 31.2
    var lastLon = 121.5
    var lastRadiusKm = 420.0
    var hasOnboarded = false

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func value<T: Decodable>(_ key: CodingKeys, _ fallback: T) -> T {
            (try? c.decodeIfPresent(T.self, forKey: key)) ?? fallback
        }
        let d = AppSettings()
        mapProvider = value(.mapProvider, d.mapProvider)
        passengerName = value(.passengerName, d.passengerName)
        cabin = value(.cabin, d.cabin)
        ambient = value(.ambient, d.ambient)
        chimes = value(.chimes, d.chimes)
        haptics = value(.haptics, d.haptics)
        notifications = value(.notifications, d.notifications)
        useGlobalSnapshot = value(.useGlobalSnapshot, d.useGlobalSnapshot)
        keepAwake = value(.keepAwake, d.keepAwake)
        finderMinutes = value(.finderMinutes, d.finderMinutes)
        lastLat = value(.lastLat, d.lastLat)
        lastLon = value(.lastLon, d.lastLon)
        lastRadiusKm = value(.lastRadiusKm, d.lastRadiusKm)
        hasOnboarded = value(.hasOnboarded, d.hasOnboarded)
    }

    /// Name printed on boarding passes, in the SURNAME/GIVEN style of real ones.
    var passengerDisplay: String {
        let trimmed = passengerName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "STRATO/FLYER" : trimmed.uppercased()
    }
}

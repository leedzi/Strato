import Foundation
import WidgetKit

/// Shared persistence between Strato app and StratoWidget.
public final class SharedStore: @unchecked Sendable {
    public static let shared = SharedStore()
    public static let appGroupID = "group.com.strato.focus"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Keys {
        static let activeFlight = "strato.activeFlightSnapshot"
        static let logbook = "strato.flightLogbook"
        static let preferredScope = "strato.preferredScope.v2"
        static let mapStyleRaw = "strato.mapStyle"
        static let adsbLolApiKey = "strato.adsbLolApiKey"
    }

    private init() {
        if let groupDefaults = UserDefaults(suiteName: Self.appGroupID) {
            self.defaults = groupDefaults
        } else {
            self.defaults = .standard
        }
    }

    public func saveActiveFlight(_ snapshot: ActiveFlightSnapshot?) {
        if let snapshot, let data = try? encoder.encode(snapshot) {
            defaults.set(data, forKey: Keys.activeFlight)
        } else {
            defaults.removeObject(forKey: Keys.activeFlight)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func loadActiveFlight() -> ActiveFlightSnapshot? {
        guard let data = defaults.data(forKey: Keys.activeFlight) else { return nil }
        return try? decoder.decode(ActiveFlightSnapshot.self, from: data)
    }

    public func saveLogbook(_ records: [FocusSessionRecord]) {
        if let data = try? encoder.encode(records) {
            defaults.set(data, forKey: Keys.logbook)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    public func loadLogbook() -> [FocusSessionRecord] {
        guard let data = defaults.data(forKey: Keys.logbook) else { return [] }
        return (try? decoder.decode([FocusSessionRecord].self, from: data)) ?? []
    }

    public var preferredScope: RadarScope {
        get {
            guard let raw = defaults.string(forKey: Keys.preferredScope),
                  let scope = RadarScope(rawValue: raw) else {
                return .globalLive
            }
            return scope
        }
        set {
            defaults.set(newValue.rawValue, forKey: Keys.preferredScope)
        }
    }

    public var mapStyleRaw: String {
        get { defaults.string(forKey: Keys.mapStyleRaw) ?? "imagery" }
        set { defaults.set(newValue, forKey: Keys.mapStyleRaw) }
    }

    public var adsbLolApiKey: String {
        get { defaults.string(forKey: Keys.adsbLolApiKey) ?? "" }
        set { defaults.set(newValue, forKey: Keys.adsbLolApiKey) }
    }
}

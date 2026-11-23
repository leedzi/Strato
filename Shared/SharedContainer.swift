import Foundation
import WidgetKit

/// What the widgets and the Live Activity need to know, written by the app whenever it changes.
struct WidgetSnapshot: Codable, Sendable {
    struct Flight: Codable, Sendable, Hashable {
        var flightNumber: String
        var airlineICAO: String?
        var originCode: String
        var originCity: String
        var destinationCode: String
        var destinationCity: String
        var tagTitle: String
        var seat: String
        var startedAt: Date
        /// When the session is due to end (touchdown or timer).
        var plannedEnd: Date
        /// A virtual departure time chosen so that a linear bar from here to `plannedEnd`
        /// shows the aircraft's real progress along its route right now.
        var routeStart: Date
        var isPaused: Bool
        /// Seconds left, frozen, while paused.
        var pausedRemaining: TimeInterval?
        var phaseTitle: String
        var altitudeFt: Int
        var groundSpeedKt: Int
        var simulated: Bool
    }

    struct Stats: Codable, Sendable, Hashable {
        var todayMinutes = 0
        var weekMinutes = 0
        var totalMinutes = 0
        var totalKm = 0.0
        var sessions = 0
        var streak = 0
        var tierTitle = "蓝天卡"
        /// Minutes for each of the last seven days, oldest first.
        var week: [Int] = Array(repeating: 0, count: 7)
        var lastFlightNumber: String?
        var lastRoute: String?
        var lastEndedAt: Date?
    }

    var flight: Flight?
    var stats = Stats()
    var updatedAt = Date()

    static let empty = WidgetSnapshot()
}

extension WidgetSnapshot.Flight {
    /// Picks `routeStart` so a linear time bar reads `fraction` now and 1 at `plannedEnd`.
    static func routeStart(fraction: Double, now: Date, plannedEnd: Date) -> Date {
        let f = min(max(fraction, 0), 0.985)
        let remaining = max(plannedEnd.timeIntervalSince(now), 1)
        return now.addingTimeInterval(-remaining * f / (1 - f))
    }

    func fraction(at now: Date) -> Double {
        let total = plannedEnd.timeIntervalSince(routeStart)
        guard total > 1 else { return 1 }
        let reference = isPaused ? plannedEnd.addingTimeInterval(-(pausedRemaining ?? 0)) : now
        return min(max(reference.timeIntervalSince(routeStart) / total, 0), 1)
    }
}

/// Storage shared between the app and its widget extension.
///
/// Sideloading tools re-sign the app with the user's own team, which changes the app group
/// identifier, so the group is discovered at run time rather than hard-coded. When no group is
/// available (for example inside LiveContainer) the app still works; only the widgets go without data.
enum SharedContainer {
    static let defaultGroup = "group.com.strato.focus"
    private static let fileName = "widget-snapshot.json"

    /// Candidate group identifiers, most specific first.
    static var groupCandidates: [String] {
        var out: [String] = []
        let bundles = [Bundle.main, hostBundle].compactMap { $0 }
        for bundle in bundles {
            // AltStore and older SideStore builds record the groups they provisioned under this key.
            if let groups = bundle.object(forInfoDictionaryKey: "ALTAppGroups") as? [String] {
                out.append(contentsOf: groups)
            }
        }
        for bundle in bundles {
            // Otherwise the provisioning profile the signer embedded says which groups we were given
            // (for sideloaded apps that is "group.com.strato.focus.<TEAMID>").
            out.append(contentsOf: provisionedGroups(in: bundle))
        }
        out.append(defaultGroup)
        var seen = Set<String>()
        let unique = out.filter { seen.insert($0).inserted }
        // Prefer groups derived from ours over unrelated ones the profile may also list.
        return unique.filter { $0.hasPrefix(defaultGroup) } + unique.filter { !$0.hasPrefix(defaultGroup) }
    }

    /// The containing app's bundle when running inside the widget extension.
    private static var hostBundle: Bundle? {
        let url = Bundle.main.bundleURL
        guard url.pathExtension == "appex" else { return nil }
        return Bundle(url: url.deletingLastPathComponent().deletingLastPathComponent())
    }

    /// App groups listed in a bundle's embedded.mobileprovision. The file is a signed envelope
    /// around a property list, so the plist is cut out of the raw bytes.
    static func provisionedGroups(in bundle: Bundle) -> [String] {
        guard let url = bundle.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: url) else { return [] }
        return groups(inProvisioningProfile: data)
    }

    static func groups(inProvisioningProfile data: Data) -> [String] {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex) else { return [] }
        let plistData = data.subdata(in: start.lowerBound..<end.upperBound)
        guard let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
              let entitlements = plist["Entitlements"] as? [String: Any],
              let groups = entitlements["com.apple.security.application-groups"] as? [String] else { return [] }
        return groups
    }

    static let containerURL: URL? = {
        for group in groupCandidates {
            if let url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: group) {
                return url
            }
        }
        return nil
    }()

    static var isAvailable: Bool { containerURL != nil }

    static func read() -> WidgetSnapshot {
        guard let url = containerURL?.appendingPathComponent(fileName),
              let data = try? Data(contentsOf: url) else { return .empty }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return (try? decoder.decode(WidgetSnapshot.self, from: data)) ?? .empty
    }

    /// Writes the snapshot and asks WidgetKit to redraw. Returns false when there is no shared container.
    @discardableResult
    static func write(_ snapshot: WidgetSnapshot, reloadWidgets: Bool = true) -> Bool {
        guard let url = containerURL?.appendingPathComponent(fileName) else { return false }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        guard let data = try? encoder.encode(snapshot) else { return false }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            return false
        }
        if reloadWidgets {
            WidgetCenter.shared.reloadAllTimelines()
        }
        return true
    }
}

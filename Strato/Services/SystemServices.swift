import ActivityKit
import CoreLocation
import Foundation
import UIKit
import UserNotifications

// MARK: - Local notifications

/// The landing notification, so a session can finish while the phone is locked or the app is closed.
enum Notifier {
    private static let landingID = "strato.landing"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }

    static func isAuthorized() async -> Bool {
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        return status == .authorized || status == .provisional || status == .ephemeral
    }

    static func scheduleLanding(at date: Date, title: String, body: String, sound: Bool = true) {
        let interval = date.timeIntervalSinceNow
        guard interval > 2 else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = sound ? .default : nil
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        // Re-adding with the same identifier replaces the pending request.
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: landingID, content: content, trigger: trigger))
    }

    static func cancelLanding() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [landingID])
        center.removeDeliveredNotifications(withIdentifiers: [landingID])
    }
}

// MARK: - Live Activity

@MainActor
final class LiveActivityController {
    private var activity: Activity<StratoFlightAttributes>?

    var isAvailable: Bool { ActivityAuthorizationInfo().areActivitiesEnabled }
    var isRunning: Bool { activity != nil }

    /// Picks up an activity that survived an app relaunch.
    func adoptExisting() {
        if activity == nil { activity = Activity<StratoFlightAttributes>.activities.first }
    }

    func start(attributes: StratoFlightAttributes, state: StratoFlightAttributes.ContentState) {
        guard isAvailable else { return }
        let stale = Activity<StratoFlightAttributes>.activities
        Task {
            for old in stale { await old.end(nil, dismissalPolicy: .immediate) }
        }
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: state.plannedEnd.addingTimeInterval(180)),
                pushType: nil
            )
        } catch {
            // Not available here (for example inside LiveContainer); the app works without it.
            activity = nil
        }
    }

    func update(_ state: StratoFlightAttributes.ContentState) {
        guard let activity else { return }
        let stale: Date? = state.isPaused ? nil : state.plannedEnd.addingTimeInterval(180)
        Task {
            await activity.update(ActivityContent(state: state, staleDate: stale))
        }
    }

    func end(_ state: StratoFlightAttributes.ContentState?, keepFor seconds: TimeInterval) {
        let ending = activity.map { [$0] } ?? Activity<StratoFlightAttributes>.activities
        activity = nil
        Task {
            for a in ending {
                let content = state.map { ActivityContent(state: $0, staleDate: nil) }
                await a.end(content, dismissalPolicy: seconds > 0 ? .after(Date().addingTimeInterval(seconds)) : .immediate)
            }
        }
    }
}

// MARK: - Haptics

@MainActor
enum Haptics {
    static var enabled = true

    static func tap() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func thud() {
        guard enabled else { return }
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func success() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        guard enabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

// MARK: - Where am I

/// One-shot location lookup for "what is flying over me".
@MainActor
final class Locator: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<GeoPoint?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func current() async -> GeoPoint? {
        if continuation != nil { return nil }
        let status = manager.authorizationStatus
        if status == .denied || status == .restricted { return nil }
        return await withCheckedContinuation { (c: CheckedContinuation<GeoPoint?, Never>) in
            continuation = c
            if status == .notDetermined {
                manager.requestWhenInUseAuthorization()
            } else {
                manager.requestLocation()
            }
            // Never leave the caller waiting if the system stays silent.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 12_000_000_000)
                self?.finish(nil)
            }
        }
    }

    private func finish(_ point: GeoPoint?) {
        continuation?.resume(returning: point)
        continuation = nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            guard self.continuation != nil else { return }
            switch status {
            case .authorizedWhenInUse, .authorizedAlways:
                self.manager.requestLocation()
            case .denied, .restricted:
                self.finish(nil)
            default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let point = locations.last.map { GeoPoint($0.coordinate.latitude, $0.coordinate.longitude) }
        Task { @MainActor in self.finish(point) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in self.finish(nil) }
    }
}

// MARK: - Aircraft photos

struct AircraftPhoto: Hashable, Sendable {
    var image: URL
    var page: URL?
    var photographer: String
}

/// Looks up a photo of the actual airframe on Planespotters.net, which asks for a credit and a link back.
actor PhotoService {
    private struct Response: Decodable {
        struct Photo: Decodable {
            struct Image: Decodable { var src: String? }
            var thumbnail_large: Image?
            var thumbnail: Image?
            var link: String?
            var photographer: String?
        }
        var photos: [Photo]?
    }

    private let http: HTTPFetching
    private var cache: [String: AircraftPhoto?] = [:]

    init(http: HTTPFetching) {
        self.http = http
    }

    func photo(hex: String) async -> AircraftPhoto? {
        let key = hex.lowercased()
        if let hit = cache[key] { return hit }
        guard key.count == 6, let url = URL(string: "https://api.planespotters.net/pub/photos/hex/\(key)") else { return nil }
        guard let result = try? await http.get(url, timeout: 8), result.status == 200,
              let decoded = try? JSONDecoder().decode(Response.self, from: result.data) else {
            return nil
        }
        var found: AircraftPhoto?
        if let p = decoded.photos?.first, let src = p.thumbnail_large?.src ?? p.thumbnail?.src, let image = URL(string: src) {
            found = AircraftPhoto(image: image, page: p.link.flatMap { URL(string: $0) }, photographer: p.photographer ?? "")
        }
        cache[key] = found
        return found
    }
}

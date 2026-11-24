import Foundation
import Observation
import SwiftUI

/// A request for the map to move, issued by the model and consumed once by the map view.
struct MapCommand: Equatable {
    enum Kind: Equatable {
        case center(GeoPoint, distanceMeters: Double)
        case fit([GeoPoint])
    }
    var id: Int
    var kind: Kind
}

struct FinderState {
    enum Phase: Equatable {
        case idle
        case snapshot
        case resolving(done: Int, total: Int)
        case finished
    }

    var phase: Phase = .idle
    var targetMinutes = 60
    var isUnlimited = false
    var matchingMinutes: Int? { isUnlimited ? nil : targetMinutes }
    var destination: Airport?
    var results: [FlightMatch] = []
    /// True when nothing landed inside the tolerance and the closest alternatives are shown instead.
    var relaxed = false
    var note: String?
    /// Aircraft considered in the last search.
    var scanned = 0

    var isSearching: Bool {
        switch phase {
        case .snapshot, .resolving: return true
        default: return false
        }
    }
}

struct QuickTakeoffRequest: Identifiable {
    var id = UUID()
    var origin: Airport
    var destination: Airport?
}

@MainActor
@Observable
final class AppModel {
    // MARK: Dependencies

    let reference: ReferenceData
    let isDemo: Bool
    /// Set by UI tests: system permission prompts would block them.
    @ObservationIgnored private let quiet = UserDefaults.standard.bool(forKey: "uitest")
    @ObservationIgnored let demo: DemoWorld?
    @ObservationIgnored let clock: @Sendable () -> Date
    @ObservationIgnored let adsb: ADSBClient
    @ObservationIgnored let opensky: OpenSkyClient
    @ObservationIgnored let routes: RouteResolver
    @ObservationIgnored let photos: PhotoService
    @ObservationIgnored let activity = LiveActivityController()
    let cloudSync: ICloudDriveSync
    @ObservationIgnored private var locator: Locator?

    // MARK: State

    var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            Storage.save(settings, to: Storage.File.settings)
            Haptics.enabled = settings.haptics
            if settings.notifications != oldValue.notifications || settings.chimes != oldValue.chimes {
                lastNotifiedEnd = nil
                if !settings.notifications { Notifier.cancelLanding() }
                syncNotification()
            }
        }
    }

    // Radar
    var flights: [LiveFlight] = []
    var focus: LiveFlight?
    var focusPhoto: AircraftPhoto?
    var radarCenter: GeoPoint
    var radarRadiusKm: Double
    var isScanning = false
    var radarNote: String?
    var lastScan: Date?
    var mapCommand: MapCommand?
    var radarVisible = false

    // Finding and boarding
    var finder = FinderState()
    var boarding: LiveFlight?
    var quickTakeoffRequest: QuickTakeoffRequest?
    var lookupNote: String?
    var isLookingUp = false

    // Session
    var session: FocusSession?
    var arrival: FocusRecord?
    var announcement: String?

    // Logbook
    var records: [FocusRecord] = []
    var stats = FocusStats()
    var dataError: String?

    // MARK: Private

    @ObservationIgnored private var commandCounter = 0
    @ObservationIgnored private var scanTask: Task<Void, Never>?
    @ObservationIgnored private var routeTask: Task<Void, Never>?
    @ObservationIgnored private var radarLoop: Task<Void, Never>?
    @ObservationIgnored private var finderTask: Task<Void, Never>?
    @ObservationIgnored private var sessionLoop: Task<Void, Never>?
    @ObservationIgnored private var announcementTask: Task<Void, Never>?
    @ObservationIgnored private var isPolling = false
    @ObservationIgnored private var lastPollAt = Date.distantPast
    @ObservationIgnored private var lastNotifiedEnd: Date?
    @ObservationIgnored private var lastPublishedEnd: Date?
    @ObservationIgnored private var lastPublishedPhase: FlightPhase?
    @ObservationIgnored private var isActive = true
    @ObservationIgnored private var cloudTask: Task<Void, Never>?
    @ObservationIgnored private var cloudTaskID: UUID?
    @ObservationIgnored private var cloudLoop: Task<Void, Never>?
    @ObservationIgnored private var cloudNeedsSync = false
    @ObservationIgnored private var cloudRevision = 0
    @ObservationIgnored private var lastPublishedAt = Date.distantPast
    @ObservationIgnored private var lastSnapshotAt = Date.distantPast
    @ObservationIgnored private var lastSignalLost = false

    // MARK: Init

    init(demoSpeed: Double? = nil) {
        let reference = ReferenceData.shared
        self.reference = reference
        if let demoSpeed {
            let world = DemoWorld(reference: reference, speed: demoSpeed)
            let fetcher = DemoFetcher(world: world)
            self.demo = world
            self.isDemo = true
            self.clock = { world.now() }
            self.adsb = ADSBClient(http: fetcher, clock: { world.now() }, minInterval: 0.02)
            self.opensky = OpenSkyClient(http: fetcher, clock: { world.now() }, minimumCount: 1)
            self.routes = RouteResolver(http: fetcher, reference: reference)
            self.photos = PhotoService(http: fetcher)
            Storage.folderName = "StratoDemo"
            try? FileManager.default.removeItem(at: Storage.root)
        } else {
            let fetcher = URLSessionFetcher()
            self.demo = nil
            self.isDemo = false
            self.clock = { Date() }
            self.adsb = ADSBClient(http: fetcher)
            self.opensky = OpenSkyClient(http: fetcher)
            self.routes = RouteResolver(http: fetcher, reference: reference)
            self.photos = PhotoService(http: fetcher)
        }

        self.cloudSync = ICloudDriveSync()
        var loaded = Storage.load(AppSettings.self, from: Storage.File.settings) ?? AppSettings()
        // `-startLat` / `-startLon` open the radar somewhere specific (used by the live smoke test).
        let defaults = UserDefaults.standard
        if defaults.object(forKey: "startLat") != nil, defaults.object(forKey: "startLon") != nil {
            loaded.lastLat = defaults.double(forKey: "startLat")
            loaded.lastLon = defaults.double(forKey: "startLon")
        }
        if isDemo {
            loaded.hasOnboarded = true
            loaded.notifications = false
            loaded.passengerName = "LI/DEMO"
        }
        self.settings = loaded
        self.radarCenter = GeoPoint(loaded.lastLat, loaded.lastLon)
        self.radarRadiusKm = loaded.lastRadiusKm
        Haptics.enabled = loaded.haptics

        if let world = demo {
            records = world.seedRecords(calendar: .current)
        } else {
            records = Storage.load([FocusRecord].self, from: Storage.File.logbook) ?? []
        }
        records.sort { $0.endedAt > $1.endedAt }
        finder.targetMinutes = loaded.finderMinutes
        finder.isUnlimited = loaded.finderUnlimited
        if let landed = records.first(where: { $0.outcome == .landed }),
           loaded.lastAirportCode == nil || landed.endedAt > (loaded.lastAirportAt ?? .distantPast) {
            settings.lastAirportCode = landed.destination.code
            settings.lastAirportAt = landed.endedAt
        }
        if defaults.object(forKey: "startLat") == nil,
           let code = settings.lastAirportCode, let airport = reference.airport(code: code) {
            radarCenter = airport.point
            radarRadiusKm = 260
        }
        refreshStats()

        if let saved = Storage.load(FocusSession.self, from: Storage.File.session) {
            session = saved
            activity.adoptExisting()
            startSessionLoop()
        }

        Task { [routes] in
            if let data = Storage.data(Storage.File.routes) { await routes.importCache(data) }
        }
        cloudSync.onRemoteChange = { [weak self] in self?.scheduleCloudSync(delay: 0.5) }
        if !isDemo { startCloudLoop() }
        publishSnapshot()
    }

    // MARK: Small helpers

    var now: Date { clock() }

    /// A completed landing determines where the next journey begins.
    var homeAirport: Airport? {
        if let code = settings.lastAirportCode, let airport = reference.airport(code: code) { return airport }
        if let landed = records.first(where: { $0.outcome == .landed }) { return landed.destination }
        return reference.nearestAirport(to: radarCenter, maxKm: 800)?.airport ?? reference.airport(code: "PVG")
    }

    func requestQuickTakeoff(origin: Airport? = nil, destination: Airport? = nil) {
        guard session == nil, let airport = origin ?? homeAirport else { return }
        boarding = nil
        finder.targetMinutes = settings.finderMinutes
        finder.isUnlimited = settings.finderUnlimited
        quickTakeoffRequest = QuickTakeoffRequest(origin: airport, destination: destination)
    }

    func openWidgetURL(_ url: URL) {
        guard url.scheme == "strato" else { return }
        switch url.host {
        case "takeoff":
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let origin = items.first(where: { $0.name == "origin" }).flatMap { $0.value }.flatMap { reference.airport(code: $0) }
            let destination = items.first(where: { $0.name == "destination" }).flatMap { $0.value }.flatMap { reference.airport(code: $0) }
            requestQuickTakeoff(origin: origin, destination: destination)
        case "airport":
            guard session == nil, let airport = homeAirport else { return }
            clearFocus()
            radarCenter = airport.point
            command(.center(airport.point, distanceMeters: 520_000))
            refreshRadar()
        default: break
        }
    }

    private func rememberLanding(_ record: FocusRecord) {
        guard record.outcome == .landed,
              record.endedAt >= (settings.lastAirportAt ?? .distantPast) else { return }
        settings.lastAirportCode = record.destination.code
        settings.lastAirportAt = record.endedAt
        settings.lastLat = record.destination.lat
        settings.lastLon = record.destination.lon
        settings.lastRadiusKm = 260
        radarCenter = record.destination.point
        radarRadiusKm = 260
        command(.center(record.destination.point, distanceMeters: 520_000))
    }

    private func command(_ kind: MapCommand.Kind) {
        commandCounter += 1
        mapCommand = MapCommand(id: commandCounter, kind: kind)
    }

    func airlineName(for flight: LiveFlight) -> String {
        reference.airlineName(icao: flight.airlineICAO, fallback: flight.route?.airlineName)
    }

    func brand(for flight: LiveFlight) -> AirlineBrand {
        AirlineBrand.forICAO(flight.airlineICAO)
    }

    func announce(_ text: String, chime: SoundEngine.Chime? = nil) {
        announcement = text
        if let chime, settings.chimes { SoundEngine.shared.chime(chime) }
        announcementTask?.cancel()
        announcementTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            guard !Task.isCancelled else { return }
            self?.announcement = nil
        }
    }

    private func refreshStats() {
        stats = FocusStats(records: records, now: clock(), calendar: .current, reference: reference)
    }

    /// Persist the completed batch before removing the recoverable active session.
    private func saveRecords(_ updated: [FocusRecord]) -> Bool {
        let ordered = updated.sorted {
            if $0.endedAt != $1.endedAt { return $0.endedAt > $1.endedAt }
            if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
        guard isDemo || Storage.save(ordered, to: Storage.File.logbook) else {
            dataError = "飞行记录暂时无法写入本机，请检查可用空间后重试。当前航程已保留。"
            return false
        }
        records = ordered
        cloudRevision += 1
        scheduleCloudSync()
        return true
    }

    private func saveRouteCacheIfNeeded() {
        guard !isDemo else { return }
        Task { [routes] in
            guard await routes.dirty, let data = await routes.exportCache() else { return }
            Storage.write(data, to: Storage.File.routes)
        }
    }

    // MARK: App lifecycle

    func sceneBecameActive() {
        isActive = true
        refreshStats()
        publishSnapshot()
        startCloudLoop()
        scheduleCloudSync(delay: 0)
        if session != nil {
            Task { await pollAircraft(force: true) }
        } else if radarVisible {
            startRadarLoop()
        }
    }

    func sceneResignedActive() {
        isActive = false
        cloudLoop?.cancel()
        cloudLoop = nil
        radarLoop?.cancel()
        radarLoop = nil
        if let session { Storage.save(session, to: Storage.File.session) }
        saveRouteCacheIfNeeded()
        publishSnapshot()
    }

    // MARK: Radar

    func radarAppeared() {
        radarVisible = true
        if session == nil { startRadarLoop() }
    }

    func radarDisappeared() {
        radarVisible = false
        radarLoop?.cancel()
        radarLoop = nil
    }

    private func startRadarLoop() {
        radarLoop?.cancel()
        radarLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.scan(quiet: true)
                try? await Task.sleep(nanoseconds: 15_000_000_000)
            }
        }
    }

    /// The map moved: remember where, and rescan if it went somewhere new.
    func mapRegionChanged(center: GeoPoint, radiusKm: Double, byUser: Bool) {
        let moved = Geo.distanceKm(center, radarCenter)
        let previousRadius = radarRadiusKm
        radarCenter = center
        radarRadiusKm = radiusKm
        guard byUser, session == nil else { return }
        settings.lastLat = center.lat
        settings.lastLon = center.lon
        settings.lastRadiusKm = min(max(radiusKm, 60), 900)
        if moved > max(60, previousRadius * 0.35) || abs(radiusKm - previousRadius) > previousRadius * 0.4 {
            scanTask?.cancel()
            scanTask = Task { [weak self] in
                // Wait for the gesture to settle before spending a request.
                try? await Task.sleep(nanoseconds: 700_000_000)
                guard !Task.isCancelled else { return }
                await self?.scan(quiet: false)
            }
        }
    }

    func refreshRadar() {
        scanTask?.cancel()
        scanTask = Task { [weak self] in await self?.scan(quiet: false) }
    }

    private func scan(quiet: Bool) async {
        guard session == nil else { return }
        if isScanning { return }
        isScanning = true
        defer { isScanning = false }

        let center = radarCenter
        let nm = Int(min(Double(ADSBClient.maxRadiusNM), max(40, radarRadiusKm / Geo.kmPerNM)))
        let result = await adsb.aircraft(near: center, radiusNM: nm)
        guard !Task.isCancelled else { return }
        guard let list = result else {
            if !quiet || flights.isEmpty { radarNote = "实时数据暂时连不上，稍后会自动重试" }
            return
        }

        let known = Dictionary(flights.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var merged: [LiveFlight] = []
        merged.reserveCapacity(list.count)
        for s in list where s.isAirborne && !s.callsign.isEmpty {
            var route = known[s.hex]?.route
            if let r = route, r.callsign != s.callsign || !FlightMath.isPlausible(state: s, origin: r.origin, destination: r.destination) {
                route = nil
            }
            merged.append(LiveFlight(state: s, route: route))
        }
        merged.sort { Geo.distanceKm($0.state.point, center) < Geo.distanceKm($1.state.point, center) }
        if merged.count > 320 { merged.removeLast(merged.count - 320) }
        flights = merged
        lastScan = clock()
        radarNote = merged.isEmpty ? "这片空域暂时没有接收到航班，换个地方看看" : nil

        if let f = focus, let fresh = merged.first(where: { $0.id == f.id }) {
            focus = LiveFlight(state: fresh.state.inheritingDetails(from: f.state), route: fresh.route ?? f.route)
        } else if let f = focus, !f.isSimulated {
            // The selected aircraft is outside the scanned area (found by number, or the map moved on):
            // keep it current on its own.
            if case .ok(let fresh) = await adsb.aircraft(hex: f.id), fresh.callsign == f.callsign, focus?.id == f.id {
                focus = LiveFlight(state: fresh.inheritingDetails(from: f.state), route: f.route)
            }
        }
        resolveRoutes(for: merged)
    }

    /// Looks up routes for aircraft on screen that do not have one yet, nearest first.
    private func resolveRoutes(for list: [LiveFlight]) {
        let wanted = list.filter { $0.route == nil && $0.state.hasAirlineCallsign }.prefix(70).map { $0.state }
        guard !wanted.isEmpty else { return }
        routeTask?.cancel()
        routeTask = Task { [weak self, routes] in
            _ = await routes.routes(for: Array(wanted), concurrency: 8) { flight in
                guard flight.route != nil else { return }
                Task { @MainActor in self?.attach(flight) }
            }
            self?.saveRouteCacheIfNeeded()
        }
    }

    private func attach(_ resolved: LiveFlight) {
        guard let route = resolved.route else { return }
        if let i = flights.firstIndex(where: { $0.id == resolved.id }), flights[i].callsign == route.callsign {
            flights[i].route = route
        }
        if focus?.id == resolved.id, focus?.callsign == route.callsign {
            focus?.route = route
        }
    }

    // MARK: Selection

    func select(_ id: String) {
        guard let flight = flights.first(where: { $0.id == id }) ?? (focus?.id == id ? focus : nil) else { return }
        setFocus(flight, moveMap: false)
    }

    func setFocus(_ flight: LiveFlight, moveMap: Bool) {
        let changed = focus?.id != flight.id
        focus = flight
        if changed { focusPhoto = nil }
        Haptics.tap()
        if moveMap {
            command(.center(flight.state.point, distanceMeters: 900_000))
        }
        if flight.route == nil, flight.state.hasAirlineCallsign {
            Task { [weak self, routes] in
                if let route = await routes.route(for: flight.state) {
                    self?.attach(LiveFlight(state: flight.state, route: route))
                }
            }
        }
        if changed, !isDemo, !flight.isSimulated {
            let hex = flight.id
            Task { [weak self, photos] in
                let photo = await photos.photo(hex: hex)
                if self?.focus?.id == hex { self?.focusPhoto = photo }
            }
        }
    }

    func clearFocus() {
        focus = nil
        focusPhoto = nil
    }

    func showWholeRoute() {
        guard let f = focus, let r = f.route else { return }
        command(.fit([r.origin.point, f.state.point, r.destination.point]))
    }

    /// Centres the radar on the user's position ("what is flying over me").
    func goToMyLocation() {
        guard !isDemo else {
            command(.center(GeoPoint(31.2, 121.5), distanceMeters: 700_000))
            return
        }
        if locator == nil { locator = Locator() }
        Task { [weak self] in
            guard let self, let here = await self.locator?.current() else {
                self?.radarNote = "没有拿到定位，可以在系统设置里允许 Strato 使用位置"
                return
            }
            self.command(.center(here, distanceMeters: 500_000))
        }
    }

    // MARK: Finding a flight by number

    func lookUp(flightNumber text: String) {
        let candidates = reference.callsignCandidates(forFlightNumber: text)
        guard !candidates.isEmpty else {
            lookupNote = "没认出这个航班号，试试 CA1831 或 CCA1831 这样的写法"
            return
        }
        isLookingUp = true
        lookupNote = nil
        Task { [weak self, adsb, routes] in
            defer { self?.isLookingUp = false }
            for callsign in candidates {
                let hits = await adsb.aircraft(callsign: callsign)
                guard let state = hits.first(where: { $0.callsign == callsign }) else { continue }
                let route = await routes.route(for: state)
                guard let self else { return }
                self.setFocus(LiveFlight(state: state, route: route), moveMap: true)
                self.lookupNote = nil
                return
            }
            self?.lookupNote = "\(text.uppercased()) 现在不在接收范围内，可能还没起飞或已经落地"
        }
    }

    // MARK: Finder

    /// Busy airspace swept when the worldwide snapshot is unavailable. Each sweep covers a 460 km radius.
    private static let hubs: [GeoPoint] = [
        GeoPoint(31.2, 121.5), GeoPoint(39.9, 116.4), GeoPoint(23.1, 113.3), GeoPoint(30.6, 104.0),
        GeoPoint(35.6, 139.8), GeoPoint(37.5, 126.5), GeoPoint(1.4, 103.9), GeoPoint(13.7, 100.7),
        GeoPoint(28.6, 77.1), GeoPoint(25.3, 55.4), GeoPoint(41.3, 28.7), GeoPoint(50.0, 8.6),
        GeoPoint(51.5, -0.5), GeoPoint(49.0, 2.5), GeoPoint(40.5, -3.6), GeoPoint(40.6, -73.8),
        GeoPoint(42.0, -87.9), GeoPoint(33.6, -84.4), GeoPoint(32.9, -97.0), GeoPoint(34.0, -118.4),
        GeoPoint(-33.9, 151.2)
    ]

    func findFlights() {
        finderTask?.cancel()
        settings.finderMinutes = finder.targetMinutes
        settings.finderUnlimited = finder.isUnlimited
        finderTask = Task { [weak self] in await self?.runFinder() }
    }

    func cancelFinder() {
        finderTask?.cancel()
        if finder.isSearching { finder.phase = finder.results.isEmpty ? .idle : .finished }
    }

    private func runFinder() async {
        let target = finder.matchingMinutes
        let destination = finder.destination
        finder.phase = .snapshot
        finder.results = []
        finder.relaxed = false
        finder.note = nil
        finder.scanned = 0

        // 1. Everything in the air, in one request if possible.
        var pool: [AircraftState] = []
        var maxAge: TimeInterval = 180
        if settings.useGlobalSnapshot, let snapshot = await opensky.snapshot(maxAge: 120) {
            pool = snapshot
            maxAge = 600
        }
        if Task.isCancelled { return }
        if pool.isEmpty {
            // Fall back to sweeping busy airspace, or the approaches to the chosen airport.
            var centres = Self.hubs
            if let d = destination {
                centres = [d.point] + [45.0, 135, 225, 315].map { Geo.destination(from: d.point, bearing: $0, distanceKm: 620) }
            } else {
                centres.insert(radarCenter, at: 0)
            }
            var seen = Set<String>()
            for c in centres {
                if Task.isCancelled { return }
                if let list = await adsb.aircraft(near: c, radiusNM: ADSBClient.maxRadiusNM) {
                    for s in list where seen.insert(s.hex).inserted { pool.append(s) }
                    finder.scanned = pool.count
                }
            }
        }
        finder.scanned = pool.count
        guard !pool.isEmpty else {
            finder.phase = .finished
            finder.note = "现在连不上实时航班数据，检查一下网络再试"
            return
        }

        // 2. Spend route lookups on the aircraft most likely to fit, nearby ones first.
        let now = clock()
        let home = radarCenter
        var scored: [(AircraftState, Double)] = []
        for s in pool.shuffled() {
            guard var p = Matching.lookupPriority(state: s, targetMinutes: target, destination: destination, now: now, maxAge: maxAge) else { continue }
            if destination == nil, Geo.distanceKm(s.point, home) < 4500 { p += 25 }
            scored.append((s, p))
        }
        scored.sort { $0.1 > $1.1 }
        let candidates = scored.map { $0.0 }
        let batchSize = 120
        let maxLookups = destination == nil ? 480 : 240

        var resolved: [LiveFlight] = []
        var offset = 0
        while offset < min(candidates.count, maxLookups) {
            if Task.isCancelled { return }
            let batch = Array(candidates[offset..<min(offset + batchSize, candidates.count, maxLookups)])
            let total = min(candidates.count, maxLookups)
            let base = offset
            let counter = Counter()
            let found = await routes.routes(for: batch, concurrency: 10) { [weak self] _ in
                let done = counter.increment()
                if done % 6 == 0 {
                    Task { @MainActor in
                        guard let self, self.finder.isSearching else { return }
                        self.finder.phase = .resolving(done: base + done, total: total)
                    }
                }
            }
            if Task.isCancelled { return }
            resolved.append(contentsOf: found.filter { $0.route != nil })
            offset += batch.count
            let ranked = Matching.rank(flights: resolved, targetMinutes: target, destination: destination, now: clock(), strict: true, maxAge: maxAge)
            finder.results = Array(ranked.prefix(30))
            finder.phase = .resolving(done: offset, total: total)
            if ranked.count >= 10 { break }
        }

        if finder.results.isEmpty {
            let loose = Matching.rank(flights: resolved, targetMinutes: target, destination: destination, now: clock(), strict: false, maxAge: maxAge)
            finder.results = Array(loose.prefix(10))
            finder.relaxed = !loose.isEmpty
            if loose.isEmpty {
                finder.note = destination == nil
                    ? "这一刻没有找到合适的航班，换个时长试试"
                    : "现在没有飞往\(destination!.city)的航班在接收范围内"
            }
        }
        finder.phase = .finished
        saveRouteCacheIfNeeded()
        await refreshTopResults(target: target, destination: destination, maxAge: maxAge)
    }

    /// The global snapshot is coarse and lacks aircraft details; fetch precise data for the best matches.
    private func refreshTopResults(target: Int?, destination: Airport?, maxAge: TimeInterval) async {
        let top = finder.results.prefix(6).map { $0.flight }
        guard top.contains(where: { $0.state.source == .opensky }) else { return }
        var flights = finder.results.map { $0.flight }
        for flight in top {
            if Task.isCancelled { return }
            guard case .ok(let fresh) = await adsb.aircraft(hex: flight.id), fresh.callsign == flight.callsign,
                  let route = flight.route else { continue }
            guard let i = flights.firstIndex(where: { $0.id == flight.id }) else { continue }
            let updated = LiveFlight(state: fresh, route: route)
            flights[i] = updated
        }
        finder.results = Array(Matching.rank(flights: flights, targetMinutes: target, destination: destination,
                                             now: clock(), strict: !finder.relaxed, maxAge: maxAge).prefix(30))
    }

    // MARK: Boarding

    /// Opens the boarding sheet for a flight, fetching a fresh position first if ours is not precise.
    func prepareBoarding(_ flight: LiveFlight) {
        boarding = flight
        guard !flight.isSimulated, flight.state.source == .opensky || clock().timeIntervalSince(flight.state.positionTime) > 30 else { return }
        Task { [weak self, adsb] in
            guard case .ok(let fresh) = await adsb.aircraft(hex: flight.id), fresh.callsign == flight.callsign else { return }
            guard let self, self.boarding?.id == flight.id else { return }
            self.boarding = LiveFlight(state: fresh.inheritingDetails(from: flight.state), route: flight.route)
        }
    }

    func makeSimulatedFlight(origin: Airport, destination: Airport, airlineICAO: String, minutes: Int) -> LiveFlight {
        let digits = 100 + abs((origin.code + destination.code).hashValueStable) % 8900
        return SimFlight.make(
            origin: origin, destination: destination, minutes: minutes, airlineICAO: airlineICAO,
            flightDigits: digits, reference: reference, now: clock()
        ).flight
    }

    func nextSequence() -> Int {
        (records.count * 37 + 11) % 180 + 1
    }

    /// Starts a focus session on a flight. `timerMinutes` nil means "until it lands".
    func board(_ flight: LiveFlight, tag: FocusTag, seat: String, cabin: CabinClass, gate: String, timerMinutes: Int?) {
        guard let route = flight.route else { return }
        let start = clock()
        var s = FocusSession(
            flight: flight, route: route, tag: tag, seat: seat, cabin: cabin, gate: gate,
            sequence: nextSequence(), startedAt: start, timerMinutes: timerMinutes
        )
        if flight.isSimulated {
            // A simulated flight runs to a fixed schedule, counted from where it was created.
            let remaining = Geo.distanceKm(flight.state.point, route.destination.point)
            let minutes = SimFlight.minutes(forRemainingKm: remaining) + (flight.state.onGround ? 4 : 0)
            s.estimatedLanding = start.addingTimeInterval(minutes * 60)
        }
        session = s
        boarding = nil
        focus = nil
        settings.cabin = cabin
        radarLoop?.cancel()
        radarLoop = nil
        finderTask?.cancel()
        lastPollAt = clock()
        lastNotifiedEnd = nil
        lastPublishedEnd = nil
        Storage.save(s, to: Storage.File.session)

        if settings.ambient != .off { SoundEngine.shared.play(settings.ambient) }
        if settings.chimes { SoundEngine.shared.chime(.attention) }
        Haptics.thud()

        activity.start(
            attributes: StratoFlightAttributes(
                flightNumber: flight.displayNumber,
                airlineICAO: flight.airlineICAO,
                originCode: route.origin.code,
                originCity: route.origin.city,
                destinationCode: route.destination.code,
                destinationCity: route.destination.city,
                tagTitle: tag.title,
                seat: seat,
                simulated: flight.isSimulated
            ),
            state: activityState(for: s, at: start)
        )
        lastPublishedEnd = s.plannedEnd(at: start)
        lastPublishedPhase = s.phase
        lastPublishedAt = start
        syncNotification()
        publishSnapshot()
        startSessionLoop()
        command(.center(flight.state.point, distanceMeters: 520_000))
    }

    // MARK: Session loop

    private func startSessionLoop() {
        sessionLoop?.cancel()
        sessionLoop = Task { [weak self] in
            while !Task.isCancelled {
                await self?.sessionTick()
                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }
        }
    }

    private func pollInterval(for s: FocusSession) -> TimeInterval {
        let remaining = Geo.distanceKm(s.flight.state.point, s.route.destination.point)
        if remaining < 80 { return 6 }
        if s.signalLost { return 20 }
        return 12
    }

    private func sessionTick() async {
        guard let s = session else { return }
        let now = clock()
        if s.flight.isSimulated {
            if now.timeIntervalSince(s.lastFixAt) >= 15 {
                session?.refreshSimulated(at: now)
                sessionChanged(save: false)
            }
        } else if now.timeIntervalSince(lastPollAt) >= pollInterval(for: s) {
            await pollAircraft(force: false)
        }
        evaluateSession()
    }

    private func pollAircraft(force: Bool) async {
        guard let s = session, !s.flight.isSimulated else {
            evaluateSession()
            return
        }
        if isPolling { return }
        isPolling = true
        lastPollAt = clock()
        // If one feed has lost the aircraft, ask the other.
        let preferred: DataSource = s.consecutiveMisses % 2 == 1 ? .adsblol : .adsbfi
        let result = await adsb.aircraft(hex: s.flight.id, preferred: preferred)
        isPolling = false
        guard session?.id == s.id else { return }
        let now = clock()
        switch result {
        case .ok(let fix) where session?.accepts(fix) == true:
            session?.apply(fix: fix, at: now)
        default:
            session?.recordMiss()
        }
        sessionChanged(save: true)
        evaluateSession()
    }

    /// Announces milestones and ends the session when it is over.
    private func evaluateSession() {
        guard session != nil else { return }
        let now = clock()
        if let milestones = session?.newMilestones(at: now), let last = milestones.last, isActive {
            announce(last.announcement, chime: last == .finalApproach ? .attention : .notice)
        }
        if let done = session?.completion(at: now) {
            finish(done)
        }
    }

    private func sessionChanged(save: Bool) {
        guard let s = session else { return }
        if save { Storage.save(s, to: Storage.File.session) }
        let now = clock()
        let end = s.plannedEnd(at: now)
        let phase = s.phase
        let shifted = lastPublishedEnd.map { abs($0.timeIntervalSince(end)) > 20 } ?? true
        let phaseChanged = phase != lastPublishedPhase
        let signalChanged = s.signalLost != lastSignalLost
        if shifted || phaseChanged || signalChanged || now.timeIntervalSince(lastPublishedAt) >= 30 {
            lastPublishedEnd = end
            lastPublishedPhase = phase
            lastPublishedAt = now
            lastSignalLost = s.signalLost
            activity.update(activityState(for: s, at: now))
            if shifted || phaseChanged || signalChanged || now.timeIntervalSince(lastSnapshotAt) >= 60 {
                publishSnapshot()
            }
        }
        syncNotification()
    }

    func togglePause() {
        guard session != nil else { return }
        let now = clock()
        if session?.isPaused == true {
            session?.resume(at: now)
        } else {
            session?.pause(at: now)
        }
        Haptics.tap()
        lastPublishedEnd = nil
        sessionChanged(save: true)
    }

    func setAmbient(_ preset: AmbientPreset) {
        settings.ambient = preset
        if session != nil { SoundEngine.shared.play(preset) }
    }

    /// Ends the session now. Sessions shorter than a minute are not worth a logbook entry.
    func endEarly(save: Bool) {
        guard let s = session else { return }
        let now = clock()
        if save, s.focusSeconds(at: now) >= 60 {
            finish(FocusSession.Completion(outcome: .endedEarly, endedAt: now, estimated: false))
        } else {
            cleanUpSession(landedState: nil)
            session = nil
            publishSnapshot()
            if radarVisible { startRadarLoop() }
        }
    }

    private func finish(_ completion: FocusSession.Completion) {
        guard let s = session else { return }
        let record = s.record(completion)
        let updated = [record] + records.filter { $0.id != record.id }
        guard saveRecords(updated) else { return }
        cleanUpSession(landedState: completion.outcome == .endedEarly ? nil : activityState(for: s, at: completion.endedAt, landed: true))
        session = nil
        rememberLanding(record)
        refreshStats()
        publishSnapshot()
        if isActive {
            if completion.outcome != .endedEarly, settings.chimes { SoundEngine.shared.chime(.arrival) }
            Haptics.success()
        }
        arrival = record
        if radarVisible { startRadarLoop() }
    }

    private func cleanUpSession(landedState: StratoFlightAttributes.ContentState?) {
        sessionLoop?.cancel()
        sessionLoop = nil
        Storage.remove(Storage.File.session)
        SoundEngine.shared.stop()
        if !isDemo { Notifier.cancelLanding() }
        activity.end(landedState, keepFor: landedState == nil ? 0 : 900)
        lastNotifiedEnd = nil
        lastPublishedEnd = nil
        lastPublishedPhase = nil
        announcement = nil
        mapCommand = nil
    }

    // MARK: Notifications, Live Activity, widgets

    func enableNotifications() {
        guard !isDemo, !quiet else { return }
        Task { [weak self] in
            let granted = await Notifier.requestAuthorization()
            guard let self else { return }
            if !granted { self.settings.notifications = false }
            self.lastNotifiedEnd = nil
            self.syncNotification()
        }
    }

    private func syncNotification() {
        guard !isDemo, settings.notifications, let s = session else { return }
        let now = clock()
        if s.isPaused, s.timerMinutes != nil {
            if lastNotifiedEnd != nil {
                Notifier.cancelLanding()
                lastNotifiedEnd = nil
            }
            return
        }
        let end = s.plannedEnd(at: now)
        if let last = lastNotifiedEnd, abs(last.timeIntervalSince(end)) < 45 { return }
        lastNotifiedEnd = end
        let number = s.flight.displayNumber
        if s.timerMinutes != nil {
            Notifier.scheduleLanding(at: end, title: "专注时间到", body: "\(number) 还在飞往\(s.route.destination.city)，你的这一段已经完成。", sound: settings.chimes)
        } else {
            Notifier.scheduleLanding(at: end, title: "\(number) 预计已落地\(s.route.destination.city)", body: "这趟专注航程结束了，回来给登机牌盖章。", sound: settings.chimes)
        }
    }

    private func activityState(for s: FocusSession, at now: Date, landed: Bool = false) -> StratoFlightAttributes.ContentState {
        let end = landed ? now : s.plannedEnd(at: now)
        let routeStart: Date
        if s.timerMinutes != nil {
            routeStart = s.startedAt.addingTimeInterval(s.pausedSeconds(at: now))
        } else {
            routeStart = WidgetSnapshot.Flight.routeStart(fraction: s.progress(at: now).fraction, now: now, plannedEnd: end)
        }
        return StratoFlightAttributes.ContentState(
            plannedEnd: end,
            routeStart: routeStart,
            // Only a fixed timer stops when paused; a landing countdown keeps running.
            isPaused: s.isPaused && s.timerMinutes != nil,
            pausedRemaining: s.isPaused && s.timerMinutes != nil ? s.remainingSeconds(at: now) : nil,
            phaseTitle: landed ? (s.followsLanding ? "已落地" : "专注完成") : s.phase.title,
            altitudeFt: s.flight.state.altitudeFt ?? 0,
            groundSpeedKt: Int(s.flight.state.groundSpeedKt ?? 0),
            landed: landed,
            remainingKm: s.progress(at: now).remainingKm,
            focusStartedAt: now.addingTimeInterval(-s.focusSeconds(at: now)),
            focusSeconds: s.focusSeconds(at: now),
            focusPaused: s.isPaused,
            signalLost: s.signalLost,
            followsLanding: s.followsLanding,
            completionTitle: landed ? (s.followsLanding ? "已落地" : "专注完成") : nil
        )
    }

    func publishSnapshot() {
        var snapshot = WidgetSnapshot()
        func place(_ airport: Airport) -> WidgetSnapshot.Place {
            WidgetSnapshot.Place(code: airport.code, city: airport.city, lat: airport.lat, lon: airport.lon)
        }
        if let airport = homeAirport {
            snapshot.airport = place(airport)
            snapshot.airportSince = settings.lastAirportAt
            snapshot.destinations = reference.majorAirports
                .filter { $0.code != airport.code && Geo.distanceKm(airport.point, $0.point) > 60 }
                .sorted { Geo.distanceKm(airport.point, $0.point) < Geo.distanceKm(airport.point, $1.point) }
                .prefix(4)
                .map {
                    WidgetSnapshot.Destination(place: place($0), minutes: Int(SimFlight.fullMinutes(routeKm: Geo.distanceKm(airport.point, $0.point)).rounded()))
                }
        }
        if let last = records.first {
            snapshot.lastJourney = WidgetSnapshot.Journey(
                flightNumber: last.flightNumber, origin: place(last.origin), destination: place(last.destination),
                endedAt: last.endedAt, focusMinutes: last.focusMinutes, distanceKm: last.distanceKm,
                completed: last.completed, landed: last.outcome == .landed, simulated: last.simulated,
                path: last.path.count > 1 ? last.path : Geo.arc(
                    Geo.interpolate(last.origin.point, last.destination.point, last.boardedFraction),
                    Geo.interpolate(last.origin.point, last.destination.point, last.endFraction), segments: 30)
            )
        }
        snapshot.routes = records.prefix(40).map { record in
            let path = record.path.count > 1 ? record.path : Geo.arc(
                Geo.interpolate(record.origin.point, record.destination.point, record.boardedFraction),
                Geo.interpolate(record.origin.point, record.destination.point, record.endFraction), segments: 30)
            // Keep the shared file compact even after a long journey.
            guard path.count > 48 else { return path }
            return stride(from: 0, to: path.count, by: max(1, path.count / 40)).map { path[$0] } + [path[path.count - 1]]
        }
        snapshot.stats = WidgetSnapshot.Stats(
            todayMinutes: stats.todayMinutes,
            weekMinutes: stats.weekMinutes,
            totalMinutes: stats.totalMinutes,
            totalKm: stats.totalKm,
            sessions: stats.totalSessions,
            streak: stats.currentStreak,
            tierTitle: stats.tier.title,
            week: stats.daily.suffix(7).map { $0.minutes },
            lastFlightNumber: records.first?.flightNumber,
            lastRoute: records.first.map { "\($0.origin.code) → \($0.destination.code)" },
            lastEndedAt: records.first?.endedAt
        )
        if let s = session {
            let now = clock()
            let state = activityState(for: s, at: now)
            snapshot.flight = WidgetSnapshot.Flight(
                flightNumber: s.flight.displayNumber,
                airlineICAO: s.flight.airlineICAO,
                originCode: s.route.origin.code,
                originCity: s.route.origin.city,
                destinationCode: s.route.destination.code,
                destinationCity: s.route.destination.city,
                tagTitle: s.tag.title,
                seat: s.seat,
                startedAt: s.startedAt,
                plannedEnd: state.plannedEnd,
                routeStart: state.routeStart,
                isPaused: state.isPaused,
                pausedRemaining: state.pausedRemaining,
                phaseTitle: state.phaseTitle,
                altitudeFt: state.altitudeFt,
                groundSpeedKt: state.groundSpeedKt,
                simulated: s.flight.isSimulated
            )
        }
        snapshot.updatedAt = Date()
        SharedContainer.write(snapshot)
        lastSnapshotAt = clock()
    }

    // MARK: Logbook

    func delete(_ record: FocusRecord) {
        Task { [weak self] in
            guard let self else { return }
            do {
                if !isDemo { try await cloudSync.markDeleted([record.id]).value }
                let remaining = records.filter { $0.id != record.id }
                guard isDemo || Storage.save(remaining, to: Storage.File.logbook) else {
                    dataError = "没有足够空间保存更改，请释放空间后重试。"
                    return
                }
                records = remaining
                cloudRevision += 1
                refreshStats()
                publishSnapshot()
                scheduleCloudSync()
            } catch {
                dataError = error.localizedDescription
            }
        }
    }

    func eraseAllRecords() {
        let ids = records.map { $0.id }
        Task { [weak self] in
            guard let self else { return }
            do {
                if !isDemo { try await cloudSync.markDeleted(ids).value }
                let removed = Set(ids)
                let remaining = records.filter { !removed.contains($0.id) }
                guard isDemo || Storage.save(remaining, to: Storage.File.logbook) else {
                    dataError = "没有足够空间保存更改，请释放空间后重试。"
                    return
                }
                records = remaining
                cloudRevision += 1
                refreshStats()
                publishSnapshot()
                scheduleCloudSync()
            } catch {
                dataError = error.localizedDescription
            }
        }
    }

    // MARK: iCloud Drive logbook

    func connectICloudFolder(_ url: URL) {
        guard !isDemo else { return }
        Task { [weak self] in
            guard let self else { return }
            let revision = cloudRevision
            do {
                let merged = try await cloudSync.connect(to: url, records: records)
                if revision == cloudRevision { applyCloudRecords(merged) }
                else { scheduleCloudSync(delay: 0) }
                startCloudLoop()
            } catch {
                dataError = error.localizedDescription
            }
        }
    }

    func syncICloudNow() { scheduleCloudSync(delay: 0) }

    func disconnectICloud() {
        cloudTask?.cancel()
        cloudTask = nil
        cloudTaskID = nil
        cloudNeedsSync = false
        cloudSync.disconnect()
    }

    private func startCloudLoop() {
        guard !isDemo, isActive else { return }
        cloudLoop?.cancel()
        cloudLoop = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled, let self else { return }
                if cloudSync.isConnected { scheduleCloudSync(delay: 0) }
            }
        }
    }

    /// Coalesces writes and merges again if a local change happens during an external read.
    private func scheduleCloudSync(delay: TimeInterval = 0.7) {
        guard !isDemo, cloudSync.isConnected else { return }
        cloudNeedsSync = true
        guard cloudTask == nil else { return }
        let job = UUID()
        cloudTaskID = job
        cloudTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if cloudTaskID == job {
                    cloudTask = nil
                    cloudTaskID = nil
                }
            }
            if delay > 0 { try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            while cloudNeedsSync && !Task.isCancelled && cloudSync.isConnected {
                cloudNeedsSync = false
                let revision = cloudRevision
                do {
                    let merged = try await cloudSync.sync(records: records)
                    guard !Task.isCancelled else { return }
                    if revision == cloudRevision { applyCloudRecords(merged) }
                    else { cloudNeedsSync = true }
                } catch {
                    // The service keeps local records and exposes the reason for the next retry.
                    break
                }
            }
        }
    }

    private func applyCloudRecords(_ merged: [FocusRecord]) {
        guard merged != records else { return }
        guard Storage.save(merged, to: Storage.File.logbook) else {
            cloudSync.reportLocalSaveFailure()
            dataError = "合并后的记录暂时无法保存，本机和同步文件已保留。请检查可用空间。"
            return
        }
        records = merged
        if let latest = records.first(where: { $0.outcome == .landed }), latest.endedAt > (settings.lastAirportAt ?? .distantPast) {
            rememberLanding(latest)
        }
        refreshStats()
        publishSnapshot()
    }

    /// The logbook as pretty-printed JSON, for the share sheet.
    func exportLogbook() -> URL? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(records) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Strato-logbook.json")
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            return nil
        }
    }
}

/// A tiny thread-safe counter for progress callbacks that arrive off the main actor.
final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

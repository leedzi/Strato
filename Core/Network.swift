import Foundation

// MARK: - HTTP plumbing

struct HTTPResult: Sendable {
    var status: Int
    var data: Data
    var retryAfter: TimeInterval?
}

protocol HTTPFetching: Sendable {
    func get(_ url: URL, timeout: TimeInterval) async throws -> HTTPResult
}

final class URLSessionFetcher: HTTPFetching, @unchecked Sendable {
    /// Identifies the app to the volunteer-run feeds, as their terms ask.
    static let userAgent = "Strato/3.0 (iOS focus flight tracker; +https://github.com/leedzi/Strato)"

    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.httpMaximumConnectionsPerHost = 8
        config.waitsForConnectivity = false
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.session = URLSession(configuration: config)
    }

    func get(_ url: URL, timeout: TimeInterval) async throws -> HTTPResult {
        var request = URLRequest(url: url, timeoutInterval: timeout)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        let http = response as? HTTPURLResponse
        var retry: TimeInterval?
        if let h = http?.value(forHTTPHeaderField: "Retry-After") ?? http?.value(forHTTPHeaderField: "X-Rate-Limit-Retry-After-Seconds") {
            retry = TimeInterval(h)
        }
        return HTTPResult(status: http?.statusCode ?? 0, data: data, retryAfter: retry)
    }
}

/// Spaces out requests per host so we stay inside each feed's published rate limit.
actor HostThrottle {
    private var nextSlot: [String: Date] = [:]

    func acquire(_ key: String, interval: TimeInterval) async {
        let now = Date()
        let slot = max(nextSlot[key] ?? now, now)
        nextSlot[key] = slot.addingTimeInterval(interval)
        let wait = slot.timeIntervalSince(now)
        if wait > 0 {
            try? await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000))
        }
    }
}

// MARK: - Live positions

enum FeedResult<T: Sendable>: Sendable {
    case ok(T)
    /// The feed answered and has no such aircraft.
    case notFound
    /// Network or server trouble.
    case failed
}

struct SourceHealth: Sendable, Hashable {
    var lastSuccess: Date?
    var lastFailure: Date?
    var consecutiveFailures = 0
    var lastLatencyMs: Int?
    var blockedUntil: Date?

    var isHealthy: Bool { consecutiveFailures < 3 }
}

/// Reads live aircraft positions from the community ADS-B feeds, with failover between them.
actor ADSBClient {
    private let http: HTTPFetching
    private let clock: @Sendable () -> Date
    private let minInterval: TimeInterval?
    private let throttle = HostThrottle()
    private(set) var health: [DataSource: SourceHealth] = [:]

    /// `clock` stamps positions (a demo can run on a virtual clock); `minInterval` overrides the
    /// per-host request spacing and is only meant for offline fixtures.
    init(http: HTTPFetching, clock: @escaping @Sendable () -> Date = { Date() }, minInterval: TimeInterval? = nil) {
        self.http = http
        self.clock = clock
        self.minInterval = minInterval
    }

    static let maxRadiusNM = 250

    private func interval(for source: DataSource) -> TimeInterval {
        if let minInterval { return minInterval }
        // adsb.fi asks for no more than one request per second; be equally gentle with adsb.lol.
        return source == .adsbfi ? 1.05 : 0.6
    }

    private func pointURL(_ source: DataSource, _ p: GeoPoint, _ nm: Int) -> URL? {
        let lat = String(format: "%.4f", p.lat), lon = String(format: "%.4f", p.lon)
        switch source {
        case .adsbfi: return URL(string: "https://opendata.adsb.fi/api/v3/lat/\(lat)/lon/\(lon)/dist/\(nm)")
        case .adsblol: return URL(string: "https://api.adsb.lol/v2/point/\(lat)/\(lon)/\(nm)")
        default: return nil
        }
    }

    private func hexURL(_ source: DataSource, _ hex: String) -> URL? {
        switch source {
        case .adsbfi: return URL(string: "https://opendata.adsb.fi/api/v2/hex/\(hex)")
        case .adsblol: return URL(string: "https://api.adsb.lol/v2/hex/\(hex)")
        default: return nil
        }
    }

    private func callsignURL(_ source: DataSource, _ callsign: String) -> URL? {
        switch source {
        case .adsbfi: return URL(string: "https://opendata.adsb.fi/api/v2/callsign/\(callsign)")
        case .adsblol: return URL(string: "https://api.adsb.lol/v2/callsign/\(callsign)")
        default: return nil
        }
    }

    /// Feeds in the order to try them: healthy ones first, the caller's preference leading.
    private func order(preferred: DataSource?) -> [DataSource] {
        let now = Date()
        var list: [DataSource] = [.adsbfi, .adsblol]
        if let preferred, let i = list.firstIndex(of: preferred) {
            list.remove(at: i)
            list.insert(preferred, at: 0)
        }
        func usable(_ s: DataSource) -> Bool {
            guard let h = health[s] else { return true }
            if let blocked = h.blockedUntil, blocked > now { return false }
            return true
        }
        let good = list.filter(usable)
        let bad = list.filter { !usable($0) }
        return good + bad
    }

    private func note(_ source: DataSource, success: Bool, latencyMs: Int?, retryAfter: TimeInterval? = nil) {
        var h = health[source] ?? SourceHealth()
        if success {
            h.lastSuccess = Date()
            h.consecutiveFailures = 0
            h.lastLatencyMs = latencyMs
            h.blockedUntil = nil
        } else {
            h.lastFailure = Date()
            h.consecutiveFailures += 1
            if let retryAfter {
                h.blockedUntil = Date().addingTimeInterval(min(max(retryAfter, 5), 300))
            } else if h.consecutiveFailures >= 3 {
                h.blockedUntil = Date().addingTimeInterval(45)
            }
        }
        health[source] = h
    }

    private func fetch(_ source: DataSource, _ url: URL, timeout: TimeInterval) async -> [AircraftState]? {
        await throttle.acquire(source.rawValue, interval: interval(for: source))
        let started = Date()
        do {
            let result = try await http.get(url, timeout: timeout)
            guard result.status == 200 else {
                note(source, success: false, latencyMs: nil, retryAfter: result.status == 429 ? (result.retryAfter ?? 30) : nil)
                return nil
            }
            guard let list = Feeds.decodeReadsb(result.data, source: source, fetchedAt: clock()) else {
                note(source, success: false, latencyMs: nil)
                return nil
            }
            note(source, success: true, latencyMs: Int(Date().timeIntervalSince(started) * 1000))
            return list
        } catch {
            // A request abandoned because the caller moved on says nothing about the feed.
            if !Task.isCancelled { note(source, success: false, latencyMs: nil) }
            return nil
        }
    }

    /// Aircraft within `radiusNM` (max 250) of a point. nil when every feed failed.
    func aircraft(near p: GeoPoint, radiusNM: Int, preferred: DataSource? = nil) async -> [AircraftState]? {
        let nm = min(max(radiusNM, 5), Self.maxRadiusNM)
        for source in order(preferred: preferred) {
            guard let url = pointURL(source, p, nm) else { continue }
            if let list = await fetch(source, url, timeout: 12) { return list }
        }
        return nil
    }

    /// Current state of one airframe by ICAO 24-bit address.
    func aircraft(hex: String, preferred: DataSource? = nil) async -> FeedResult<AircraftState> {
        let clean = hex.lowercased()
        guard clean.count == 6, clean.unicodeScalars.allSatisfy({ ($0.value >= 48 && $0.value <= 57) || ($0.value >= 97 && $0.value <= 102) }) else {
            return .notFound
        }
        for source in order(preferred: preferred) {
            guard let url = hexURL(source, clean) else { continue }
            // The feeds share most receivers, so one clear answer is enough; the second feed is
            // only asked when the first could not be reached (it has a small daily allowance).
            if let list = await fetch(source, url, timeout: 10) {
                if let match = list.first(where: { $0.hex == clean }) { return .ok(match) }
                return .notFound
            }
        }
        return .failed
    }

    /// Airborne aircraft currently using a radio callsign, across feeds.
    func aircraft(callsign: String) async -> [AircraftState] {
        let cs = Callsign.clean(callsign)
        guard Callsign.isSafeForURL(cs) else { return [] }
        for source in order(preferred: nil) {
            guard let url = callsignURL(source, cs) else { continue }
            if let list = await fetch(source, url, timeout: 10) { return list }
        }
        return []
    }
}

// MARK: - Global snapshot

/// OpenSky's anonymous API returns every aircraft it can see worldwide in one request, which is what
/// makes "find me a flight landing in two hours, anywhere" practical. It is rate limited by daily
/// credits, so snapshots are cached and only refreshed when a search needs fresh data.
actor OpenSkyClient {
    private let http: HTTPFetching
    private var cached: [AircraftState] = []
    private var cachedAt: Date?
    private var blockedUntil: Date?
    private var inFlight: Task<[AircraftState]?, Never>?
    private(set) var health = SourceHealth()
    private let clock: @Sendable () -> Date
    private let minimumCount: Int

    /// A real snapshot holds thousands of aircraft; fewer than `minimumCount` means a degraded answer.
    init(http: HTTPFetching, clock: @escaping @Sendable () -> Date = { Date() }, minimumCount: Int = 200) {
        self.http = http
        self.clock = clock
        self.minimumCount = minimumCount
    }

    var snapshotAge: TimeInterval? { cachedAt.map { Date().timeIntervalSince($0) } }

    /// The latest worldwide snapshot, at most `maxAge` seconds old. nil when unavailable.
    func snapshot(maxAge: TimeInterval) async -> [AircraftState]? {
        if let at = cachedAt, Date().timeIntervalSince(at) <= maxAge, !cached.isEmpty { return cached }
        if let blocked = blockedUntil, blocked > Date() {
            return cached.isEmpty ? nil : cached
        }
        if let running = inFlight { return await running.value }
        let task = Task<[AircraftState]?, Never> { [http, clock] in
            guard let url = URL(string: "https://opensky-network.org/api/states/all?extended=1") else { return nil }
            do {
                let result = try await http.get(url, timeout: 40)
                guard result.status == 200 else {
                    return result.status == 429 ? [] : nil
                }
                return Feeds.decodeOpenSky(result.data, fetchedAt: clock())
            } catch {
                return nil
            }
        }
        inFlight = task
        let started = Date()
        let fresh = await task.value
        inFlight = nil
        if let fresh, fresh.count >= minimumCount {
            cached = fresh
            cachedAt = Date()
            health.lastSuccess = Date()
            health.consecutiveFailures = 0
            health.lastLatencyMs = Int(Date().timeIntervalSince(started) * 1000)
            return fresh
        }
        health.lastFailure = Date()
        health.consecutiveFailures += 1
        // An empty list here means "rate limited"; either way, do not hammer.
        blockedUntil = Date().addingTimeInterval(fresh?.isEmpty == true ? 600 : 60)
        return cached.isEmpty ? nil : cached
    }
}

// MARK: - Routes

/// Looks up where a callsign is flying from and to. Tries a static mirror first (fast, no rate limit),
/// then a database API. Results, including misses, are cached and can be persisted.
actor RouteResolver {
    private struct Entry: Codable {
        var raw: Feeds.RawRoute?
        var at: Date
    }

    private let http: HTTPFetching
    private let reference: ReferenceData
    private var cache: [String: Entry] = [:]
    private var pending: [String: Task<Feeds.RawRoute?, Never>] = [:]
    private(set) var lookups = 0
    private(set) var dirty = false

    static let hitTTL: TimeInterval = 4 * 86400
    static let missTTL: TimeInterval = 8 * 3600

    init(http: HTTPFetching, reference: ReferenceData) {
        self.http = http
        self.reference = reference
    }

    // Persistence: the app saves `exportCache()` to disk and restores it at launch.
    func importCache(_ data: Data) {
        guard let decoded = try? JSONDecoder().decode([String: Entry].self, from: data) else { return }
        let now = Date()
        for (k, v) in decoded where now.timeIntervalSince(v.at) < Self.hitTTL { cache[k] = v }
    }

    func exportCache() -> Data? {
        dirty = false
        // Keep the file small: newest 4000 entries.
        var entries = cache
        if entries.count > 4000 {
            let keep = entries.sorted { $0.value.at > $1.value.at }.prefix(4000)
            entries = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        return try? JSONEncoder().encode(entries)
    }

    func cachedRaw(_ callsign: String) -> Feeds.RawRoute?? {
        guard let e = cache[callsign] else { return nil }
        let ttl = e.raw == nil ? Self.missTTL : Self.hitTTL
        guard Date().timeIntervalSince(e.at) < ttl else { return nil }
        return .some(e.raw)
    }

    /// True when a lookup for this callsign would be answered from memory.
    func isCached(_ callsign: String) -> Bool {
        if case .some = cachedRaw(callsign) { return true }
        return false
    }

    private func fetchRaw(_ callsign: String) async -> (route: Feeds.RawRoute?, definitive: Bool) {
        var definitive = true
        if let url = URL(string: "https://vrs-standing-data.adsb.lol/routes/\(callsign.prefix(2))/\(callsign).json") {
            do {
                let r = try await http.get(url, timeout: 8)
                if r.status == 200, let route = Feeds.decodeVRSRoute(r.data, reference: reference) { return (route, true) }
                if r.status != 200 && r.status != 404 { definitive = false }
            } catch {
                definitive = false
            }
        }
        if let url = URL(string: "https://api.adsbdb.com/v0/callsign/\(callsign)") {
            do {
                let r = try await http.get(url, timeout: 8)
                if r.status == 200, let route = Feeds.decodeADSBDBRoute(r.data, reference: reference) { return (route, true) }
                if r.status != 200 && r.status != 404 { definitive = false }
            } catch {
                definitive = false
            }
        }
        return (nil, definitive)
    }

    private func raw(for callsign: String) async -> Feeds.RawRoute? {
        if case .some(let hit) = cachedRaw(callsign) { return hit }
        if let running = pending[callsign] { return await running.value }
        let task = Task<Feeds.RawRoute?, Never> { [weak self] in
            guard let self else { return nil }
            let result = await self.fetchRaw(callsign)
            await self.store(callsign, result.route, definitive: result.definitive)
            return result.route
        }
        pending[callsign] = task
        let value = await task.value
        pending[callsign] = nil
        return value
    }

    private func store(_ callsign: String, _ route: Feeds.RawRoute?, definitive: Bool) {
        lookups += 1
        // A network failure is not evidence that the route does not exist; do not cache it.
        guard route != nil || definitive else { return }
        cache[callsign] = Entry(raw: route, at: Date())
        dirty = true
    }

    /// The route this aircraft is flying, or nil when unknown or implausible for where it is.
    func route(for state: AircraftState) async -> FlightRoute? {
        let cs = state.callsign
        guard Callsign.isAirline(cs), Callsign.isSafeForURL(cs) else { return nil }
        guard let raw = await raw(for: cs) else { return nil }
        return Feeds.resolve(raw, for: state)
    }

    /// Resolves many aircraft with bounded concurrency, reporting each as it completes.
    func routes(
        for states: [AircraftState],
        concurrency: Int = 8,
        onEach: (@Sendable (LiveFlight) -> Void)? = nil
    ) async -> [LiveFlight] {
        var results: [LiveFlight] = []
        results.reserveCapacity(states.count)
        var index = 0
        await withTaskGroup(of: LiveFlight.self) { group in
            func addNext() {
                guard index < states.count else { return }
                let s = states[index]
                index += 1
                group.addTask { LiveFlight(state: s, route: await self.route(for: s)) }
            }
            for _ in 0..<max(1, concurrency) { addNext() }
            while let flight = await group.next() {
                results.append(flight)
                onEach?(flight)
                if Task.isCancelled { group.cancelAll(); break }
                addNext()
            }
        }
        return results
    }
}

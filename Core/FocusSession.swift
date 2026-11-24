import Foundation

/// One sample of the flight while the user was on board. Drives the altitude profile and the logbook map.
struct TrackPoint: Codable, Hashable, Sendable {
    var t: Date
    var lat: Double
    var lon: Double
    var altFt: Int
    var gsKt: Int
    /// False when the point was projected because the feed had no fix.
    var live: Bool

    var point: GeoPoint { GeoPoint(lat, lon) }
}

enum SessionOutcome: String, Codable, Sendable {
    /// Rode the flight to touchdown.
    case landed
    /// A fixed-length session ran its full time.
    case timerDone
    /// The user ended it before the planned end.
    case endedEarly
}

/// A focus session in progress. All timing derives from wall-clock dates, so it stays correct
/// while the app is suspended or after it is relaunched.
struct FocusSession: Codable, Sendable, Identifiable {
    var id: UUID
    var flight: LiveFlight
    var route: FlightRoute
    var tag: FocusTag
    var seat: String
    var cabin: CabinClass
    var gate: String
    var sequence: Int

    var startedAt: Date
    /// Fixed session length in minutes; nil means "until the aircraft lands".
    var timerMinutes: Int?
    /// Best current estimate of touchdown.
    var estimatedLanding: Date
    var boardedFraction: Double
    var boardedRemainingKm: Double

    var pausedAt: Date?
    var pausedTotal: TimeInterval
    var pauseCount: Int

    /// Time of the newest real position report.
    var lastFixAt: Date
    var consecutiveMisses: Int
    var track: [TrackPoint]
    var announced: [String]
    var maxAltitudeFt: Int
    /// Set once a position report shows the aircraft down at its destination.
    var touchdown: Date?
    /// True when nobody was watching at the moment of touchdown, so its time is a best guess.
    var touchdownEstimated: Bool

    init(
        id: UUID = UUID(),
        flight: LiveFlight,
        route: FlightRoute,
        tag: FocusTag,
        seat: String,
        cabin: CabinClass,
        gate: String,
        sequence: Int,
        startedAt: Date,
        timerMinutes: Int?
    ) {
        self.id = id
        self.flight = flight
        self.route = route
        self.tag = tag
        self.seat = seat
        self.cabin = cabin
        self.gate = gate
        self.sequence = sequence
        self.startedAt = startedAt
        self.timerMinutes = timerMinutes
        let progress = FlightMath.progress(at: flight.state.point, route: route)
        self.boardedFraction = progress.fraction
        self.boardedRemainingKm = progress.remainingKm
        self.estimatedLanding = max(FlightMath.estimatedLanding(state: flight.state, route: route), startedAt.addingTimeInterval(60))
        self.pausedAt = nil
        self.pausedTotal = 0
        self.pauseCount = 0
        self.lastFixAt = flight.state.positionTime
        self.consecutiveMisses = 0
        self.track = [TrackPoint(
            t: startedAt,
            lat: flight.state.lat,
            lon: flight.state.lon,
            altFt: flight.state.altitudeFt ?? 0,
            gsKt: Int(flight.state.groundSpeedKt ?? 0),
            live: true
        )]
        self.announced = []
        self.maxAltitudeFt = flight.state.altitudeFt ?? 0
        self.touchdown = nil
        self.touchdownEstimated = false
    }

    // MARK: Timing

    var isPaused: Bool { pausedAt != nil }
    var followsLanding: Bool { timerMinutes == nil }

    func pausedSeconds(at now: Date) -> TimeInterval {
        pausedTotal + (pausedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
    }

    /// When the session is due to finish. A fixed timer is pushed back by pauses; a landing is not.
    func plannedEnd(at now: Date) -> Date {
        if let timerMinutes {
            return startedAt.addingTimeInterval(Double(timerMinutes) * 60 + pausedSeconds(at: now))
        }
        return estimatedLanding
    }

    func remainingSeconds(at now: Date) -> TimeInterval {
        max(0, plannedEnd(at: now).timeIntervalSince(now))
    }

    /// Seconds actually spent focusing (excludes pauses), measured up to `now`.
    func focusSeconds(at now: Date) -> TimeInterval {
        max(0, now.timeIntervalSince(startedAt) - pausedSeconds(at: now))
    }

    /// 0...1 through the planned session.
    func sessionFraction(at now: Date) -> Double {
        let total = plannedEnd(at: now).timeIntervalSince(startedAt)
        guard total > 1 else { return 1 }
        return min(max(now.timeIntervalSince(startedAt) / total, 0), 1)
    }

    var signalLost: Bool { consecutiveMisses >= 3 }

    // MARK: Position

    /// Best estimate of where the aircraft is right now.
    func position(at now: Date) -> GeoPoint {
        if flight.isSimulated {
            return SimFlight.state(route: route, landing: estimatedLanding, at: now, hex: flight.state.hex, callsign: flight.callsign).point
        }
        return FlightMath.projected(state: flight.state, route: route, after: now.timeIntervalSince(flight.state.positionTime))
    }

    func progress(at now: Date) -> RouteProgress {
        FlightMath.progress(at: position(at: now), route: route)
    }

    var phase: FlightPhase { FlightMath.phase(state: flight.state, route: route) }

    // MARK: Updates

    mutating func pause(at now: Date) {
        guard pausedAt == nil else { return }
        pausedAt = now
        pauseCount += 1
    }

    mutating func resume(at now: Date) {
        guard let p = pausedAt else { return }
        pausedTotal += max(0, now.timeIntervalSince(p))
        pausedAt = nil
    }

    /// Applies a fresh position report.
    mutating func apply(fix: AircraftState, at now: Date) {
        let merged = fix.inheritingDetails(from: flight.state)
        guard merged.positionTime >= lastFixAt else { return }
        let gap = merged.positionTime.timeIntervalSince(lastFixAt)
        let priorEstimate = estimatedLanding
        let priorFixAt = lastFixAt
        flight.state = merged
        lastFixAt = max(lastFixAt, merged.positionTime)
        consecutiveMisses = 0
        maxAltitudeFt = max(maxAltitudeFt, merged.altitudeFt ?? 0)
        if FlightMath.hasLanded(state: merged, route: route) {
            if touchdown == nil {
                if gap > 240 {
                    // It landed while nobody was watching (app suspended or closed). The earlier
                    // estimate is the best guess, bounded by the two reports either side of it.
                    touchdown = min(max(priorEstimate, priorFixAt), merged.positionTime)
                    touchdownEstimated = true
                } else {
                    touchdown = merged.positionTime
                    touchdownEstimated = false
                }
            }
        } else if gap > 0 {
            let estimate = FlightMath.estimatedLanding(state: merged, route: route)
            // Never claim a landing in the past while the aircraft is still flying.
            // A cached report must not keep pushing an overdue estimate to "now + 30 seconds".
            estimatedLanding = max(estimate, now.addingTimeInterval(30))
        }
        appendTrack(TrackPoint(
            t: merged.positionTime,
            lat: merged.lat,
            lon: merged.lon,
            altFt: merged.altitudeFt ?? 0,
            gsKt: Int(merged.groundSpeedKt ?? 0),
            live: true
        ))
    }

    /// Advances a simulated flight to `now`. Its schedule is fixed, so the estimate is left alone.
    mutating func refreshSimulated(at now: Date) {
        guard flight.isSimulated else { return }
        let s = SimFlight.state(route: route, landing: estimatedLanding, at: now, hex: flight.state.hex, callsign: flight.callsign)
        flight.state = s.inheritingDetails(from: flight.state)
        lastFixAt = now
        consecutiveMisses = 0
        maxAltitudeFt = max(maxAltitudeFt, s.altitudeFt ?? 0)
        appendTrack(TrackPoint(t: now, lat: s.lat, lon: s.lon, altFt: s.altitudeFt ?? 0, gsKt: Int(s.groundSpeedKt ?? 0), live: false))
    }

    /// Whether a report for this airframe still belongs to the flight being followed. The same
    /// aircraft flies several legs a day, so a different callsign means it has moved on.
    func accepts(_ fix: AircraftState) -> Bool {
        if !fix.callsign.isEmpty, !flight.callsign.isEmpty, fix.callsign != flight.callsign { return false }
        return true
    }

    mutating func recordMiss() {
        consecutiveMisses += 1
    }

    private mutating func appendTrack(_ p: TrackPoint) {
        if let last = track.last, p.t.timeIntervalSince(last.t) < 20 { return }
        track.append(p)
        // Keep the profile bounded on very long flights by thinning the older half.
        if track.count > 360 {
            var thinned: [TrackPoint] = []
            thinned.reserveCapacity(270)
            for (i, point) in track.enumerated() where i >= 180 || i % 2 == 0 { thinned.append(point) }
            track = thinned
        }
    }

    // MARK: Completion

    struct Completion: Equatable, Sendable {
        var outcome: SessionOutcome
        var endedAt: Date
        /// True when the touchdown time is inferred rather than observed.
        var estimated: Bool
    }

    /// Decides whether the session is over as of `now`. Pure: callers act on the result.
    func completion(at now: Date) -> Completion? {
        if timerMinutes != nil {
            let end = plannedEnd(at: now)
            return now >= end && !isPaused ? Completion(outcome: .timerDone, endedAt: end, estimated: false) : nil
        }
        if flight.isSimulated {
            return now >= estimatedLanding ? Completion(outcome: .landed, endedAt: estimatedLanding, estimated: false) : nil
        }
        if let touchdown {
            return Completion(outcome: .landed, endedAt: min(now, max(touchdown, startedAt)), estimated: touchdownEstimated)
        }
        let silence = now.timeIntervalSince(lastFixAt)
        if silence > 100 {
            if FlightMath.vanishedOnFinal(lastSeen: flight.state, route: route) {
                let remaining = Geo.distanceKm(flight.state.point, route.destination.point)
                let expected = lastFixAt.addingTimeInterval(FlightMath.terminalMinutes(forKm: remaining) * 60)
                if now >= expected { return Completion(outcome: .landed, endedAt: expected, estimated: true) }
            }
            if now >= estimatedLanding.addingTimeInterval(45) {
                return Completion(outcome: .landed, endedAt: estimatedLanding, estimated: true)
            }
        }
        return nil
    }

    // MARK: Milestones

    enum Milestone: String, CaseIterable, Sendable {
        case topOfDescent
        case tenMinutes
        case finalApproach

        var announcement: String {
            switch self {
            case .topOfDescent: return "已开始下降，最后一段了"
            case .tenMinutes: return "预计 10 分钟后落地"
            case .finalApproach: return "正在最后进近"
            }
        }
    }

    /// Milestones newly reached at `now`; marks them announced.
    mutating func newMilestones(at now: Date) -> [Milestone] {
        guard followsLanding else { return [] }
        var fresh: [Milestone] = []
        func reached(_ m: Milestone) -> Bool {
            switch m {
            case .topOfDescent:
                return phase == .descent || phase == .approach
            case .tenMinutes:
                return remainingSeconds(at: now) <= 600
            case .finalApproach:
                return phase == .approach && Geo.distanceKm(flight.state.point, route.destination.point) < 22
            }
        }
        for m in Milestone.allCases where !announced.contains(m.rawValue) && reached(m) {
            // Boarding late in the flight should not replay everything at once.
            if now.timeIntervalSince(startedAt) > 45 { fresh.append(m) }
            announced.append(m.rawValue)
        }
        return fresh
    }

    // MARK: Record

    func record(_ completion: Completion) -> FocusRecord {
        let end = completion.endedAt
        let endPoint: GeoPoint = completion.outcome == .landed ? route.destination.point : position(at: end)
        let endProgress = FlightMath.progress(at: endPoint, route: route)
        let flownDuringSession = max(0, boardedRemainingKm - endProgress.remainingKm)
        var thumbnail = track.map { GeoPoint($0.lat, $0.lon) }
        if completion.outcome == .landed { thumbnail.append(route.destination.point) }
        return FocusRecord(
            id: id,
            flightNumber: flight.displayNumber,
            callsign: flight.callsign,
            airlineICAO: flight.airlineICAO,
            airlineName: route.airlineName,
            registration: flight.state.registration,
            typeCode: flight.state.typeCode,
            typeName: flight.state.typeName,
            origin: route.origin,
            destination: route.destination,
            tag: tag,
            seat: seat,
            cabin: cabin,
            gate: gate,
            sequence: sequence,
            startedAt: startedAt,
            endedAt: end,
            focusSeconds: Int(focusSeconds(at: end).rounded()),
            pausedSeconds: Int(pausedSeconds(at: end).rounded()),
            pauseCount: pauseCount,
            distanceKm: flownDuringSession,
            routeKm: route.distanceKm,
            boardedFraction: boardedFraction,
            endFraction: completion.outcome == .landed ? 1 : endProgress.fraction,
            outcome: completion.outcome,
            simulated: flight.isSimulated,
            landingEstimated: completion.estimated,
            maxAltitudeFt: maxAltitudeFt,
            path: FocusRecord.thin(thumbnail, to: 48),
            altitudeProfile: FocusRecord.thin(track.map { $0.altFt }, to: 60)
        )
    }
}

/// A finished session, as kept in the logbook.
struct FocusRecord: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    var flightNumber: String
    var callsign: String
    var airlineICAO: String?
    var airlineName: String?
    var registration: String?
    var typeCode: String?
    var typeName: String?
    var origin: Airport
    var destination: Airport
    var tag: FocusTag
    var seat: String
    var cabin: CabinClass
    var gate: String
    var sequence: Int
    var startedAt: Date
    var endedAt: Date
    var focusSeconds: Int
    var pausedSeconds: Int
    var pauseCount: Int
    /// Distance covered while on board.
    var distanceKm: Double
    var routeKm: Double
    var boardedFraction: Double
    var endFraction: Double
    var outcome: SessionOutcome
    var simulated: Bool
    var landingEstimated: Bool
    var maxAltitudeFt: Int
    var path: [GeoPoint]
    var altitudeProfile: [Int]

    var focusMinutes: Int { Int((Double(focusSeconds) / 60).rounded()) }
    var completed: Bool { outcome != .endedEarly }

    static func thin<T>(_ items: [T], to limit: Int) -> [T] {
        guard items.count > limit, limit > 1 else { return items }
        var out: [T] = []
        out.reserveCapacity(limit)
        let step = Double(items.count - 1) / Double(limit - 1)
        for i in 0..<limit { out.append(items[Int((Double(i) * step).rounded())]) }
        return out
    }
}

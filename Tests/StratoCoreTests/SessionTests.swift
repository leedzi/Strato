import XCTest
@testable import StratoCore

final class FocusSessionTests: XCTestCase {
    private func session(fraction: Double = 0.4, timer: Int? = nil, start: Date = Fixtures.t0) -> FocusSession {
        let route = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        let state = Fixtures.cruising(route, fraction: fraction, at: start)
        return FocusSession(
            flight: LiveFlight(state: state, route: route), route: route, tag: .coding,
            seat: "12A", cabin: .business, gate: "G16", sequence: 18, startedAt: start, timerMinutes: timer
        )
    }

    func testStartsAtTheAircraftsRealProgress() {
        let s = session(fraction: 0.64)
        XCTAssertEqual(s.boardedFraction, 0.64, accuracy: 0.005)
        XCTAssertEqual(s.progress(at: Fixtures.t0).fraction, 0.64, accuracy: 0.005)
        XCTAssertGreaterThan(s.remainingSeconds(at: Fixtures.t0), 20 * 60)
    }

    func testTimingIsWallClockNotTickBased() {
        // No ticks at all for an hour (app suspended): remaining time still drops by exactly an hour.
        let s = session(timer: 90)
        XCTAssertEqual(s.remainingSeconds(at: Fixtures.t0), 5400, accuracy: 0.001)
        XCTAssertEqual(s.remainingSeconds(at: Fixtures.t0.addingTimeInterval(3600)), 1800, accuracy: 0.001)
        XCTAssertEqual(s.focusSeconds(at: Fixtures.t0.addingTimeInterval(3600)), 3600, accuracy: 0.001)
        XCTAssertNil(s.completion(at: Fixtures.t0.addingTimeInterval(5399)))
        let done = s.completion(at: Fixtures.t0.addingTimeInterval(9000)) // reopened long after
        XCTAssertEqual(done?.outcome, .timerDone)
        XCTAssertEqual(done?.endedAt, Fixtures.t0.addingTimeInterval(5400)) // credited to the planned end, not "now"
        XCTAssertEqual(s.record(done!).focusSeconds, 5400)
    }

    func testPauseExtendsATimerAndIsExcludedFromFocusTime() {
        var s = session(timer: 60)
        s.pause(at: Fixtures.t0.addingTimeInterval(600))
        XCTAssertTrue(s.isPaused)
        // While paused the countdown is frozen.
        XCTAssertEqual(s.remainingSeconds(at: Fixtures.t0.addingTimeInterval(900)), 3000, accuracy: 0.001)
        XCTAssertNil(s.completion(at: Fixtures.t0.addingTimeInterval(99_999)))
        s.resume(at: Fixtures.t0.addingTimeInterval(900))
        XCTAssertFalse(s.isPaused)
        XCTAssertEqual(s.pausedSeconds(at: Fixtures.t0.addingTimeInterval(2000)), 300, accuracy: 0.001)
        XCTAssertEqual(s.plannedEnd(at: Fixtures.t0.addingTimeInterval(2000)), Fixtures.t0.addingTimeInterval(3900))
        XCTAssertEqual(s.focusSeconds(at: Fixtures.t0.addingTimeInterval(3900)), 3600, accuracy: 0.001)
        XCTAssertEqual(s.pauseCount, 1)
        s.resume(at: Fixtures.t0.addingTimeInterval(950)) // resuming twice is harmless
        XCTAssertEqual(s.pauseCount, 1)
    }

    func testFollowsRealFixesAndLandsWhenTheAircraftDoes() {
        var s = session(fraction: 0.90)
        let route = s.route
        let firstEstimate = s.estimatedLanding

        // Ten minutes later the aircraft is further along and descending.
        let t1 = Fixtures.t0.addingTimeInterval(600)
        s.apply(fix: Fixtures.cruising(route, fraction: 0.96, at: t1, alt: 12000, gs: 300, vs: -1500), at: t1)
        XCTAssertEqual(s.phase, .descent)
        XCTAssertEqual(s.consecutiveMisses, 0)
        XCTAssertNil(s.completion(at: t1))
        XCTAssertEqual(s.estimatedLanding.timeIntervalSince(firstEstimate), 0, accuracy: 8 * 60) // estimate moves, not wildly
        XCTAssertEqual(s.progress(at: t1).fraction, 0.96, accuracy: 0.005)

        // On the ground at the destination.
        let t2 = t1.addingTimeInterval(700)
        var down = Fixtures.cruising(route, fraction: 1.0, at: t2, alt: 0, gs: 40)
        down.onGround = true
        s.apply(fix: down, at: t2)
        let done = s.completion(at: t2.addingTimeInterval(5))
        XCTAssertEqual(done?.outcome, .landed)
        XCTAssertEqual(done?.estimated, false)
        let record = s.record(done!)
        XCTAssertEqual(record.endFraction, 1)
        XCTAssertEqual(record.distanceKm, route.distanceKm * 0.10, accuracy: 6)
        XCTAssertEqual(record.focusSeconds, 1300, accuracy: 2)
        XCTAssertEqual(record.destination.code, "HND")
        XCTAssertEqual(record.boardedFraction, 0.90, accuracy: 0.005)
        XCTAssertGreaterThan(record.path.count, 1)
    }

    func testLostSignalFallsBackToTheEstimate() {
        var s = session(fraction: 0.5)
        let eta = s.estimatedLanding
        for _ in 0..<4 { s.recordMiss() }
        XCTAssertTrue(s.signalLost)
        // Still mid-flight: silence alone must not end the session.
        XCTAssertNil(s.completion(at: Fixtures.t0.addingTimeInterval(600)))
        // The projected position keeps moving toward the destination and never passes it.
        let later = s.progress(at: Fixtures.t0.addingTimeInterval(1800)).fraction
        XCTAssertGreaterThan(later, 0.6)
        XCTAssertLessThanOrEqual(s.progress(at: eta.addingTimeInterval(7200)).fraction, 1.0)
        // Once the estimated landing has passed with no word, it is treated as landed, flagged as estimated.
        let done = s.completion(at: eta.addingTimeInterval(120))
        XCTAssertEqual(done?.outcome, .landed)
        XCTAssertEqual(done?.estimated, true)
        XCTAssertEqual(done?.endedAt, eta)
    }

    func testVanishingOnShortFinalCountsAsLanding() {
        var s = session(fraction: 0.9)
        let route = s.route
        let t1 = Fixtures.t0.addingTimeInterval(900)
        // Last seen 12 km out at 1,800 ft, then nothing (below receiver coverage).
        var final = Fixtures.cruising(route, fraction: 0.5, at: t1, alt: 1800, gs: 150, vs: -700)
        let p = Geo.destination(from: route.destination.point, bearing: 200, distanceKm: 12)
        final.lat = p.lat; final.lon = p.lon
        s.apply(fix: final, at: t1)
        XCTAssertNil(s.completion(at: t1.addingTimeInterval(60)))
        let done = s.completion(at: t1.addingTimeInterval(400))
        XCTAssertEqual(done?.outcome, .landed)
        XCTAssertEqual(done?.estimated, true)
        XCTAssertEqual(done!.endedAt.timeIntervalSince(t1), FlightMath.terminalMinutes(forKm: 12) * 60, accuracy: 20)
    }

    func testEndingEarlyRecordsTheSegmentFlown() {
        let s = session(fraction: 0.30)
        let end = Fixtures.t0.addingTimeInterval(1200)
        let record = s.record(.init(outcome: .endedEarly, endedAt: end, estimated: false))
        XCTAssertFalse(record.completed)
        XCTAssertEqual(record.focusSeconds, 1200)
        XCTAssertGreaterThan(record.endFraction, 0.30)
        XCTAssertLessThan(record.endFraction, 1)
        // 20 minutes at 460 kt is about 284 km.
        XCTAssertEqual(record.distanceKm, 284, accuracy: 12)
    }

    func testMilestonesFireOnceAndNotOnBoarding() {
        var s = session(fraction: 0.90)
        let route = s.route
        XCTAssertTrue(s.newMilestones(at: Fixtures.t0.addingTimeInterval(5)).isEmpty)
        let t1 = Fixtures.t0.addingTimeInterval(300)
        s.apply(fix: Fixtures.cruising(route, fraction: 0.93, at: t1, alt: 20000, gs: 340, vs: -1800), at: t1)
        XCTAssertEqual(s.newMilestones(at: t1), [.topOfDescent])
        XCTAssertTrue(s.newMilestones(at: t1.addingTimeInterval(10)).isEmpty)
    }

    func testSessionSurvivesEncodingRoundTrip() throws {
        var s = session(timer: 45)
        s.pause(at: Fixtures.t0.addingTimeInterval(60))
        let data = try JSONEncoder().encode(s)
        let back = try JSONDecoder().decode(FocusSession.self, from: data)
        XCTAssertEqual(back.id, s.id)
        XCTAssertEqual(back.timerMinutes, 45)
        XCTAssertEqual(back.pausedAt, s.pausedAt)
        XCTAssertEqual(back.route.destination.code, "HND")
        XCTAssertEqual(back.remainingSeconds(at: Fixtures.t0.addingTimeInterval(500)), s.remainingSeconds(at: Fixtures.t0.addingTimeInterval(500)), accuracy: 0.001)
    }

    func testTrackStaysBounded() {
        var s = session(fraction: 0.05)
        let route = s.route
        for i in 1...900 {
            let t = Fixtures.t0.addingTimeInterval(Double(i) * 30)
            s.apply(fix: Fixtures.cruising(route, fraction: 0.05 + Double(i) * 0.0005, at: t), at: t)
        }
        XCTAssertLessThanOrEqual(s.track.count, 360)
        XCTAssertEqual(s.track.first?.t, Fixtures.t0)
    }
}

final class SimFlightTests: XCTestCase {
    func testMinutesAndDistanceAreInverse() {
        for km in [5.0, 60, 229, 231, 800, 1740, 5540] {
            let m = SimFlight.minutes(forRemainingKm: km)
            XCTAssertEqual(SimFlight.remainingKm(forMinutes: m), km, accuracy: 0.5, "km=\(km)")
        }
    }

    func testSimulatedFlightLandsOnSchedule() {
        let made = SimFlight.make(origin: Fixtures.pvg, destination: Fixtures.hnd, minutes: 60, airlineICAO: "ANA", flightDigits: 920, reference: Fixtures.reference, now: Fixtures.t0)
        let route = made.flight.route!
        XCTAssertEqual(route.flightNumber, "NH920")
        XCTAssertTrue(made.flight.isSimulated)
        XCTAssertEqual(made.landing.timeIntervalSince(Fixtures.t0), 3600, accuracy: 1)
        // Sixty minutes from landing it is already well on its way, not at the gate.
        XCTAssertGreaterThan(FlightMath.progress(at: made.flight.state.point, route: route).fraction, 0.3)

        var session = FocusSession(flight: made.flight, route: route, tag: .study, seat: "1A", cabin: .first, gate: "A1", sequence: 1, startedAt: Fixtures.t0, timerMinutes: nil)
        session.estimatedLanding = made.landing
        var last = -1.0
        for minute in stride(from: 0, through: 60, by: 5) {
            let f = session.progress(at: Fixtures.t0.addingTimeInterval(Double(minute) * 60)).fraction
            XCTAssertGreaterThanOrEqual(f, last)
            last = f
        }
        XCTAssertEqual(last, 1, accuracy: 0.01)
        XCTAssertNil(session.completion(at: made.landing.addingTimeInterval(-1)))
        XCTAssertEqual(session.completion(at: made.landing.addingTimeInterval(1))?.outcome, .landed)
    }

    func testRequestLongerThanTheRouteIsCappedToTheFullFlight() {
        let made = SimFlight.make(origin: Fixtures.muc, destination: Fixtures.dus, minutes: 600, airlineICAO: "DLH", flightDigits: 2010, reference: Fixtures.reference, now: Fixtures.t0)
        let minutes = made.landing.timeIntervalSince(Fixtures.t0) / 60
        XCTAssertLessThan(minutes, 90)
        XCTAssertGreaterThan(minutes, 35)
        XCTAssertTrue(made.flight.state.onGround) // starts at the origin
    }

    func testStableHash() {
        XCTAssertEqual("PVGHND".hashValueStable, "PVGHND".hashValueStable)
        XCTAssertNotEqual("PVGHND".hashValueStable, "HNDPVG".hashValueStable)
        XCTAssertGreaterThanOrEqual("anything".hashValueStable, 0)
    }
}

final class MatchingTests: XCTestCase {
    func testRanksByClosenessToTheRequestedLength() {
        let route = Fixtures.route(Fixtures.lhr, Fixtures.jfk, callsign: "BAW117", number: "BA117")
        var flights: [LiveFlight] = []
        for (i, f) in [0.2, 0.5, 0.7, 0.85, 0.95].enumerated() {
            flights.append(LiveFlight(state: Fixtures.cruising(route, fraction: f, hex: "00000\(i)"), route: route))
        }
        let minutes = flights.map { Int((FlightMath.secondsToLanding(state: $0.state, route: route) / 60).rounded()) }
        let target = minutes[2]
        let ranked = Matching.rank(flights: flights, targetMinutes: target, destination: nil, now: Fixtures.t0, strict: false)
        XCTAssertEqual(ranked.first?.flight.id, "000002")
        XCTAssertEqual(ranked.first?.deltaMinutes, 0)
        XCTAssertEqual(ranked.count, 5)

        let strict = Matching.rank(flights: flights, targetMinutes: target, destination: nil, now: Fixtures.t0, strict: true)
        XCTAssertTrue(strict.allSatisfy { abs($0.deltaMinutes) <= Matching.tolerance(forTarget: target) })
        XCTAssertLessThan(strict.count, 5)
    }

    func testDestinationFilterAndStaleness() {
        let toTokyo = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        let toNewYork = Fixtures.route(Fixtures.lhr, Fixtures.jfk, callsign: "BAW117", number: "BA117")
        let a = LiveFlight(state: Fixtures.cruising(toTokyo, fraction: 0.5, hex: "aaaaaa"), route: toTokyo)
        let b = LiveFlight(state: Fixtures.cruising(toNewYork, fraction: 0.5, hex: "bbbbbb"), route: toNewYork)
        let noRoute = LiveFlight(state: Fixtures.cruising(toTokyo, fraction: 0.5, hex: "cccccc"), route: nil)
        let stale = LiveFlight(state: Fixtures.cruising(toTokyo, fraction: 0.5, at: Fixtures.t0.addingTimeInterval(-900), hex: "dddddd"), route: toTokyo)

        let ranked = Matching.rank(flights: [a, b, noRoute, stale], targetMinutes: 60, destination: Fixtures.hnd, now: Fixtures.t0, strict: false)
        XCTAssertEqual(ranked.map { $0.flight.id }, ["aaaaaa"])
    }

    func testLookupPriorityPrefersPlausibleCandidates() {
        let route = Fixtures.route(Fixtures.lhr, Fixtures.jfk, callsign: "BAW117", number: "BA117")
        let cruise = Fixtures.cruising(route, fraction: 0.5)
        XCTAssertNotNil(Matching.lookupPriority(state: cruise, targetMinutes: 120, destination: nil, now: Fixtures.t0))
        // Descending through 9,000 ft is not a two-hour flight.
        let descending = Fixtures.cruising(route, fraction: 0.98, alt: 9000, gs: 250, vs: -1200)
        XCTAssertNil(Matching.lookupPriority(state: descending, targetMinutes: 120, destination: nil, now: Fixtures.t0))
        XCTAssertNotNil(Matching.lookupPriority(state: descending, targetMinutes: 15, destination: nil, now: Fixtures.t0))
        // Private registrations are skipped.
        var privateJet = cruise
        privateJet.callsign = "N123AB"
        XCTAssertNil(Matching.lookupPriority(state: privateJet, targetMinutes: 120, destination: nil, now: Fixtures.t0))
        // With a destination, an aircraft heading away is skipped and one inbound at the right range is kept.
        let inbound = Fixtures.cruising(route, fraction: 0.7)
        let m = Int(SimFlight.minutes(forRemainingKm: Geo.distanceKm(inbound.point, Fixtures.jfk.point)))
        XCTAssertNotNil(Matching.lookupPriority(state: inbound, targetMinutes: m, destination: Fixtures.jfk, now: Fixtures.t0))
        var outbound = inbound
        outbound.trackDeg = Geo.bearing(inbound.point, Fixtures.lhr.point)
        XCTAssertNil(Matching.lookupPriority(state: outbound, targetMinutes: m, destination: Fixtures.jfk, now: Fixtures.t0))
    }
}

final class StatsAndPassTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        return c
    }

    private func record(daysAgo: Int, hour: Int, minutes: Int, tag: FocusTag = .coding, outcome: SessionOutcome = .landed, km: Double = 800, now: Date) -> FocusRecord {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: now))!
        let start = calendar.date(byAdding: .hour, value: hour, to: day)!
        return FocusRecord(
            id: UUID(), flightNumber: "NH920", callsign: "ANA920", airlineICAO: "ANA", airlineName: "All Nippon Airways",
            registration: "JA873A", typeCode: "B789", typeName: "BOEING 787-9", origin: Fixtures.pvg, destination: Fixtures.hnd,
            tag: tag, seat: "12A", cabin: .business, gate: "G16", sequence: 18, startedAt: start,
            endedAt: start.addingTimeInterval(Double(minutes) * 60), focusSeconds: minutes * 60, pausedSeconds: 0, pauseCount: 0,
            distanceKm: km, routeKm: 1740, boardedFraction: 0.4, endFraction: outcome == .landed ? 1 : 0.7, outcome: outcome,
            simulated: false, landingEstimated: false, maxAltitudeFt: 38000, path: [], altitudeProfile: []
        )
    }

    func testTotalsStreaksAndDistribution() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 15))!
        let records = [
            record(daysAgo: 0, hour: 9, minutes: 90, now: now),
            record(daysAgo: 1, hour: 20, minutes: 60, tag: .study, now: now),
            record(daysAgo: 2, hour: 23, minutes: 120, tag: .coding, outcome: .endedEarly, now: now), // crosses midnight
            record(daysAgo: 5, hour: 10, minutes: 30, now: now),
            record(daysAgo: 6, hour: 10, minutes: 30, now: now)
        ]
        let s = FocusStats(records: records, now: now, calendar: calendar, reference: Fixtures.reference, days: 7)
        XCTAssertEqual(s.totalSessions, 5)
        XCTAssertEqual(s.completedSessions, 4)
        XCTAssertEqual(s.totalMinutes, 330)
        XCTAssertEqual(s.todayMinutes, 90)
        XCTAssertEqual(s.currentStreak, 3)
        XCTAssertEqual(s.longestStreak, 3)
        XCTAssertEqual(s.longestMinutes, 120)
        XCTAssertEqual(s.weekMinutes, 330)
        XCTAssertEqual(s.daily.count, 7)
        XCTAssertEqual(s.daily.last?.minutes, 90)
        XCTAssertEqual(s.daily.map { $0.minutes }.reduce(0, +), 330)
        XCTAssertEqual(s.hourly.reduce(0, +), 330)
        XCTAssertEqual(s.hourly[23], 60) // the late session is split across midnight
        XCTAssertEqual(s.hourly[0], 60)
        XCTAssertEqual(s.tags.first?.tag, .coding)
        XCTAssertEqual(s.tags.first?.minutes, 270)
        XCTAssertEqual(s.topAirlines.first?.title, "全日空")
        XCTAssertEqual(s.topAirlines.first?.count, 5)
        XCTAssertEqual(s.topRoutes.first?.title, "上海浦东 → 东京羽田")
        XCTAssertEqual(s.topAircraft.first?.title, "波音 787-9")
        XCTAssertEqual(s.airportsVisited, 1) // the abandoned flight never reached anything new
        XCTAssertEqual(s.totalKm, 4000, accuracy: 0.001)
        XCTAssertEqual(s.tier.title, "蓝天卡")
        XCTAssertEqual(s.tierProgress, 0.8, accuracy: 0.001)
    }

    func testStreakToleratesNotHavingFocusedYetToday() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 8))!
        let s = FocusStats(records: [record(daysAgo: 1, hour: 9, minutes: 30, now: now), record(daysAgo: 2, hour: 9, minutes: 30, now: now)], now: now, calendar: calendar, reference: Fixtures.reference)
        XCTAssertEqual(s.currentStreak, 2)
        let broken = FocusStats(records: [record(daysAgo: 3, hour: 9, minutes: 30, now: now)], now: now, calendar: calendar, reference: Fixtures.reference)
        XCTAssertEqual(broken.currentStreak, 0)
        XCTAssertEqual(broken.longestStreak, 1)
        let empty = FocusStats(records: [], now: now, calendar: calendar, reference: Fixtures.reference)
        XCTAssertEqual(empty.totalMinutes, 0)
        XCTAssertNil(empty.bestHour)
        XCTAssertEqual(empty.completionRate, 0)
    }

    func testTiers() {
        XCTAssertEqual(FocusStats.tier(forKm: 0).index, 0)
        XCTAssertEqual(FocusStats.tier(forKm: 4_999).index, 0)
        XCTAssertEqual(FocusStats.tier(forKm: 5_000).title, "银卡")
        XCTAssertEqual(FocusStats.tier(forKm: 20_000).title, "金卡")
        XCTAssertNil(FocusStats.tier(forKm: 999_999).nextKm)
    }

    func testBoardingPassBarcodeLayout() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let date = utc.date(from: DateComponents(year: 2026, month: 11, day: 23, hour: 12))! // day 327
        let code = BoardingPassCode.make(passenger: "STRATO/FLYER", pnr: "K7M2QX", fromIATA: "PVG", toIATA: "HND", flightNumber: "NH920", date: date, cabin: .business, seat: "12A", sequence: 18, calendar: utc)
        XCTAssertEqual(code.count, 60)
        XCTAssertTrue(code.hasPrefix("M1STRATO/FLYER        EK7M2QX PVGHNDNH 0920 327J012A0018 100"))

        XCTAssertEqual(BoardingPassCode.split(flightNumber: "CA1831").carrier, "CA")
        XCTAssertEqual(BoardingPassCode.split(flightNumber: "CA1831").number, "1831")
        XCTAssertEqual(BoardingPassCode.split(flightNumber: "9C8515").carrier, "9C")
        XCTAssertEqual(BoardingPassCode.split(flightNumber: "MU583A").suffix, "A")
        XCTAssertEqual(BoardingPassCode.split(flightNumber: "DLH2HT").carrier, "DLH")
        XCTAssertEqual(BoardingPassCode.seatField("1A"), "001A")
        XCTAssertEqual(BoardingPassCode.pnr(for: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!).count, 6)

        XCTAssertTrue(Seating.isWindow(Seating.windowSeat(cabin: .economy, seed: 12345)))
        XCTAssertTrue(Seating.rows(for: .business).contains(Int(Seating.windowSeat(cabin: .business, seed: 99).dropLast())!))
    }

    func testBrandColours() {
        XCTAssertTrue(AirlineBrand.forICAO("CCA").curated)
        let unknown = AirlineBrand.forICAO("ZZQ")
        XCTAssertFalse(unknown.curated)
        XCTAssertEqual(unknown, AirlineBrand.forICAO("zzq")) // stable and case-insensitive
        XCTAssertEqual(AirlineBrand.hsl(0, 1, 0.5), 0xFF0000)
        XCTAssertEqual(AirlineBrand.hsl(120, 1, 0.5), 0x00FF00)
        XCTAssertTrue(AirlineBrand.forICAO("DLH").prefersLightText)
        XCTAssertFalse(AirlineBrand.forICAO("TGW").prefersLightText) // Scoot yellow needs dark text
    }
}

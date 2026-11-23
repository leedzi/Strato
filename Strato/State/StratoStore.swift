import Foundation
import SwiftUI
import MapKit
import Observation

public enum CockpitViewMode: String, CaseIterable, Identifiable, Sendable {
    case follow3D = "3D 伴飞"
    case fullRoute = "全航线"
    case cockpitHUD = "PFD 仪表"

    public var id: String { rawValue }
}

public struct FrequentFlyerTier: Sendable {
    public let titleCN: String
    public let titleEN: String
    public let color: Color
    public let nextTierKM: Int
}

@MainActor
@Observable
final class StratoStore {
    // Radar & Discovery
    var radarFlights: [LiveFlight] = []
    var recommendedFlights: [LiveFlight] = []
    var selectedFlight: LiveFlight?
    var searchText: String = ""
    var isLoadingRadar: Bool = false
    var isMatchingFlights: Bool = false
    var radarStatusMessage: String = "正在扫描全球实时 ADS-B 雷达…"

    // Matcher & Map Preferences
    var targetFocusMinutes: Int = 90
    var selectedDestination: Airport?
    var selectedFocusTag: FocusTag = .deepWork
    var selectedScope: RadarScope {
        didSet {
            SharedStore.shared.preferredScope = selectedScope
        }
    }
    var mapProvider: StratoMapProvider {
        didSet {
            SharedStore.shared.mapStyleRaw = mapProvider.rawValue
        }
    }

    // Active Focus Flight Session
    var activeFlight: LiveFlight?
    var activeSeatNumber: String = "12A"
    var activeGateNumber: String = "G16"
    var activeCabinClass: String = "BUSINESS · 公务舱"
    var activeSequenceNumber: String = "SEQ 018"
    var boardedAtFlightProgress: Double = 0.5
    var sessionStartedAt: Date?
    var sessionTargetEndAt: Date?
    var totalPlannedSeconds: Int = 5400
    var remainingSeconds: Int = 0
    var isPaused: Bool = false
    var audioPreset: CabinAudioPreset = .off
    var cockpitViewMode: CockpitViewMode = .follow3D
    var recentlyCompletedRecord: FocusSessionRecord?

    // Telemetry History during active flight (for altitude/speed profile chart)
    struct TelemetryPoint: Identifiable, Sendable {
        let id = UUID()
        let timestamp: Date
        let altitudeFeet: Int
        let groundSpeedKnots: Int
    }
    var telemetrySamples: [TelemetryPoint] = []

    // Logbook
    var logbook: [FocusSessionRecord] = []

    // Internal timers
    private var tickTask: Task<Void, Never>?
    private var livePollTask: Task<Void, Never>?

    init() {
        self.selectedScope = SharedStore.shared.preferredScope
        self.mapProvider = StratoMapProvider(rawValue: SharedStore.shared.mapStyleRaw) ?? .autoHybrid
        let savedLogs = SharedStore.shared.loadLogbook()
        if savedLogs.isEmpty {
            // Seed with 3 realistic sample records if brand new so Analytics & Passport look rich immediately
            self.logbook = Self.sampleInitialRecords()
            SharedStore.shared.saveLogbook(self.logbook)
        } else {
            self.logbook = savedLogs
        }
    }

    // MARK: - Filtered Flights & Real Progress

    var filteredRadarFlights: [LiveFlight] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !query.isEmpty else { return radarFlights }
        return radarFlights.filter { f in
            f.callsign.uppercased().contains(query)
            || f.iataFlightNumber.uppercased().contains(query)
            || f.airlineName.uppercased().contains(query)
            || (f.origin?.iata.uppercased().contains(query) == true)
            || (f.origin?.city.uppercased().contains(query) == true)
            || (f.destination?.iata.uppercased().contains(query) == true)
            || (f.destination?.city.uppercased().contains(query) == true)
        }
    }

    var isFlying: Bool {
        activeFlight != nil
    }

    /// Fraction of the user's focus timer completed (0.0 ... 1.0).
    var focusTimerProgress: Double {
        guard totalPlannedSeconds > 0 else { return 0 }
        let elapsed = Double(totalPlannedSeconds - remainingSeconds)
        return min(max(elapsed / Double(totalPlannedSeconds), 0), 1)
    }

    /// The aircraft's ACTUAL real-world route progress (e.g. starts at 64% when boarded mid-air and advances to 100%).
    var liveAircraftProgress: Double {
        guard let flight = activeFlight else {
            return selectedFlight?.realFlightProgress ?? 0.5
        }
        if flight.isLiveADSB {
            // Blend real geometric progress with timer progression so it never resets to 0
            let geometric = flight.realFlightProgress
            let timerProjected = boardedAtFlightProgress + (1.0 - boardedAtFlightProgress) * focusTimerProgress
            return min(max(max(geometric, timerProjected), boardedAtFlightProgress), 0.995)
        } else {
            return min(max(boardedAtFlightProgress + (1.0 - boardedAtFlightProgress) * focusTimerProgress, 0.02), 0.995)
        }
    }

    var formattedRemainingTime: String {
        let hours = remainingSeconds / 3600
        let minutes = (remainingSeconds % 3600) / 60
        let seconds = remainingSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - Analytics & Frequent Flyer Metrics

    var totalFocusMinutes: Int {
        logbook.reduce(0) { $0 + $1.durationMinutes }
    }

    var totalDistanceKM: Int {
        logbook.reduce(0) { $0 + $1.distanceKM }
    }

    var visitedAirportsCount: Int {
        Set(logbook.flatMap { [$0.originIATA, $0.destinationIATA] }).count
    }

    var currentStreakDays: Int {
        let calendar = Calendar.current
        let uniqueDays = Set(logbook.map { calendar.startOfDay(for: $0.completedAt) }).sorted(by: >)
        guard let first = uniqueDays.first else { return 0 }
        let today = calendar.startOfDay(for: Date())
        guard let diff = calendar.dateComponents([.day], from: first, to: today).day, diff <= 1 else {
            return 0
        }
        var streak = 1
        var prev = first
        for day in uniqueDays.dropFirst() {
            if calendar.dateComponents([.day], from: day, to: prev).day == 1 {
                streak += 1
                prev = day
            } else {
                break
            }
        }
        return streak
    }

    var frequentFlyerTier: FrequentFlyerTier {
        let km = totalDistanceKM
        if km >= 50_000 {
            return FrequentFlyerTier(titleCN: "终身平流层机长", titleEN: "STRATO MILLION MILER", color: StratoTheme.amberBeacon, nextTierKM: 100_000)
        } else if km >= 20_000 {
            return FrequentFlyerTier(titleCN: "白金卡会员", titleEN: "STRATO PLATINUM", color: StratoTheme.skyCyan, nextTierKM: 50_000)
        } else if km >= 8_000 {
            return FrequentFlyerTier(titleCN: "金卡会员", titleEN: "STRATO GOLD", color: StratoTheme.amberBeacon, nextTierKM: 20_000)
        } else {
            return FrequentFlyerTier(titleCN: "银卡会员", titleEN: "STRATO SILVER", color: StratoTheme.radarEmerald, nextTierKM: 8_000)
        }
    }

    // MARK: - Global Radar Actions

    func refreshRadar(customCenter: CLLocationCoordinate2D? = nil) async {
        guard !isLoadingRadar else { return }
        isLoadingRadar = true
        radarStatusMessage = customCenter != nil ? "正在扫描当前地图视野空域…" : "并发扫描全球 12 大实时 ADS-B 空域…"

        let allLive = await ADSBService.shared.scanGlobalOrScopedAirspace(
            scope: selectedScope,
            customCenter: customCenter,
            maxResults: 90
        )

        let matched = await ADSBService.shared.recommendFlights(
            targetMinutes: targetFocusMinutes,
            preferredDestination: selectedDestination,
            scope: selectedScope,
            existingPool: allLive
        )

        self.radarFlights = allLive.isEmpty ? matched : allLive
        self.recommendedFlights = matched.isEmpty ? allLive : matched
        if selectedFlight == nil || !self.radarFlights.contains(where: { $0.id == selectedFlight?.id }) {
            self.selectedFlight = self.recommendedFlights.first ?? self.radarFlights.first
        }

        let verifiedCount = self.radarFlights.filter(\.isRouteVerified).count
        radarStatusMessage = "实时追踪 \(self.radarFlights.count) 架真飞机 (\(verifiedCount) 条时刻表航线)"
        isLoadingRadar = false
    }

    func matchFlightsForDuration() async {
        isMatchingFlights = true
        let matched = await ADSBService.shared.recommendFlights(
            targetMinutes: targetFocusMinutes,
            preferredDestination: selectedDestination,
            scope: selectedScope,
            existingPool: radarFlights
        )
        self.recommendedFlights = matched
        if let first = matched.first {
            self.selectedFlight = first
        }
        isMatchingFlights = false
    }

    // MARK: - Focus Flight Lifecycle (Starts at Aircraft's Real Position!)

    func boardAndTakeOff(
        flight: LiveFlight,
        durationMinutes: Int? = nil,
        focusTag: FocusTag,
        seatNumber: String,
        gateNumber: String,
        cabinClass: String
    ) {
        let minutes = max(1, durationMinutes ?? flight.estimatedRemainingMinutes)
        let realStartProgress = flight.realFlightProgress

        self.activeFlight = flight
        self.selectedFlight = flight
        self.selectedFocusTag = focusTag
        self.activeSeatNumber = seatNumber
        self.activeGateNumber = gateNumber
        self.activeCabinClass = cabinClass
        self.activeSequenceNumber = String(format: "SEQ %03d", Int.random(in: 1...180))
        self.boardedAtFlightProgress = realStartProgress
        self.sessionStartedAt = Date()
        self.totalPlannedSeconds = minutes * 60
        self.remainingSeconds = minutes * 60
        self.sessionTargetEndAt = Date().addingTimeInterval(TimeInterval(minutes * 60))
        self.isPaused = false
        self.cockpitViewMode = .follow3D
        self.telemetrySamples = [
            TelemetryPoint(timestamp: Date(), altitudeFeet: flight.altitudeFeet, groundSpeedKnots: Int(flight.groundSpeedKnots))
        ]

        persistActiveSnapshot()
        LiveActivityManager.shared.start(
            flight: flight,
            focusTag: focusTag,
            etaDate: sessionTargetEndAt ?? Date().addingTimeInterval(TimeInterval(minutes * 60)),
            remainingMinutes: minutes
        )

        startLoops()
    }

    func togglePause() {
        guard isFlying else { return }
        isPaused.toggle()
        if !isPaused {
            sessionTargetEndAt = Date().addingTimeInterval(TimeInterval(remainingSeconds))
        }
        syncLiveTelemetryOutputs()
    }

    func cycleCabinAudio() {
        audioPreset = AmbientSoundManager.shared.cyclePreset()
    }

    func setCabinAudio(_ preset: CabinAudioPreset) {
        AmbientSoundManager.shared.setPreset(preset)
        audioPreset = preset
    }

    func landEarly(saveToLogbook: Bool) {
        completeFlight(completedFullDuration: false, saveRecord: saveToLogbook)
    }

    func deleteLogRecord(_ record: FocusSessionRecord) {
        logbook.removeAll { $0.id == record.id }
        SharedStore.shared.saveLogbook(logbook)
    }

    // MARK: - Loops & Telemetry

    private func startLoops() {
        tickTask?.cancel()
        livePollTask?.cancel()

        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }
                self.handleSecondTick()
            }
        }

        livePollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(15))
                guard let self, !Task.isCancelled else { break }
                await self.pollLiveAircraftIfNeeded()
            }
        }
    }

    private func handleSecondTick() {
        guard var flight = activeFlight, !isPaused else { return }

        if remainingSeconds > 0 {
            remainingSeconds -= 1
        }

        // Advance aircraft along its real current position toward destination
        if let dest = flight.destination {
            if !flight.isLiveADSB, let orig = flight.origin {
                let currentFrac = liveAircraftProgress
                let nextCoord = GreatCircle.interpolate(
                    from: orig.coordinate,
                    to: dest.coordinate,
                    fraction: currentFrac
                )
                flight.trackDegrees = GreatCircle.bearingDegrees(from: flight.coordinate, to: dest.coordinate)
                flight.latitude = nextCoord.latitude
                flight.longitude = nextCoord.longitude
            } else {
                // Smooth 1-second dead-reckoning from the real ADS-B coordinate along true track
                let nmPerSecond = max(flight.groundSpeedKnots, 240) / 3600.0
                let nextCoord = GreatCircle.destination(
                    from: flight.coordinate,
                    bearingDegrees: flight.trackDegrees,
                    distanceNM: nmPerSecond
                )
                flight.latitude = nextCoord.latitude
                flight.longitude = nextCoord.longitude
            }
            activeFlight = flight
        }

        if remainingSeconds % 20 == 0 {
            telemetrySamples.append(
                TelemetryPoint(timestamp: Date(), altitudeFeet: flight.altitudeFeet, groundSpeedKnots: Int(flight.groundSpeedKnots))
            )
            if telemetrySamples.count > 60 {
                telemetrySamples.removeFirst()
            }
        }

        if remainingSeconds % 15 == 0 || remainingSeconds <= 5 {
            syncLiveTelemetryOutputs()
        }

        if remainingSeconds <= 0 {
            completeFlight(completedFullDuration: true, saveRecord: true)
        }
    }

    private func pollLiveAircraftIfNeeded() async {
        guard let current = activeFlight, current.isLiveADSB, !isPaused else { return }
        if let refreshed = await ADSBService.shared.refreshFlight(hex: current.id, existing: current) {
            self.activeFlight = refreshed
            telemetrySamples.append(
                TelemetryPoint(timestamp: Date(), altitudeFeet: refreshed.altitudeFeet, groundSpeedKnots: Int(refreshed.groundSpeedKnots))
            )
            syncLiveTelemetryOutputs()
        }
    }

    private func completeFlight(completedFullDuration: Bool, saveRecord: Bool) {
        tickTask?.cancel()
        livePollTask?.cancel()
        tickTask = nil
        livePollTask = nil

        if audioPreset != .off {
            AmbientSoundManager.shared.stop()
            audioPreset = .off
        }

        if let flight = activeFlight, saveRecord {
            let elapsedSeconds = max(60, totalPlannedSeconds - remainingSeconds)
            let elapsedMinutes = max(1, elapsedSeconds / 60)
            let orig = flight.origin ?? AirportDatabase.nearest(to: flight.coordinate)
            let dest = flight.destination ?? AirportDatabase.nearest(to: flight.coordinate)
            let distanceKM = Int((Double(elapsedMinutes) / 60.0 * max(flight.groundSpeedKnots, 410) * 1.852).rounded())

            let record = FocusSessionRecord(
                callsign: flight.callsign,
                airlineName: flight.airlineName,
                aircraftType: flight.aircraftType,
                originIATA: orig.iata,
                originCity: orig.city,
                destinationIATA: dest.iata,
                destinationCity: dest.city,
                originLat: orig.latitude,
                originLon: orig.longitude,
                destinationLat: dest.latitude,
                destinationLon: dest.longitude,
                focusTag: selectedFocusTag,
                seatNumber: activeSeatNumber,
                gateNumber: activeGateNumber,
                cabinClass: activeCabinClass,
                sequenceNumber: activeSequenceNumber,
                startedAt: sessionStartedAt ?? Date(),
                completedAt: Date(),
                durationMinutes: elapsedMinutes,
                distanceKM: max(distanceKM, 85),
                boardedAtProgress: boardedAtFlightProgress,
                landedAtProgress: liveAircraftProgress,
                wasLiveTracked: flight.isLiveADSB,
                completed: completedFullDuration
            )

            logbook.insert(record, at: 0)
            SharedStore.shared.saveLogbook(logbook)
            recentlyCompletedRecord = record
        }

        activeFlight = nil
        sessionStartedAt = nil
        sessionTargetEndAt = nil
        remainingSeconds = 0
        isPaused = false

        SharedStore.shared.saveActiveFlight(nil)
        Task {
            await LiveActivityManager.shared.endAll()
        }
    }

    private func syncLiveTelemetryOutputs() {
        persistActiveSnapshot()
        guard let flight = activeFlight else { return }
        let eta = sessionTargetEndAt ?? Date().addingTimeInterval(TimeInterval(remainingSeconds))
        LiveActivityManager.shared.update(
            progress: liveAircraftProgress,
            remainingMinutes: max(1, (remainingSeconds + 59) / 60),
            altitudeFeet: flight.altitudeFeet,
            groundSpeedKnots: Int(flight.groundSpeedKnots),
            phase: flight.phase,
            etaDate: eta,
            isPaused: isPaused
        )
    }

    private func persistActiveSnapshot() {
        guard let flight = activeFlight else {
            SharedStore.shared.saveActiveFlight(nil)
            return
        }
        let snapshot = ActiveFlightSnapshot(
            callsign: flight.callsign,
            originIATA: flight.origin?.iata ?? "LIVE",
            destinationIATA: flight.destination?.iata ?? "DEST",
            aircraftType: flight.aircraftType,
            focusTag: selectedFocusTag.rawValue,
            seatNumber: activeSeatNumber,
            progress: liveAircraftProgress,
            altitudeFeet: flight.altitudeFeet,
            groundSpeedKnots: Int(flight.groundSpeedKnots),
            phase: flight.phase.rawValue,
            startedAt: sessionStartedAt ?? Date(),
            etaDate: sessionTargetEndAt ?? Date().addingTimeInterval(TimeInterval(remainingSeconds)),
            isPaused: isPaused,
            isLiveADSB: flight.isLiveADSB
        )
        SharedStore.shared.saveActiveFlight(snapshot)
    }

    private static func sampleInitialRecords() -> [FocusSessionRecord] {
        let now = Date()
        return [
            FocusSessionRecord(
                callsign: "ANA975",
                airlineName: "全日空",
                aircraftType: "A20N",
                originIATA: "KIX",
                originCity: "大阪关西",
                destinationIATA: "PVG",
                destinationCity: "上海浦东",
                originLat: 34.4347,
                originLon: 135.2441,
                destinationLat: 31.1443,
                destinationLon: 121.8083,
                focusTag: .deepWork,
                seatNumber: "02A",
                gateNumber: "G14",
                cabinClass: "THE ROOM · 商务舱",
                sequenceNumber: "SEQ 012",
                startedAt: now.addingTimeInterval(-86400 * 1 - 5400),
                completedAt: now.addingTimeInterval(-86400 * 1),
                durationMinutes: 95,
                distanceKM: 1340,
                boardedAtProgress: 0.28,
                landedAtProgress: 1.0,
                wasLiveTracked: true,
                completed: true
            ),
            FocusSessionRecord(
                callsign: "CCA1831",
                airlineName: "中国国际航空",
                aircraftType: "A359",
                originIATA: "PEK",
                originCity: "北京首都",
                destinationIATA: "SHA",
                destinationCity: "上海虹桥",
                originLat: 40.0799,
                originLon: 116.6031,
                destinationLat: 31.1979,
                destinationLon: 121.3363,
                focusTag: .coding,
                seatNumber: "06K",
                gateNumber: "C32",
                cabinClass: "FIRST · 头等舱",
                sequenceNumber: "SEQ 005",
                startedAt: now.addingTimeInterval(-86400 * 2 - 6600),
                completedAt: now.addingTimeInterval(-86400 * 2),
                durationMinutes: 110,
                distanceKM: 1088,
                boardedAtProgress: 0.15,
                landedAtProgress: 1.0,
                wasLiveTracked: true,
                completed: true
            ),
            FocusSessionRecord(
                callsign: "CPA494",
                airlineName: "国泰航空",
                aircraftType: "A333",
                originIATA: "HKG",
                originCity: "香港",
                destinationIATA: "TPE",
                destinationCity: "台北桃园",
                originLat: 22.3080,
                originLon: 113.9185,
                destinationLat: 25.0777,
                destinationLon: 121.2328,
                focusTag: .study,
                seatNumber: "15A",
                gateNumber: "G65",
                cabinClass: "BUSINESS · 公务舱",
                sequenceNumber: "SEQ 039",
                startedAt: now.addingTimeInterval(-86400 * 3 - 4500),
                completedAt: now.addingTimeInterval(-86400 * 3),
                durationMinutes: 75,
                distanceKM: 806,
                boardedAtProgress: 0.22,
                landedAtProgress: 1.0,
                wasLiveTracked: true,
                completed: true
            )
        ]
    }
}

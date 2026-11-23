import Foundation
import SwiftUI
import MapKit
import Observation

enum StratoMapStyleOption: String, CaseIterable, Identifiable {
    case imagery = "imagery"
    case hybrid = "hybrid"
    case standard = "standard"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .imagery: return "深空卫星"
        case .hybrid: return "航路混合"
        case .standard: return "极简矢量"
        }
    }

    var mapStyle: MapStyle {
        switch self {
        case .imagery: return .imagery(elevation: .realistic)
        case .hybrid: return .hybrid(elevation: .realistic)
        case .standard: return .standard(elevation: .realistic, emphasis: .muted)
        }
    }
}

@MainActor
@Observable
final class StratoStore {
    // Radar & Discovery
    var radarFlights: [LiveFlight] = []
    var recommendedFlights: [LiveFlight] = []
    var selectedFlight: LiveFlight?
    var isLoadingRadar: Bool = false
    var isMatchingFlights: Bool = false
    var radarStatusMessage: String = "正在扫描实时 ADS-B 航路…"

    // Matcher Preferences
    var targetFocusMinutes: Int = 120
    var selectedDestination: Airport?
    var selectedFocusTag: FocusTag = .deepWork
    var selectedRegion: RadarRegion {
        didSet {
            SharedStore.shared.preferredRegion = selectedRegion
        }
    }
    var mapStyleOption: StratoMapStyleOption {
        didSet {
            SharedStore.shared.mapStyleRaw = mapStyleOption.rawValue
        }
    }

    // Active Focus Flight Session
    var activeFlight: LiveFlight?
    var activeSeatNumber: String = "12A"
    var sessionStartedAt: Date?
    var sessionTargetEndAt: Date?
    var totalPlannedSeconds: Int = 7200
    var remainingSeconds: Int = 0
    var isPaused: Bool = false
    var isCabinSoundOn: Bool = false
    var recentlyCompletedRecord: FocusSessionRecord?

    // Logbook
    var logbook: [FocusSessionRecord] = []

    // Internal timers
    private var tickTask: Task<Void, Never>?
    private var livePollTask: Task<Void, Never>?

    init() {
        self.selectedRegion = SharedStore.shared.preferredRegion
        self.mapStyleOption = StratoMapStyleOption(rawValue: SharedStore.shared.mapStyleRaw) ?? .imagery
        self.logbook = SharedStore.shared.loadLogbook()
    }

    // MARK: - Computed Stats

    var isFlying: Bool {
        activeFlight != nil
    }

    var sessionProgress: Double {
        guard totalPlannedSeconds > 0 else { return 0 }
        let elapsed = Double(totalPlannedSeconds - remainingSeconds)
        return min(max(elapsed / Double(totalPlannedSeconds), 0), 1)
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

    var totalFocusMinutes: Int {
        logbook.reduce(0) { $0 + $1.durationMinutes }
    }

    var totalDistanceKM: Int {
        logbook.reduce(0) { $0 + $1.distanceKM }
    }

    var visitedAirportsCount: Int {
        Set(logbook.flatMap { [$0.originIATA, $0.destinationIATA] }).count
    }

    // MARK: - Radar Actions

    func refreshRadar() async {
        guard !isLoadingRadar else { return }
        isLoadingRadar = true
        radarStatusMessage = "连接 ADS-B 实时雷达…"

        let flights = await ADSBService.shared.recommendFlights(
            targetMinutes: targetFocusMinutes,
            preferredDestination: selectedDestination,
            region: selectedRegion
        )

        self.radarFlights = flights
        self.recommendedFlights = flights
        if selectedFlight == nil {
            self.selectedFlight = flights.first
        }

        let liveCount = flights.filter(\.isLiveADSB).count
        if liveCount > 0 {
            radarStatusMessage = "实时追踪 \(liveCount) 架在飞航班"
        } else {
            radarStatusMessage = "已生成 \(flights.count) 条校准模拟航线"
        }
        isLoadingRadar = false
    }

    func matchFlightsForDuration() async {
        isMatchingFlights = true
        let matched = await ADSBService.shared.recommendFlights(
            targetMinutes: targetFocusMinutes,
            preferredDestination: selectedDestination,
            region: selectedRegion
        )
        self.recommendedFlights = matched
        if !matched.isEmpty {
            self.radarFlights = matched
        }
        isMatchingFlights = false
    }

    // MARK: - Focus Flight Lifecycle

    func boardAndTakeOff(
        flight: LiveFlight,
        durationMinutes: Int? = nil,
        focusTag: FocusTag,
        seatNumber: String
    ) {
        let minutes = durationMinutes ?? flight.estimatedRemainingMinutes
        let clampedMinutes = max(1, minutes)

        self.activeFlight = flight
        self.selectedFlight = flight
        self.selectedFocusTag = focusTag
        self.activeSeatNumber = seatNumber
        self.sessionStartedAt = Date()
        self.totalPlannedSeconds = clampedMinutes * 60
        self.remainingSeconds = clampedMinutes * 60
        self.sessionTargetEndAt = Date().addingTimeInterval(TimeInterval(clampedMinutes * 60))
        self.isPaused = false

        persistActiveSnapshot()
        LiveActivityManager.shared.start(
            flight: flight,
            focusTag: focusTag,
            etaDate: sessionTargetEndAt ?? Date().addingTimeInterval(TimeInterval(clampedMinutes * 60)),
            remainingMinutes: clampedMinutes
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

    func toggleCabinSound() {
        isCabinSoundOn = AmbientSoundManager.shared.toggle()
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

        // 1-second smooth timer + dead-reckoning aircraft glide
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { break }
                self.handleSecondTick()
            }
        }

        // 15-second live ADS-B position sync when tracking a real aircraft
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

        // Smoothly advance aircraft position along its heading or great-circle route
        if let dest = flight.destination {
            if !flight.isLiveADSB, let orig = flight.origin {
                let nextCoord = GreatCircle.interpolate(
                    from: orig.coordinate,
                    to: dest.coordinate,
                    fraction: max(0.02, min(0.99, sessionProgress))
                )
                flight.trackDegrees = GreatCircle.bearingDegrees(from: flight.coordinate, to: dest.coordinate)
                flight.latitude = nextCoord.latitude
                flight.longitude = nextCoord.longitude
            } else {
                // Dead-reckon real ADS-B plane smoothly between 15s network polls
                let nmPerSecond = max(flight.groundSpeedKnots, 250) / 3600.0
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

        // Sync Live Activity & Widget every 15 seconds (or last minute)
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
            syncLiveTelemetryOutputs()
        }
    }

    private func completeFlight(completedFullDuration: Bool, saveRecord: Bool) {
        tickTask?.cancel()
        livePollTask?.cancel()
        tickTask = nil
        livePollTask = nil

        if isCabinSoundOn {
            AmbientSoundManager.shared.stop()
            isCabinSoundOn = false
        }

        if let flight = activeFlight, saveRecord {
            let elapsedSeconds = max(60, totalPlannedSeconds - remainingSeconds)
            let elapsedMinutes = max(1, elapsedSeconds / 60)
            let orig = flight.origin ?? AirportDatabase.nearest(to: flight.coordinate)
            let dest = flight.destination ?? AirportDatabase.nearest(to: flight.coordinate)
            let distanceKM = Int((Double(elapsedMinutes) / 60.0 * max(flight.groundSpeedKnots, 380) * 1.852).rounded())

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
                startedAt: sessionStartedAt ?? Date(),
                completedAt: Date(),
                durationMinutes: elapsedMinutes,
                distanceKM: max(distanceKM, 50),
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
            progress: sessionProgress,
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
            progress: sessionProgress,
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
}

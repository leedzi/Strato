import Foundation
import ActivityKit

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private var currentActivity: Activity<StratoFlightAttributes>?

    var isSupported: Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }

    func start(
        flight: LiveFlight,
        focusTag: FocusTag,
        etaDate: Date,
        remainingMinutes: Int
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // End any stale activities first
        Task {
            await endAll()
            let attributes = StratoFlightAttributes(
                callsign: flight.callsign,
                originIATA: flight.origin?.iata ?? "LIVE",
                destinationIATA: flight.destination?.iata ?? "DEST",
                aircraftType: flight.aircraftType,
                focusTag: focusTag.rawValue,
                isLiveADSB: flight.isLiveADSB
            )
            let state = StratoFlightAttributes.ContentState(
                progress: flight.progress,
                remainingMinutes: remainingMinutes,
                altitudeFeet: flight.altitudeFeet,
                groundSpeedKnots: Int(flight.groundSpeedKnots),
                phase: flight.phase.rawValue,
                etaDate: etaDate,
                isPaused: false
            )
            let content = ActivityContent(state: state, staleDate: etaDate.addingTimeInterval(600))
            do {
                self.currentActivity = try Activity.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                // Gracefully ignored if sideloaded without Live Activity entitlement
            }
        }
    }

    func update(
        progress: Double,
        remainingMinutes: Int,
        altitudeFeet: Int,
        groundSpeedKnots: Int,
        phase: FlightPhase,
        etaDate: Date,
        isPaused: Bool
    ) {
        guard let activity = currentActivity else { return }
        let state = StratoFlightAttributes.ContentState(
            progress: progress,
            remainingMinutes: remainingMinutes,
            altitudeFeet: altitudeFeet,
            groundSpeedKnots: groundSpeedKnots,
            phase: phase.rawValue,
            etaDate: etaDate,
            isPaused: isPaused
        )
        Task {
            let content = ActivityContent(state: state, staleDate: etaDate.addingTimeInterval(600))
            await activity.update(content)
        }
    }

    func endAll() async {
        for activity in Activity<StratoFlightAttributes>.activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        currentActivity = nil
    }
}

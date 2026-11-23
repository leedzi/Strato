import ActivityKit
import Foundation

/// The Live Activity shown on the Lock Screen and in the Dynamic Island during a focus flight.
struct StratoFlightAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Touchdown (or timer end). Countdown text and the progress bar animate toward this on their own.
        var plannedEnd: Date
        /// See `WidgetSnapshot.Flight.routeStart`.
        var routeStart: Date
        var isPaused: Bool
        var pausedRemaining: TimeInterval?
        var phaseTitle: String
        var altitudeFt: Int
        var groundSpeedKt: Int
        /// True once the flight is over; the activity then shows the arrival.
        var landed: Bool
    }

    var flightNumber: String
    var airlineICAO: String?
    var originCode: String
    var originCity: String
    var destinationCode: String
    var destinationCity: String
    var tagTitle: String
    var seat: String
    var simulated: Bool
}

extension StratoFlightAttributes.ContentState {
    func fraction(at now: Date) -> Double {
        if landed { return 1 }
        let total = plannedEnd.timeIntervalSince(routeStart)
        guard total > 1 else { return 1 }
        let reference = isPaused ? plannedEnd.addingTimeInterval(-(pausedRemaining ?? 0)) : now
        return min(max(reference.timeIntervalSince(routeStart) / total, 0), 1)
    }
}

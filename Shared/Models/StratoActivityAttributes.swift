import Foundation
import ActivityKit

public struct StratoFlightAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var progress: Double
        public var remainingMinutes: Int
        public var altitudeFeet: Int
        public var groundSpeedKnots: Int
        public var phase: String
        public var etaDate: Date
        public var isPaused: Bool

        public init(
            progress: Double,
            remainingMinutes: Int,
            altitudeFeet: Int,
            groundSpeedKnots: Int,
            phase: String,
            etaDate: Date,
            isPaused: Bool
        ) {
            self.progress = progress
            self.remainingMinutes = remainingMinutes
            self.altitudeFeet = altitudeFeet
            self.groundSpeedKnots = groundSpeedKnots
            self.phase = phase
            self.etaDate = etaDate
            self.isPaused = isPaused
        }
    }

    public var callsign: String
    public var originIATA: String
    public var destinationIATA: String
    public var aircraftType: String
    public var focusTag: String
    public var isLiveADSB: Bool

    public init(
        callsign: String,
        originIATA: String,
        destinationIATA: String,
        aircraftType: String,
        focusTag: String,
        isLiveADSB: Bool
    ) {
        self.callsign = callsign
        self.originIATA = originIATA
        self.destinationIATA = destinationIATA
        self.aircraftType = aircraftType
        self.focusTag = focusTag
        self.isLiveADSB = isLiveADSB
    }
}

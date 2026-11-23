import Foundation

public struct FocusSessionRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public let callsign: String
    public let airlineName: String
    public let aircraftType: String
    public let originIATA: String
    public let originCity: String
    public let destinationIATA: String
    public let destinationCity: String
    public let originLat: Double
    public let originLon: Double
    public let destinationLat: Double
    public let destinationLon: Double
    public let focusTag: FocusTag
    public let seatNumber: String
    public let gateNumber: String
    public let cabinClass: String
    public let sequenceNumber: String
    public let startedAt: Date
    public let completedAt: Date
    public let durationMinutes: Int
    public let distanceKM: Int
    public let boardedAtProgress: Double
    public let landedAtProgress: Double
    public let wasLiveTracked: Bool
    public let completed: Bool

    public init(
        id: UUID = UUID(),
        callsign: String,
        airlineName: String,
        aircraftType: String,
        originIATA: String,
        originCity: String,
        destinationIATA: String,
        destinationCity: String,
        originLat: Double,
        originLon: Double,
        destinationLat: Double,
        destinationLon: Double,
        focusTag: FocusTag,
        seatNumber: String,
        gateNumber: String = "G18",
        cabinClass: String = "BUSINESS",
        sequenceNumber: String = "SEQ 024",
        startedAt: Date,
        completedAt: Date,
        durationMinutes: Int,
        distanceKM: Int,
        boardedAtProgress: Double = 0.35,
        landedAtProgress: Double = 1.0,
        wasLiveTracked: Bool,
        completed: Bool
    ) {
        self.id = id
        self.callsign = callsign
        self.airlineName = airlineName
        self.aircraftType = aircraftType
        self.originIATA = originIATA
        self.originCity = originCity
        self.destinationIATA = destinationIATA
        self.destinationCity = destinationCity
        self.originLat = originLat
        self.originLon = originLon
        self.destinationLat = destinationLat
        self.destinationLon = destinationLon
        self.focusTag = focusTag
        self.seatNumber = seatNumber
        self.gateNumber = gateNumber
        self.cabinClass = cabinClass
        self.sequenceNumber = sequenceNumber
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.durationMinutes = durationMinutes
        self.distanceKM = distanceKM
        self.boardedAtProgress = boardedAtProgress
        self.landedAtProgress = landedAtProgress
        self.wasLiveTracked = wasLiveTracked
        self.completed = completed
    }
}

/// Compact snapshot written to shared storage so Home Screen Widgets always reflect the live focus flight.
public struct ActiveFlightSnapshot: Codable, Sendable {
    public let callsign: String
    public let originIATA: String
    public let destinationIATA: String
    public let aircraftType: String
    public let focusTag: String
    public let seatNumber: String
    public let progress: Double
    public let altitudeFeet: Int
    public let groundSpeedKnots: Int
    public let phase: String
    public let startedAt: Date
    public let etaDate: Date
    public let isPaused: Bool
    public let isLiveADSB: Bool

    public init(
        callsign: String,
        originIATA: String,
        destinationIATA: String,
        aircraftType: String,
        focusTag: String,
        seatNumber: String,
        progress: Double,
        altitudeFeet: Int,
        groundSpeedKnots: Int,
        phase: String,
        startedAt: Date,
        etaDate: Date,
        isPaused: Bool,
        isLiveADSB: Bool
    ) {
        self.callsign = callsign
        self.originIATA = originIATA
        self.destinationIATA = destinationIATA
        self.aircraftType = aircraftType
        self.focusTag = focusTag
        self.seatNumber = seatNumber
        self.progress = progress
        self.altitudeFeet = altitudeFeet
        self.groundSpeedKnots = groundSpeedKnots
        self.phase = phase
        self.startedAt = startedAt
        self.etaDate = etaDate
        self.isPaused = isPaused
        self.isLiveADSB = isLiveADSB
    }
}

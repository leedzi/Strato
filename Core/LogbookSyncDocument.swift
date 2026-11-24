import Foundation

enum LogbookSyncDocumentError: LocalizedError, Equatable {
    case unsupportedSchema(Int)
    case malformedDocument

    var errorDescription: String? {
        switch self {
        case .unsupportedSchema(let version):
            return "同步文件使用了不支持的版本（\(version)），请更新 Strato。原文件已保留。"
        case .malformedDocument:
            return "同步文件内容损坏或不完整，原文件已保留。"
        }
    }
}

/// Each device owns one document. Records are immutable finished sessions; tombstones never expire.
struct LogbookSyncDocument: Codable, Equatable, Sendable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let deviceID: UUID
    private(set) var deletedRecordIDs: Set<UUID>
    private var recordsByID: [UUID: FocusRecord]

    /// A stable order for both the logbook and comparisons between devices.
    var records: [FocusRecord] {
        recordsByID.values.sorted {
            if $0.endedAt != $1.endedAt { return $0.endedAt > $1.endedAt }
            if $0.startedAt != $1.startedAt { return $0.startedAt > $1.startedAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    init(deviceID: UUID, records: [FocusRecord], deletedRecordIDs: Set<UUID> = []) throws {
        self.schemaVersion = Self.currentSchemaVersion
        self.deviceID = deviceID
        self.deletedRecordIDs = deletedRecordIDs
        var keyed: [UUID: FocusRecord] = [:]
        for record in records {
            try Self.validate(record)
            guard !deletedRecordIDs.contains(record.id) else { continue }
            if let existing = keyed[record.id] {
                keyed[record.id] = try Self.preferred(existing, record)
            } else {
                keyed[record.id] = record
            }
        }
        self.recordsByID = keyed
    }

    /// Commutative and idempotent: an old device snapshot cannot undo a deletion.
    static func merge(
        deviceID: UUID,
        localRecords: [FocusRecord],
        deletedRecordIDs: Set<UUID> = [],
        documents: [LogbookSyncDocument]
    ) throws -> LogbookSyncDocument {
        var deletions = deletedRecordIDs
        var allRecords = localRecords
        for document in documents {
            guard document.schemaVersion == currentSchemaVersion else {
                throw LogbookSyncDocumentError.unsupportedSchema(document.schemaVersion)
            }
            deletions.formUnion(document.deletedRecordIDs)
            allRecords.append(contentsOf: document.records)
        }
        return try LogbookSyncDocument(
            deviceID: deviceID, records: allRecords, deletedRecordIDs: deletions
        )
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> LogbookSyncDocument {
        do {
            return try JSONDecoder().decode(LogbookSyncDocument.self, from: data)
        } catch let error as LogbookSyncDocumentError {
            throw error
        } catch {
            throw LogbookSyncDocumentError.malformedDocument
        }
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, deviceID, records, deletedRecordIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let version = try container.decode(Int.self, forKey: .schemaVersion)
        guard version == Self.currentSchemaVersion else {
            throw LogbookSyncDocumentError.unsupportedSchema(version)
        }
        let device = try container.decode(UUID.self, forKey: .deviceID)
        let deletions = Set(try container.decode([UUID].self, forKey: .deletedRecordIDs))
        let rawRecords = try container.decode([String: FocusRecord].self, forKey: .records)
        var keyed: [UUID: FocusRecord] = [:]
        for (key, record) in rawRecords {
            guard let id = UUID(uuidString: key), id == record.id, keyed[id] == nil else {
                throw LogbookSyncDocumentError.malformedDocument
            }
            try Self.validate(record)
            keyed[id] = record
        }
        self.schemaVersion = version
        self.deviceID = device
        self.deletedRecordIDs = deletions
        self.recordsByID = keyed.filter { !deletions.contains($0.key) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(deviceID, forKey: .deviceID)
        let keyed = Dictionary(uniqueKeysWithValues: recordsByID.map { ($0.key.uuidString, $0.value) })
        try container.encode(keyed, forKey: .records)
        try container.encode(
            deletedRecordIDs.sorted { $0.uuidString < $1.uuidString }, forKey: .deletedRecordIDs
        )
    }

    /// There is no edit timestamp on a finished record. Canonical bytes provide a total,
    /// deterministic order if two surviving copies with the same UUID ever differ.
    private static func preferred(_ first: FocusRecord, _ second: FocusRecord) throws -> FocusRecord {
        guard first != second else { return first }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let a = try encoder.encode(first)
        let b = try encoder.encode(second)
        return a.lexicographicallyPrecedes(b) ? second : first
    }

    private static func validate(_ record: FocusRecord) throws {
        func valid(_ point: GeoPoint) -> Bool {
            point.lat.isFinite && point.lon.isFinite
                && (-90...90).contains(point.lat) && (-180...180).contains(point.lon)
        }
        guard record.startedAt.timeIntervalSinceReferenceDate.isFinite,
              record.endedAt.timeIntervalSinceReferenceDate.isFinite,
              record.endedAt >= record.startedAt,
              record.focusSeconds >= 0, record.pausedSeconds >= 0, record.pauseCount >= 0,
              record.distanceKm.isFinite, record.distanceKm >= 0,
              record.routeKm.isFinite, record.routeKm >= 0,
              record.boardedFraction.isFinite, (0...1).contains(record.boardedFraction),
              record.endFraction.isFinite, (0...1).contains(record.endFraction),
              valid(record.origin.point), valid(record.destination.point),
              record.path.allSatisfy(valid) else {
            throw LogbookSyncDocumentError.malformedDocument
        }
    }
}

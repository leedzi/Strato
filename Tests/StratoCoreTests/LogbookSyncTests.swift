import Foundation
import XCTest
@testable import StratoCore

final class LogbookSyncTests: XCTestCase {
    private let deviceA = UUID(uuidString: "11111111-1111-4111-8111-111111111111")!
    private let deviceB = UUID(uuidString: "22222222-2222-4222-8222-222222222222")!

    private func record(_ id: String, endOffset: TimeInterval = 600) -> FocusRecord {
        let route = Fixtures.route(Fixtures.pvg, Fixtures.hnd)
        let session = FocusSession(
            flight: LiveFlight(state: Fixtures.cruising(route, fraction: 0.4), route: route),
            route: route, tag: .coding, seat: "12A", cabin: .business, gate: "G16",
            sequence: 18, startedAt: Fixtures.t0, timerMinutes: 10
        )
        var record = session.record(FocusSession.Completion(
            outcome: .timerDone, endedAt: Fixtures.t0.addingTimeInterval(endOffset), estimated: false
        ))
        record.id = UUID(uuidString: id)!
        return record
    }

    func testRoundTripUsesUUIDKeysAndPreservesFinishedRecord() throws {
        let finished = record("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let deleted = UUID(uuidString: "bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")!
        let document = try LogbookSyncDocument(
            deviceID: deviceA, records: [finished], deletedRecordIDs: [deleted]
        )
        let data = try document.encoded()
        XCTAssertEqual(try LogbookSyncDocument.decode(data), document)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keyed = try XCTUnwrap(object["records"] as? [String: Any])
        XCTAssertEqual(Set(keyed.keys), [finished.id.uuidString])
        XCTAssertEqual(object["schemaVersion"] as? Int, 1)
        XCTAssertNil(object["session"])
    }

    func testDevicesMergeWithoutDuplicatesAndSortConsistently() throws {
        let older = record("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa", endOffset: 300)
        let newer = record("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb", endOffset: 900)
        let remote = try LogbookSyncDocument(deviceID: deviceB, records: [newer, older])
        let merged = try LogbookSyncDocument.merge(
            deviceID: deviceA, localRecords: [older], documents: [remote, remote]
        )
        XCTAssertEqual(merged.records, [newer, older])
        XCTAssertEqual(
            try LogbookSyncDocument.merge(
                deviceID: deviceA, localRecords: merged.records, documents: [remote]
            ), merged
        )
    }

    func testConflictingCopiesConvergeRegardlessOfMergeOrder() throws {
        let original = record("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        var other = original
        other.seat = "18K"
        other.focusSeconds += 2
        let a = try LogbookSyncDocument(deviceID: deviceA, records: [original])
        let b = try LogbookSyncDocument(deviceID: deviceB, records: [other])
        let ab = try LogbookSyncDocument.merge(
            deviceID: deviceA, localRecords: [], documents: [a, b]
        )
        let ba = try LogbookSyncDocument.merge(
            deviceID: deviceA, localRecords: [], documents: [b, a]
        )
        XCTAssertEqual(ab, ba)
        XCTAssertEqual(ab.records.count, 1)
        XCTAssertEqual(
            try LogbookSyncDocument.merge(
                deviceID: deviceA, localRecords: [original, other], documents: [ab, ba]
            ), ab
        )
    }

    func testOfflineSnapshotCannotResurrectPermanentlyDeletedRecord() throws {
        let finished = record("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let stale = try LogbookSyncDocument(deviceID: deviceB, records: [finished])
        let deletion = try LogbookSyncDocument(
            deviceID: deviceA, records: [], deletedRecordIDs: [finished.id]
        )
        let first = try LogbookSyncDocument.merge(
            deviceID: deviceB, localRecords: [finished], documents: [stale, deletion]
        )
        let later = try LogbookSyncDocument.merge(
            deviceID: deviceA, localRecords: [finished], documents: [first, stale]
        )
        XCTAssertTrue(later.records.isEmpty)
        XCTAssertEqual(later.deletedRecordIDs, [finished.id])
    }

    func testTombstonesFromBothDevicesAreRetained() throws {
        let one = record("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let two = record("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let three = record("cccccccc-cccc-4ccc-8ccc-cccccccccccc")
        let a = try LogbookSyncDocument(
            deviceID: deviceA, records: [two, three], deletedRecordIDs: [one.id]
        )
        let b = try LogbookSyncDocument(
            deviceID: deviceB, records: [one, three], deletedRecordIDs: [two.id]
        )
        let merged = try LogbookSyncDocument.merge(
            deviceID: deviceA, localRecords: [one, two], documents: [a, b]
        )
        XCTAssertEqual(merged.records, [three])
        XCTAssertEqual(merged.deletedRecordIDs, [one.id, two.id])
    }

    func testCanonicalEncodingAndTieOrderDoNotDependOnInputOrder() throws {
        let one = record("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let two = record("bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb")
        let deletedA = UUID(uuidString: "cccccccc-cccc-4ccc-8ccc-cccccccccccc")!
        let deletedB = UUID(uuidString: "dddddddd-dddd-4ddd-8ddd-dddddddddddd")!
        let a = try LogbookSyncDocument(
            deviceID: deviceA, records: [two, one], deletedRecordIDs: [deletedB, deletedA]
        )
        let b = try LogbookSyncDocument(
            deviceID: deviceA, records: [one, two, one], deletedRecordIDs: [deletedA, deletedB]
        )
        XCTAssertEqual(a.records, [one, two])
        XCTAssertEqual(try a.encoded(), try b.encoded())
    }

    func testFutureSchemaIsRejectedBeforeTryingToInterpretItsRecords() {
        let data = Data(#"{"schemaVersion":99}"#.utf8)
        XCTAssertThrowsError(try LogbookSyncDocument.decode(data)) {
            XCTAssertEqual($0 as? LogbookSyncDocumentError, .unsupportedSchema(99))
        }
    }

    func testMismatchedRecordKeyAndMalformedInputAreRejected() throws {
        let finished = record("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        let original = try LogbookSyncDocument(deviceID: deviceA, records: [finished]).encoded()
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [String: Any])
        let keyed = try XCTUnwrap(object["records"] as? [String: Any])
        object["records"] = [deviceB.uuidString: try XCTUnwrap(keyed[finished.id.uuidString])]
        let mismatch = try JSONSerialization.data(withJSONObject: object)
        for data in [mismatch, Data("not JSON".utf8), Data(#"{"schemaVersion":1}"#.utf8)] {
            XCTAssertThrowsError(try LogbookSyncDocument.decode(data)) {
                XCTAssertEqual($0 as? LogbookSyncDocumentError, .malformedDocument)
            }
        }
    }

    func testInvalidFinishedRecordValuesAreRejected() {
        let original = record("aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa")
        var backwards = original
        backwards.endedAt = original.startedAt.addingTimeInterval(-1)
        var negative = original
        negative.focusSeconds = -1
        var invalidPoint = original
        invalidPoint.path = [GeoPoint(100, 0)]
        var nonfinite = original
        nonfinite.distanceKm = .infinity
        for invalid in [backwards, negative, invalidPoint, nonfinite] {
            XCTAssertThrowsError(try LogbookSyncDocument(deviceID: deviceA, records: [invalid])) {
                XCTAssertEqual($0 as? LogbookSyncDocumentError, .malformedDocument)
            }
        }
    }
}

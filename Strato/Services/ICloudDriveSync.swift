import Foundation
import Observation

/// The document picker supplies folder access; no iCloud entitlement or new App ID is needed.
@MainActor
@Observable
final class ICloudDriveSync {
    private(set) var isConnected = false
    private(set) var folderName = ""
    private(set) var statusText = "正在恢复同步连接"
    private(set) var lastSyncedAt: Date?
    private(set) var isSyncing = false
    private(set) var errorMessage: String?

    @ObservationIgnored var onRemoteChange: (() -> Void)?
    @ObservationIgnored private let io: LogbookSyncIO
    @ObservationIgnored private var startupTask: Task<Void, Never>?
    @ObservationIgnored private var syncTask: Task<[FocusRecord], Error>?
    @ObservationIgnored private var syncJob: UUID?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var requestRevision = 0
    @ObservationIgnored private var persistenceRevision = 0
    @ObservationIgnored private var deviceID = UUID()
    @ObservationIgnored private var knownRecords: [FocusRecord] = []
    @ObservationIgnored private var deletedRecordIDs: Set<UUID> = []

    init(storageFolderName: String = Storage.folderName) {
        io = LogbookSyncIO(storageFolderName: storageFolderName)
        startupTask = Task { [weak self] in
            guard let self else { return }
            await self.restoreConnection()
        }
    }

    func connect(to url: URL, records: [FocusRecord]) async throws -> [FocusRecord] {
        await startupTask?.value
        generation += 1
        let currentGeneration = generation
        syncTask?.cancel()
        syncTask = nil
        syncJob = nil
        isConnected = false
        isSyncing = true
        statusText = "正在连接同步文件夹"
        errorMessage = nil
        do {
            let state = try await io.connect(
                to: url, generation: currentGeneration,
                onChange: remoteCallback(for: currentGeneration)
            )
            guard generation == currentGeneration else { throw CancellationError() }
            adopt(state)
            return try await sync(records: records)
        } catch {
            if generation == currentGeneration {
                isSyncing = false
                report(error)
            }
            throw userFacing(error)
        }
    }

    /// Overlapping callers join one operation. New local records/deletions cause another pass
    /// before that operation returns, so a stale snapshot cannot replace a newly finished flight.
    func sync(records: [FocusRecord]) async throws -> [FocusRecord] {
        await startupTask?.value
        guard isConnected else { throw ICloudDriveSyncError.notConnected }
        do {
            try absorb(records)
        } catch {
            report(error)
            throw userFacing(error)
        }
        requestRevision += 1
        if let task = syncTask { return try await task.value }

        let currentGeneration = generation
        let job = UUID()
        syncJob = job
        isSyncing = true
        statusText = "正在同步航行记录"
        errorMessage = nil
        let task = Task { [weak self] () throws -> [FocusRecord] in
            guard let self else { throw CancellationError() }
            return try await self.runSync(generation: currentGeneration, job: job)
        }
        syncTask = task
        return try await task.value
    }

    /// Save deletion markers even while disconnected or offline. Absence from a snapshot
    /// is never interpreted as deletion.
    @discardableResult
    func markDeleted(_ ids: [UUID]) -> Task<Void, Error> {
        let added = Set(ids).subtracting(deletedRecordIDs)
        deletedRecordIDs.formUnion(added)
        knownRecords.removeAll { added.contains($0.id) }
        if !added.isEmpty { requestRevision += 1 }
        let revision = persistenceRevision
        return Task { [weak self, io] () throws -> Void in
            do {
                // Retry a previous failed save even if these IDs are already in memory.
                try await io.addDeleted(Set(ids))
                self?.persistenceRevision += 1
            } catch {
                if let self, self.persistenceRevision == revision { self.report(error) }
                throw userFacing(error)
            }
        }
    }

    /// Leaves all device documents, local records and permanent deletion metadata intact.
    func disconnect() {
        generation += 1
        let currentGeneration = generation
        syncTask?.cancel()
        syncTask = nil
        syncJob = nil
        isConnected = false
        isSyncing = false
        folderName = ""
        statusText = "未连接"
        errorMessage = nil
        Task { [weak self, io] in
            do {
                try await io.disconnect(generation: currentGeneration)
            } catch {
                guard let self, self.generation == currentGeneration else { return }
                self.report(error)
            }
        }
    }

    /// The owner persists the returned array in its logbook. Keep the visible outcome honest
    /// if that separate save fails after the device document was successfully merged.
    func reportLocalSaveFailure() {
        errorMessage = "本机航行记录保存失败，请稍后重试。"
        statusText = "同步未完成，等待保存本机记录"
    }

    private func restoreConnection() async {
        // A synchronous disconnect immediately after init must not be undone by this task.
        let currentGeneration = 0
        guard generation == currentGeneration else { return }
        do {
            let state = try await io.restore(
                generation: currentGeneration, onChange: remoteCallback(for: currentGeneration)
            )
            guard generation == currentGeneration else { return }
            adopt(state)
            if isConnected { onRemoteChange?() }
        } catch {
            guard generation == currentGeneration else { return }
            statusText = "同步连接无法恢复"
            report(error)
        }
    }

    private func adopt(_ state: LogbookSyncState) {
        deviceID = state.deviceID
        deletedRecordIDs.formUnion(state.deletedRecordIDs)
        knownRecords.removeAll { deletedRecordIDs.contains($0.id) }
        isConnected = state.folder != nil
        folderName = state.folder?.lastPathComponent ?? ""
        lastSyncedAt = state.lastSyncedAt
        statusText = isConnected ? "已连接，等待同步" : "未连接"
        errorMessage = state.warning
    }

    private func absorb(_ records: [FocusRecord]) throws {
        knownRecords = try LogbookSyncDocument(
            deviceID: deviceID, records: knownRecords + records, deletedRecordIDs: deletedRecordIDs
        ).records
    }

    private func runSync(generation expectedGeneration: Int, job: UUID) async throws -> [FocusRecord] {
        defer {
            if generation == expectedGeneration, syncJob == job {
                syncTask = nil
                syncJob = nil
                isSyncing = false
            }
        }
        do {
            while true {
                try Task.checkCancellation()
                guard generation == expectedGeneration, isConnected else { throw CancellationError() }
                let revision = requestRevision
                let result = try await io.sync(
                    generation: expectedGeneration, records: knownRecords,
                    deletedRecordIDs: deletedRecordIDs
                )
                try Task.checkCancellation()
                guard generation == expectedGeneration, isConnected else { throw CancellationError() }
                deletedRecordIDs.formUnion(result.document.deletedRecordIDs)
                try absorb(result.document.records)
                persistenceRevision += 1
                lastSyncedAt = result.syncedAt
                folderName = result.folder.lastPathComponent
                if requestRevision != revision { continue }
                errorMessage = nil
                statusText = "航行记录已同步"
                return knownRecords
            }
        } catch {
            if generation == expectedGeneration { report(error) }
            throw userFacing(error)
        }
    }

    private func remoteCallback(for expectedGeneration: Int) -> @Sendable () -> Void {
        { [weak self] in
            Task { @MainActor in
                guard let self, self.generation == expectedGeneration, self.isConnected else { return }
                self.onRemoteChange?()
            }
        }
    }

    private func report(_ error: Error) {
        guard !(error is CancellationError) else { return }
        errorMessage = logbookSyncMessage(error)
        statusText = isConnected ? "同步暂不可用，可稍后重试" : "同步连接不可用"
    }
}

private enum ICloudDriveSyncError: LocalizedError {
    case notConnected
    case invalidFolder
    case localStorageUnavailable
    case invalidLocalState
    case localStateWriteFailed
    case bookmarkWriteFailed
    case invalidDocumentName
    case documentIdentityMismatch
    case coordinationFailed

    var errorDescription: String? {
        switch self {
        case .notConnected: return "请先选择一个同步文件夹。"
        case .invalidFolder: return "所选位置不是可访问的文件夹，请重新选择。"
        case .localStorageUnavailable: return "无法打开本机同步信息的保存位置。"
        case .invalidLocalState: return "本机同步信息无法读取，原信息已保留。"
        case .localStateWriteFailed: return "本机同步信息保存失败，请稍后重试。"
        case .bookmarkWriteFailed: return "同步文件夹的访问凭据保存失败，请重新选择。"
        case .invalidDocumentName: return "文件夹内有名称不完整的 Strato 同步文件，原文件已保留。"
        case .documentIdentityMismatch: return "同步文件的设备标识与文件名不一致，原文件已保留。"
        case .coordinationFailed: return "文件夹暂时无法访问，请稍后重试。"
        }
    }
}

private struct LogbookSyncFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

private func logbookSyncMessage(_ error: Error) -> String {
    if let failure = error as? LogbookSyncFailure { return failure.message }
    if let error = error as? LogbookSyncDocumentError { return error.localizedDescription }
    if let error = error as? ICloudDriveSyncError { return error.localizedDescription }
    let nsError = error as NSError
    if nsError.domain == NSCocoaErrorDomain {
        switch CocoaError.Code(rawValue: nsError.code) {
        case .fileReadNoPermission, .fileWriteNoPermission:
            return "同步文件夹访问被拒绝，请重新选择。"
        case .fileWriteOutOfSpace:
            return "存储空间不足，同步未完成。"
        case .fileReadNoSuchFile, .fileNoSuchFile:
            return "同步文件夹或文件暂不可用，请稍后重试。"
        default: break
        }
    }
    return "同步暂不可用，请稍后重试。"
}

private func userFacing(_ error: Error) -> Error {
    if error is CancellationError { return error }
    return LogbookSyncFailure(message: logbookSyncMessage(error))
}

private struct LogbookSyncState: Sendable {
    var deviceID: UUID
    var deletedRecordIDs: Set<UUID>
    var folder: URL?
    var lastSyncedAt: Date?
    var warning: String?
}

private struct LogbookSyncResult: Sendable {
    var document: LogbookSyncDocument
    var folder: URL
    var syncedAt: Date
}

/// All bookmarks, directory enumeration, coordinated reads/writes and local persistence run
/// on this actor's executor, never on the main actor.
private actor LogbookSyncIO {
    private struct LocalState: Codable {
        let schemaVersion: Int
        let deviceID: UUID
        var deletedRecordIDs: [UUID]
        var lastSyncedAt: Date?
    }

    private static let stateFilename = "icloud-drive-sync-state.json"
    private static let bookmarkFilename = "icloud-drive-sync-folder.bookmark"
    private let storageFolderName: String
    private var localRoot: URL?
    private var localState: LocalState?
    private var localStateDirty = false
    private var folder: URL?
    private var securityScopeURL: URL?
    private var presenter: LogbookFolderPresenter?
    private var generation = -1

    init(storageFolderName: String) {
        self.storageFolderName = storageFolderName
    }

    deinit {
        if let presenter { NSFileCoordinator.removeFilePresenter(presenter) }
        securityScopeURL?.stopAccessingSecurityScopedResource()
    }

    func restore(generation newGeneration: Int, onChange: @escaping @Sendable () -> Void) throws -> LogbookSyncState {
        guard newGeneration >= generation else { throw CancellationError() }
        generation = newGeneration
        let state = try loadState()
        let bookmarkURL = try root().appendingPathComponent(Self.bookmarkFilename)
        guard FileManager.default.fileExists(atPath: bookmarkURL.path) else {
            return snapshot(state)
        }
        let data = try Data(contentsOf: bookmarkURL)
        var stale = false
        // iOS preserves picker-granted access with a normal bookmark. The macOS-only
        // .withSecurityScope creation/resolution option must not be used here.
        let url = try URL(
            resolvingBookmarkData: data, options: [.withoutUI],
            relativeTo: nil, bookmarkDataIsStale: &stale
        )
        try Task.checkCancellation()
        install(url, deviceID: state.deviceID, onChange: onChange)
        var restored = snapshot(state)
        if stale {
            do {
                try saveBookmark(url)
            } catch {
                restored.warning = logbookSyncMessage(error)
            }
        }
        do {
            try coordinatedRead(url, presenter: presenter) { coordinatedURL in
                let values = try coordinatedURL.resourceValues(forKeys: [.isDirectoryKey])
                guard values.isDirectory == true else { throw ICloudDriveSyncError.invalidFolder }
            }
        } catch {
            // A remembered folder remains connected while offline, so foreground recovery
            // can retry it without making the user choose a folder again.
            restored.warning = logbookSyncMessage(error)
        }
        return restored
    }

    func connect(
        to url: URL, generation newGeneration: Int,
        onChange: @escaping @Sendable () -> Void
    ) throws -> LogbookSyncState {
        guard newGeneration >= generation else { throw CancellationError() }
        generation = newGeneration
        let state = try loadState()
        let access = url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        let temporaryPresenter = LogbookFolderPresenter(
            url: url, ownDocumentName: Self.documentName(state.deviceID), onChange: onChange
        )
        try coordinatedRead(url, presenter: temporaryPresenter) { coordinatedURL in
            let values = try coordinatedURL.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory == true else { throw ICloudDriveSyncError.invalidFolder }
            // Prove that folder enumeration is authorized before replacing a remembered folder.
            _ = try FileManager.default.contentsOfDirectory(
                at: coordinatedURL, includingPropertiesForKeys: nil
            )
        }
        try Task.checkCancellation()
        try saveBookmark(url)
        install(url, deviceID: state.deviceID, onChange: onChange)
        return snapshot(state)
    }

    func addDeleted(_ ids: Set<UUID>) throws {
        let state = try loadState()
        let combined = Set(state.deletedRecordIDs).union(ids)
        if combined != Set(state.deletedRecordIDs) {
            localState?.deletedRecordIDs = sortedIDs(combined)
            localStateDirty = true
        }
        guard localStateDirty else { return }
        // Keep the union in memory even if storage is temporarily unavailable.
        try saveState()
    }

    func disconnect(generation newGeneration: Int) throws {
        guard newGeneration >= generation else { return }
        generation = newGeneration
        closeFolder()
        let bookmarkURL = try root().appendingPathComponent(Self.bookmarkFilename)
        if FileManager.default.fileExists(atPath: bookmarkURL.path) {
            try FileManager.default.removeItem(at: bookmarkURL)
        }
    }

    func sync(
        generation expectedGeneration: Int, records: [FocusRecord], deletedRecordIDs: Set<UUID>
    ) throws -> LogbookSyncResult {
        try Task.checkCancellation()
        guard generation == expectedGeneration, folder != nil else { throw CancellationError() }
        let state = try loadState()
        try addDeleted(deletedRecordIDs)
        try followFolderMove()
        guard let folder else { throw ICloudDriveSyncError.notConnected }
        let listed = try coordinatedRead(folder, presenter: presenter) { coordinatedURL in
            try FileManager.default.contentsOfDirectory(
                at: coordinatedURL, includingPropertiesForKeys: nil
            )
        }
        let files = Set(listed.compactMap { Self.syncDocumentURL($0) })
            .sorted { $0.lastPathComponent < $1.lastPathComponent }

        var documents: [LogbookSyncDocument] = []
        for file in files {
            try Task.checkCancellation()
            guard let fileDeviceID = Self.deviceID(from: file) else {
                throw ICloudDriveSyncError.invalidDocumentName
            }
            if !FileManager.default.fileExists(atPath: file.path) {
                // Legacy iCloud Drive can expose only a hidden .icloud placeholder.
                // The coordinated read below is authoritative; if hydration is unavailable,
                // it throws and the next foreground/provider notification can retry.
                try? FileManager.default.startDownloadingUbiquitousItem(at: file)
            }
            let document = try coordinatedRead(file, presenter: presenter) { coordinatedURL in
                try Self.readDocument(coordinatedURL, expectedDeviceID: fileDeviceID)
            }
            documents.append(document)
        }
        // Validate every input before any cloud write. An unsupported/corrupt device file
        // stops the operation, rather than being silently ignored or overwritten.
        var merged = try LogbookSyncDocument.merge(
            deviceID: state.deviceID, localRecords: records,
            deletedRecordIDs: Set(localState?.deletedRecordIDs ?? []), documents: documents
        )
        try addDeleted(merged.deletedRecordIDs)
        // The device ID and all observed deletions must be durable before writing to cloud.
        if localStateDirty { try saveState() }
        let ownURL = folder.appendingPathComponent(Self.documentName(state.deviceID))
        try coordinatedWrite(ownURL, presenter: presenter) { coordinatedURL in
            var existing: LogbookSyncDocument?
            if FileManager.default.fileExists(atPath: coordinatedURL.path) {
                let latest = try Self.readDocument(coordinatedURL, expectedDeviceID: state.deviceID)
                existing = latest
                merged = try LogbookSyncDocument.merge(
                    deviceID: state.deviceID, localRecords: merged.records,
                    deletedRecordIDs: merged.deletedRecordIDs, documents: [latest]
                )
                try addDeleted(merged.deletedRecordIDs)
            }
            try Task.checkCancellation()
            if existing != merged {
                try merged.encoded().write(to: coordinatedURL, options: [.atomic])
            }
        }
        let syncedAt = Date()
        localState?.lastSyncedAt = syncedAt
        try saveState()
        return LogbookSyncResult(document: merged, folder: folder, syncedAt: syncedAt)
    }

    private func root() throws -> URL {
        if let localRoot { return localRoot }
        guard let base = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first else { throw ICloudDriveSyncError.localStorageUnavailable }
        let url = base.appendingPathComponent(storageFolderName, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        localRoot = url
        return url
    }

    private func loadState() throws -> LocalState {
        if let localState { return localState }
        let url = try root().appendingPathComponent(Self.stateFilename)
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let state = try JSONDecoder().decode(LocalState.self, from: Data(contentsOf: url))
                guard state.schemaVersion == 1,
                      state.lastSyncedAt?.timeIntervalSinceReferenceDate.isFinite != false else {
                    throw ICloudDriveSyncError.invalidLocalState
                }
                localState = state
                return state
            } catch {
                throw ICloudDriveSyncError.invalidLocalState
            }
        }
        let state = LocalState(schemaVersion: 1, deviceID: UUID(), deletedRecordIDs: [], lastSyncedAt: nil)
        localState = state
        localStateDirty = true
        try saveState()
        return state
    }

    private func saveState() throws {
        guard let localState else { throw ICloudDriveSyncError.invalidLocalState }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        localStateDirty = true
        do {
            try encoder.encode(localState).write(
                to: try root().appendingPathComponent(Self.stateFilename), options: [.atomic]
            )
            localStateDirty = false
        } catch {
            throw ICloudDriveSyncError.localStateWriteFailed
        }
    }

    private func saveBookmark(_ url: URL) throws {
        let data = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        do {
            try data.write(to: try root().appendingPathComponent(Self.bookmarkFilename), options: [.atomic])
        } catch {
            throw ICloudDriveSyncError.bookmarkWriteFailed
        }
    }

    private func snapshot(_ state: LocalState) -> LogbookSyncState {
        LogbookSyncState(
            deviceID: state.deviceID, deletedRecordIDs: Set(state.deletedRecordIDs),
            folder: folder, lastSyncedAt: state.lastSyncedAt, warning: nil
        )
    }

    private func install(_ url: URL, deviceID: UUID, onChange: @escaping @Sendable () -> Void) {
        closeFolder()
        securityScopeURL = url.startAccessingSecurityScopedResource() ? url : nil
        folder = url
        let newPresenter = LogbookFolderPresenter(
            url: url, ownDocumentName: Self.documentName(deviceID), onChange: onChange
        )
        presenter = newPresenter
        NSFileCoordinator.addFilePresenter(newPresenter)
    }

    private func closeFolder() {
        if let presenter { NSFileCoordinator.removeFilePresenter(presenter) }
        presenter = nil
        securityScopeURL?.stopAccessingSecurityScopedResource()
        securityScopeURL = nil
        folder = nil
    }

    private func followFolderMove() throws {
        guard let movedURL = presenter?.presentedItemURL, let previousURL = folder,
              movedURL.standardizedFileURL != previousURL.standardizedFileURL else { return }
        let access = movedURL.startAccessingSecurityScopedResource()
        do {
            try saveBookmark(movedURL)
        } catch {
            if access { movedURL.stopAccessingSecurityScopedResource() }
            throw error
        }
        // The move callback can supply an ordinary URL. Keep the original resource's
        // scope alive unless the new URL actually supplies a replacement scope.
        if access {
            securityScopeURL?.stopAccessingSecurityScopedResource()
            securityScopeURL = movedURL
        }
        folder = movedURL
    }

    private func sortedIDs(_ ids: Set<UUID>) -> [UUID] {
        ids.sorted { $0.uuidString < $1.uuidString }
    }

    private static func documentName(_ id: UUID) -> String {
        "Strato-device-\(id.uuidString).json"
    }

    private static func deviceID(from url: URL) -> UUID? {
        let name = url.deletingPathExtension().lastPathComponent
        guard name.hasPrefix("Strato-device-") else { return nil }
        return UUID(uuidString: String(name.dropFirst("Strato-device-".count)))
    }

    fileprivate static func syncDocumentURL(_ url: URL) -> URL? {
        let name = url.lastPathComponent
        if name.hasPrefix("Strato-device-"), url.pathExtension.lowercased() == "json" {
            return url
        }
        if name.hasPrefix(".Strato-device-"), name.lowercased().hasSuffix(".json.icloud") {
            let canonicalName = String(name.dropFirst().dropLast(".icloud".count))
            return url.deletingLastPathComponent().appendingPathComponent(canonicalName)
        }
        return nil
    }

    private static func readDocument(_ url: URL, expectedDeviceID: UUID) throws -> LogbookSyncDocument {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else {
            throw LogbookSyncDocumentError.malformedDocument
        }
        let document = try LogbookSyncDocument.decode(Data(contentsOf: url))
        guard document.deviceID == expectedDeviceID else { throw ICloudDriveSyncError.documentIdentityMismatch }
        return document
    }

    private func coordinatedRead<T>(
        _ url: URL, presenter: LogbookFolderPresenter?, accessor: (URL) throws -> T
    ) throws -> T {
        var coordinationError: NSError?
        var result: Result<T, Error>?
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            result = Result { try accessor(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ICloudDriveSyncError.coordinationFailed }
        return try result.get()
    }

    private func coordinatedWrite(
        _ url: URL, presenter: LogbookFolderPresenter?, accessor: (URL) throws -> Void
    ) throws {
        var coordinationError: NSError?
        var result: Result<Void, Error>?
        // Passing our presenter prevents the coordinator from notifying it about its own write.
        let coordinator = NSFileCoordinator(filePresenter: presenter)
        coordinator.coordinate(
            writingItemAt: url, options: [.forReplacing], error: &coordinationError
        ) { coordinatedURL in
            result = Result { try accessor(coordinatedURL) }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw ICloudDriveSyncError.coordinationFailed }
        try result.get()
    }
}

/// File-provider callbacks arrive on a serial background queue; only the final callback
/// crosses to the main actor. The coordinator and own-file filtering suppress self-write loops.
private final class LogbookFolderPresenter: NSObject, NSFilePresenter, @unchecked Sendable {
    private let urlLock = NSLock()
    private var url: URL
    private let ownDocumentName: String
    private let onChange: @Sendable () -> Void
    let presentedItemOperationQueue: OperationQueue

    var presentedItemURL: URL? {
        urlLock.lock()
        defer { urlLock.unlock() }
        return url
    }

    init(url: URL, ownDocumentName: String, onChange: @escaping @Sendable () -> Void) {
        self.url = url
        self.ownDocumentName = ownDocumentName
        self.onChange = onChange
        let queue = OperationQueue()
        queue.name = "Strato.logbook-sync.presenter"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 1
        presentedItemOperationQueue = queue
        super.init()
    }

    func presentedItemDidChange() { onChange() }

    func presentedItemDidMove(to newURL: URL) {
        urlLock.lock()
        url = newURL
        urlLock.unlock()
        onChange()
    }

    func presentedSubitemDidAppear(at url: URL) { notifyIfRemote(url) }
    func presentedSubitemDidChange(at url: URL) { notifyIfRemote(url) }

    func presentedSubitemDidMove(at oldURL: URL, to newURL: URL) {
        notifyIfRemote(oldURL)
        notifyIfRemote(newURL)
    }

    func accommodatePresentedSubitemDeletion(
        at url: URL, completionHandler: @escaping (Error?) -> Void
    ) {
        notifyIfRemote(url)
        completionHandler(nil)
    }

    func accommodatePresentedItemDeletion(completionHandler: @escaping (Error?) -> Void) {
        onChange()
        completionHandler(nil)
    }

    private func notifyIfRemote(_ url: URL) {
        guard let documentURL = LogbookSyncIO.syncDocumentURL(url),
              documentURL.lastPathComponent != ownDocumentName else { return }
        onChange()
    }
}

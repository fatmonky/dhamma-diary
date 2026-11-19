import Foundation
import SQLite3
import SwiftData

/// The first stored schema: stones and journal entries.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Stone.self, JournalEntry.self]
    }
}

/// Adds mind check-ins (spec 9.1). Later model changes add `SchemaV3` and a
/// stage in `DhammaDiaryMigrationPlan`, so existing data migrates.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [Stone.self, JournalEntry.self, MindCheck.self]
    }
}

enum DhammaDiaryMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [.lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self)]
    }
}

enum DhammaDiaryStore {
    /// The store lives in the app's own container, where every build before
    /// the widget kept it. SwiftData's default (`groupContainer: .automatic`)
    /// would move it into the App Group once the app has one; the widget
    /// never reads the store, so it stays here.
    static var appStoreURL: URL {
        URL.applicationSupportDirectory.appending(path: "default.store")
    }

    /// Where builds with the App Group (from the widget build) opened it.
    static var groupStoreURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: PassageSequence.appGroup)?
            .appending(path: "Library/Application Support/default.store")
    }

    static func makeContainer(inMemory: Bool = false, url: URL? = nil) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV2.self)
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            configuration = ModelConfiguration(schema: schema, url: url ?? appStoreURL)
        }
        return try ModelContainer(
            for: schema,
            migrationPlan: DhammaDiaryMigrationPlan.self,
            configurations: [configuration]
        )
    }

    enum Settled: Equatable {
        case nothingToMove
        /// The group store moved into the app container.
        case movedFromGroup
        /// Both existed; the group one was newer and moved in. The app's
        /// older copy was kept, renamed with this suffix.
        case movedFromGroupKeepingOlder(backupSuffix: String)
        /// Both existed; the app's own was newer. The group copy was kept, renamed.
        case keptAppStore(backupSuffix: String)
    }

    /// Before opening the container: if a store is in the App Group, bring
    /// it to `appStore`. When both exist, a store with no records never wins
    /// over one with records; otherwise the more recently written one is
    /// used. The other is renamed, never deleted.
    @discardableResult
    static func settleStoreLocation(
        appStore: URL = appStoreURL,
        groupStore: URL? = groupStoreURL,
        now: Date = .now,
        fileManager: FileManager = .default
    ) throws -> Settled {
        guard let groupStore, fileManager.fileExists(atPath: groupStore.path) else { return .nothingToMove }
        try fileManager.createDirectory(at: appStore.deletingLastPathComponent(), withIntermediateDirectories: true)

        let suffix = "before-" + backupStamp(now)
        guard fileManager.fileExists(atPath: appStore.path) else {
            try moveStore(from: groupStore, to: appStore, fileManager: fileManager)
            return .movedFromGroup
        }
        if groupShouldWin(group: groupStore, app: appStore, fileManager: fileManager) {
            try moveStore(from: appStore, to: backupURL(appStore, suffix), fileManager: fileManager)
            try moveStore(from: groupStore, to: appStore, fileManager: fileManager)
            return .movedFromGroupKeepingOlder(backupSuffix: suffix)
        }
        try moveStore(from: groupStore, to: backupURL(groupStore, suffix), fileManager: fileManager)
        return .keptAppStore(backupSuffix: suffix)
    }

    private static func groupShouldWin(group: URL, app: URL, fileManager: FileManager) -> Bool {
        let groupHasRecords = (recordCount(group) ?? 1) > 0
        let appHasRecords = (recordCount(app) ?? 1) > 0
        if groupHasRecords != appHasRecords {
            return groupHasRecords
        }
        return lastWritten(group, fileManager) > lastWritten(app, fileManager)
    }

    /// Stones, journal entries and check-ins in a store, read without
    /// SwiftData. Nil if the file can't be read.
    static func recordCount(_ store: URL) -> Int? {
        var db: OpaquePointer?
        defer { sqlite3_close(db) }
        guard sqlite3_open_v2(store.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else { return nil }
        var total = 0
        var readAny = false
        for table in ["ZSTONE", "ZJOURNALENTRY", "ZMINDCHECK"] {
            var statement: OpaquePointer?
            defer { sqlite3_finalize(statement) }
            // A missing table (an older schema) just counts as none.
            guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM \(table)", -1, &statement, nil) == SQLITE_OK,
                  sqlite3_step(statement) == SQLITE_ROW else { continue }
            total += Int(sqlite3_column_int64(statement, 0))
            readAny = true
        }
        return readAny ? total : nil
    }

    /// A SQLite store is up to three files.
    private static let sidecars = ["", "-wal", "-shm"]

    private static func moveStore(from source: URL, to destination: URL, fileManager: FileManager) throws {
        for sidecar in sidecars {
            let from = URL(fileURLWithPath: source.path + sidecar)
            let to = URL(fileURLWithPath: destination.path + sidecar)
            guard fileManager.fileExists(atPath: from.path) else { continue }
            if fileManager.fileExists(atPath: to.path) {
                try fileManager.removeItem(at: to)
            }
            try fileManager.moveItem(at: from, to: to)
        }
    }

    private static func lastWritten(_ store: URL, _ fileManager: FileManager) -> Date {
        sidecars.compactMap { sidecar in
            try? fileManager.attributesOfItem(atPath: store.path + sidecar)[.modificationDate] as? Date
        }.max() ?? .distantPast
    }

    /// "default.store" → "default-before-20261120-0724.store".
    static func backupURL(_ store: URL, _ suffix: String) -> URL {
        let name = store.deletingPathExtension().lastPathComponent + "-" + suffix
        return store.deletingLastPathComponent().appending(path: name).appendingPathExtension(store.pathExtension)
    }

    private static func backupStamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: date)
    }
}

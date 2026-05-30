import Foundation
import SQLite3

/// Thread-safe SQLite database that stores every file-system event.
/// Uses WAL mode for concurrent readers and crash safety.
actor HistoryDatabase {
    static let shared = HistoryDatabase()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "chronos.db", qos: .utility)
    private let dbPath: String

    private init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Chronos", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.dbPath = supportDir.appendingPathComponent("history.db").path
    }

    deinit {
        sqlite3_close(db)
    }

    /// Opens the database, creates schema, and enables WAL mode.
    func setup() throws {
        try queue.sync {
            let rc = sqlite3_open(dbPath, &db)
            guard rc == SQLITE_OK else {
                throw DatabaseError.openFailed(String(cString: sqlite3_errmsg(db)))
            }

            // WAL mode for concurrent readers + crash safety
            try exec("PRAGMA journal_mode = WAL")
            try exec("PRAGMA synchronous = NORMAL")
            try exec("PRAGMA mmap_size = 134217728") // 128 MB
            try exec("PRAGMA temp_store = MEMORY")
            try exec("PRAGMA cache_size = -32768") // 32 MB

            try createSchema()
        }
    }

    // MARK: - Schema

    private func createSchema() throws {
        let ddl = """
        CREATE TABLE IF NOT EXISTS events (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            path        TEXT NOT NULL,
            name        TEXT NOT NULL,
            parent_path TEXT NOT NULL,
            event_type  TEXT NOT NULL CHECK(event_type IN ('created','modified','renamed','removed')),
            timestamp   REAL NOT NULL,
            size        INTEGER NOT NULL DEFAULT 0,
            is_dir      INTEGER NOT NULL DEFAULT 0,
            inode       INTEGER NOT NULL DEFAULT 0
        );

        CREATE INDEX IF NOT EXISTS idx_path       ON events(path);
        CREATE INDEX IF NOT EXISTS idx_parent     ON events(parent_path);
        CREATE INDEX IF NOT EXISTS idx_timestamp  ON events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_inode      ON events(inode);
        CREATE INDEX IF NOT EXISTS idx_name       ON events(name COLLATE NOCASE);
        CREATE INDEX IF NOT EXISTS idx_type_time  ON events(event_type, timestamp);

        CREATE TABLE IF NOT EXISTS folders (
            path TEXT PRIMARY KEY,
            enabled INTEGER NOT NULL DEFAULT 1,
            added_at REAL NOT NULL
        );
        """
        try exec(ddl)
    }

    // MARK: - Inserts

    func insertEvent(path: String, name: String, parentPath: String,
                     eventType: EventType, timestamp: Date,
                     size: Int64 = 0, isDirectory: Bool = false,
                     inode: UInt64 = 0) throws {
        let sql = """
        INSERT INTO events (path, name, parent_path, event_type, timestamp, size, is_dir, inode)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        """
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 2, (name as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 3, (parentPath as NSString).utf8String, -1, nil)
        sqlite3_bind_text(stmt, 4, (eventType.rawValue as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 5, timestamp.timeIntervalSince1970)
        sqlite3_bind_int64(stmt, 6, size)
        sqlite3_bind_int(stmt, 7, isDirectory ? 1 : 0)
        sqlite3_bind_int64(stmt, 8, Int64(inode))

        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw DatabaseError.insertFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Queries

    /// Returns the state of a folder at a specific point in time.
    /// For each path, we take the most recent event before `at`.
    func snapshot(ofFolder folderPath: String, at date: Date) throws -> [FileSnapshot] {
        let sql = """
        SELECT path, name, parent_path, event_type, timestamp, size, is_dir, inode
        FROM events e1
        WHERE parent_path = ?
          AND timestamp <= ?
          AND id = (
              SELECT id FROM events e2
              WHERE e2.path = e1.path
                AND e2.timestamp <= ?
              ORDER BY e2.timestamp DESC, e2.id DESC
              LIMIT 1
          )
          AND event_type != 'removed'
        ORDER BY name COLLATE NOCASE
        """

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }

        let ts = date.timeIntervalSince1970
        sqlite3_bind_text(stmt, 1, (folderPath as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, ts)
        sqlite3_bind_double(stmt, 3, ts)

        var results: [FileSnapshot] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(FileSnapshot(
                path: String(cString: sqlite3_column_text(stmt, 0)),
                name: String(cString: sqlite3_column_text(stmt, 1)),
                parentPath: String(cString: sqlite3_column_text(stmt, 2)),
                lastEventType: EventType(rawValue: String(cString: sqlite3_column_text(stmt, 3))) ?? .modified,
                lastEventTime: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 4)),
                size: sqlite3_column_int64(stmt, 5),
                isDirectory: sqlite3_column_int(stmt, 6) == 1,
                inode: UInt64(sqlite3_column_int64(stmt, 7))
            ))
        }
        return results
    }

    /// Returns all events for a given path, newest first.
    func history(forPath path: String, limit: Int = 100) throws -> [FileEvent] {
        let sql = """
        SELECT id, path, name, parent_path, event_type, timestamp, size, is_dir, inode
        FROM events
        WHERE path = ?
        ORDER BY timestamp DESC, id DESC
        LIMIT ?
        """
        return try fetchEvents(sql: sql, bindings: { stmt in
            sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        })
    }

    /// Returns recent events across all watched folders.
    func recentEvents(since: Date, limit: Int = 200) throws -> [FileEvent] {
        let sql = """
        SELECT id, path, name, parent_path, event_type, timestamp, size, is_dir, inode
        FROM events
        WHERE timestamp >= ?
        ORDER BY timestamp DESC, id DESC
        LIMIT ?
        """
        return try fetchEvents(sql: sql, bindings: { stmt in
            sqlite3_bind_double(stmt, 1, since.timeIntervalSince1970)
            sqlite3_bind_int(stmt, 2, Int32(limit))
        })
    }

    /// Returns the earliest and latest timestamp in the database.
    func timeRange() throws -> (earliest: Date, latest: Date)? {
        let sql = "SELECT MIN(timestamp), MAX(timestamp) FROM events"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }

        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let minTs = sqlite3_column_double(stmt, 0)
        let maxTs = sqlite3_column_double(stmt, 1)
        guard minTs > 0 else { return nil }
        return (Date(timeIntervalSince1970: minTs), Date(timeIntervalSince1970: maxTs))
    }

    // MARK: - Folders

    func addWatchedFolder(_ path: String) throws {
        let sql = "INSERT OR REPLACE INTO folders (path, enabled, added_at) VALUES (?, 1, ?)"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func watchedFolders() throws -> [String] {
        let sql = "SELECT path FROM folders WHERE enabled = 1 ORDER BY added_at DESC"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return [] }
        defer { sqlite3_finalize(stmt) }
        var paths: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            paths.append(String(cString: sqlite3_column_text(stmt, 0)))
        }
        return paths
    }

    func removeWatchedFolder(_ path: String) throws {
        try exec("DELETE FROM folders WHERE path = '\(path)'")
    }

    // MARK: - Helpers

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw DatabaseError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func fetchEvents(sql: String, bindings: (OpaquePointer?) -> Void) throws -> [FileEvent] {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DatabaseError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        bindings(stmt)

        var results: [FileEvent] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            results.append(FileEvent(
                id: sqlite3_column_int64(stmt, 0),
                path: String(cString: sqlite3_column_text(stmt, 1)),
                name: String(cString: sqlite3_column_text(stmt, 2)),
                parentPath: String(cString: sqlite3_column_text(stmt, 3)),
                eventType: EventType(rawValue: String(cString: sqlite3_column_text(stmt, 4))) ?? .modified,
                timestamp: Date(timeIntervalSince1970: sqlite3_column_double(stmt, 5)),
                size: sqlite3_column_int64(stmt, 6),
                isDirectory: sqlite3_column_int(stmt, 7) == 1,
                inode: UInt64(sqlite3_column_int64(stmt, 8))
            ))
        }
        return results
    }
}

struct FileSnapshot: Sendable {
    let path: String
    let name: String
    let parentPath: String
    let lastEventType: EventType
    let lastEventTime: Date
    let size: Int64
    let isDirectory: Bool
    let inode: UInt64
}

enum DatabaseError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case insertFailed(String)
    case execFailed(String)
}

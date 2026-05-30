import Foundation
import SQLite3

actor HistoryDatabase {
    static let shared = HistoryDatabase()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "chronos.db", qos: .utility)
    let dbPath: String

    private init() {
        let supportDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Chronos", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportDir, withIntermediateDirectories: true)
        self.dbPath = supportDir.appendingPathComponent("history.db").path
    }

    func resetDatabase() throws {
        try queue.sync {
            sqlite3_close(db)
            db = nil
            try? FileManager.default.removeItem(atPath: dbPath)
            let rc = sqlite3_open(dbPath, &db)
            guard rc == SQLITE_OK else {
                throw DBError.openFailed(String(cString: sqlite3_errmsg(db)))
            }
            try createSchema()
        }
    }

    func setup() throws {
        try queue.sync {
            let rc = sqlite3_open(dbPath, &db)
            guard rc == SQLITE_OK else {
                throw DBError.openFailed(String(cString: sqlite3_errmsg(db)))
            }
            try exec("PRAGMA journal_mode = WAL")
            try exec("PRAGMA synchronous = NORMAL")
            try exec("PRAGMA temp_store = MEMORY")
            try exec("PRAGMA cache_size = -32768")
            try createSchema()
        }
    }

    private func createSchema() throws {
        try exec("""
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
        CREATE INDEX IF NOT EXISTS idx_path      ON events(path);
        CREATE INDEX IF NOT EXISTS idx_parent    ON events(parent_path);
        CREATE INDEX IF NOT EXISTS idx_timestamp ON events(timestamp);
        CREATE INDEX IF NOT EXISTS idx_name      ON events(name COLLATE NOCASE);

        CREATE TABLE IF NOT EXISTS folders (
            path    TEXT PRIMARY KEY,
            enabled INTEGER NOT NULL DEFAULT 1,
            added_at REAL NOT NULL
        );
        """)
    }

    // MARK: - Insert

    func insertEvent(path: String, name: String, parentPath: String,
                     eventType: EventType, timestamp: Date,
                     size: Int64 = 0, isDirectory: Bool = false,
                     inode: UInt64 = 0) throws {
        let sql = """
        INSERT INTO events (path, name, parent_path, event_type, timestamp, size, is_dir, inode)
        VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)
        """
        let stmt = try prepare(sql)
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
            throw DBError.insertFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    // MARK: - Snapshot

    /// Returns files that existed in `folderPath` at time `date`.
    /// Logic: for each path, get the latest event at or before `date`;
    /// include it only if that event is not 'removed'.
    func snapshot(ofFolder folderPath: String, at date: Date) throws -> [FileSnapshot] {
        // Simpler approach: fetch all events for the folder up to date,
        // then keep only the latest per path.
        let sql = """
        SELECT id, path, name, parent_path, event_type, timestamp, size, is_dir, inode
        FROM events
        WHERE parent_path = ?1 AND timestamp <= ?2
        ORDER BY timestamp DESC
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (folderPath as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, date.timeIntervalSince1970)

        let events = try decodeEvents(stmt: stmt)
        print("[Chronos DB] snapshot query returned \(events.count) raw events for \(folderPath)")
        var seen = Set<String>()
        var result: [FileSnapshot] = []
        for event in events {
            guard event.path != folderPath else { continue }
            guard seen.insert(event.path).inserted else { continue }
            guard event.eventType != .removed else { continue }
            result.append(FileSnapshot(
                path: event.path,
                name: event.name,
                parentPath: event.parentPath,
                lastEventType: event.eventType,
                lastEventTime: event.timestamp,
                size: event.size,
                isDirectory: event.isDirectory,
                inode: event.inode
            ))
        }
        return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Diff

    /// Compare folder state at two timestamps. Returns added, removed, modified, unchanged.
    func diff(folderPath: String, from: Date, to: Date) throws -> [FileDiff] {
        let old = try snapshot(ofFolder: folderPath, at: from)
        let new = try snapshot(ofFolder: folderPath, at: to)
        var diffs: [FileDiff] = []
        let oldMap = Dictionary(uniqueKeysWithValues: old.map { ($0.path, $0) })
        let newMap = Dictionary(uniqueKeysWithValues: new.map { ($0.path, $0) })

        for (path, n) in newMap {
            if let o = oldMap[path] {
                if o.size != n.size || o.name != n.name {
                    diffs.append(FileDiff(path: path, name: n.name, status: .modified,
                                          oldSize: o.size, newSize: n.size, isDirectory: n.isDirectory))
                } else {
                    diffs.append(FileDiff(path: path, name: n.name, status: .unchanged,
                                          oldSize: o.size, newSize: n.size, isDirectory: n.isDirectory))
                }
            } else {
                diffs.append(FileDiff(path: path, name: n.name, status: .added,
                                      oldSize: 0, newSize: n.size, isDirectory: n.isDirectory))
            }
        }
        for (path, o) in oldMap where newMap[path] == nil {
            diffs.append(FileDiff(path: path, name: o.name, status: .removed,
                                  oldSize: o.size, newSize: 0, isDirectory: o.isDirectory))
        }
        return diffs.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Search

    /// Search events by name (case-insensitive). Can optionally filter by deleted files only.
    func search(query: String, includeRemoved: Bool = true, limit: Int = 100) throws -> [FileEvent] {
        let pattern = "%\(query)%"
        let sql: String
        if includeRemoved {
            sql = """
            SELECT id, path, name, parent_path, event_type, timestamp, size, is_dir, inode
            FROM events
            WHERE name LIKE ?1
            ORDER BY timestamp DESC
            LIMIT ?2
            """
        } else {
            sql = """
            SELECT e.id, e.path, e.name, e.parent_path, e.event_type, e.timestamp, e.size, e.is_dir, e.inode
            FROM events e
            INNER JOIN (
                SELECT path, MAX(timestamp) AS max_ts
                FROM events
                WHERE name LIKE ?1
                GROUP BY path
            ) latest ON e.path = latest.path AND e.timestamp = latest.max_ts
            WHERE e.name LIKE ?1 AND e.event_type != 'removed'
            ORDER BY e.timestamp DESC
            LIMIT ?2
            """
        }
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (pattern as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        return try decodeEvents(stmt: stmt)
    }

    // MARK: - Recent

    func recentEvents(since: Date, limit: Int = 200) throws -> [FileEvent] {
        let sql = """
        SELECT id, path, name, parent_path, event_type, timestamp, size, is_dir, inode
        FROM events
        WHERE timestamp >= ?1
        ORDER BY timestamp DESC, id DESC
        LIMIT ?2
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_double(stmt, 1, since.timeIntervalSince1970)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        return try decodeEvents(stmt: stmt)
    }

    func history(forPath path: String, limit: Int = 50) throws -> [FileEvent] {
        let sql = """
        SELECT id, path, name, parent_path, event_type, timestamp, size, is_dir, inode
        FROM events
        WHERE path = ?1
        ORDER BY timestamp DESC, id DESC
        LIMIT ?2
        """
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
        sqlite3_bind_int(stmt, 2, Int32(limit))
        return try decodeEvents(stmt: stmt)
    }

    func eventCount() throws -> Int {
        let sql = "SELECT COUNT(*) FROM events"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    // MARK: - Time range

    func timeRange() throws -> (earliest: Date, latest: Date)? {
        let sql = "SELECT MIN(timestamp), MAX(timestamp) FROM events"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return nil }
        let minTs = sqlite3_column_double(stmt, 0)
        let maxTs = sqlite3_column_double(stmt, 1)
        guard minTs > 0 else { return nil }
        return (Date(timeIntervalSince1970: minTs), Date(timeIntervalSince1970: maxTs))
    }

    // MARK: - Folders

    func addWatchedFolder(_ path: String) throws {
        let sql = "INSERT OR REPLACE INTO folders (path, enabled, added_at) VALUES (?1, 1, ?2)"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
        sqlite3_bind_double(stmt, 2, Date().timeIntervalSince1970)
        sqlite3_step(stmt)
    }

    func watchedFolders() throws -> [String] {
        let sql = "SELECT path FROM folders WHERE enabled = 1 ORDER BY added_at DESC"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        var paths: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            paths.append(String(cString: sqlite3_column_text(stmt, 0)))
        }
        return paths
    }

    func removeWatchedFolder(_ path: String) throws {
        let sql = "DELETE FROM folders WHERE path = ?1"
        let stmt = try prepare(sql)
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, nil)
        sqlite3_step(stmt)
    }

    // MARK: - Helpers

    private func exec(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else {
            throw DBError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func prepare(_ sql: String) throws -> OpaquePointer? {
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else {
            throw DBError.prepareFailed(String(cString: sqlite3_errmsg(db)))
        }
        return stmt
    }

    private func decodeSnapshots(stmt: OpaquePointer?) throws -> [FileSnapshot] {
        guard let stmt else { return [] }
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

    private func decodeEvents(stmt: OpaquePointer?) throws -> [FileEvent] {
        guard let stmt else { return [] }
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

enum DBError: Error {
    case openFailed(String)
    case prepareFailed(String)
    case insertFailed(String)
    case execFailed(String)
}

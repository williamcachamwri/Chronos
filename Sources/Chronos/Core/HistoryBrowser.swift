import Foundation
import SwiftUI

/// High-level coordinator bridging UI and database.
@MainActor
final class HistoryBrowser: ObservableObject {
    static let shared = HistoryBrowser()

    @Published var currentFolder: String = NSHomeDirectory() + "/Desktop"
    @Published var snapshotDate: Date = Date()
    @Published var items: [FileSnapshot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var timeRange: (earliest: Date, latest: Date)?
    @Published var totalEventCount: Int = 0

    private let db = HistoryDatabase.shared

    private init() {}

    func setup() async {
        do {
            print("[Chronos] Setting up database...")
            try await db.resetDatabase()
            print("[Chronos] Database reset at \(db.dbPath)")

            let home = NSHomeDirectory()
            try? await db.addWatchedFolder(home + "/Desktop")
            try? await db.addWatchedFolder(home + "/Documents")
            try? await db.addWatchedFolder(home + "/Downloads")

            let folders = (try? await db.watchedFolders()) ?? []
            print("[Chronos] Watching folders: \(folders)")

            // Seed baseline: scan current files so the database is never empty.
            await performInitialScan(folders: folders)

            await FileSystemMonitor.shared.start(watching: folders)

            await refreshTimeRange()
            await loadSnapshot()
        } catch {
            errorMessage = "Database setup failed: \(error)"
            print("[Chronos] Setup error: \(error)")
        }
    }

    /// Scans watched folders (top-level only) and inserts files as 'created' baseline.
    private func performInitialScan(folders: [String]) async {
        let fm = FileManager.default
        let now = Date()
        var inserted = 0
        for folder in folders {
            guard let contents = try? fm.contentsOfDirectory(atPath: folder) else {
                print("[Chronos] Could not list: \(folder)")
                continue
            }
            for name in contents {
                guard !name.hasPrefix(".") else { continue }
                let fullPath = (folder as NSString).appendingPathComponent(name)
                let parent = folder

                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
                let attrs = try? fm.attributesOfItem(atPath: fullPath)
                let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                let inode = UInt64((attrs?[.systemFileNumber] as? NSNumber)?.int64Value ?? 0)

                do {
                    try await db.insertEvent(
                        path: fullPath,
                        name: name,
                        parentPath: parent,
                        eventType: .created,
                        timestamp: now,
                        size: size,
                        isDirectory: isDir.boolValue,
                        inode: inode
                    )
                    inserted += 1
                } catch {
                    print("[Chronos] Insert failed for \(fullPath): \(error)")
                }
            }
        }
        print("[Chronos] Initial scan complete: \(inserted) files inserted")
        await refreshStats()
    }

    func refreshStats() async {
        totalEventCount = (try? await db.eventCount()) ?? 0
        print("[Chronos] Total events: \(totalEventCount)")
        await refreshTimeRange()
    }

    func loadSnapshot() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            print("[Chronos] Loading snapshot for folder: \(currentFolder)")
            items = try await db.snapshot(ofFolder: currentFolder, at: snapshotDate)
            print("[Chronos] Snapshot loaded: \(items.count) items")
        } catch {
            errorMessage = "Failed to load snapshot: \(error)"
            print("[Chronos] Snapshot error: \(error)")
        }
    }

    func refreshTimeRange() async {
        timeRange = try? await db.timeRange()
        if let range = timeRange {
            print("[Chronos] Time range: \(range.earliest) → \(range.latest)")
        } else {
            print("[Chronos] Time range: nil (no events)")
        }
    }

    func navigate(to folderPath: String) async {
        currentFolder = folderPath
        await loadSnapshot()
    }

    func setSnapshotDate(_ date: Date) async {
        snapshotDate = date
        await loadSnapshot()
    }

    func goUp() async {
        let parent = (currentFolder as NSString).deletingLastPathComponent
        guard parent != currentFolder else { return }
        await navigate(to: parent)
    }

    func addFolderToWatch(_ path: String) async {
        try? await db.addWatchedFolder(path)
        let folders = (try? await db.watchedFolders()) ?? []
        await FileSystemMonitor.shared.start(watching: folders)
        await performInitialScan(folders: [path])
        await refreshStats()
    }

    func recentEvents(since: Date) async -> [FileEvent] {
        return (try? await db.recentEvents(since: since, limit: 100)) ?? []
    }

    func diff(folderPath: String, from: Date, to: Date) async -> [FileDiff] {
        print("[Chronos] Diff from \(from) to \(to) in \(folderPath)")
        let result = (try? await db.diff(folderPath: folderPath, from: from, to: to)) ?? []
        print("[Chronos] Diff result: \(result.count) changes")
        return result
    }

    func search(query: String, includeRemoved: Bool = true) async -> [FileEvent] {
        print("[Chronos] Search query: '\(query)'")
        let result = (try? await db.search(query: query, includeRemoved: includeRemoved, limit: 100)) ?? []
        print("[Chronos] Search result: \(result.count) items")
        return result
    }
}

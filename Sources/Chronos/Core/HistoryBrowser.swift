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
            try await db.setup()
            let home = NSHomeDirectory()
            try? await db.addWatchedFolder(home + "/Desktop")
            try? await db.addWatchedFolder(home + "/Documents")
            try? await db.addWatchedFolder(home + "/Downloads")

            let folders = (try? await db.watchedFolders()) ?? []

            // Seed baseline: scan current files so the database is never empty.
            await performInitialScan(folders: folders)

            await FileSystemMonitor.shared.start(watching: folders)

            await refreshTimeRange()
            await loadSnapshot()
        } catch {
            errorMessage = "Database setup failed: \(error)"
        }
    }

    /// Scans watched folders and inserts every existing file as a 'created' baseline.
    private func performInitialScan(folders: [String]) async {
        let fm = FileManager.default
        let now = Date()
        for folder in folders {
            guard let enumerator = fm.enumerator(atPath: folder) else { continue }
            while let relativePath = enumerator.nextObject() as? String {
                let fullPath = (folder as NSString).appendingPathComponent(relativePath)
                let name = (fullPath as NSString).lastPathComponent
                let parent = (fullPath as NSString).deletingLastPathComponent
                guard !name.hasPrefix(".") else { continue }

                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: fullPath, isDirectory: &isDir) else { continue }
                let attrs = try? fm.attributesOfItem(atPath: fullPath)
                let size = (attrs?[.size] as? NSNumber)?.int64Value ?? 0
                let inode = UInt64((attrs?[.systemFileNumber] as? NSNumber)?.int64Value ?? 0)

                try? await db.insertEvent(
                    path: fullPath,
                    name: name,
                    parentPath: parent,
                    eventType: .created,
                    timestamp: now,
                    size: size,
                    isDirectory: isDir.boolValue,
                    inode: inode
                )
            }
        }
        await refreshStats()
    }

    func refreshStats() async {
        totalEventCount = (try? await db.eventCount()) ?? 0
        await refreshTimeRange()
    }

    func loadSnapshot() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            items = try await db.snapshot(ofFolder: currentFolder, at: snapshotDate)
        } catch {
            errorMessage = "Failed to load snapshot: \(error)"
        }
    }

    func refreshTimeRange() async {
        timeRange = try? await db.timeRange()
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
        return (try? await db.diff(folderPath: folderPath, from: from, to: to)) ?? []
    }

    func search(query: String, includeRemoved: Bool = true) async -> [FileEvent] {
        return (try? await db.search(query: query, includeRemoved: includeRemoved, limit: 100)) ?? []
    }
}

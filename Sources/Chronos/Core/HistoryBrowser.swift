import Foundation
import SwiftUI

/// High-level coordinator bridging UI and database.
@MainActor
final class HistoryBrowser: ObservableObject {
    static let shared = HistoryBrowser()

    @Published var currentFolder: String = NSHomeDirectory()
    @Published var snapshotDate: Date = Date()
    @Published var items: [FileSnapshot] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var timeRange: (earliest: Date, latest: Date)?

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
            await FileSystemMonitor.shared.start(watching: folders)

            await refreshTimeRange()
            await loadSnapshot()
        } catch {
            errorMessage = "Database setup failed: \(error)"
        }
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
    }

    func recentEvents(since: Date) async -> [FileEvent] {
        return (try? await db.recentEvents(since: since, limit: 100)) ?? []
    }

    // MARK: - Diff

    func diff(folderPath: String, from: Date, to: Date) async -> [FileDiff] {
        return (try? await db.diff(folderPath: folderPath, from: from, to: to)) ?? []
    }

    // MARK: - Search

    func search(query: String, includeRemoved: Bool = true) async -> [FileEvent] {
        return (try? await db.search(query: query, includeRemoved: includeRemoved, limit: 100)) ?? []
    }
}

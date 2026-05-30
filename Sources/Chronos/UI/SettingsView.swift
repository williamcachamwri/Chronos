import SwiftUI

struct SettingsView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @State private var watchedFolders: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Settings")
                .font(AppFont.title)
                .foregroundColor(AppColors.text)

            VStack(alignment: .leading, spacing: 6) {
                Text("Watched Folders")
                    .font(AppFont.bodyM)
                    .foregroundColor(AppColors.text)
                Text("Chronos monitors these folders for file-system changes.")
                    .font(AppFont.time)
                    .foregroundColor(AppColors.muted)
            }

            VStack(spacing: 6) {
                ForEach(watchedFolders, id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(systemName: "folder")
                            .font(.system(size: 12))
                            .foregroundColor(AppColors.muted)
                        Text(path)
                            .font(AppFont.bodyS)
                            .foregroundColor(AppColors.text)
                            .lineLimit(1)
                        Spacer()
                        Button(action: { removeFolder(path) }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(AppColors.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.card)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.border, lineWidth: 0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            ChronosButton(title: "Add Folder...", icon: "plus") { addFolder() }

            Spacer()
        }
        .padding(28)
        .frame(minWidth: 480, minHeight: 320)
        .task {
            watchedFolders = (try? await HistoryDatabase.shared.watchedFolders()) ?? []
        }
    }

    private func addFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        if panel.runModal() == .OK, let url = panel.url {
            Task {
                await browser.addFolderToWatch(url.path)
                watchedFolders = (try? await HistoryDatabase.shared.watchedFolders()) ?? []
            }
        }
    }

    private func removeFolder(_ path: String) {
        Task {
            try? await HistoryDatabase.shared.removeWatchedFolder(path)
            watchedFolders = (try? await HistoryDatabase.shared.watchedFolders()) ?? []
        }
    }
}

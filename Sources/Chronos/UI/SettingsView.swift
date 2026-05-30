import SwiftUI

struct SettingsView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @State private var watchedFolders: [String] = []
    @State private var isShowingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Watched Folders")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.primary)

            Text("Chronos monitors these folders for changes. Add folders you want to track.")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)

            ForEach(watchedFolders, id: \.self) { path in
                HStack {
                    Image(systemName: "folder")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text(path)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    Spacer()
                    Button(action: { removeFolder(path) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button("Add Folder...") {
                addFolder()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(.blue)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.blue.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))

            Spacer()
        }
        .padding(20)
        .frame(minWidth: 400, minHeight: 250)
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))
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
            let path = url.path
            Task {
                await browser.addFolderToWatch(path)
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

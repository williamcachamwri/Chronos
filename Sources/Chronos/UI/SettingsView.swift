import SwiftUI

struct SettingsView: View {
    @Environment(\.colorScheme) var scheme
    @StateObject private var browser = HistoryBrowser.shared
    @State private var watchedFolders: [String] = []
    @State private var isAppearing = false

    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 24) {
                Text("Settings")
                    .font(F.title)
                    .foregroundColor(t.text)
                    .offset(y: isAppearing ? 0 : -20)
                    .opacity(isAppearing ? 1 : 0)
                    .animation(A.bouncy.delay(0.05), value: isAppearing)

                Glass(radius: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Watched Folders")
                            .font(F.bodyM)
                            .foregroundColor(t.text)
                        Text("Chronos monitors these folders for file-system changes.")
                            .font(F.time)
                            .foregroundColor(t.muted)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    VStack(spacing: 6) {
                        ForEach(watchedFolders.indices, id: \.self) { i in
                            let path = watchedFolders[i]
                            HStack(spacing: 10) {
                                Image(systemName: "folder")
                                    .font(.system(size: 12))
                                    .foregroundColor(t.muted)
                                Text(path)
                                    .font(F.bodyS)
                                    .foregroundColor(t.text)
                                    .lineLimit(1)
                                Spacer()
                                Button(action: { removeFolder(path) }) {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(t.red)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(t.card)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.glassBorder, lineWidth: 0.8))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .offset(x: isAppearing ? 0 : -30)
                            .opacity(isAppearing ? 1 : 0)
                            .animation(A.spring.delay(0.1 + Double(i) * 0.05), value: isAppearing)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)

                    GlassButton(title: "Add Folder...", icon: "plus") { addFolder() }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                        .offset(y: isAppearing ? 0 : 10)
                        .opacity(isAppearing ? 1 : 0)
                        .animation(A.spring.delay(0.3), value: isAppearing)
                }

                Spacer()
            }
            .padding(28)
            .frame(minWidth: 480, minHeight: 320)
        }
        .task {
            watchedFolders = (try? await HistoryDatabase.shared.watchedFolders()) ?? []
            isAppearing = true
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
        withAnimation(A.fast) {
            watchedFolders.removeAll { $0 == path }
        }
        Task {
            try? await HistoryDatabase.shared.removeWatchedFolder(path)
        }
    }
}

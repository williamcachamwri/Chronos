import SwiftUI

struct SettingsModal: View {
    @Binding var showSettings: Bool
    @Environment(\.colorScheme) var scheme
    @ObservedObject private var browser = HistoryBrowser.shared
    @State private var watchedFolders: [String] = []
    @State private var isAppearing = false

    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        ZStack {
            // Backdrop — close without explicit animation (parent handles it)
            t.bg.opacity(0.35)
                .background(.ultraThinMaterial)
                .ignoresSafeArea()
                .onTapGesture {
                    showSettings = false
                }

            // Modal card
            Glass(radius: 20) {
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("Settings")
                            .font(F.title)
                            .foregroundColor(t.text)
                        Spacer()
                        Button(action: {
                            showSettings = false
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(t.muted)
                                .frame(width: 28, height: 28)
                                .background(t.surface)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 20)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Watched Folders")
                                    .font(F.bodyM)
                                    .foregroundColor(t.text)
                                Text("Chronos monitors these folders for file-system changes.")
                                    .font(F.time)
                                    .foregroundColor(t.muted)
                            }

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
                                    .offset(x: isAppearing ? 0 : -20)
                                    .opacity(isAppearing ? 1 : 0)
                                    .animation(A.spring.delay(0.08 + Double(i) * 0.04), value: isAppearing)
                                }
                            }

                            GlassButton(title: "Add Folder...", icon: "plus") { addFolder() }
                                .offset(y: isAppearing ? 0 : 10)
                                .opacity(isAppearing ? 1 : 0)
                                .animation(A.spring.delay(0.25), value: isAppearing)
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
            .frame(maxWidth: 520, maxHeight: 520)
            .padding(.horizontal, 40)
            .scaleEffect(isAppearing ? 1 : 0.88)
            .opacity(isAppearing ? 1 : 0)
            .animation(A.bouncy.delay(0.02), value: isAppearing)
        }
        .onAppear {
            watchedFolders = (try? HistoryDatabase.shared.watchedFolders()) ?? []
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isAppearing = true
            }
        }
        .onDisappear {
            isAppearing = false
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

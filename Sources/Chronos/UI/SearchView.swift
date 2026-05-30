import SwiftUI

struct SearchView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @Environment(\.colorScheme) var scheme
    @State private var query = ""
    @State private var results: [FileEvent] = []
    @State private var isSearching = false
    @State private var includeRemoved = true
    @State private var hoverItem: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        VStack(spacing: 0) {
            topBar(t: t)
            searchBar(t: t)
            listSection(t: t)
        }
    }

    private func topBar(t: Theme) -> some View {
        HStack {
            Text("Search History")
                .font(F.bodyM)
                .foregroundColor(t.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func searchBar(t: Theme) -> some View {
        Glass(radius: 12) {
            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(t.muted)

                    TextField("Search file name...", text: $query)
                        .font(F.bodyS)
                        .foregroundColor(t.text)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .onSubmit { performSearch() }
                        .onChange(of: query) { _, new in
                            if new.isEmpty { results = [] }
                        }

                    if !query.isEmpty {
                        Button(action: { query = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 14))
                                .foregroundColor(t.muted)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

                HStack {
                    Toggle("Include deleted files", isOn: $includeRemoved)
                        .toggleStyle(.switch)
                        .font(F.time)
                        .foregroundColor(t.muted)
                    Spacer()
                    GlassButton(title: "Search", icon: "magnifyingglass") { performSearch() }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func listSection(t: Theme) -> some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                if isSearching {
                    ForEach(0..<4, id: \.self) { i in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(t.dim.opacity(0.3))
                                .frame(height: 36)
                        }
                        .padding(.horizontal, 12)
                        .shimmer()
                        .reveal(delay: Double(i) * 0.05)
                    }
                } else if query.isEmpty {
                    emptyState("Type a file name to search history.", t: t)
                } else if results.isEmpty {
                    emptyState("No results found.", t: t)
                } else {
                    ForEach(results.indices, id: \.self) { i in
                        let event = results[i]
                        SearchRow(event: event, isHovered: hoverItem == event.path, t: t)
                            .onHover { hovering in
                                withAnimation(A.fast) {
                                    hoverItem = hovering ? event.path : nil
                                }
                            }
                            .reveal(delay: Double(i) * 0.015)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func emptyState(_ msg: String, t: Theme) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(t.muted.opacity(0.15))
            Text(msg)
                .font(F.bodyS)
                .foregroundColor(t.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
        .reveal(delay: 0.1)
    }

    private func performSearch() {
        guard !query.isEmpty else { return }
        isSearching = true
        Task {
            results = await browser.search(query: query, includeRemoved: includeRemoved)
            isSearching = false
        }
    }
}

struct SearchRow: View {
    let event: FileEvent
    let isHovered: Bool
    let t: Theme

    var body: some View {
        HStack(spacing: 12) {
            FileIcon(name: event.name, isDirectory: event.isDirectory)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(F.bodyS)
                    .foregroundColor(t.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    EventBadge(text: event.eventType.description, color: eventColor)
                    Text(shortPath(event.parentPath))
                        .font(F.time)
                        .foregroundColor(t.muted)
                }
            }

            Spacer()

            Text(event.timestamp, style: .date)
                .font(F.time)
                .foregroundColor(t.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered ? t.surface.opacity(0.5) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? t.glassBorder : Color.clear, lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private var eventColor: Color {
        switch event.eventType {
        case .created:  return t.green
        case .modified: return t.accent
        case .renamed:  return t.amber
        case .removed:  return t.red
        }
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}

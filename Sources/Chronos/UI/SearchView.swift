import SwiftUI

struct SearchView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @State private var query = ""
    @State private var results: [FileEvent] = []
    @State private var isSearching = false
    @State private var includeRemoved = true
    @State private var hoverItem: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            topBar
            searchBar
            listSection
        }
    }

    private var topBar: some View {
        HStack {
            Text("Search History")
                .font(AppFont.bodyM)
                .foregroundColor(AppColors.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var searchBar: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(AppColors.muted)

                TextField("Search file name...", text: $query)
                    .font(AppFont.bodyS)
                    .foregroundColor(AppColors.text)
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
                            .foregroundColor(AppColors.muted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(AppColors.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                Toggle("Include deleted files", isOn: $includeRemoved)
                    .toggleStyle(.switch)
                    .font(AppFont.time)
                    .foregroundColor(AppColors.muted)
                Spacer()
                ChronosButton(title: "Search", icon: "magnifyingglass") { performSearch() }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private var listSection: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if isSearching {
                    ProgressView().padding(40)
                } else if query.isEmpty {
                    emptyState("Type a file name to search history.")
                } else if results.isEmpty {
                    emptyState("No results found.")
                } else {
                    ForEach(results.indices, id: \.self) { i in
                        let event = results[i]
                        SearchRow(event: event, isHovered: hoverItem == event.path)
                            .onHover { hovering in
                                withAnimation(Smooth.fast) {
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

    private func emptyState(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(AppColors.muted.opacity(0.15))
            Text(msg)
                .font(AppFont.bodyS)
                .foregroundColor(AppColors.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
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

    var body: some View {
        HStack(spacing: 12) {
            FileIcon(name: event.name, isDirectory: event.isDirectory)

            VStack(alignment: .leading, spacing: 2) {
                Text(event.name)
                    .font(AppFont.bodyS)
                    .foregroundColor(AppColors.text)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    EventBadge(text: event.eventType.description, color: eventColor)
                    Text(shortPath(event.parentPath))
                        .font(AppFont.time)
                        .foregroundColor(AppColors.muted)
                }
            }

            Spacer()

            Text(event.timestamp, style: .date)
                .font(AppFont.time)
                .foregroundColor(AppColors.muted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered ? AppColors.surface.opacity(0.5) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? AppColors.border : Color.clear, lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private var eventColor: Color {
        switch event.eventType {
        case .created:  return AppColors.green
        case .modified: return AppColors.accent
        case .renamed:  return AppColors.amber
        case .removed:  return AppColors.red
        }
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
        return path
    }
}

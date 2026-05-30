import SwiftUI

struct DiffView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @Environment(\.colorScheme) var scheme
    @State private var fromFraction: Double = 0.0
    @State private var toFraction: Double = 1.0
    @State private var diffs: [FileDiff] = []
    @State private var isLoading = false
    @State private var filter: DiffFilter = .all
    @State private var hoverItem: String?
    @State private var hasRun = false

    enum DiffFilter: String, CaseIterable {
        case all = "All"
        case added = "Added"
        case removed = "Removed"
        case modified = "Modified"
    }

    var filteredDiffs: [FileDiff] {
        switch filter {
        case .all:      return diffs
        case .added:    return diffs.filter { $0.status == .added }
        case .removed:  return diffs.filter { $0.status == .removed }
        case .modified: return diffs.filter { $0.status == .modified }
        }
    }

    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        VStack(spacing: 0) {
            topBar(t: t)
            controls(t: t)
            listSection(t: t)
        }
    }

    private func topBar(t: Theme) -> some View {
        HStack {
            Text("Diff")
                .font(F.bodyM)
                .foregroundColor(t.text)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func controls(t: Theme) -> some View {
        Glass(radius: 12) {
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    datePicker(label: "From", fraction: $fromFraction, range: browser.timeRange, t: t)
                    datePicker(label: "To",   fraction: $toFraction,   range: browser.timeRange, t: t)
                }

                HStack(spacing: 8) {
                    GlassButton(title: "Compare", icon: "arrow.left.arrow.right") { runDiff() }
                    Spacer()
                    Picker("", selection: $filter) {
                        ForEach(DiffFilter.allCases, id: \.self) { f in
                            Text(f.rawValue).tag(f)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func datePicker(label: String, fraction: Binding<Double>, range: (earliest: Date, latest: Date)?, t: Theme) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(F.label)
                .foregroundColor(t.muted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(t.dim.opacity(0.4))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(t.accent.opacity(0.7))
                        .frame(width: max(0, geo.size.width * fraction.wrappedValue), height: 6)
                    Circle()
                        .fill(t.accent)
                        .frame(width: 14, height: 14)
                        .shadow(color: t.accentGlow, radius: 6)
                        .offset(x: geo.size.width * fraction.wrappedValue - 7)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            fraction.wrappedValue = max(0, min(1, value.location.x / geo.size.width))
                        }
                )
            }
            .frame(height: 20)
            if let range = range {
                Text(dateAt(fraction: fraction.wrappedValue, range: range), style: .date)
                    .font(F.time)
                    .foregroundColor(t.muted)
            }
        }
    }

    private func listSection(t: Theme) -> some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                if isLoading {
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
                } else if filteredDiffs.isEmpty && hasRun {
                    emptyState("No changes between these two moments.", t: t)
                } else if !hasRun {
                    emptyState("Pick two moments and hit Compare.", t: t)
                } else {
                    ForEach(filteredDiffs.indices, id: \.self) { i in
                        let diff = filteredDiffs[i]
                        DiffRow(diff: diff, isHovered: hoverItem == diff.path, t: t)
                            .onHover { hovering in
                                withAnimation(A.fast) {
                                    hoverItem = hovering ? diff.path : nil
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
            Image(systemName: "arrow.left.arrow.right")
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

    private func runDiff() {
        guard let range = browser.timeRange else { return }
        let total = range.latest.timeIntervalSince(range.earliest)
        guard total > 0 else { return }
        let from = range.earliest.addingTimeInterval(total * fromFraction)
        let to   = range.earliest.addingTimeInterval(total * toFraction)
        isLoading = true
        hasRun = true
        Task {
            diffs = await browser.diff(folderPath: browser.currentFolder, from: from, to: to)
            isLoading = false
        }
    }

    private func dateAt(fraction: Double, range: (earliest: Date, latest: Date)) -> Date {
        let total = range.latest.timeIntervalSince(range.earliest)
        return range.earliest.addingTimeInterval(total * fraction)
    }
}

struct DiffRow: View {
    let diff: FileDiff
    let isHovered: Bool
    let t: Theme

    var body: some View {
        HStack(spacing: 12) {
            FileIcon(name: diff.name, isDirectory: diff.isDirectory)

            VStack(alignment: .leading, spacing: 2) {
                Text(diff.name)
                    .font(F.bodyS)
                    .foregroundColor(t.text)
                    .lineLimit(1)

                if diff.status == .modified {
                    HStack(spacing: 4) {
                        Text(byteString(diff.oldSize))
                            .font(F.time)
                            .foregroundColor(t.muted)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundColor(t.muted)
                        Text(byteString(diff.newSize))
                            .font(F.time)
                            .foregroundColor(t.text)
                    }
                }
            }

            Spacer()

            EventBadge(text: diff.status.description, color: statusColor)
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

    private var statusColor: Color {
        switch diff.status {
        case .added:     return t.green
        case .removed:   return t.red
        case .modified:  return t.amber
        case .unchanged: return t.muted
        }
    }
}

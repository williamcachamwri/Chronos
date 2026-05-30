import SwiftUI

struct DiffView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @State private var fromFraction: Double = 0.0
    @State private var toFraction: Double = 1.0
    @State private var diffs: [FileDiff] = []
    @State private var isLoading = false
    @State private var filter: DiffFilter = .all
    @State private var hoverItem: String?

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
        VStack(spacing: 0) {
            topBar
            controls
            listSection
        }
        .background(AppColors.bgGradient)
    }

    private var topBar: some View {
        HStack {
            Text("Diff")
                .font(AppFont.bodyM)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
        .overlay(Divider().background(AppColors.glassBorder), alignment: .bottom)
    }

    private var controls: some View {
        VStack(spacing: 16) {
            HStack(spacing: 16) {
                datePicker(label: "From", fraction: $fromFraction, range: browser.timeRange)
                datePicker(label: "To",   fraction: $toFraction,   range: browser.timeRange)
            }

            HStack(spacing: 8) {
                LiquidGlassButton(title: "Compare", icon: "arrow.left.arrow.right") { runDiff() }
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
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial)
        .overlay(Divider().background(AppColors.glassBorder), alignment: .bottom)
    }

    private func datePicker(label: String, fraction: Binding<Double>, range: (earliest: Date, latest: Date)?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(AppFont.label)
                .foregroundColor(AppColors.muted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.ultraThinMaterial)
                        .frame(height: 6)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(AppColors.glassBorder, lineWidth: 0.5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.accent.opacity(0.7))
                        .frame(width: max(0, geo.size.width * fraction.wrappedValue), height: 6)
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        .shadow(color: AppColors.accent.opacity(0.4), radius: 6)
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
                    .font(AppFont.time)
                    .foregroundColor(AppColors.muted)
            }
        }
    }

    private var listSection: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if isLoading {
                    ProgressView()
                        .padding(40)
                } else if filteredDiffs.isEmpty {
                    emptyState("Run a comparison to see changes.")
                } else {
                    ForEach(filteredDiffs.indices, id: \.self) { i in
                        let diff = filteredDiffs[i]
                        DiffRow(diff: diff, isHovered: hoverItem == diff.path)
                            .onHover { hovering in
                                withAnimation(Smooth.fast) {
                                    hoverItem = hovering ? diff.path : nil
                                }
                            }
                            .reveal(delay: Double(i) * 0.015)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(AppColors.bgGradient)
    }

    private func emptyState(_ msg: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "arrow.left.arrow.right")
                .font(.system(size: 32))
                .foregroundColor(AppColors.muted.opacity(0.15))
            Text(msg)
                .font(AppFont.bodyS)
                .foregroundColor(AppColors.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    private func runDiff() {
        guard let range = browser.timeRange else { return }
        let total = range.latest.timeIntervalSince(range.earliest)
        guard total > 0 else { return }
        let from = range.earliest.addingTimeInterval(total * fromFraction)
        let to   = range.earliest.addingTimeInterval(total * toFraction)
        isLoading = true
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

    var body: some View {
        HStack(spacing: 12) {
            FileIcon(name: diff.name, isDirectory: diff.isDirectory)

            VStack(alignment: .leading, spacing: 2) {
                Text(diff.name)
                    .font(AppFont.bodyS)
                    .foregroundColor(.white)
                    .lineLimit(1)

                if diff.status == .modified {
                    HStack(spacing: 4) {
                        Text(byteString(diff.oldSize))
                            .font(AppFont.time)
                            .foregroundColor(AppColors.muted)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 8))
                            .foregroundColor(AppColors.muted)
                        Text(byteString(diff.newSize))
                            .font(AppFont.time)
                            .foregroundColor(.white)
                    }
                }
            }

            Spacer()

            EventBadge(text: diff.status.description, color: statusColor)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(isHovered ? AppColors.accent.opacity(0.06) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial.opacity(isHovered ? 1 : 0))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? AppColors.glassBorder : Color.clear, lineWidth: 0.8)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
    }

    private var statusColor: Color {
        switch diff.status {
        case .added:     return AppColors.green
        case .removed:   return AppColors.red
        case .modified:  return AppColors.amber
        case .unchanged: return AppColors.muted
        }
    }
}

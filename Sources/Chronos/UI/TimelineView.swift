import SwiftUI

struct TimelineView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @State private var dateFraction: Double = 1.0
    @State private var isDragging = false
    @State private var hoverItem: String?

    var body: some View {
        VStack(spacing: 0) {
            topBar
            scrubberSection
            listSection
        }
        .background(AppColors.bg)
        .task {
            await browser.setup()
            updateFraction()
        }
        .onChange(of: dateFraction) { _, new in
            guard let range = browser.timeRange else { return }
            let total = range.latest.timeIntervalSince(range.earliest)
            guard total > 0 else { return }
            let newDate = range.earliest.addingTimeInterval(total * new)
            Task { await browser.setSnapshotDate(newDate) }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 12) {
            Button(action: { Task { await browser.goUp() } }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppColors.muted)
            }
            .buttonStyle(.plain)
            .disabled(browser.currentFolder == NSHomeDirectory())
            .opacity(browser.currentFolder == NSHomeDirectory() ? 0.3 : 1)

            Text(shortPath(browser.currentFolder))
                .font(AppFont.mono)
                .foregroundColor(AppColors.muted)
                .lineLimit(1)

            Spacer()

            if let range = browser.timeRange {
                Text(relativeDate(browser.snapshotDate, range: range))
                    .font(AppFont.label)
                    .foregroundColor(AppColors.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(AppColors.accent.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.accent.opacity(0.15), lineWidth: 0.5))
            }

            Button("Now") {
                withAnimation(Smooth.spring) { dateFraction = 1.0 }
            }
            .buttonStyle(.plain)
            .font(AppFont.label)
            .foregroundColor(AppColors.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(AppColors.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(AppColors.bgElev)
        .overlay(Divider().background(AppColors.border), alignment: .bottom)
    }

    // MARK: - Scrubber

    private var scrubberSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(AppColors.dim.opacity(0.5))
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.accent.opacity(0.5), AppColors.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * dateFraction), height: 6)

                    // Tick marks
                    if let range = browser.timeRange {
                        tickMarks(width: geo.size.width, range: range)
                    }

                    // Thumb
                    Circle()
                        .fill(AppColors.accent)
                        .frame(width: isDragging ? 18 : 14, height: isDragging ? 18 : 14)
                        .shadow(color: AppColors.accent.opacity(0.5), radius: isDragging ? 10 : 6)
                        .offset(x: geo.size.width * dateFraction - (isDragging ? 9 : 7))
                        .animation(Smooth.fast, value: isDragging)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dateFraction = max(0, min(1, value.location.x / geo.size.width))
                        }
                        .onEnded { _ in
                            withAnimation(Smooth.fast) { isDragging = false }
                        }
                )
            }
            .frame(height: 24)

            // Labels
            HStack {
                if let range = browser.timeRange {
                    Text(range.earliest, style: .date)
                        .font(AppFont.time)
                        .foregroundColor(AppColors.muted.opacity(0.6))
                    Spacer()
                    Text(range.latest, style: .date)
                        .font(AppFont.time)
                        .foregroundColor(AppColors.muted.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(AppColors.bg)
        .overlay(Divider().background(AppColors.border), alignment: .bottom)
    }

    private func tickMarks(width: CGFloat, range: (earliest: Date, latest: Date)) -> some View {
        let total = range.latest.timeIntervalSince(range.earliest)
        guard total > 0 else { return AnyView(EmptyView()) }
        let days = max(1, Int(total / 86400))
        let count = min(days, 12)
        let step = max(1, days / count)

        return AnyView(
            HStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    let x = CGFloat(i * step) / CGFloat(days) * width
                    Rectangle()
                        .fill(AppColors.text.opacity(0.06))
                        .frame(width: 1, height: 6)
                        .position(x: x + 0.5, y: 12)
                }
            }
        )
    }

    // MARK: - List

    private var listSection: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                if browser.items.isEmpty {
                    emptyState
                } else {
                    ForEach(browser.items.indices, id: \.self) { i in
                        let item = browser.items[i]
                        SnapshotRow(item: item, isHovered: hoverItem == item.path) {
                            if item.isDirectory {
                                Task { await browser.navigate(to: item.path) }
                            }
                        }
                        .onHover { hovering in
                            withAnimation(Smooth.fast) {
                                hoverItem = hovering ? item.path : nil
                            }
                        }
                        .reveal(delay: Double(i) * 0.02)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundColor(AppColors.muted.opacity(0.25))
            Text("Nothing here at this point in time")
                .font(AppFont.bodyM)
                .foregroundColor(AppColors.muted)
            if browser.timeRange == nil {
                Text("Chronos is recording changes. Make some file operations and check back.")
                    .font(AppFont.time)
                    .foregroundColor(AppColors.muted.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
    }

    // MARK: - Helpers

    private func updateFraction() {
        guard let range = browser.timeRange else { return }
        let total = range.latest.timeIntervalSince(range.earliest)
        guard total > 0 else { return }
        dateFraction = max(0, min(1, browser.snapshotDate.timeIntervalSince(range.earliest) / total))
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    private func relativeDate(_ date: Date, range: (earliest: Date, latest: Date)) -> String {
        let now = range.latest
        let diff = now.timeIntervalSince(date)
        if diff < 60 { return "Just now" }
        if diff < 3600 { return "\(Int(diff / 60))m ago" }
        if diff < 86400 { return "\(Int(diff / 3600))h ago" }
        if diff < 604800 { return "\(Int(diff / 86400))d ago" }
        let fmt = DateFormatter()
        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

// MARK: - Snapshot Row

struct SnapshotRow: View {
    let item: FileSnapshot
    let isHovered: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                FileIcon(name: item.name, isDirectory: item.isDirectory)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(AppFont.bodyS)
                        .foregroundColor(AppColors.text)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        EventBadge(text: item.lastEventType.description, color: eventColor)
                        Text(item.lastEventTime, style: .time)
                            .font(AppFont.time)
                            .foregroundColor(AppColors.muted)
                    }
                }

                Spacer()

                if !item.isDirectory {
                    Text(byteString(item.size))
                        .font(AppFont.time)
                        .foregroundColor(AppColors.muted)
                }

                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(AppColors.muted.opacity(0.4))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(isHovered ? AppColors.bgElev.opacity(0.5) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var eventColor: Color {
        switch item.lastEventType {
        case .created:  return AppColors.green
        case .modified: return AppColors.accent
        case .renamed:  return AppColors.amber
        case .removed:  return AppColors.red
        }
    }
}

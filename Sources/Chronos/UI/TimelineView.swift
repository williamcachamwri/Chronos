import SwiftUI

struct TimelineView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @Environment(\.colorScheme) var scheme
    @State private var dateFraction: Double = 1.0
    @State private var isDragging = false
    @State private var hoverItem: String?

    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        VStack(spacing: 0) {
            topBar(t: t)
            scrubberSection(t: t)
            listSection(t: t)
        }
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

    private func topBar(t: Theme) -> some View {
        HStack(spacing: 12) {
            Button(action: { Task { await browser.goUp() } }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(t.muted)
            }
            .buttonStyle(.plain)
            .disabled(browser.currentFolder == NSHomeDirectory())
            .opacity(browser.currentFolder == NSHomeDirectory() ? 0.3 : 1)

            Text(shortPath(browser.currentFolder))
                .font(F.mono)
                .foregroundColor(t.muted)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 6) {
                if browser.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(0.7)
                }
                AnimatedCounter(value: browser.totalEventCount)
            }

            if let range = browser.timeRange {
                Text(relativeDate(browser.snapshotDate, range: range))
                    .font(F.label)
                    .foregroundColor(t.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(t.accentDim)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.accent.opacity(0.15), lineWidth: 0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }

            Button("Now") {
                withAnimation(A.spring) { dateFraction = 1.0 }
            }
            .buttonStyle(.plain)
            .font(F.label)
            .foregroundColor(t.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(t.accentDim)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.accent.opacity(0.15), lineWidth: 0.5))
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    private func scrubberSection(t: Theme) -> some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(t.dim.opacity(0.4))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [t.accent.opacity(0.5), t.accent],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * dateFraction), height: 6)

                    if let range = browser.timeRange {
                        tickMarks(width: geo.size.width, range: range, t: t)
                    }

                    Circle()
                        .fill(t.accent)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .shadow(color: t.accentGlow, radius: isDragging ? 10 : 5)
                        .offset(x: geo.size.width * dateFraction - (isDragging ? 8 : 6))
                        .animation(A.fast, value: isDragging)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dateFraction = max(0, min(1, value.location.x / geo.size.width))
                        }
                        .onEnded { _ in
                            withAnimation(A.fast) { isDragging = false }
                        }
                )
            }
            .frame(height: 24)

            HStack {
                if let range = browser.timeRange {
                    Text(range.earliest, style: .date)
                        .font(F.time)
                        .foregroundColor(t.muted.opacity(0.5))
                    Spacer()
                    Text(range.latest, style: .date)
                        .font(F.time)
                        .foregroundColor(t.muted.opacity(0.5))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(t.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.glassBorder, lineWidth: 0.8))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func tickMarks(width: CGFloat, range: (earliest: Date, latest: Date), t: Theme) -> some View {
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
                        .fill(t.text.opacity(0.08))
                        .frame(width: 1, height: 6)
                        .position(x: x + 0.5, y: 12)
                }
            }
        )
    }

    private func listSection(t: Theme) -> some View {
        ScrollView {
            LazyVStack(spacing: 3) {
                if browser.items.isEmpty && !browser.isLoading {
                    emptyState(t: t)
                } else if browser.isLoading {
                    ForEach(0..<6, id: \.self) { i in
                        HStack {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(t.dim.opacity(0.3))
                                .frame(height: 36)
                        }
                        .padding(.horizontal, 12)
                        .shimmer()
                        .reveal(delay: Double(i) * 0.05)
                    }
                } else {
                    ForEach(browser.items.indices, id: \.self) { i in
                        let item = browser.items[i]
                        SnapshotRow(item: item, isHovered: hoverItem == item.path, t: t) {
                            if item.isDirectory {
                                Task { await browser.navigate(to: item.path) }
                            }
                        }
                        .onHover { hovering in
                            withAnimation(A.fast) {
                                hoverItem = hovering ? item.path : nil
                            }
                        }
                        .reveal(delay: Double(i) * 0.02)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
    }

    private func emptyState(t: Theme) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundColor(t.muted.opacity(0.2))
                .symbolEffect(.pulse, options: .repeating)
            Text("Nothing here at this point in time")
                .font(F.bodyM)
                .foregroundColor(t.muted)
            if browser.timeRange == nil {
                Text("Chronos is recording changes. Make some file operations and check back.")
                    .font(F.time)
                    .foregroundColor(t.muted.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 300)
        .padding()
        .reveal(delay: 0.1)
    }

    private func updateFraction() {
        guard let range = browser.timeRange else { return }
        let total = range.latest.timeIntervalSince(range.earliest)
        guard total > 0 else { return }
        dateFraction = max(0, min(1, browser.snapshotDate.timeIntervalSince(range.earliest) / total))
    }

    private func shortPath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) { return "~" + path.dropFirst(home.count) }
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

struct SnapshotRow: View {
    let item: FileSnapshot
    let isHovered: Bool
    let t: Theme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                FileIcon(name: item.name, isDirectory: item.isDirectory)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(F.bodyS)
                        .foregroundColor(t.text)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        EventBadge(text: item.lastEventType.description, color: eventColor)
                        Text(item.lastEventTime, style: .time)
                            .font(F.time)
                            .foregroundColor(t.muted)
                    }
                }

                Spacer()

                if !item.isDirectory {
                    Text(byteString(item.size))
                        .font(F.time)
                        .foregroundColor(t.muted)
                }

                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(t.muted.opacity(0.3))
                }
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
        .buttonStyle(.plain)
    }

    private var eventColor: Color {
        switch item.lastEventType {
        case .created:  return t.green
        case .modified: return t.accent
        case .renamed:  return t.amber
        case .removed:  return t.red
        }
    }
}

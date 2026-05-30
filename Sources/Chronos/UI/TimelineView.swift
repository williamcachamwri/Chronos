import SwiftUI

/// The main browser view: folder contents at a selected point in time.
struct TimelineView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @State private var dateFraction: Double = 1.0
    @State private var isDragging = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            toolbar

            Divider()
                .background(Color.white.opacity(0.06))

            // Timeline scrubber
            timelineScrubber
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.06))

            // Folder contents
            folderList
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))
        .task {
            await browser.setup()
            updateDateFraction()
        }
        .onChange(of: dateFraction) { _, newValue in
            guard let range = browser.timeRange else { return }
            let total = range.latest.timeIntervalSince(range.earliest)
            guard total > 0 else { return }
            let newDate = range.earliest.addingTimeInterval(total * newValue)
            Task { await browser.setSnapshotDate(newDate) }
        }
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: { Task { await browser.goUp() } }) {
                Image(systemName: "chevron.up")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)
            .disabled(browser.currentFolder == NSHomeDirectory())

            // Path breadcrumb
            Text(browser.currentFolder)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .truncationMode(.head)

            Spacer()

            // Date display
            if let range = browser.timeRange {
                Text(formattedDate(browser.snapshotDate, relativeTo: range))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            // Live button
            Button("Now") {
                withAnimation(.easeOut(duration: 0.3)) {
                    dateFraction = 1.0
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.blue)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Timeline Scrubber

    private var timelineScrubber: some View {
        VStack(spacing: 6) {
            // Gradient track with ticks
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track background
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 6)

                    // Filled portion
                    RoundedRectangle(cornerRadius: 3)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.4), .blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * dateFraction), height: 6)

                    // Ticks
                    if let range = browser.timeRange {
                        tickMarks(in: geo.size.width, range: range)
                    }

                    // Thumb
                    Circle()
                        .fill(Color.blue)
                        .frame(width: isDragging ? 16 : 12, height: isDragging ? 16 : 12)
                        .shadow(color: .blue.opacity(0.5), radius: isDragging ? 6 : 4)
                        .offset(x: geo.size.width * dateFraction - (isDragging ? 8 : 6))
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            let fraction = max(0, min(1, value.location.x / geo.size.width))
                            dateFraction = fraction
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 20)

            // Time labels
            HStack {
                if let range = browser.timeRange {
                    Text(range.earliest, style: .date)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(range.latest, style: .date)
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                } else {
                    Text("No history yet")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func tickMarks(in width: CGFloat, range: (earliest: Date, latest: Date)) -> some View {
        let total = range.latest.timeIntervalSince(range.earliest)
        guard total > 0 else { return AnyView(EmptyView()) }

        // Show ticks for each day
        let days = max(1, Int(total / 86400))
        let step = max(1, days / 10)

        return AnyView(
            HStack(spacing: 0) {
                ForEach(0..<(days / step + 1), id: \.self) { i in
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 1, height: 6)
                        .offset(x: width * CGFloat(i * step) / CGFloat(days) - width * CGFloat(i * step) / CGFloat(days))
                    Spacer()
                }
            }
        )
    }

    // MARK: - Folder List

    private var folderList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if browser.items.isEmpty {
                    emptyState
                } else {
                    ForEach(browser.items, id: \.path) { item in
                        SnapshotRow(item: item) {
                            if item.isDirectory {
                                Task { await browser.navigate(to: item.path) }
                            }
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))
            Text("Nothing here at this point in time")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            if browser.timeRange == nil {
                Text("Chronos is recording changes. Make some file operations and come back.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 200)
        .padding()
    }

    // MARK: - Helpers

    private func updateDateFraction() {
        guard let range = browser.timeRange else { return }
        let total = range.latest.timeIntervalSince(range.earliest)
        guard total > 0 else { return }
        let elapsed = browser.snapshotDate.timeIntervalSince(range.earliest)
        dateFraction = max(0, min(1, elapsed / total))
    }

    private func formattedDate(_ date: Date, relativeTo range: (earliest: Date, latest: Date)) -> String {
        let fmt = DateFormatter()
        let now = range.latest
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "Just now"
        } else if diff < 3600 {
            return "\(Int(diff / 60))m ago"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))h ago"
        } else if diff < 604800 {
            return "\(Int(diff / 86400))d ago"
        }

        fmt.dateStyle = .short
        fmt.timeStyle = .short
        return fmt.string(from: date)
    }
}

// MARK: - Snapshot Row

struct SnapshotRow: View {
    let item: FileSnapshot
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                // Icon
                Image(systemName: item.isDirectory ? "folder.fill" : iconFor(name: item.name))
                    .font(.system(size: 16))
                    .foregroundColor(item.isDirectory ? Color.yellow.opacity(0.8) : iconColor(name: item.name))
                    .frame(width: 24)

                // Name
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    HStack(spacing: 4) {
                        Text(item.lastEventType.rawValue)
                            .font(.system(size: 9, weight: .semibold))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(eventColor.opacity(0.12))
                            .foregroundColor(eventColor)
                            .clipShape(RoundedRectangle(cornerRadius: 3))

                        Text(item.lastEventTime, style: .time)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Size
                if !item.isDirectory {
                    Text(byteCount(item.size))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }

                if item.isDirectory {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .background(Color.white.opacity(0.0))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.15)) {
                // Hover state handled by SwiftUI automatically via button
            }
        }
    }

    private var eventColor: Color {
        let c = item.lastEventType.typeColor
        return Color(red: c.r, green: c.g, blue: c.b)
    }

    private func iconFor(name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return "photo.fill"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "mp3", "aac", "wav", "flac", "m4a": return "music.note"
        case "pdf": return "doc.fill"
        case "txt", "md", "rtf": return "doc.text.fill"
        case "swift", "py", "js", "ts", "go", "rs", "c", "cpp", "h": return "chevron.left.forwardslash.chevron.right"
        case "zip", "tar", "gz", "rar", "7z": return "archivebox.fill"
        case "dmg", "pkg", "app": return "cube.box.fill"
        default: return "doc"
        }
    }

    private func iconColor(name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return .purple.opacity(0.8)
        case "mp4", "mov", "avi", "mkv": return .pink.opacity(0.8)
        case "mp3", "aac", "wav", "flac", "m4a": return .red.opacity(0.8)
        case "pdf", "txt", "md", "rtf": return .blue.opacity(0.8)
        case "swift", "py", "js", "ts", "go", "rs": return .green.opacity(0.8)
        case "zip", "tar", "gz", "rar": return .orange.opacity(0.8)
        default: return .secondary.opacity(0.7)
        }
    }

    private func byteCount(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }
}

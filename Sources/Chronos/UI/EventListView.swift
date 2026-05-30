import SwiftUI

/// Shows a live stream of recent file-system events.
struct EventListView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @State private var events: [FileEvent] = []
    @State private var timer: Timer?

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(events) { event in
                    EventRow(event: event)
                }
            }
            .padding(.vertical, 4)
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))
        .onAppear { startPolling() }
        .onDisappear { timer?.invalidate() }
    }

    private func startPolling() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task {
                let newEvents = await browser.recentEvents(since: Date().addingTimeInterval(-3600))
                await MainActor.run { events = newEvents }
            }
        }
        timer?.fire()
    }
}

struct EventRow: View {
    let event: FileEvent

    var body: some View {
        HStack(spacing: 10) {
            // Event type dot
            Circle()
                .fill(eventColor)
                .frame(width: 6, height: 6)

            // Name
            Text(event.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)

            Spacer()

            // Event type label
            Text(event.eventType.rawValue)
                .font(.system(size: 9, weight: .semibold))
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(eventColor.opacity(0.12))
                .foregroundColor(eventColor)
                .clipShape(RoundedRectangle(cornerRadius: 3))

            // Time
            Text(event.timestamp, style: .time)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.0))
    }

    private var eventColor: Color {
        let c = event.eventType.typeColor
        return Color(red: c.r, green: c.g, blue: c.b)
    }
}

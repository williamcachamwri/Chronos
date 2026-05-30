import SwiftUI
import Combine

struct EventListView: View {
    @ObservedObject private var browser = HistoryBrowser.shared
    @Environment(\.colorScheme) var scheme
    @State private var events: [FileEvent] = []
    @State private var timerCancellable: Cancellable?
    @State private var livePulse = false

    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        VStack(spacing: 0) {
            HStack {
                Text("Live Events")
                    .font(F.bodyM)
                    .foregroundColor(t.text)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(t.green)
                        .frame(width: 6, height: 6)
                        .scaleEffect(livePulse ? 1.3 : 1.0)
                        .opacity(livePulse ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: livePulse)
                        .onAppear { livePulse = true }
                    Text("Recording")
                        .font(F.label)
                        .foregroundColor(t.muted)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(t.green.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(t.green.opacity(0.15), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            ScrollView {
                LazyVStack(spacing: 3) {
                    ForEach(events) { event in
                        EventRowLive(event: event, t: t)
                            .reveal(delay: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        }
        .onAppear { startPolling() }
        .onDisappear { timerCancellable?.cancel() }
    }

    private func startPolling() {
        let timer = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()
        timerCancellable = timer.sink { _ in
            Task {
                let newEvents = await browser.recentEvents(since: Date().addingTimeInterval(-3600))
                await MainActor.run { events = newEvents }
            }
        }
    }
}

struct EventRowLive: View {
    let event: FileEvent
    let t: Theme
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(eventColor)
                .frame(width: 6, height: 6)

            Text(event.name)
                .font(F.bodyS)
                .foregroundColor(t.text)
                .lineLimit(1)

            Spacer()

            EventBadge(text: event.eventType.description, color: eventColor)

            Text(event.timestamp, style: .time)
                .font(F.time)
                .foregroundColor(t.muted)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? t.surface.opacity(0.5) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? t.glassBorder : Color.clear, lineWidth: 0.6)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(A.fast) { isHovered = hovering }
        }
    }

    private var eventColor: Color {
        switch event.eventType {
        case .created:  return t.green
        case .modified: return t.accent
        case .renamed:  return t.amber
        case .removed:  return t.red
        }
    }
}

import SwiftUI
import Combine

struct EventListView: View {
    @StateObject private var browser = HistoryBrowser.shared
    @State private var events: [FileEvent] = []
    @State private var timerCancellable: Cancellable?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Live Events")
                    .font(AppFont.bodyM)
                    .foregroundColor(AppColors.text)
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.green)
                        .frame(width: 6, height: 6)
                    Text("Recording")
                        .font(AppFont.label)
                        .foregroundColor(AppColors.muted)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(AppColors.bgElev)
            .overlay(Divider().background(AppColors.border), alignment: .bottom)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(events) { event in
                        EventRowLive(event: event)
                            .reveal(delay: 0)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .background(AppColors.bg)
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
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(eventColor)
                .frame(width: 6, height: 6)

            Text(event.name)
                .font(AppFont.bodyS)
                .foregroundColor(AppColors.text)
                .lineLimit(1)

            Spacer()

            EventBadge(text: event.eventType.description, color: eventColor)

            Text(event.timestamp, style: .time)
                .font(AppFont.time)
                .foregroundColor(AppColors.muted)
                .frame(width: 44, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isHovered ? AppColors.bgElev.opacity(0.5) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(Smooth.fast) { isHovered = hovering }
        }
    }

    private var eventColor: Color {
        switch event.eventType {
        case .created:  return AppColors.green
        case .modified: return AppColors.accent
        case .renamed:  return AppColors.amber
        case .removed:  return AppColors.red
        }
    }
}

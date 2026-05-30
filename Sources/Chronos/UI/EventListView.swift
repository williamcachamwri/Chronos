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
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppColors.green.opacity(0.08))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(AppColors.green.opacity(0.15), lineWidth: 0.5))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(events) { event in
                        EventRowLive(event: event)
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
        .background(isHovered ? AppColors.surface.opacity(0.5) : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? AppColors.border : Color.clear, lineWidth: 0.6)
        )
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

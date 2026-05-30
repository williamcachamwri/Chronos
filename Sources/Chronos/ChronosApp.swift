import SwiftUI

@main
struct ChronosApp: App {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .frame(minWidth: 960, minHeight: 640)
                } else {
                    OnboardingView()
                        .frame(minWidth: 640, minHeight: 540)
                }
            }
            .background(AppColors.bgGradient)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: hasCompletedOnboarding ? 1100 : 640, height: hasCompletedOnboarding ? 700 : 580)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Settings {
            SettingsView()
        }
    }
}

enum SidebarTab: String, CaseIterable {
    case timeline = "Timeline"
    case diff = "Diff"
    case search = "Search"
    case events = "Events"

    var icon: String {
        switch self {
        case .timeline: return "clock.arrow.circlepath"
        case .diff:     return "arrow.left.arrow.right"
        case .search:   return "magnifyingglass"
        case .events:   return "bolt.fill"
        }
    }
}

struct ContentView: View {
    @State private var selectedTab: SidebarTab = .timeline

    var body: some View {
        NavigationSplitView {
            Sidebar(selectedTab: $selectedTab)
                .frame(minWidth: 200, idealWidth: 220)
        } detail: {
            ZStack {
                AppColors.bgGradient.ignoresSafeArea()
                switch selectedTab {
                case .timeline: TimelineView()
                case .diff:     DiffView()
                case .search:   SearchView()
                case .events:   EventListView()
                }
            }
        }
    }
}

struct Sidebar: View {
    @Binding var selectedTab: SidebarTab
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 36, height: 36)
                        .overlay(Circle().stroke(AppColors.glassBorder, lineWidth: 0.8))
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
                Text("Chronos")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)

            VStack(spacing: 3) {
                ForEach(SidebarTab.allCases, id: \.self) { tab in
                    SidebarRow(
                        icon: tab.icon,
                        label: tab.rawValue,
                        isSelected: selectedTab == tab
                    ) {
                        withAnimation(Smooth.fast) {
                            selectedTab = tab
                        }
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            SidebarRow(icon: "gear", label: "Settings", isSelected: false) {
                openSettings()
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
        .background(.ultraThinMaterial)
        .background(AppColors.bg.opacity(0.7))
    }
}

struct SidebarRow: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.muted)
                    .frame(width: 22)
                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .white : AppColors.muted)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                isSelected
                    ? AppColors.accent.opacity(0.12)
                    : Color.clear
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial.opacity(isSelected ? 1 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? AppColors.accent.opacity(0.25) : Color.clear, lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}

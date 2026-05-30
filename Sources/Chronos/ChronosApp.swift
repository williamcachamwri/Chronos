import SwiftUI

@main
struct ChronosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 960, minHeight: 640)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1100, height: 700)
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
                AppColors.bg.ignoresSafeArea()
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

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.15))
                        .frame(width: 32, height: 32)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                }
                Text("Chronos")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(AppColors.text)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
            .padding(.bottom, 24)

            // Tabs
            VStack(spacing: 2) {
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

            // Settings
            SidebarRow(icon: "gear", label: "Settings", isSelected: false) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 16)
        }
        .background(AppColors.bgElev)
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
                    .foregroundColor(isSelected ? AppColors.text : AppColors.muted)
                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(isSelected ? AppColors.accent.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? AppColors.accent.opacity(0.15) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

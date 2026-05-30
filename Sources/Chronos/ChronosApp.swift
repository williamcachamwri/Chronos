import SwiftUI

@main
struct ChronosApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 700, minHeight: 500)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 900, height: 600)

        Settings {
            SettingsView()
        }
    }
}

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        NavigationSplitView {
            sidebar
                .frame(minWidth: 180)
                .background(Color(red: 0.03, green: 0.03, blue: 0.04))
        } detail: {
            Group {
                switch selectedTab {
                case 0: TimelineView()
                case 1: EventListView()
                default: TimelineView()
                }
            }
            .background(Color(red: 0.03, green: 0.03, blue: 0.04))
        }
        .background(Color(red: 0.03, green: 0.03, blue: 0.04))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Logo
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.blue)
                Text("Chronos")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.horizontal, 8)

            // Nav items
            SidebarItem(icon: "clock", label: "Timeline", isSelected: selectedTab == 0) {
                selectedTab = 0
            }
            SidebarItem(icon: "bolt", label: "Live Events", isSelected: selectedTab == 1) {
                selectedTab = 1
            }

            Spacer()

            // Settings link
            SidebarItem(icon: "gear", label: "Settings", isSelected: false) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            }
        }
        .padding(.vertical, 4)
    }
}

struct SidebarItem: View {
    let icon: String
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .frame(width: 20)

                Text(label)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(isSelected ? .primary : .secondary)

                Spacer()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 6)
    }
}

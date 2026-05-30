import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.colorScheme) var scheme
    @State private var step = 0
    @State private var animating = false
    @State private var isAppearing = false

    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        ZStack {
            t.bg.ignoresSafeArea()

            GridPattern()
                .opacity(0.015)
                .ignoresSafeArea()

            GeometryReader { geo in
                RadialGradient(
                    colors: [
                        t.accent.opacity(0.06),
                        t.accent.opacity(0.02),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: min(geo.size.width, 700)
                )
                .offset(y: -geo.size.height * 0.2)
            }
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(t.accent.opacity(0.1))
                        .frame(width: 80, height: 80)
                        .scaleEffect(animating ? 1.05 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: animating)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(t.accent)
                        .symbolEffect(.pulse, options: .repeating, value: animating)
                }
                .onAppear { animating = true }
                .offset(y: isAppearing ? 0 : -20)
                .opacity(isAppearing ? 1 : 0)
                .animation(A.bouncy.delay(0.05), value: isAppearing)

                VStack(spacing: 10) {
                    Text(stepTitle)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(t.text)

                    Text(stepDescription)
                        .font(F.bodyS)
                        .foregroundColor(t.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .offset(y: isAppearing ? 0 : 16)
                .opacity(isAppearing ? 1 : 0)
                .animation(A.ease.delay(0.1), value: isAppearing)

                stepContent(t: t)
                    .offset(y: isAppearing ? 0 : 20)
                    .opacity(isAppearing ? 1 : 0)
                    .animation(A.ease.delay(0.2), value: isAppearing)

                Spacer()

                VStack(spacing: 20) {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(step == i ? t.accent : t.dim)
                                .frame(width: step == i ? 8 : 6, height: step == i ? 8 : 6)
                                .animation(A.spring, value: step)
                        }
                    }

                    GlassButton(
                        title: step == 2 ? "Get Started" : "Continue",
                        icon: step == 2 ? "arrow.right" : "chevron.right"
                    ) {
                        withAnimation(A.spring) {
                            if step < 2 {
                                step += 1
                            } else {
                                hasCompletedOnboarding = true
                            }
                        }
                    }
                }
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 480)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isAppearing = true
            }
        }
    }

    private var stepTitle: String {
        switch step {
        case 0: return "Chronos"
        case 1: return "Permissions"
        case 2: return "Ready"
        default: return ""
        }
    }

    private var stepDescription: String {
        switch step {
        case 0: return "Time-travel through your files. See what any folder looked like at any moment in the past."
        case 1: return "Chronos needs permission to monitor your folders. Full Disk Access lets us track file changes in real-time."
        case 2: return "Chronos will watch Desktop, Documents, and Downloads by default. You can add more folders later in Settings."
        default: return ""
        }
    }

    @ViewBuilder
    private func stepContent(t: Theme) -> some View {
        switch step {
        case 1:
            Glass(radius: 14) {
                VStack(alignment: .leading, spacing: 14) {
                    PermissionRow(icon: "folder.badge.gearshape", title: "Full Disk Access", subtitle: "Monitor file changes across your Mac", granted: hasFullDiskAccess(), t: t)
                    Divider().background(t.glassBorder)
                    PermissionRow(icon: "accessibility", title: "Accessibility", subtitle: "Optional: global shortcuts in the future", granted: false, t: t)
                }
                .padding(16)
            }
            .frame(maxWidth: 360)

        case 2:
            Glass(radius: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(["Desktop", "Documents", "Downloads"], id: \.self) { folder in
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(t.green)
                                .font(.system(size: 14))
                            Text(folder)
                                .font(F.bodyS)
                                .foregroundColor(t.text)
                            Spacer()
                        }
                    }
                }
                .padding(16)
            }
            .frame(maxWidth: 260)

        default:
            Glass(radius: 14) {
                HStack(spacing: 16) {
                    featureItem(icon: "clock.arrow.circlepath", title: "Timeline", subtitle: "Drag to travel back in time", t: t)
                    featureItem(icon: "arrow.left.arrow.right", title: "Diff", subtitle: "Compare any two moments", t: t)
                    featureItem(icon: "magnifyingglass", title: "Search", subtitle: "Find deleted files", t: t)
                }
                .padding(20)
            }
            .frame(maxWidth: 440)
        }
    }

    private func featureItem(icon: String, title: String, subtitle: String, t: Theme) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(t.accent)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(t.text)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(t.muted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private func hasFullDiskAccess() -> Bool {
        let testFile = "/Library/Application Support/com.apple.TCC/TCC.db"
        return FileManager.default.isReadableFile(atPath: testFile)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let granted: Bool
    let t: Theme

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(granted ? t.green : t.muted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(F.bodyS).foregroundColor(t.text)
                Text(subtitle).font(F.time).foregroundColor(t.muted)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(t.green)
                    .font(.system(size: 16))
            } else {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(t.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(t.accentDim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

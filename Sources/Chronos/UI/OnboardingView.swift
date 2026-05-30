import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var step = 0
    @State private var animating = false

    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            // Grid + orbs (same as main app)
            GridPattern()
                .opacity(0.02)
                .ignoresSafeArea()

            GlowOrb()
                .frame(width: 600, height: 400)
                .position(x: 320, y: 120)
                .ignoresSafeArea()

            FloatingParticles()
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(AppColors.accent.opacity(0.1))
                        .frame(width: 72, height: 72)
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(AppColors.accent)
                        .symbolEffect(.pulse, options: .repeating, value: animating)
                }
                .onAppear { animating = true }

                VStack(spacing: 10) {
                    Text(stepTitle)
                        .font(.system(size: 30, weight: .bold))
                        .foregroundColor(AppColors.text)

                    Text(stepDescription)
                        .font(AppFont.bodyS)
                        .foregroundColor(AppColors.muted)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 380)
                        .fixedSize(horizontal: false, vertical: true)
                }

                stepContent

                Spacer()

                VStack(spacing: 20) {
                    HStack(spacing: 6) {
                        ForEach(0..<3, id: \.self) { i in
                            Circle()
                                .fill(step == i ? AppColors.accent : AppColors.dim)
                                .frame(width: step == i ? 8 : 6, height: step == i ? 8 : 6)
                                .animation(Smooth.spring, value: step)
                        }
                    }

                    ChronosButton(
                        title: step == 2 ? "Get Started" : "Continue",
                        icon: step == 2 ? "arrow.right" : "chevron.right"
                    ) {
                        withAnimation(Smooth.spring) {
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
    private var stepContent: some View {
        switch step {
        case 1:
            VStack(alignment: .leading, spacing: 14) {
                PermissionRow(icon: "folder.badge.gearshape", title: "Full Disk Access", subtitle: "Monitor file changes across your Mac", granted: hasFullDiskAccess())
                Divider().background(AppColors.border)
                PermissionRow(icon: "accessibility", title: "Accessibility", subtitle: "Optional: global shortcuts in the future", granted: false)
            }
            .padding(16)
            .background(AppColors.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 360)

        case 2:
            VStack(alignment: .leading, spacing: 10) {
                ForEach(["Desktop", "Documents", "Downloads"], id: \.self) { folder in
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(AppColors.green)
                            .font(.system(size: 14))
                        Text(folder)
                            .font(AppFont.bodyS)
                            .foregroundColor(AppColors.text)
                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(AppColors.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 260)

        default:
            HStack(spacing: 16) {
                featureItem(icon: "clock.arrow.circlepath", title: "Timeline", subtitle: "Drag to travel back in time")
                featureItem(icon: "arrow.left.arrow.right", title: "Diff", subtitle: "Compare any two moments")
                featureItem(icon: "magnifyingglass", title: "Search", subtitle: "Find deleted files")
            }
            .padding(20)
            .background(AppColors.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 0.8))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .frame(maxWidth: 440)
        }
    }

    private func featureItem(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(AppColors.accent)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.text)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(AppColors.muted)
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

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(granted ? AppColors.green : AppColors.muted)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppFont.bodyS).foregroundColor(AppColors.text)
                Text(subtitle).font(AppFont.time).foregroundColor(AppColors.muted)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppColors.green)
                    .font(.system(size: 16))
            } else {
                Button("Open Settings") {
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(AppColors.accent)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppColors.accentDim)
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
    }
}

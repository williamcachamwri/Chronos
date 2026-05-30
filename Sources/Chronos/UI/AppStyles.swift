import SwiftUI

// MARK: - Snything-style Clean Design System

struct AppColors {
    // Deep but not oppressive — the Snything vibe
    static let bg        = Color(red: 0.031, green: 0.031, blue: 0.039) // #08080a
    static let surface   = Color(red: 0.067, green: 0.067, blue: 0.075) // #111113
    static let card      = Color(red: 0.051, green: 0.051, blue: 0.063) // #0d0d10
    static let border    = Color(red: 0.122, green: 0.122, blue: 0.137).opacity(0.6) // #1f1f23

    static let text      = Color(red: 0.945, green: 0.945, blue: 0.953) // #f1f1f3
    static let muted     = Color(red: 0.557, green: 0.557, blue: 0.576) // #8e8e93
    static let dim       = Color(red: 0.165, green: 0.165, blue: 0.176) // #2a2a2e

    static let accent    = Color(red: 0.231, green: 0.510, blue: 0.965) // #3b82f6
    static let accentDim = accent.opacity(0.12)

    static let green     = Color(red: 0.204, green: 0.827, blue: 0.600) // #34d399
    static let red       = Color(red: 0.973, green: 0.443, blue: 0.443) // #f87171
    static let amber     = Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b
}

struct AppFont {
    static let nav       = Font.system(size: 13, weight: .medium)
    static let bodyS     = Font.system(size: 13, weight: .regular)
    static let bodyM     = Font.system(size: 14, weight: .medium)
    static let title     = Font.system(size: 28, weight: .bold)
    static let label     = Font.system(size: 11, weight: .semibold)
    static let mono      = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let time      = Font.system(size: 10, weight: .regular)
    static let badge     = Font.system(size: 9,  weight: .semibold)
}

struct Smooth {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
    static let ease   = Animation.easeOut(duration: 0.3)
    static let fast   = Animation.easeOut(duration: 0.15)
}

// MARK: - Background (grid + orbs)

struct ChronosBackground: View {
    var body: some View {
        ZStack {
            AppColors.bg.ignoresSafeArea()

            // Subtle grid
            GeometryReader { geo in
                GridPattern()
                    .opacity(0.025)
                    .frame(width: geo.size.width, height: geo.size.height)
            }
            .ignoresSafeArea()

            // Large ambient glow orb — top center, pulsing
            GeometryReader { geo in
                GlowOrb()
                    .frame(width: min(900, geo.size.width), height: 500)
                    .position(x: geo.size.width / 2, y: 120)
                    .ignoresSafeArea()
            }

            // Small floating particles
            FloatingParticles()
                .ignoresSafeArea()
        }
    }
}

struct GridPattern: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 80
            let lineColor = Color.white.opacity(0.15)

            for x in stride(from: 0, to: size.width, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
            for y in stride(from: 0, to: size.height, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(lineColor), lineWidth: 0.5)
            }
        }
    }
}

struct GlowOrb: View {
    @State private var phase = false

    var body: some View {
        RadialGradient(
            colors: [
                AppColors.accent.opacity(0.08),
                AppColors.accent.opacity(0.03),
                Color.clear
            ],
            center: .center,
            startRadius: 0,
            endRadius: 350
        )
        .blur(radius: 80)
        .scaleEffect(phase ? 1.08 : 1.0)
        .opacity(phase ? 0.7 : 0.5)
        .animation(.easeInOut(duration: 6).repeatForever(autoreverses: true), value: phase)
        .onAppear { phase = true }
    }
}

struct FloatingParticles: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Particle(x: geo.size.width * 0.15, y: geo.size.height * 0.25, size: 3, delay: 0)
                Particle(x: geo.size.width * 0.85, y: geo.size.height * 0.35, size: 2, delay: 1.5)
                Particle(x: geo.size.width * 0.70, y: geo.size.height * 0.70, size: 2.5, delay: 3)
                Particle(x: geo.size.width * 0.20, y: geo.size.height * 0.80, size: 2, delay: 2)
                Particle(x: geo.size.width * 0.50, y: geo.size.height * 0.55, size: 1.5, delay: 4)
            }
        }
    }
}

struct Particle: View {
    let x: CGFloat
    let y: CGFloat
    let size: CGFloat
    let delay: Double

    @State private var offset: CGFloat = 0

    var body: some View {
        Circle()
            .fill(AppColors.accent.opacity(0.15))
            .frame(width: size, height: size)
            .position(x: x, y: y + offset)
            .blur(radius: 1)
            .onAppear {
                withAnimation(.easeInOut(duration: 7).repeatForever(autoreverses: true).delay(delay)) {
                    offset = -18
                }
            }
    }
}

// MARK: - Components

struct EventBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(AppFont.badge)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

struct FileIcon: View {
    let name: String
    let isDirectory: Bool
    var body: some View {
        Image(systemName: isDirectory ? "folder.fill" : iconName(for: name))
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(isDirectory ? Color.yellow.opacity(0.75) : iconColor(for: name))
            .frame(width: 22, alignment: .center)
    }

    private func iconName(for name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp", "tiff": return "photo.fill"
        case "mp4", "mov", "avi", "mkv": return "film.fill"
        case "mp3", "aac", "wav", "flac", "m4a": return "music.note"
        case "pdf": return "doc.fill"
        case "txt", "md", "rtf": return "doc.text.fill"
        case "swift", "py", "js", "ts", "go", "rs", "c", "cpp", "h", "java": return "chevron.left.forwardslash.chevron.right"
        case "zip", "tar", "gz", "rar", "7z": return "archivebox.fill"
        case "dmg", "pkg", "app": return "cube.box.fill"
        case "xlsx", "xls", "csv": return "tablecells.fill"
        case "pptx", "ppt", "key": return "play.rectangle.fill"
        default: return "doc"
        }
    }

    private func iconColor(for name: String) -> Color {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "jpg", "jpeg", "png", "gif", "heic", "webp": return .purple.opacity(0.75)
        case "mp4", "mov", "avi", "mkv": return .pink.opacity(0.75)
        case "mp3", "aac", "wav", "flac", "m4a": return .red.opacity(0.75)
        case "pdf", "txt", "md", "rtf": return .blue.opacity(0.75)
        case "swift", "py", "js", "ts", "go", "rs", "java": return .green.opacity(0.75)
        case "zip", "tar", "gz", "rar": return .orange.opacity(0.75)
        default: return AppColors.muted
        }
    }
}

struct ChronosButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(AppFont.bodyS)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(AppColors.accent)
            .clipShape(Capsule())
            .shadow(color: AppColors.accent.opacity(0.35), radius: 12, x: 0, y: 3)
        }
        .buttonStyle(.plain)
    }
}

struct ChronosButtonSecondary: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(AppFont.bodyS)
                .foregroundColor(AppColors.muted)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .overlay(Capsule().stroke(AppColors.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

func byteString(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

// MARK: - Reveal Animation

struct RevealModifier: ViewModifier {
    @State private var isVisible = false
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 16)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

extension View {
    func reveal(delay: Double = 0) -> some View {
        modifier(RevealModifier(delay: delay))
    }
}

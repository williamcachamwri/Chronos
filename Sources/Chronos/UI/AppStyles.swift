import SwiftUI

// MARK: - Theme (Adaptive Light / Dark)

struct Theme {
    let isDark: Bool

    var bg:        Color { isDark ? Color(red: 0.031, green: 0.031, blue: 0.039) : Color(red: 0.97,  green: 0.97,  blue: 0.98) }
    var surface:   Color { isDark ? Color(red: 0.067, green: 0.067, blue: 0.075) : Color(red: 0.95,  green: 0.95,  blue: 0.96) }
    var card:      Color { isDark ? Color(red: 0.051, green: 0.051, blue: 0.063) : Color.white }
    var elevated:  Color { isDark ? Color(red: 0.10,  green: 0.10,  blue: 0.12)  : Color.white }

    var text:      Color { isDark ? Color(red: 0.945, green: 0.945, blue: 0.953) : Color(red: 0.08, green: 0.08, blue: 0.10) }
    var muted:     Color { isDark ? Color(red: 0.557, green: 0.557, blue: 0.576) : Color(red: 0.45, green: 0.45, blue: 0.50) }
    var dim:       Color { isDark ? Color(red: 0.165, green: 0.165, blue: 0.176) : Color(red: 0.82, green: 0.82, blue: 0.85) }

    var accent:    Color { isDark ? Color(red: 0.35, green: 0.55, blue: 1.0) : Color(red: 0.20, green: 0.42, blue: 0.90) }
    var accentDim: Color { accent.opacity(0.12) }
    var accentGlow:Color { accent.opacity(0.25) }

    var green:     Color { Color(red: 0.25, green: 0.85, blue: 0.50) }
    var red:       Color { Color(red: 1.0,  green: 0.35, blue: 0.35) }
    var amber:     Color { Color(red: 1.0,  green: 0.65, blue: 0.15) }

    var glassBorder:    Color { isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.06) }
    var glassHighlight: Color { isDark ? Color.white.opacity(0.05) : Color.white.opacity(0.6) }
}

struct F {
    static let nav   = Font.system(size: 13, weight: .medium)
    static let bodyS = Font.system(size: 13, weight: .regular)
    static let bodyM = Font.system(size: 14, weight: .medium)
    static let title = Font.system(size: 28, weight: .bold)
    static let label = Font.system(size: 11, weight: .semibold)
    static let mono  = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let time  = Font.system(size: 10, weight: .regular)
    static let badge = Font.system(size: 9,  weight: .semibold)
}

struct A {
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2)
    static let ease   = Animation.easeOut(duration: 0.35)
    static let fast   = Animation.easeOut(duration: 0.15)
    static let bouncy = Animation.spring(response: 0.55, dampingFraction: 0.70, blendDuration: 0.25)
}

// MARK: - Glass Panel

struct Glass<Content: View>: View {
    @Environment(\.colorScheme) var scheme
    let radius: CGFloat
    let content: Content
    init(radius: CGFloat = 14, @ViewBuilder content: () -> Content) {
        self.radius = radius
        self.content = content()
    }
    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        content
            .background(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: radius)
                    .fill(t.glassHighlight)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius)
                    .stroke(t.glassBorder, lineWidth: 0.8)
            )
            .clipShape(RoundedRectangle(cornerRadius: radius))
    }
}

struct GlassButton: View {
    @Environment(\.colorScheme) var scheme
    let title: String
    let icon: String?
    let action: () -> Void
    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 11, weight: .semibold)) }
                Text(title).font(F.bodyS)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(t.accent.opacity(0.9))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: t.accentGlow, radius: 14, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct GlassButtonSecondary: View {
    @Environment(\.colorScheme) var scheme
    let title: String
    let action: () -> Void
    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        Button(action: action) {
            Text(title).font(F.bodyS)
                .foregroundColor(t.text.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(t.glassBorder, lineWidth: 0.8)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct EventBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(F.badge)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 4))
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
        default: return Color.gray
        }
    }
}

func byteString(_ bytes: Int64) -> String {
    ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

// MARK: - Shimmer Loading

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geo in
                    LinearGradient(
                        colors: [Color.clear, Color.white.opacity(0.12), Color.clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geo.size.width * 2)
                    .offset(x: -geo.size.width + phase * geo.size.width * 2)
                    .onAppear {
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            phase = 1
                        }
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
            )
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Reveal Animation

struct RevealModifier: ViewModifier {
    @State private var visible = false
    let delay: Double
    func body(content: Content) -> some View {
        content
            .opacity(visible ? 1 : 0)
            .offset(y: visible ? 0 : 16)
            .scaleEffect(visible ? 1 : 0.96)
            .onAppear {
                withAnimation(A.ease.delay(delay)) {
                    visible = true
                }
            }
    }
}

extension View {
    func reveal(delay: Double = 0) -> some View {
        modifier(RevealModifier(delay: delay))
    }
}

// MARK: - Background

struct ChronosBackground: View {
    @Environment(\.colorScheme) var scheme
    var body: some View {
        let t = Theme(isDark: scheme == .dark)
        ZStack {
            t.bg.ignoresSafeArea()

            GeometryReader { geo in
                RadialGradient(
                    colors: [
                        t.accent.opacity(0.05),
                        t.accent.opacity(0.01),
                        Color.clear
                    ],
                    center: .top,
                    startRadius: 0,
                    endRadius: min(geo.size.width, 900)
                )
                .offset(y: -geo.size.height * 0.15)
            }
            .ignoresSafeArea()

            GridPattern()
                .opacity(0.015)
                .ignoresSafeArea()
        }
    }
}

struct GridPattern: View {
    var body: some View {
        Canvas { ctx, size in
            let step: CGFloat = 60
            for x in stride(from: 0, to: size.width, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
                ctx.stroke(path, with: .color(Color.white.opacity(0.2)), lineWidth: 0.4)
            }
            for y in stride(from: 0, to: size.height, by: step) {
                var path = Path()
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
                ctx.stroke(path, with: .color(Color.white.opacity(0.2)), lineWidth: 0.4)
            }
        }
    }
}

struct AnimatedCounter: View {
    let value: Int
    @State private var display: Int = 0
    var body: some View {
        Text("\(display)")
            .font(F.time)
            .foregroundColor(Color.gray)
            .onAppear { display = value }
            .onChange(of: value) { _, new in
                withAnimation(A.spring) {
                    display = new
                }
            }
    }
}

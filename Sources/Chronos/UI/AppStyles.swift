import SwiftUI

// MARK: - Liquid Glass Design System

struct AppColors {
    // Atmospheric background — not pure black, but deep dark with subtle warmth
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let bgGradient = LinearGradient(
        colors: [
            Color(red: 0.02, green: 0.02, blue: 0.05),
            Color(red: 0.05, green: 0.03, blue: 0.07),
            Color(red: 0.03, green: 0.04, blue: 0.06)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let text   = Color.white
    static let muted  = Color.white.opacity(0.55)
    static let accent = Color(red: 0.35, green: 0.55, blue: 1.0) // softer blue
    static let glassBorder = Color.white.opacity(0.18)
    static let glassHighlight = Color.white.opacity(0.08)

    static let green  = Color(red: 0.25, green: 0.85, blue: 0.50)
    static let red    = Color(red: 1.0,  green: 0.35, blue: 0.35)
    static let amber  = Color(red: 1.0,  green: 0.65, blue: 0.15)
}

struct AppFont {
    static let nav   = Font.system(size: 13, weight: .medium)
    static let bodyS = Font.system(size: 13, weight: .regular)
    static let bodyM = Font.system(size: 14, weight: .medium)
    static let title = Font.system(size: 32, weight: .bold, design: .rounded)
    static let label = Font.system(size: 11, weight: .semibold)
    static let mono  = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let time  = Font.system(size: 10, weight: .regular)
    static let badge = Font.system(size: 9,  weight: .semibold)
}

struct Smooth {
    static let spring = Animation.spring(response: 0.45, dampingFraction: 0.82, blendDuration: 0.2)
    static let ease   = Animation.easeOut(duration: 0.35)
    static let fast   = Animation.easeOut(duration: 0.2)
}

// MARK: - Liquid Glass Components

struct LiquidGlassPanel<Content: View>: View {
    let cornerRadius: CGFloat
    let content: Content

    init(cornerRadius: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .background(.ultraThinMaterial)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(AppColors.glassBorder, lineWidth: 0.8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [AppColors.glassHighlight, Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

struct LiquidGlassButton: View {
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.accent.opacity(0.85))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
            )
            .shadow(color: AppColors.accent.opacity(0.35), radius: 12, x: 0, y: 4)
        }
        .buttonStyle(.plain)
    }
}

struct LiquidGlassButtonSecondary: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title).font(AppFont.bodyS)
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(AppColors.glassBorder, lineWidth: 0.8)
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
            .font(AppFont.badge)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
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
        default: return AppColors.muted
        }
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
            .offset(y: isVisible ? 0 : 14)
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

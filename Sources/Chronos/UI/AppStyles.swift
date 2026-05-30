import SwiftUI

// MARK: - Design System

struct AppColors {
    static let bg     = Color(red: 0.031, green: 0.031, blue: 0.039) // #08080a
    static let bgElev = Color(red: 0.067, green: 0.067, blue: 0.075) // #111113
    static let bgCard = Color(red: 0.051, green: 0.051, blue: 0.063) // #0d0d10
    static let text   = Color(red: 0.945, green: 0.945, blue: 0.953) // #f1f1f3
    static let muted  = Color(red: 0.557, green: 0.557, blue: 0.576) // #8e8e93
    static let dim    = Color(red: 0.165, green: 0.165, blue: 0.176) // #2a2a2e
    static let border = Color(red: 0.122, green: 0.122, blue: 0.137) // #1f1f23
    static let accent = Color(red: 0.231, green: 0.510, blue: 0.965) // #3b82f6
    static let accentDim = accent.opacity(0.12)
    static let green  = Color(red: 0.204, green: 0.827, blue: 0.600) // #34d399
    static let red    = Color(red: 0.973, green: 0.443, blue: 0.443) // #f87171
    static let amber  = Color(red: 0.961, green: 0.620, blue: 0.043) // #f59e0b
}

struct AppFont {
    static let nav   = Font.system(size: 13, weight: .medium)
    static let bodyS = Font.system(size: 13, weight: .regular)
    static let bodyM = Font.system(size: 14, weight: .medium)
    static let title = Font.system(size: 28, weight: .bold)
    static let label = Font.system(size: 11, weight: .semibold)
    static let mono  = Font.system(size: 12, weight: .medium, design: .monospaced)
    static let time  = Font.system(size: 10, weight: .regular)
    static let badge = Font.system(size: 9,  weight: .semibold)
}

// MARK: - Smooth Animations

struct Smooth {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0.2)
    static let ease   = Animation.easeOut(duration: 0.3)
    static let fast   = Animation.easeOut(duration: 0.2)
}

// MARK: - Reusable Components

struct GlassCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder _ content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .background(AppColors.bgCard.opacity(0.6))
            .background(.ultraThinMaterial)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppColors.border.opacity(0.6), lineWidth: 1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
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
            .shadow(color: AppColors.accent.opacity(0.3), radius: 8, x: 0, y: 2)
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

struct EventBadge: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(AppFont.badge)
            .foregroundColor(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
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

// MARK: - Scroll Reveal

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

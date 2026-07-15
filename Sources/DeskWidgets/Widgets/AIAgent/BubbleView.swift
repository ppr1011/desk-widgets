import SwiftUI

/// 卡通风气泡主题:每种触发场景一套糖果配色 + 表情吉祥物。
private struct BubbleTheme {
    let emoji: String
    let top: Color
    let bottom: Color
    let accent: Color

    static func of(_ scene: TriggerScene) -> BubbleTheme {
        switch scene {
        case .scheduled:
            return .init(emoji: "☕️", top: rgb(255, 233, 214), bottom: rgb(255, 211, 165), accent: rgb(255, 140, 66))
        case .longSitting:
            return .init(emoji: "🚶", top: rgb(216, 245, 227), bottom: rgb(181, 234, 215), accent: rgb(47, 191, 113))
        case .idle:
            return .init(emoji: "💭", top: rgb(237, 231, 255), bottom: rgb(214, 201, 255), accent: rgb(124, 92, 252))
        case .highLoad:
            return .init(emoji: "🔥", top: rgb(255, 224, 224), bottom: rgb(255, 194, 194), accent: rgb(255, 92, 92))
        case .manual:
            return .init(emoji: "👋", top: rgb(222, 235, 255), bottom: rgb(185, 214, 255), accent: rgb(59, 130, 246))
        case .conversation:
            return .init(emoji: "💬", top: rgb(214, 245, 242), bottom: rgb(168, 230, 224), accent: rgb(20, 184, 166))
        }
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255)
    }
}

/// 卡通风气泡。带指向头像的小尾巴(pointsDown=true 时尾巴在下方指向组件)。
struct BubbleView: View {
    let message: String
    let scene: TriggerScene
    let pointsDown: Bool
    let onKnown: () -> Void
    let onRemindLater: () -> Void
    let onOpenChat: () -> Void

    @State private var appeared = false

    private let contentWidth: CGFloat = 276
    private var theme: BubbleTheme { .of(scene) }
    private var ink: Color { Color(red: 0.24, green: 0.22, blue: 0.30) }

    var body: some View {
        VStack(spacing: -1) {
            if !pointsDown { tail(up: true) }
            card
            if pointsDown { tail(up: false) }
        }
        .frame(width: contentWidth + 24)
        .padding(8)
        .scaleEffect(appeared ? 1 : 0.82, anchor: pointsDown ? .bottom : .top)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.6)) { appeared = true }
        }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 11) {
                mascot
                Text(message)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(ink)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
            }

            HStack(spacing: 8) {
                filledButton("知道了", action: onKnown)
                softButton("稍后", action: onRemindLater)
                Spacer(minLength: 0)
                chatButton
            }
        }
        .padding(14)
        .frame(width: contentWidth)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [theme.top, theme.bottom],
                    startPoint: .top, endPoint: .bottom
                ))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.85), lineWidth: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(theme.accent.opacity(0.25), lineWidth: 1)
                .padding(-0.5)
        )
        .shadow(color: theme.accent.opacity(0.35), radius: 16, y: 7)
    }

    private var mascot: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: 38, height: 38)
                .overlay(Circle().strokeBorder(theme.accent.opacity(0.35), lineWidth: 2))
                .shadow(color: theme.accent.opacity(0.3), radius: 4, y: 2)
            Text(theme.emoji)
                .font(.system(size: 20))
        }
    }

    private func filledButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule().fill(theme.accent)
                )
                .overlay(Capsule().strokeBorder(Color.white.opacity(0.5), lineWidth: 1))
                .foregroundStyle(.white)
                .shadow(color: theme.accent.opacity(0.4), radius: 4, y: 2)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private func softButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Capsule().fill(Color.white.opacity(0.75)))
                .foregroundStyle(theme.accent)
        }
        .buttonStyle(BouncyButtonStyle())
    }

    private var chatButton: some View {
        Button(action: onOpenChat) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(theme.accent)
                .padding(8)
                .background(Circle().fill(Color.white.opacity(0.75)))
        }
        .buttonStyle(BouncyButtonStyle())
        .help("展开对话")
    }

    private func tail(up: Bool) -> some View {
        Triangle()
            .fill(up ? theme.top : theme.bottom)
            .frame(width: 24, height: 12)
            .overlay(
                Triangle()
                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
            )
            .rotationEffect(.degrees(up ? 180 : 0))
            .shadow(color: theme.accent.opacity(0.2), radius: 2, y: up ? -1 : 1)
    }
}

/// 点击时轻微回弹,增强卡通交互手感。
private struct BouncyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.5), value: configuration.isPressed)
    }
}

/// 简单三角形(默认尖端朝下)。
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

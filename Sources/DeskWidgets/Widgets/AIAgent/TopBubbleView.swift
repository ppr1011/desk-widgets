import SwiftUI

/// 顶部菜单栏气泡的交互容器:默认展示提示气泡,点「展开对话」就地展开成聊天框。
struct TopBubbleHost: View {
    let message: String
    let scene: TriggerScene
    let reminderSize: CGSize
    let onKnown: () -> Void
    let onRemindLater: () -> Void
    let onEnterChat: () -> Void
    let onResize: (CGFloat) -> Void

    @State private var showChat = false
    @State private var messages: [ChatMessage] = []
    @State private var input = ""
    @State private var isSending = false

    private let chatHeight: CGFloat = 420

    var body: some View {
        Group {
            if showChat {
                chatCard
                    .frame(width: reminderSize.width, height: chatHeight)
            } else {
                BubbleView(
                    message: message,
                    scene: scene,
                    pointsDown: false,
                    onKnown: onKnown,
                    onRemindLater: onRemindLater,
                    onOpenChat: openChat
                )
            }
        }
    }

    private func openChat() {
        messages = [ChatMessage(role: .assistant, content: message)]
        showChat = true
        onEnterChat()
        onResize(chatHeight)
    }

    // MARK: - Chat

    private var chatCard: some View {
        VStack(spacing: 0) {
            header
            messageList
            inputBar
        }
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(LinearGradient(
                            colors: [Color.accentColor.opacity(0.07), .clear],
                            startPoint: .top, endPoint: .bottom
                        ))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(Color.white.opacity(0.55), lineWidth: 1.5)
        )
        .shadow(color: Color.accentColor.opacity(0.28), radius: 18, y: 8)
        .padding(8)
    }

    private var header: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor, Color.purple.opacity(0.8)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 28, height: 28)
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 4, y: 2)
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("AI 助手")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(AISettingsStore.shared.settings.persona.displayName)
                    .font(.system(size: 10.5, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onKnown) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { msg in
                        chatBubble(msg).id(msg.id)
                    }
                    if isSending {
                        typingIndicator.id("typing")
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
            .onChange(of: isSending) { sending in
                if sending { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
        }
    }

    private func chatBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        return HStack(alignment: .top, spacing: 7) {
            if isUser {
                Spacer(minLength: 34)
            } else {
                assistantAvatar
            }
            Text(msg.content)
                .font(.system(size: 13.5, weight: .regular, design: .rounded))
                .lineSpacing(4)
                .tracking(0.2)
                .foregroundStyle(isUser ? Color.white : Color.primary.opacity(0.9))
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(bubbleBackground(isUser: isUser))
                .fixedSize(horizontal: false, vertical: true)
            if !isUser { Spacer(minLength: 34) }
        }
    }

    @ViewBuilder
    private func bubbleBackground(isUser: Bool) -> some View {
        if isUser {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .shadow(color: Color.accentColor.opacity(0.35), radius: 5, y: 2)
        } else {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.primary.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
                )
        }
    }

    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.accentColor.opacity(0.9), Color.purple.opacity(0.75)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 22, height: 22)
            Image(systemName: "sparkles")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.top, 2)
    }

    private var typingIndicator: some View {
        HStack(spacing: 7) {
            assistantAvatar
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.primary.opacity(0.35))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            )
            Spacer(minLength: 34)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            NativeTextField(text: $input, placeholder: "输入消息…", onSubmit: send)
                .frame(height: 24)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.primary.opacity(0.06))
                        .overlay(Capsule().strokeBorder(Color.primary.opacity(0.06), lineWidth: 1))
                )
            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle().fill(LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.85)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    )
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 5, y: 2)
                    .opacity(isSending ? 0.5 : 1)
            }
            .buttonStyle(.plain)
            .disabled(isSending)
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 14)
    }

    private func send() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        input = ""
        messages.append(ChatMessage(role: .user, content: text))
        isSending = true
        let history = Array(messages.suffix(10))
        let settings = AISettingsStore.shared.settings
        Task { @MainActor in
            do {
                let reply = try await AIService.shared.converse(history: history, settings: settings)
                messages.append(ChatMessage(role: .assistant, content: reply))
            } catch {
                messages.append(ChatMessage(
                    role: .assistant,
                    content: "连不上模型了：\((error as? LLMError)?.errorDescription ?? "请检查设置")"
                ))
            }
            isSending = false
        }
    }
}

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
            Divider().opacity(0.5)
            messageList
            inputBar
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
        )
        .shadow(color: Color.accentColor.opacity(0.28), radius: 16, y: 7)
        .padding(8)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.accentColor, Color.purple.opacity(0.8)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 26, height: 26)
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("AI 助手")
                .font(.system(size: 13, weight: .bold, design: .rounded))
            Spacer()
            Button(action: onKnown) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(messages) { msg in
                        chatBubble(msg).id(msg.id)
                    }
                    if isSending {
                        HStack {
                            Text("正在思考…")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .id("typing")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .onChange(of: messages.count) { _ in
                if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func chatBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        return HStack {
            if isUser { Spacer(minLength: 28) }
            Text(msg.content)
                .font(.system(size: 12.5, design: .rounded))
                .padding(.horizontal, 11)
                .padding(.vertical, 7)
                .background(
                    isUser ? AnyShapeStyle(Color.accentColor)
                           : AnyShapeStyle(Color.primary.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                )
                .foregroundStyle(isUser ? Color.white : Color.primary)
            if !isUser { Spacer(minLength: 28) }
        }
    }

    private var inputBar: some View {
        HStack(spacing: 6) {
            NativeTextField(text: $input, placeholder: "输入消息…", onSubmit: send)
                .frame(height: 22)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: Capsule())
            Button(action: send) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color.accentColor))
            }
            .buttonStyle(.plain)
            .disabled(isSending)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
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

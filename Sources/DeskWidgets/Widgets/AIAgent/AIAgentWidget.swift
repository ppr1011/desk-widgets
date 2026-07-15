import SwiftUI

/// AI 办公助手组件 —— 全天候陪伴,定时/按状态弹气泡,支持对话与个性化设置。
struct AIAgentWidget: WidgetProvider {
    let kind: WidgetKind = .aiAgent
    let displayName = "AI 助手"
    let defaultSize = CGSize(width: 320, height: 300)
    var acceptsKeyboardInput: Bool { true }

    func makeView(instance: WidgetInstance, store: WidgetStore) -> AnyView {
        AnyView(AIAgentView(instanceID: instance.id, store: store))
    }
}

private struct AIAgentView: View {
    let instanceID: UUID
    @ObservedObject var store: WidgetStore
    @ObservedObject private var settingsStore = AISettingsStore.shared
    @ObservedObject private var activity = ActivityTracker.shared

    @State private var showSettings = false
    @State private var showChat = false
    @State private var ollamaOnline: Bool?

    @State private var chatMessages: [ChatMessage] = []
    @State private var inputText = ""
    @State private var isSending = false

    private var settings: AISettings { settingsStore.settings }

    var body: some View {
        VStack(spacing: 0) {
            WindowDragHandle(instanceID: instanceID, store: store, title: "AI 助手")
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    actionRow
                    if showSettings { settingsSection }
                    if showChat { chatSection }
                }
                .padding(12)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(cardBackground)
        .onAppear { refreshStatus() }
        .onReceive(NotificationCenter.default.publisher(for: AIAssistantCoordinator.openChatNotification)) { note in
            if (note.object as? UUID) == instanceID {
                showChat = true
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            avatar
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 助手 · \(settings.persona.displayName)")
                    .font(.system(size: 13, weight: .semibold))
                Text(statusLine)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.accentColor.opacity(0.95), Color.purple.opacity(0.75)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ))
                .frame(width: 42, height: 42)
                .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 2)
            Image(systemName: "sparkles")
                .font(.system(size: 19, weight: .semibold))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottomTrailing) {
            Circle()
                .fill(statusColor)
                .frame(width: 11, height: 11)
                .overlay(Circle().strokeBorder(Color(nsColor: .windowBackgroundColor), lineWidth: 2))
                .offset(x: 1, y: 1)
        }
    }

    private var statusColor: Color {
        switch settings.providerKind {
        case .ollama:
            guard let online = ollamaOnline else { return .gray }
            return online ? .green : .red
        case .openAICompatible:
            return .blue
        }
    }

    private var statusLine: String {
        let minutes = Int(activity.todayActiveSeconds / 60)
        let usage = minutes < 60 ? "\(minutes) 分钟" : "\(minutes / 60) 小时 \(minutes % 60) 分"
        let provider: String
        switch settings.providerKind {
        case .ollama:
            let dot = ollamaOnline == nil ? "…" : (ollamaOnline == true ? "在线" : "离线")
            provider = "Ollama \(dot)"
        case .openAICompatible:
            provider = "云端模型"
        }
        return "今日已陪你 \(usage) · \(provider)"
    }

    // MARK: - Actions

    private var actionRow: some View {
        HStack(spacing: 8) {
            Button {
                AIAssistantCoordinator.shared.triggerManual(for: instanceID)
            } label: {
                Label("关心我一下", systemImage: "hand.wave.fill")
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.accentColor, in: Capsule())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)

            Spacer()

            iconToggle(systemName: "bubble.left.and.bubble.right", on: showChat) {
                showChat.toggle()
                if showChat { showSettings = false }
            }
            iconToggle(systemName: "gearshape", on: showSettings) {
                showSettings.toggle()
                if showSettings { showChat = false; refreshStatus() }
            }
        }
    }

    private func iconToggle(systemName: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13))
                .frame(width: 28, height: 26)
                .background(on ? Color.primary.opacity(0.12) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(on ? Color.primary : Color.secondary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Settings

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()

            labeled("模型提供商") {
                Picker("", selection: providerBinding) {
                    ForEach(LLMProviderKind.allCases) { kind in
                        Text(kind.displayName).tag(kind)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            if settings.providerKind == .ollama {
                textRow("服务地址", ollamaBaseURLBinding, placeholder: "http://localhost:11434")
                textRow("模型", ollamaModelBinding, placeholder: "qwen2.5")
                Button("测试连接") { refreshStatus() }
                    .font(.system(size: 11))
                    .buttonStyle(.link)
            } else {
                textRow("服务地址", cloudBaseURLBinding, placeholder: "https://api.openai.com/v1")
                textRow("模型", cloudModelBinding, placeholder: "gpt-4o-mini")
                textRow("API Key", apiKeyBinding, placeholder: "sk-…")
            }

            labeled("人格") {
                Picker("", selection: personaBinding) {
                    ForEach(Persona.allCases) { p in Text(p.displayName).tag(p) }
                }
                .labelsHidden()
            }

            labeled("气泡位置") {
                Picker("", selection: bubbleAnchorBinding) {
                    ForEach(BubbleAnchor.allCases) { a in Text(a.displayName).tag(a) }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
            }

            textRow("提醒时间", scheduleBinding, placeholder: "11:00, 15:30, 19:00")

            HStack(spacing: 8) {
                textRow("免打扰起", quietStartBinding, placeholder: "22:00")
                textRow("止", quietEndBinding, placeholder: "08:00")
            }

            Stepper("每日提醒上限：\(settings.dailyLimit) 次", value: dailyLimitBinding, in: 1...30)
                .font(.system(size: 12))

            Toggle("智能事件提醒（久坐/高负荷）", isOn: eventTriggerBinding)
                .font(.system(size: 12))
            if settings.eventTriggersEnabled {
                Stepper("久坐阈值：\(settings.sittingMinutesThreshold) 分钟",
                        value: sittingBinding, in: 30...240, step: 15)
                    .font(.system(size: 12))
            }

            labeled("上下文来源") {
                VStack(alignment: .leading, spacing: 2) {
                    Toggle("待办", isOn: useTodosBinding).font(.system(size: 12))
                    Toggle("便签", isOn: useNotesBinding).font(.system(size: 12))
                    Toggle("系统指标", isOn: useSystemBinding).font(.system(size: 12))
                    Toggle("屏幕使用/发呆", isOn: useActivityBinding).font(.system(size: 12))
                }
            }
        }
    }

    private func labeled<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            content()
        }
    }

    private func textRow(_ title: String, _ binding: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary)
            NativeTextField(text: binding, placeholder: placeholder, onSubmit: {})
                .frame(height: 20)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    // MARK: - Chat

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            if chatMessages.isEmpty {
                Text("和我聊聊吧，比如「帮我理一下今天的待办」")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(chatMessages) { msg in
                    chatBubble(msg)
                }
            }
            HStack(spacing: 6) {
                NativeTextField(text: $inputText, placeholder: "输入消息…", onSubmit: send)
                    .frame(height: 22)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                Button(action: send) {
                    Image(systemName: isSending ? "ellipsis" : "paperplane.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 28)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .disabled(isSending)
            }
        }
    }

    private func chatBubble(_ msg: ChatMessage) -> some View {
        let isUser = msg.role == .user
        return HStack {
            if isUser { Spacer(minLength: 24) }
            Text(msg.content)
                .font(.system(size: 12))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isUser ? AnyShapeStyle(Color.accentColor.opacity(0.9))
                           : AnyShapeStyle(Color.primary.opacity(0.08)),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .foregroundStyle(isUser ? Color.white : Color.primary)
            if !isUser { Spacer(minLength: 24) }
        }
    }

    private func send() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        inputText = ""
        chatMessages.append(ChatMessage(role: .user, content: text))
        isSending = true
        let history = Array(chatMessages.suffix(10))
        let current = settings
        Task { @MainActor in
            do {
                let reply = try await AIService.shared.converse(history: history, settings: current)
                chatMessages.append(ChatMessage(role: .assistant, content: reply))
            } catch {
                chatMessages.append(ChatMessage(
                    role: .assistant,
                    content: "连不上模型了：\((error as? LLMError)?.errorDescription ?? "请检查设置")"
                ))
            }
            isSending = false
        }
    }

    // MARK: - Status

    private func refreshStatus() {
        guard settings.providerKind == .ollama else {
            ollamaOnline = nil
            return
        }
        let baseURL = settings.ollamaBaseURL
        ollamaOnline = nil
        Task { @MainActor in
            ollamaOnline = await AIService.shared.pingOllama(baseURL: baseURL)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(.regularMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .fill(LinearGradient(
                        colors: [Color.accentColor.opacity(0.06), .clear],
                        startPoint: .top, endPoint: .bottom
                    ))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.12), radius: 10, y: 3)
    }

    // MARK: - Bindings

    private var providerBinding: Binding<LLMProviderKind> {
        Binding(get: { settingsStore.settings.providerKind },
                set: { settingsStore.settings.providerKind = $0; refreshStatus() })
    }
    private var personaBinding: Binding<Persona> {
        Binding(get: { settingsStore.settings.persona },
                set: { settingsStore.settings.persona = $0 })
    }
    private var bubbleAnchorBinding: Binding<BubbleAnchor> {
        Binding(get: { settingsStore.settings.bubbleAnchor },
                set: { settingsStore.settings.bubbleAnchor = $0 })
    }
    private var ollamaBaseURLBinding: Binding<String> {
        Binding(get: { settingsStore.settings.ollamaBaseURL },
                set: { settingsStore.settings.ollamaBaseURL = $0 })
    }
    private var ollamaModelBinding: Binding<String> {
        Binding(get: { settingsStore.settings.ollamaModel },
                set: { settingsStore.settings.ollamaModel = $0 })
    }
    private var cloudBaseURLBinding: Binding<String> {
        Binding(get: { settingsStore.settings.cloudBaseURL },
                set: { settingsStore.settings.cloudBaseURL = $0 })
    }
    private var cloudModelBinding: Binding<String> {
        Binding(get: { settingsStore.settings.cloudModel },
                set: { settingsStore.settings.cloudModel = $0 })
    }
    private var apiKeyBinding: Binding<String> {
        Binding(get: { settingsStore.apiKey },
                set: { settingsStore.apiKey = $0 })
    }
    private var scheduleBinding: Binding<String> {
        Binding(
            get: { settingsStore.settings.scheduleTimes.joined(separator: ", ") },
            set: { newValue in
                let times = newValue
                    .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == " " })
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                settingsStore.settings.scheduleTimes = times
            }
        )
    }
    private var quietStartBinding: Binding<String> {
        Binding(get: { settingsStore.settings.quietStart },
                set: { settingsStore.settings.quietStart = $0 })
    }
    private var quietEndBinding: Binding<String> {
        Binding(get: { settingsStore.settings.quietEnd },
                set: { settingsStore.settings.quietEnd = $0 })
    }
    private var dailyLimitBinding: Binding<Int> {
        Binding(get: { settingsStore.settings.dailyLimit },
                set: { settingsStore.settings.dailyLimit = $0 })
    }
    private var eventTriggerBinding: Binding<Bool> {
        Binding(get: { settingsStore.settings.eventTriggersEnabled },
                set: { settingsStore.settings.eventTriggersEnabled = $0 })
    }
    private var sittingBinding: Binding<Int> {
        Binding(get: { settingsStore.settings.sittingMinutesThreshold },
                set: { settingsStore.settings.sittingMinutesThreshold = $0 })
    }
    private var useTodosBinding: Binding<Bool> {
        Binding(get: { settingsStore.settings.useTodos },
                set: { settingsStore.settings.useTodos = $0 })
    }
    private var useNotesBinding: Binding<Bool> {
        Binding(get: { settingsStore.settings.useNotes },
                set: { settingsStore.settings.useNotes = $0 })
    }
    private var useSystemBinding: Binding<Bool> {
        Binding(get: { settingsStore.settings.useSystemMetrics },
                set: { settingsStore.settings.useSystemMetrics = $0 })
    }
    private var useActivityBinding: Binding<Bool> {
        Binding(get: { settingsStore.settings.useActivity },
                set: { settingsStore.settings.useActivity = $0 })
    }
}

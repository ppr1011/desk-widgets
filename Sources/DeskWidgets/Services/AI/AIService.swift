import Foundation

/// AI 调用编排入口。根据设置挑选提供商,失败降级到本地兜底文案。
final class AIService {
    static let shared = AIService()

    private init() {}

    /// 生成一句气泡提示;任何异常都回退到兜底文案,保证有返回。
    func generateReminder(context: AIContext, settings: AISettings) async -> String {
        let messages = PromptBuilder.buildReminder(context: context, persona: settings.persona)
        do {
            return try await run(messages: messages, settings: settings)
        } catch {
            return FallbackMessages.random(for: context.scene)
        }
    }

    /// 对话模式:附带 System Prompt 后调用模型,异常抛出交由 UI 处理。
    func converse(history: [ChatMessage], settings: AISettings) async throws -> String {
        var messages = [PromptBuilder.conversationSystem(persona: settings.persona)]
        messages.append(contentsOf: history)
        return try await run(messages: messages, settings: settings)
    }

    /// 探测 Ollama 是否可达(用于状态显示)。
    func pingOllama(baseURL: String) async -> Bool {
        let trimmed = baseURL.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "\(trimmed)/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        guard let (_, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse else {
            return false
        }
        return (200..<300).contains(http.statusCode)
    }

    private func run(messages: [ChatMessage], settings: AISettings) async throws -> String {
        let provider = makeProvider(settings)
        let model = settings.providerKind == .ollama ? settings.ollamaModel : settings.cloudModel
        return try await provider.chat(messages: messages, model: model)
    }

    private func makeProvider(_ settings: AISettings) -> LLMProvider {
        switch settings.providerKind {
        case .ollama:
            return OllamaProvider(baseURL: settings.ollamaBaseURL)
        case .openAICompatible:
            return OpenAICompatibleProvider(
                baseURL: settings.cloudBaseURL,
                apiKey: AISettingsStore.shared.apiKey
            )
        }
    }
}
